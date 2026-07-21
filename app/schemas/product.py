import uuid
from typing import Literal

from pydantic import BaseModel, field_validator

from app.schemas.common import ORMModel


class ProductOut(ORMModel):
    id: uuid.UUID
    title: str
    brand: str
    category: str
    price: int  # 정수(원) — 계약 §0
    currency: str
    stock_status: str
    product_url: str
    image_url: str
    attributes: dict  # {color, pattern, length, material, ...}

    @field_validator("price", mode="before")
    @classmethod
    def price_to_int(cls, v):
        return int(v)


class ProductListResponse(BaseModel):
    items: list[ProductOut]
    next_cursor: str | None


class RecommendationRequest(BaseModel):
    mode: Literal["A_direct", "B_stylist", "C_similar", "D_variation"]
    style_id: str | None = None


class StyleGroup(BaseModel):
    style_id: str
    label: str
    products: list[ProductOut]


class RecommendationResponse(BaseModel):
    photo_id: uuid.UUID
    mode: str
    groups: list[StyleGroup]
    # MODE A(직접 선택)는 평면 리스트 (계약 §4: "groups 없이 products 평면 리스트도 허용")
    products: list[ProductOut] | None = None
