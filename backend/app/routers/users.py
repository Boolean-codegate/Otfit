import uuid

from fastapi import APIRouter, Query, status

from app.core.deps import CurrentUser, DbSession
from app.core.errors import AppError
from app.schemas.generation import OkResponse
from app.schemas.social_profile import UserPostsResponse, UserProfileOut, UserSearchResponse
from app.services.profiles import ProfileService

router = APIRouter(tags=["users"])


def _resolve_id(raw: str, me: uuid.UUID) -> uuid.UUID:
    """경로의 {id}는 'me' 별칭을 허용한다."""
    if raw == "me":
        return me
    try:
        return uuid.UUID(raw)
    except ValueError:
        raise AppError("사용자 id 형식이 올바르지 않습니다.", code="VALIDATION_ERROR", status_code=422)


@router.get("/users/search", response_model=UserSearchResponse)
async def search_users(
    user: CurrentUser,
    session: DbSession,
    q: str = Query(default="", max_length=50),
):
    return {"items": await ProfileService(session).search(q)}


@router.get("/users/{user_id}/profile", response_model=UserProfileOut)
async def user_profile(user_id: str, user: CurrentUser, session: DbSession):
    return await ProfileService(session).profile(user, _resolve_id(user_id, user.id))


@router.get("/users/{user_id}/posts", response_model=UserPostsResponse)
async def user_posts(
    user_id: str,
    user: CurrentUser,
    session: DbSession,
    limit: int = Query(default=30, ge=1, le=100),
    cursor: str | None = None,
):
    try:
        offset = int(cursor) if cursor else 0
    except ValueError:
        raise AppError("cursor가 올바르지 않습니다.", code="VALIDATION_ERROR", status_code=422)
    return await ProfileService(session).user_posts(
        user, _resolve_id(user_id, user.id), limit, offset
    )


@router.put("/users/{user_id}/follow", response_model=OkResponse)
async def follow(user_id: str, user: CurrentUser, session: DbSession):
    await ProfileService(session).follow(user, _resolve_id(user_id, user.id))
    return {"ok": True}


@router.delete("/users/{user_id}/follow", status_code=status.HTTP_204_NO_CONTENT)
async def unfollow(user_id: str, user: CurrentUser, session: DbSession):
    await ProfileService(session).unfollow(user, _resolve_id(user_id, user.id))


@router.delete("/posts/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_post(post_id: uuid.UUID, user: CurrentUser, session: DbSession):
    await ProfileService(session).delete_post(user, post_id)
