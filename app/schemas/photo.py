import uuid
from datetime import datetime

from pydantic import BaseModel

from app.schemas.common import ORMModel


class PhotoUploadResponse(BaseModel):
    """POST /photos (201)"""

    id: uuid.UUID
    storage_url: str
    width: int
    height: int
    status: str
    uploaded_at: datetime


class GarmentRegion(BaseModel):
    type: str
    bbox: list[int]  # [x, y, w, h]


class StyleSuggestion(BaseModel):
    id: str
    label: str


class PhotoAnalyzeResponse(ORMModel):
    """POST /photos/{id}/analyze (200) — 계약 §3"""

    photo_id: uuid.UUID
    is_valid: bool
    reject_reason: str | None  # MULTIPLE_PERSONS | HEAVY_OCCLUSION | UNSUPPORTED_POSE | LOW_RESOLUTION
    person_count: int
    pose: str
    garment_regions: list[GarmentRegion]
    occlusion_score: float
    background_tags: list[str]
    lighting: dict
    color_palette: list[str]
    style_suggestions: list[StyleSuggestion]
