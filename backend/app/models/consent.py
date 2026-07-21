import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin

# 동의 종류: image_processing(필수), marketing, reuse(결과 이미지 재활용)
CONSENT_TYPES = ("image_processing", "marketing", "reuse")


class Consent(Base, UUIDPkMixin, TimestampMixin):
    __tablename__ = "consents"
    __table_args__ = (UniqueConstraint("user_id", "type", name="uq_consents_user_type"),)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    type: Mapped[str] = mapped_column(String(30), nullable=False)
    granted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    granted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
