import uuid
from datetime import datetime

from pydantic import BaseModel

from app.schemas.photo import PhotoUploadResponse
from app.schemas.product import ProductOut


class MyFittingItem(BaseModel):
    """계약 §11 GET /me/fittings 항목."""

    result_id: uuid.UUID
    job_id: uuid.UUID
    result_url: str
    # 비포(원본 업로드 사진) — 게시 시 '비포 함께 공개' 옵션에 사용
    source_photo_url: str | None = None
    # 이미 피드에 게시했으면 그 게시물 id ('피드 보러 가기' 분기)
    post_id: uuid.UUID | None = None
    style_label: str | None
    product: ProductOut | None
    created_at: datetime


class MyFittingsResponse(BaseModel):
    items: list[MyFittingItem]
    next_cursor: str | None


class MyPhotosResponse(BaseModel):
    items: list[PhotoUploadResponse]
    next_cursor: str | None


class FavoriteListResponse(BaseModel):
    items: list[ProductOut]
