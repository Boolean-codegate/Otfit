import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin

GENERATION_MODES = ("A_direct", "B_stylist", "C_similar", "D_variation")
JOB_STATUSES = ("queued", "analyzing", "searching", "generating", "quality_check", "done", "failed")


class GenerationJob(Base, UUIDPkMixin, TimestampMixin):
    __tablename__ = "generation_jobs"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    photo_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("photos.id", ondelete="CASCADE"), index=True, nullable=False
    )
    mode: Mapped[str] = mapped_column(String(20), nullable=False)
    selected_product_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id", ondelete="SET NULL"), nullable=True
    )
    status: Mapped[str] = mapped_column(String(20), default="queued", index=True, nullable=False)
    progress: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)  # 0.0 ~ 1.0 (계약 §5)
    step_label: Mapped[str | None] = mapped_column(String(50), nullable=True)
    error: Mapped[dict | None] = mapped_column(JSONB, nullable=True)  # {"code": "...", "message": "..."}
    credits_charged: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    # {"styles": ["casual", "formal"]} — 생성 요청 options
    options: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class GenerationResult(Base, UUIDPkMixin, TimestampMixin):
    __tablename__ = "generation_results"

    job_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("generation_jobs.id", ondelete="CASCADE"), index=True, nullable=False
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"), nullable=False
    )
    result_storage_key: Mapped[str] = mapped_column(String(500), nullable=False)
    quality_score: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    identity_preserved: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    style_label: Mapped[str | None] = mapped_column(String(50), nullable=True)
    is_selected: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
