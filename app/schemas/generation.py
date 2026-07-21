import uuid
from typing import Literal

from pydantic import BaseModel

from app.schemas.product import ProductOut

GenerationMode = Literal["A_direct", "B_stylist", "C_similar", "D_variation"]


class GenerationOptions(BaseModel):
    styles: list[str] = []


class GenerationCreateRequest(BaseModel):
    photo_id: uuid.UUID
    mode: GenerationMode
    product_id: uuid.UUID | None = None  # A_direct / C_similar / D_variation 기준 상품
    options: GenerationOptions = GenerationOptions()


class GenerationCreateResponse(BaseModel):
    """POST /generations (202)"""

    job_id: uuid.UUID
    status: str
    credits_charged: int


class GenerationStatusResponse(BaseModel):
    """GET /generations/{job_id} (200) — 프론트 2초 폴링"""

    job_id: uuid.UUID
    status: str  # queued|analyzing|searching|generating|quality_check|done|failed
    progress: float  # 0.0 ~ 1.0
    step_label: str | None
    error: dict | None  # {"code": "...", "message": "..."}


class GenerationResultOut(BaseModel):
    id: uuid.UUID
    product_id: uuid.UUID
    result_url: str
    style_label: str | None
    quality_score: float
    identity_preserved: bool
    is_selected: bool
    disclaimer: str


class GenerationResultsResponse(BaseModel):
    job_id: uuid.UUID
    results: list[GenerationResultOut]


class OkResponse(BaseModel):
    ok: bool = True


class ShopResponse(BaseModel):
    """GET /results/{id}/shop (200)"""

    applied_product: ProductOut
    similar_products: list[ProductOut]


class ExportRequest(BaseModel):
    ratio: str | None = None  # "4:5" 등 "W:H", 생략 시 원본 비율
    hi_res: bool = False
    remove_watermark: bool = False


class ExportResponse(BaseModel):
    export_url: str
    watermark: bool
