import uuid

from sqlalchemy import ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPkMixin

VOTE_CHOICES = ("buy", "skip")  # 살까 / 말까


class Post(Base, UUIDPkMixin, TimestampMixin):
    """피드 게시물 — 비포/애프터 '이거 어때요?' 투표 카드."""

    __tablename__ = "posts"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    # 내 보정 결과에서 게시한 경우 (데모 시드 게시물은 null 가능)
    result_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("generation_results.id", ondelete="SET NULL"), nullable=True
    )
    # 게시물에 태그된 상품 (구매 연결)
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id", ondelete="SET NULL"), nullable=True
    )
    caption: Mapped[str] = mapped_column(String(300), default="", nullable=False)
    # before는 없을 수 있다 (단일 컷 게시). URL 또는 R2 key.
    before_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    after_url: Mapped[str] = mapped_column(String(1000), nullable=False)
    buy_votes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    skip_votes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)


class PostVote(Base, UUIDPkMixin, TimestampMixin):
    __tablename__ = "post_votes"
    __table_args__ = (UniqueConstraint("post_id", "user_id", name="uq_post_votes_post_user"),)

    post_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("posts.id", ondelete="CASCADE"), index=True, nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    choice: Mapped[str] = mapped_column(String(10), nullable=False)  # buy | skip


class PostComment(Base, UUIDPkMixin, TimestampMixin):
    """게시물 댓글 (계약 §10)."""

    __tablename__ = "post_comments"

    post_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("posts.id", ondelete="CASCADE"), index=True, nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    content: Mapped[str] = mapped_column(String(300), nullable=False)


class Follow(Base, UUIDPkMixin, TimestampMixin):
    """팔로우 관계 (계약 §12)."""

    __tablename__ = "follows"
    __table_args__ = (UniqueConstraint("follower_id", "followee_id", name="uq_follows_pair"),)

    follower_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    followee_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
