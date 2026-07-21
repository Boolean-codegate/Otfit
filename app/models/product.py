import uuid

from pgvector.sqlalchemy import Vector
from sqlalchemy import ForeignKey, Numeric, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin

EMBEDDING_DIM = 512

# MVP: 상의류만 취급
PRODUCT_CATEGORIES = ("top", "jacket", "shirt", "dress")
STOCK_STATUSES = ("in_stock", "low_stock", "out_of_stock")


class Product(Base, UUIDPkMixin, TimestampMixin):
    __tablename__ = "products"
    __table_args__ = (UniqueConstraint("partner_id", "external_id", name="uq_products_partner_external"),)

    partner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("partners.id", ondelete="CASCADE"), index=True, nullable=False
    )
    external_id: Mapped[str] = mapped_column(String(100), nullable=False)
    title: Mapped[str] = mapped_column(String(300), nullable=False)
    brand: Mapped[str] = mapped_column(String(100), nullable=False)
    category: Mapped[str] = mapped_column(String(30), index=True, nullable=False)
    price: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="KRW", nullable=False)
    stock_status: Mapped[str] = mapped_column(String(20), default="in_stock", nullable=False)
    product_url: Mapped[str] = mapped_column(String(1000), nullable=False)
    image_url: Mapped[str] = mapped_column(String(1000), nullable=False)
    image_embedding: Mapped[list | None] = mapped_column(Vector(EMBEDDING_DIM), nullable=True)
    text_embedding: Mapped[list | None] = mapped_column(Vector(EMBEDDING_DIM), nullable=True)
    attributes: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
