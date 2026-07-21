"""생성 파이프라인 (6단계) — Celery 워커에서 실행.

1. 입력 검증 → 2. 이미지 분석 → 3. 상품 검색 → 4. 의상 생성
→ 5. 품질 검사 → 6. 결과 제공. 각 단계마다 status/progress/step_label 갱신,
실패 시 크레딧 환불. (계약 §5: progress 0.0~1.0, status 전이값 고정)
"""
import asyncio
import logging
import uuid

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.models import GenerationJob, Photo, PhotoAnalysis, Product
from app.providers.base import GarmentSpec, VisionAnalysis
from app.providers.factory import get_generation_provider, get_vision_provider
from app.repositories.consents import ConsentRepository
from app.repositories.generations import GenerationRepository
from app.repositories.photos import PhotoRepository
from app.repositories.products import ProductRepository
from app.services.catalog import resolve_product_image_url
from app.services.credits import CreditService
from app.services.recommendations import RecommendationService
from app.storage.base import get_storage
from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)

STEP_LABELS = {
    "queued": "대기 중",
    "analyzing": "사진 분석 중",
    "searching": "상품 검색 중",
    "generating": "의상 생성 중",
    "quality_check": "품질 검사 중",
    "done": "완료",
    "failed": "실패",
}


class PipelineFailure(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(message)


@celery_app.task(name="app.workers.tasks.generation_pipeline.run_generation_job")
def run_generation_job(job_id: str) -> None:
    asyncio.run(execute_pipeline(job_id))


async def execute_pipeline(job_id: str) -> None:
    """워커/이거(eager) 공용 진입점. 자체 엔진·세션을 만들어 독립 실행한다."""
    engine = create_async_engine(get_settings().database_url, pool_pre_ping=True)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    try:
        async with factory() as session:
            await _run(session, uuid.UUID(job_id))
    finally:
        await engine.dispose()


async def _set_status(session: AsyncSession, job: GenerationJob, status: str, progress: float) -> None:
    job.status = status
    job.progress = progress
    job.step_label = STEP_LABELS[status]
    await session.commit()


async def _run(session: AsyncSession, job_id: uuid.UUID) -> None:
    settings = get_settings()
    jobs = GenerationRepository(session)
    photos = PhotoRepository(session)
    storage = get_storage()

    job = await jobs.get_job(job_id)
    if job is None:
        logger.error("generation job %s not found", job_id)
        return

    try:
        # ── 1. 입력 검증 ──────────────────────────────────────────────
        await _set_status(session, job, "analyzing", 0.1)
        photo = await photos.get(job.photo_id)
        if photo is None or photo.deleted_at is not None:
            raise PipelineFailure("INVALID_PHOTO", "사진이 삭제되었거나 존재하지 않습니다.")
        if not await ConsentRepository(session).has_granted(job.user_id, "image_processing"):
            raise PipelineFailure("INVALID_PHOTO", "이미지 처리 동의가 철회되었습니다.")
        photo_bytes = storage.load(photo.storage_key)

        # ── 2. 이미지 분석 (없으면 지금 수행) ─────────────────────────
        analysis = await photos.get_analysis(job.photo_id)
        if analysis is None:
            analysis = await _analyze_now(session, photos, photo, photo_bytes)
        if not analysis.is_valid:
            raise PipelineFailure("INVALID_PHOTO", f"생성 범위 밖 사진입니다: {analysis.reject_reason}")
        vision = _to_vision(analysis)

        # ── 3. 상품 검색 ──────────────────────────────────────────────
        await _set_status(session, job, "searching", 0.35)
        candidates = await _pick_candidates(session, job, analysis)
        if not candidates:
            raise PipelineFailure("GENERATION_FAILED", "적용할 상품 후보를 찾지 못했습니다.")

        # ── 4. 의상 생성 + 5. 품질 검사 (후보별 재시도 포함) ──────────
        await _set_status(session, job, "generating", 0.6)
        generation = get_generation_provider()
        vision_provider = get_vision_provider()
        survivors = []
        for index, (product, style_label, base_seed) in enumerate(candidates):
            garment = GarmentSpec(
                product_id=str(product.id),
                title=product.title,
                brand=product.brand,
                category=product.category,
                attributes=product.attributes,
                # R2 key 저장분은 presigned URL로 변환 (Segmind garm_img는 공개 접근 필요)
                image_url=resolve_product_image_url(product.image_url),
            )
            for attempt in range(settings.generation_max_retries + 1):
                generated = await generation.swap_garment(
                    photo_bytes, garment, vision, style=style_label, variation_seed=base_seed + attempt
                )
                report = await vision_provider.assess_quality(photo_bytes, generated)
                if report.identity_preserved and report.quality_score >= settings.quality_score_threshold:
                    survivors.append((product, style_label, generated, report))
                    break
                logger.warning(
                    "job %s candidate %s attempt %s rejected (score=%.2f identity=%s issues=%s)",
                    job.id, product.id, attempt, report.quality_score,
                    report.identity_preserved, report.issues,
                )
        await _set_status(session, job, "quality_check", 0.85)
        if not survivors:
            raise PipelineFailure("GENERATION_FAILED", "품질 기준을 만족하는 결과를 만들지 못했습니다.")

        # ── 6. 결과 제공 ──────────────────────────────────────────────
        for product, style_label, generated, report in survivors:
            key = f"results/{job.user_id}/{job.id}/{uuid.uuid4()}.jpg"
            storage.save(key, generated)
            await jobs.add_result(
                job_id=job.id,
                product_id=product.id,
                result_storage_key=key,
                quality_score=report.quality_score,
                identity_preserved=report.identity_preserved,
                style_label=style_label,
            )
        job.error = None
        await _set_status(session, job, "done", 1.0)
        logger.info("job %s done with %d results", job.id, len(survivors))

    except PipelineFailure as failure:
        await _fail(session, job, failure.code, failure.message)
    except Exception:
        logger.exception("job %s crashed", job_id)
        await _fail(session, job, "GENERATION_FAILED", "생성 중 오류가 발생했습니다.")


async def _fail(session: AsyncSession, job: GenerationJob, code: str, message: str) -> None:
    await session.rollback()
    job.error = {"code": code, "message": message}
    job.status = "failed"
    job.progress = 1.0
    job.step_label = STEP_LABELS["failed"]
    if job.credits_charged > 0:
        # 실패 시 크레딧 자동 환불 (계약 §5)
        await CreditService(session).refund(job.user_id, job.credits_charged, "refund")
    await session.commit()


async def _analyze_now(
    session: AsyncSession, photos: PhotoRepository, photo: Photo, photo_bytes: bytes
) -> PhotoAnalysis:
    """분석 엔드포인트를 거치지 않고 생성이 요청된 경우의 폴백 (검증 로직 동일)."""
    from app.services.photos import PhotoService

    service = PhotoService(session)
    vision = await get_vision_provider().analyze(photo_bytes)
    reject_reason = service._validate(photo, vision)
    analysis = await photos.upsert_analysis(
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
    await session.commit()
    return analysis


def _to_vision(analysis: PhotoAnalysis) -> VisionAnalysis:
    return VisionAnalysis(
        person_count=analysis.person_count,
        pose=analysis.pose,
        garment_regions=analysis.garment_regions,
        occlusion_score=analysis.occlusion_score,
        background_tags=analysis.background_tags,
        lighting=analysis.lighting,
        color_palette=analysis.color_palette,
        style_suggestions=analysis.style_suggestions,
        is_valid=analysis.is_valid,
        reject_reason=analysis.reject_reason,
    )


async def _pick_candidates(
    session: AsyncSession, job: GenerationJob, analysis: PhotoAnalysis
) -> list[tuple[Product, str | None, int]]:
    """모드별 (상품, 스타일 라벨, variation 시드) 후보 목록."""
    products = ProductRepository(session)

    if job.mode == "A_direct":
        product = await products.get(job.selected_product_id)
        return [(product, product.attributes.get("style"), 0)] if product else []

    if job.mode == "C_similar":
        base = await products.get(job.selected_product_id)
        if base is None:
            return []
        similar = await products.similar_to(base, limit=3)
        return [(p, p.attributes.get("style"), 0) for p in similar] or [(base, base.attributes.get("style"), 0)]

    if job.mode == "D_variation":
        product = await products.get(job.selected_product_id)
        if product is None:
            return []
        style = product.attributes.get("style")
        return [(product, style, 10), (product, style, 20)]

    # B_stylist: 스타일 제안별 상위 상품 1개씩
    ranked = await RecommendationService(session).ranked_products(analysis)
    if not ranked:
        return []
    styles = list((job.options or {}).get("styles") or [])
    if not styles:
        styles = [s.get("style") for s in analysis.style_suggestions if s.get("style")][:3]
    candidates: list[tuple[Product, str | None, int]] = []
    used: set[uuid.UUID] = set()
    for style in styles:
        pick = next(
            (p for p in ranked if p.attributes.get("style") == style and p.id not in used),
            next((p for p in ranked if p.id not in used), None),
        )
        if pick:
            used.add(pick.id)
            candidates.append((pick, style, 0))
    return candidates
