import uuid

from fastapi import APIRouter, Query, status

from app.core.deps import CurrentUser, DbSession
from app.core.errors import AppError
from app.schemas.generation import OkResponse
from app.schemas.mypage import FavoriteListResponse, MyFittingsResponse, MyPhotosResponse
from app.services.mypage import MyPageService

router = APIRouter(tags=["mypage"])


def _offset(cursor: str | None) -> int:
    try:
        return int(cursor) if cursor else 0
    except ValueError:
        raise AppError("cursor가 올바르지 않습니다.", code="VALIDATION_ERROR", status_code=422)


@router.get("/me/fittings", response_model=MyFittingsResponse)
async def my_fittings(
    user: CurrentUser,
    session: DbSession,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = None,
):
    return await MyPageService(session).fittings(user.id, limit, _offset(cursor))


@router.get("/me/photos", response_model=MyPhotosResponse)
async def my_photos(
    user: CurrentUser,
    session: DbSession,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = None,
):
    return await MyPageService(session).photos(user.id, limit, _offset(cursor))


@router.get("/me/favorites", response_model=FavoriteListResponse)
async def my_favorites(user: CurrentUser, session: DbSession):
    return {"items": await MyPageService(session).favorites(user.id)}


@router.put("/me/favorites/{product_id}", response_model=OkResponse)
async def add_favorite(product_id: uuid.UUID, user: CurrentUser, session: DbSession):
    await MyPageService(session).add_favorite(user.id, product_id)
    return {"ok": True}


@router.delete("/me/favorites/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_favorite(product_id: uuid.UUID, user: CurrentUser, session: DbSession):
    await MyPageService(session).remove_favorite(user.id, product_id)
