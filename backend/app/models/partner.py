from sqlalchemy import Float, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin


class Partner(Base, UUIDPkMixin, TimestampMixin):
    __tablename__ = "partners"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    catalog_source: Mapped[str] = mapped_column(String(200), nullable=False)
    commission_rate: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    contract_note: Mapped[str | None] = mapped_column(Text, nullable=True)
