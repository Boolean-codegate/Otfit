import uuid

from fastapi import APIRouter, Query, status

from app.core.deps import CurrentUser, DbSession
from app.core.errors import AppError
from app.schemas.post import FeedResponse, PlatformOut, PostCreate, PostOut, VoteRequest, VoteResponse
from app.services.posts import PostService

router = APIRouter(tags=["sns"])


@router.post("/posts", response_model=PostOut, status_code=status.HTTP_201_CREATED)
async def create_post(body: PostCreate, user: CurrentUser, session: DbSession):
    return await PostService(session).create(user, body)


@router.get("/feed", response_model=FeedResponse)
async def feed(
    user: CurrentUser,
    session: DbSession,
    sort: str = Query(default="hot", pattern="^(hot|new)$"),
    limit: int = Query(default=20, ge=1, le=50),
    cursor: str | None = None,
):
    try:
        offset = int(cursor) if cursor else 0
    except ValueError:
        raise AppError("cursor가 올바르지 않습니다.", code="VALIDATION_ERROR", status_code=422)
    items = await PostService(session).feed(user, sort=sort, limit=limit, offset=offset)
    next_cursor = str(offset + limit) if len(items) == limit else None
    return {"items": items, "next_cursor": next_cursor}


@router.post("/posts/{post_id}/vote", response_model=VoteResponse)
async def vote(post_id: uuid.UUID, body: VoteRequest, user: CurrentUser, session: DbSession):
    post, reward = await PostService(session).vote(user, post_id, body.choice)
    return {"post": post, "reward_credits": reward}


@router.get("/platforms", response_model=list[PlatformOut])
async def platforms(user: CurrentUser, session: DbSession):
    return await PostService(session).platforms()
