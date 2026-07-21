import uuid

from fastapi import APIRouter, status

from app.core.config import get_settings
from app.core.deps import CurrentUser, DbSession
from app.schemas.generation import (
    GenerationCreateRequest,
    GenerationCreateResponse,
    GenerationResultsResponse,
    GenerationStatusResponse,
    OkResponse,
)
from app.services.generations import GenerationService
from app.storage.base import get_storage

router = APIRouter(tags=["generations"])


@router.post("/generations", response_model=GenerationCreateResponse, status_code=status.HTTP_202_ACCEPTED)
async def create_generation(body: GenerationCreateRequest, user: CurrentUser, session: DbSession):
    job = await GenerationService(session).create_job(
        user.id, body.photo_id, body.mode, body.product_id, body.options.model_dump()
    )
    return {"job_id": job.id, "status": job.status, "credits_charged": job.credits_charged}


@router.get("/generations/{job_id}", response_model=GenerationStatusResponse)
async def poll_generation(job_id: uuid.UUID, user: CurrentUser, session: DbSession):
    job = await GenerationService(session).get_owned_job(user.id, job_id)
    return {
        "job_id": job.id,
        "status": job.status,
        "progress": job.progress,
        "step_label": job.step_label,
        "error": job.error,
    }


@router.get("/generations/{job_id}/results", response_model=GenerationResultsResponse)
async def generation_results(job_id: uuid.UUID, user: CurrentUser, session: DbSession):
    service = GenerationService(session)
    job = await service.get_owned_job(user.id, job_id)
    results = await service.visible_results(job)
    storage = get_storage()
    disclaimer = get_settings().disclaimer
    return {
        "job_id": job.id,
        "results": [
            {
                "id": r.id,
                "product_id": r.product_id,
                "result_url": storage.url_for(r.result_storage_key),
                "style_label": r.style_label,
                "quality_score": r.quality_score,
                "identity_preserved": r.identity_preserved,
                "is_selected": r.is_selected,
                "disclaimer": disclaimer,
            }
            for r in results
        ],
    }


@router.post("/generations/{job_id}/results/{result_id}/select", response_model=OkResponse)
async def select_result(job_id: uuid.UUID, result_id: uuid.UUID, user: CurrentUser, session: DbSession):
    await GenerationService(session).select_result(user.id, job_id, result_id)
    return {"ok": True}
