import uuid

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin


class PhotoAnalysis(Base, UUIDPkMixin, TimestampMixin):
    __tablename__ = "photo_analyses"

    photo_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("photos.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    person_count: Mapped[int] = mapped_column(Integer, nullable=False)
    pose: Mapped[str] = mapped_column(String(30), nullable=False)
    # [{"type": "top", "bbox": [x, y, w, h]}, ...] — 계약 §3 analyze 형식
    garment_regions: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    occlusion_score: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    background_tags: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    lighting: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    color_palette: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    # [{"id": "st_1", "label": "청량한 휴양지룩", "style": "casual"}, ...]
    # style 키는 상품 attributes.style 매칭용 내부 필드 (API 응답에는 id/label만 노출)
    style_suggestions: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    is_valid: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    # MULTIPLE_PERSONS | HEAVY_OCCLUSION | UNSUPPORTED_POSE | LOW_RESOLUTION
    reject_reason: Mapped[str | None] = mapped_column(String(50), nullable=True)
