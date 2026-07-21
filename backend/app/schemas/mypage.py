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
