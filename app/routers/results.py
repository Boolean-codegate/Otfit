import uuid

from fastapi import APIRouter

from app.core.deps import CurrentUser, DbSession
from app.schemas.generation import ExportRequest, ExportResponse, ShopResponse
from app.services.exports import ExportService
from app.services.shop import ShopService

router = APIRouter(tags=["results"])


@router.get("/results/{result_id}/shop", response_model=ShopResponse)
async def shop(result_id: uuid.UUID, user: CurrentUser, session: DbSession):
    return await ShopService(session).shop_for_result(user.id, result_id)


@router.post("/results/{result_id}/export", response_model=ExportResponse)
async def export(result_id: uuid.UUID, body: ExportRequest, user: CurrentUser, session: DbSession):
    return await ExportService(session).export(
        user.id, result_id, body.ratio, body.hi_res, body.remove_watermark
    )
