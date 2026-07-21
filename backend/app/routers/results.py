import uuid

from fastapi import APIRouter, Response

from app.core.deps import CurrentUser, DbSession
from app.schemas.generation import ExportRequest, ExportResponse, ShopResponse
from app.services.exports import ExportService
from app.services.shop import ShopService

router = APIRouter(tags=["results"])


@router.get("/results/{result_id}/shop", response_model=ShopResponse)
async def shop(result_id: uuid.UUID, user: CurrentUser, session: DbSession):
    return await ShopService(session).shop_for_result(user.id, result_id)


@router.get("/results/{result_id}/export/file")
async def export_file(
    result_id: uuid.UUID,
    user: CurrentUser,
    session: DbSession,
    ratio: str | None = None,
):
    """이미지 바이트 직접 응답 — 프론트가 받아 갤러리 저장(공유 시트)/파일 저장에 사용."""
    data, filename, _ = await ExportService(session).render(
        user.id, result_id, ratio, hi_res=False, remove_watermark=False
    )
    return Response(
        content=data,
        media_type="image/jpeg",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("/results/{result_id}/export", response_model=ExportResponse)
async def export(result_id: uuid.UUID, body: ExportRequest, user: CurrentUser, session: DbSession):
    return await ExportService(session).export(
        user.id, result_id, body.ratio, body.hi_res, body.remove_watermark
    )
