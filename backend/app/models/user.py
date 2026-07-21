from sqlalchemy import Boolean, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin


class User(Base, UUIDPkMixin, TimestampMixin):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    # 소셜 가입 계정은 비밀번호가 없다
    hashed_password: Mapped[str | None] = mapped_column(String(255), nullable=True)
    nickname: Mapped[str] = mapped_column(String(50), nullable=False)
    credit_balance: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # 소셜 로그인: email | kakao | google
    provider: Mapped[str] = mapped_column(String(20), default="email", server_default="email", nullable=False)
    provider_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    __table_args__ = (
        Index(
            "uq_users_provider_provider_id",
            "provider",
            "provider_id",
            unique=True,
            postgresql_where=provider_id.isnot(None),
        ),
    )
