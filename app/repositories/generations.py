import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import GenerationJob, GenerationResult


class GenerationRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create_job(self, **kwargs) -> GenerationJob:
        job = GenerationJob(**kwargs)
        self.session.add(job)
        await self.session.flush()
        return job

    async def get_job(self, job_id: uuid.UUID) -> GenerationJob | None:
        return await self.session.get(GenerationJob, job_id)

    async def add_result(self, **kwargs) -> GenerationResult:
        result = GenerationResult(**kwargs)
        self.session.add(result)
        await self.session.flush()
        return result

    async def results_for_job(self, job_id: uuid.UUID) -> list[GenerationResult]:
        result = await self.session.execute(
            select(GenerationResult)
            .where(GenerationResult.job_id == job_id)
            .order_by(GenerationResult.created_at)
        )
        return list(result.scalars())

    async def get_result(self, result_id: uuid.UUID) -> GenerationResult | None:
        return await self.session.get(GenerationResult, result_id)

    async def select_result(self, job_id: uuid.UUID, result_id: uuid.UUID) -> GenerationResult | None:
        results = await self.results_for_job(job_id)
        selected = None
        for r in results:
            r.is_selected = r.id == result_id
            if r.is_selected:
                selected = r
        await self.session.flush()
        return selected
