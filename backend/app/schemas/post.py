import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import ORMModel
from app.schemas.product import ProductOut


class PostAuthor(ORMModel):
    id: uuid.UUID
    nickname: str


class PostCreate(BaseModel):
    """내 보정 결과(result_id)로 게시하거나, 데모/외부용으로 URL을 직접 지정."""

    result_id: uuid.UUID | None = None
    product_id: uuid.UUID | None = None
    caption: str = Field(default="", max_length=300)
    before_url: str | None = None
    after_url: str | None = None


class PostOut(ORMModel):
    id: uuid.UUID
    author: PostAuthor
    caption: str
    before_url: str | None
    after_url: str
    product: ProductOut | None
    buy_votes: int
    skip_votes: int
    my_vote: Literal["buy", "skip"] | None = None
    created_at: datetime

    @field_validator("before_url", "after_url", mode="before")
    @classmethod
    def resolve_urls(cls, v):
        if v is None:
            return v
        from app.services.catalog import resolve_product_image_url

        return resolve_product_image_url(str(v))


class FeedResponse(BaseModel):
    items: list[PostOut]
    next_cursor: str | None


class VoteRequest(BaseModel):
    choice: Literal["buy", "skip"]


class VoteResponse(BaseModel):
    post: PostOut
    reward_credits: int  # 이번 투표로 지급된 크레딧 (0이면 미지급)


class PlatformOut(ORMModel):
    id: uuid.UUID
    name: str
