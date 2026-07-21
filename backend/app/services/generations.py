import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import ForbiddenError, InvalidPhotoError, NotFoundError, AppError
from app.models import GenerationJob, GenerationResult
from app.repositories.consents import ConsentRepository
from app.repositories.generations import GenerationRepository
from app.repositories.photos import PhotoRepository
from app.repositories.products import ProductRepository
from app.services.credits import CreditService

MODES_REQUIRING_PRODUCT = ("A_direct", "C_similar", "D_variation")


class GenerationService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.jobs = GenerationRepository(session)
        self.photos = PhotoRepository(session)
        self.products = ProductRepository(session)
        self.settings = get_settings()

    async def create_job(
        self,
        user_id: uuid.UUID,
        photo_id: uuid.UUID,
        mode: str,
        product_id: uuid.UUID | None,
        options: dict,
    ) -> GenerationJob:
        photo = await self.photos.get(photo_id)
        if photo is None or photo.deleted_at is not None:
            raise NotFoundError("사진을 찾을 수 없습니다.")
        if photo.user_id != user_id:
            raise ForbiddenError("본인 사진만 사용할 수 있습니다.")
        if not await ConsentRepository(self.session).has_granted(user_id, "image_processing"):
            raise ForbiddenError("이미지 처리 동의(image_processing)가 필요합니다.")

        analysis = await self.photos.get_analysis(photo_id)
        if analysis is None:
            raise InvalidPhotoError("먼저 사진 분석(POST /photos/{id}/analyze)을 실행하세요.")
        if not analysis.is_valid:
            raise InvalidPhotoError(
                "이 사진은 생성 범위 밖입니다.", detail={"reject_reason": analysis.reject_reason}
            )

        if mode in MODES_REQUIRING_PRODUCT:
            if product_id is None:
                raise AppError(f"{mode} 모드는 product_id가 필요합니다.", code="VALIDATION_ERROR", status_code=422)
            product = await self.products.get(product_id)
            if product is None:
                raise NotFoundError("상품을 찾을 수 없습니다.")
            if product.stock_status == "out_of_stock":
                raise AppError("품절 상품으로는 생성할 수 없습니다.", code="VALIDATION_ERROR", status_code=422)

        cost = self.settings.generation_cost_credits
        await CreditService(self.session).charge(user_id, cost, "generation")
        job = await self.jobs.create_job(
            user_id=user_id,
            photo_id=photo_id,
            mode=mode,
            selected_product_id=product_id,
            status="queued",
            progress=0.0,
            step_label="대기 중",
            credits_charged=cost,
            options=options,
        )
        await self.session.commit()
        await self._enqueue(job.id)
        return job

    async def _enqueue(self, job_id: uuid.UUID) -> None:
        # 순환 import 방지를 위해 지연 import
        from app.workers.tasks.generation_pipeline import execute_pipeline, run_generation_job

        if self.settings.celery_task_always_eager:
            # 테스트/단일 프로세스 모드: 현재 이벤트 루프에서 즉시 실행
            await execute_pipeline(str(job_id))
        else:
            run_generation_job.delay(str(job_id))

    async def get_owned_job(self, user_id: uuid.UUID, job_id: uuid.UUID) -> GenerationJob:
        job = await self.jobs.get_job(job_id)
        if job is None:
            raise NotFoundError("생성 작업을 찾을 수 없습니다.")
        if job.user_id != user_id:
            raise ForbiddenError("본인 작업만 조회할 수 있습니다.")
        return job

    async def visible_results(self, job: GenerationJob) -> list[GenerationResult]:
        """품질 검사 통과 결과만 노출 (계약 §5: 탈락 결과는 애초에 포함하지 않음)."""
        results = await self.jobs.results_for_job(job.id)
        threshold = self.settings.quality_score_threshold
        return [r for r in results if r.identity_preserved and r.quality_score >= threshold]

    async def select_result(self, user_id: uuid.UUID, job_id: uuid.UUID, result_id: uuid.UUID) -> None:
        job = await self.get_owned_job(user_id, job_id)
        visible_ids = {r.id for r in await self.visible_results(job)}
        if result_id not in visible_ids:
            raise NotFoundError("결과를 찾을 수 없습니다.")
        await self.jobs.select_result(job_id, result_id)
        await self.session.commit()

    async def get_owned_result(self, user_id: uuid.UUID, result_id: uuid.UUID) -> GenerationResult:
        result = await self.jobs.get_result(result_id)
        if result is None:
            raise NotFoundError("결과를 찾을 수 없습니다.")
        job = await self.jobs.get_job(result.job_id)
        if job is None or job.user_id != user_id:
            raise ForbiddenError("본인 결과만 접근할 수 있습니다.")
        return result
