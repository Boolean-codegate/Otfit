import io
import uuid
from datetime import datetime, timedelta, timezone

from PIL import Image, UnidentifiedImageError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError, ForbiddenError, InvalidPhotoError, NotFoundError
from app.models import Photo, PhotoAnalysis
from app.providers.base import VisionAnalysis
from app.providers.factory import get_vision_provider
from app.providers.moderation import get_moderation_provider
from app.repositories.consents import ConsentRepository
from app.repositories.photos import PhotoRepository
from app.storage.base import get_storage


class PhotoService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.photos = PhotoRepository(session)
        self.storage = get_storage()
        self.settings = get_settings()

    async def upload(
        self, user_id: uuid.UUID, data: bytes, consent_image_processing: bool
    ) -> Photo:
        if not consent_image_processing:
            raise AppError(
                "이미지 처리 동의(consent_image_processing=true)가 필요합니다.",
                code="VALIDATION_ERROR",
                status_code=422,
            )
        # 업로드 시점 동의를 기록 (동의 이력 테이블과 일원화)
        await ConsentRepository(self.session).upsert(user_id, "image_processing", True)

        # 업로드 크기 제한 (DoS·스토리지 남용 방지)
        max_bytes = self.settings.max_upload_mb * 1024 * 1024
        if len(data) > max_bytes:
            raise AppError(
                f"이미지가 너무 큽니다 (최대 {self.settings.max_upload_mb}MB).",
                code="VALIDATION_ERROR",
                status_code=413,
            )

        try:
            with Image.open(io.BytesIO(data)) as im:
                im.verify()
            # 재인코딩으로 EXIF(GPS·기기정보 등) 메타데이터 제거 + 파일 포맷 정규화
            with Image.open(io.BytesIO(data)) as im:
                clean = im.convert("RGB")
                width, height = clean.size
                buf = io.BytesIO()
                clean.save(buf, format="JPEG", quality=92)
                data = buf.getvalue()
        except UnidentifiedImageError as exc:
            raise InvalidPhotoError("이미지 파일이 아닙니다.") from exc

        # 유해 콘텐츠(나체·성적·폭력 등) 차단 — 저장 전 최상류에서 거부
        verdict = await get_moderation_provider().check(data)
        if verdict.flagged:
            raise InvalidPhotoError(
                "커뮤니티 가이드라인에 맞지 않는 이미지입니다.",
                detail={"reject_reason": "UNSAFE_CONTENT", "categories": verdict.categories},
            )

        photo_id = uuid.uuid4()
        key = f"photos/{user_id}/{photo_id}.jpg"
        self.storage.save(key, data)

        photo = await self.photos.create(
            id=photo_id,
            user_id=user_id,
            storage_key=key,
            width=width,
            height=height,
            status="uploaded",
            delete_after=datetime.now(timezone.utc) + timedelta(days=self.settings.photo_retention_days),
        )
        await self.session.commit()
        return photo

    def storage_url(self, photo: Photo) -> str:
        return self.storage.url_for(photo.storage_key)

    async def get_owned(self, user_id: uuid.UUID, photo_id: uuid.UUID) -> Photo:
        photo = await self.photos.get(photo_id)
        if photo is None or photo.deleted_at is not None:
            raise NotFoundError("사진을 찾을 수 없습니다.")
        if photo.user_id != user_id:
            raise ForbiddenError("본인 사진만 접근할 수 있습니다.")
        return photo

    async def delete(self, user_id: uuid.UUID, photo_id: uuid.UUID) -> None:
        """사용자 요청 즉시 삭제 (개인정보 정책)."""
        photo = await self.get_owned(user_id, photo_id)
        self.storage.delete(photo.storage_key)
        photo.deleted_at = datetime.now(timezone.utc)
        photo.status = "deleted"
        await self.session.commit()

    async def analyze(self, user_id: uuid.UUID, photo_id: uuid.UUID) -> PhotoAnalysis:
        """파이프라인 1~2단계와 동일 로직: VisionProvider 분석 + MVP 범위 검증."""
        photo = await self.get_owned(user_id, photo_id)
        data = self.storage.load(photo.storage_key)
        vision = await get_vision_provider().analyze(data)

        reject_reason = self._validate(photo, vision)
        analysis = await self.photos.upsert_analysis(
            photo.id,
            person_count=vision.person_count,
            pose=vision.pose,
            garment_regions=vision.garment_regions,
            occlusion_score=vision.occlusion_score,
            background_tags=vision.background_tags,
            lighting=vision.lighting,
            color_palette=vision.color_palette,
            style_suggestions=vision.style_suggestions,
            is_valid=reject_reason is None,
            reject_reason=reject_reason,
        )
        photo.status = "analyzed" if reject_reason is None else "rejected"
        await self.session.commit()
        return analysis

    def _validate(self, photo: Photo, vision: VisionAnalysis) -> str | None:
        """계약 §3 reject_reason: MULTIPLE_PERSONS|HEAVY_OCCLUSION|UNSUPPORTED_POSE|LOW_RESOLUTION"""
        s = self.settings
        if min(photo.width, photo.height) < s.min_photo_short_side:
            return "LOW_RESOLUTION"
        if not vision.is_valid and vision.reject_reason:
            return vision.reject_reason
        if vision.person_count != 1:
            return "MULTIPLE_PERSONS"
        if vision.pose not in s.allowed_poses:
            return "UNSUPPORTED_POSE"
        if vision.occlusion_score > s.max_occlusion_score:
            return "HEAVY_OCCLUSION"
        if not any(r.get("bbox") for r in vision.garment_regions):
            return "HEAVY_OCCLUSION"
        return None
