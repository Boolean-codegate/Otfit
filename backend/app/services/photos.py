import io
import uuid
from datetime import datetime, timedelta, timezone

from PIL import Image, UnidentifiedImageError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError, ForbiddenError, InvalidPhotoError, NotFoundError
from app.models import GenerationJob, Photo, PhotoAnalysis, Report, User
from app.providers.base import VisionAnalysis
from app.providers.factory import get_vision_provider
from app.providers.moderation import get_moderation_provider
from app.repositories.consents import ConsentRepository
from app.repositories.photos import PhotoRepository
from app.services.admin_alerts import notify_admin
from app.storage.base import get_storage


# 모더레이션 카테고리 → 사용자 안내용 한글 사유
_GUIDELINE_KO = {
    "sexual": "선정적·성적 콘텐츠",
    "sexual/minors": "미성년자 관련 성적 콘텐츠",
    "violence": "폭력적인 장면",
    "violence/graphic": "유혈·잔혹한 장면",
    "self-harm": "자해 관련 콘텐츠",
    "self_harm": "자해 관련 콘텐츠",
    "harassment": "괴롭힘·모욕적 콘텐츠",
    "hate": "혐오 표현",
}


def _guideline_reasons(categories: list[str]) -> str:
    """카테고리 코드를 사용자에게 보여줄 사유 문구로 변환 (중복 제거, 순서 유지)."""
    seen: list[str] = []
    for category in categories:
        base = category.split("/")[0].replace("_", "-")
        label = _GUIDELINE_KO.get(category) or _GUIDELINE_KO.get(base)
        if label and label not in seen:
            seen.append(label)
    return ", ".join(seen) or "부적절한 콘텐츠"


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
        if verdict.flagged and not verdict.severe:
            # 위험 물품(칼·총) 또는 공포·혐오 이미지 — 차단 + 경고 + 관리자 알림 (스트라이크 없음)
            disturbing = "disturbing" in verdict.categories
            await notify_admin(
                f"⚠️ {'공포·혐오 이미지' if disturbing else '위험 물품 포함 사진'} 차단 — "
                f"user {user_id}, 감지: {', '.join(verdict.categories)}"
            )
            message = (
                "공포감이나 혐오감을 줄 수 있는 사진은 사용할 수 없어요. 다른 사진을 선택해 주세요."
                if disturbing
                else "위험한 물건(무기 등)이 포함된 사진은 사용할 수 없어요. 다른 사진을 선택해 주세요."
            )
            raise InvalidPhotoError(
                message,
                detail={
                    "reject_reason": "DISTURBING_CONTENT" if disturbing else "DANGEROUS_CONTENT",
                    "categories": verdict.categories,
                    "banned": False,
                },
            )
        if verdict.flagged:
            banned = await self._register_violation(user_id, verdict.categories)
            reasons = _guideline_reasons(verdict.categories)
            message = f"커뮤니티 가이드라인 위반으로 사진을 사용할 수 없어요 (사유: {reasons})."
            if banned:
                message += " 반복 위반으로 계정이 제한되었습니다."
            raise InvalidPhotoError(
                message,
                detail={
                    "reject_reason": "UNSAFE_CONTENT",
                    "categories": verdict.categories,
                    "banned": banned,
                },
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

    async def _register_violation(self, user_id: uuid.UUID, categories: list[str]) -> bool:
        """유해 업로드 적발 처리: 스트라이크 누적 → 밴, 자동 신고 접수, 관리자 알림.

        반환값: 이 적발로(또는 이미) 계정이 제한된 상태인지.
        """
        user = await self.session.get(User, user_id)
        banned = False
        label = "(알 수 없음)"
        if user is not None:
            user.moderation_strikes += 1
            if user.moderation_strikes >= self.settings.moderation_ban_strikes:
                user.is_banned = True
            banned = user.is_banned
            label = f"{user.nickname}({user.email})"
        # 관리자가 볼 수 있게 신고함에 자동 접수
        self.session.add(
            Report(
                reporter_id=user_id,
                target_type="photo",
                target_id=None,
                reason="inappropriate",
                detail=f"자동 모더레이션 적발: {', '.join(categories) or 'unknown'}",
            )
        )
        await self.session.commit()
        strikes = user.moderation_strikes if user else "?"
        await notify_admin(
            f"🚨 유해 이미지 업로드 적발 — {label}, 카테고리: {', '.join(categories) or 'unknown'}, "
            f"누적 {strikes}회{' → 계정 제한됨' if banned else ''}"
        )
        return banned

    async def delete(self, user_id: uuid.UUID, photo_id: uuid.UUID) -> None:
        """'저장한 사진' 목록에서 제거.

        피팅에 사용된 사진은 파일을 남겨 피팅 기록/피드의 비포가 유지되도록
        '숨김(hidden)' 처리하고, 한 번도 사용되지 않은 사진만 실제 삭제한다.
        (계정 삭제 시에는 전부 하드 삭제 — privacy 서비스)
        """
        photo = await self.get_owned(user_id, photo_id)
        used_in_fitting = (
            await self.session.execute(
                select(GenerationJob.id).where(GenerationJob.photo_id == photo.id).limit(1)
            )
        ).scalar_one_or_none() is not None
        if used_in_fitting:
            photo.status = "hidden"  # 목록에서만 숨김 — 스토리지 파일 유지
        else:
            self.storage.delete(photo.storage_key)
            photo.status = "deleted"
        photo.deleted_at = datetime.now(timezone.utc)
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
