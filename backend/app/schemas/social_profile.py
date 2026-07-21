import uuid

from pydantic import BaseModel

from app.schemas.post import PostOut


class UserSummary(BaseModel):
    id: uuid.UUID
    nickname: str


class UserSearchResponse(BaseModel):
    items: list[UserSummary]


class UserProfileOut(BaseModel):
    """계약 §12 GET /users/{id}/profile"""

    id: uuid.UUID
    nickname: str
    post_count: int
    follower_count: int
    following_count: int
    is_following: bool
    is_me: bool


class UserPostsResponse(BaseModel):
    items: list[PostOut]
    next_cursor: str | None
