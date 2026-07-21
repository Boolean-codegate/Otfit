"""SNS: posts + post_votes

Revision ID: 0003
Revises: 0002
Create Date: 2026-07-21

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "posts",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("result_id", UUID(as_uuid=True), sa.ForeignKey("generation_results.id", ondelete="SET NULL"), nullable=True),
        sa.Column("product_id", UUID(as_uuid=True), sa.ForeignKey("products.id", ondelete="SET NULL"), nullable=True),
        sa.Column("caption", sa.String(300), nullable=False, server_default=""),
        sa.Column("before_url", sa.String(1000), nullable=True),
        sa.Column("after_url", sa.String(1000), nullable=False),
        sa.Column("buy_votes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("skip_votes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_posts_user_id", "posts", ["user_id"])
    op.create_index("ix_posts_created_at", "posts", ["created_at"])

    op.create_table(
        "post_votes",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("post_id", UUID(as_uuid=True), sa.ForeignKey("posts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("choice", sa.String(10), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("post_id", "user_id", name="uq_post_votes_post_user"),
    )
    op.create_index("ix_post_votes_post_id", "post_votes", ["post_id"])
    op.create_index("ix_post_votes_user_id", "post_votes", ["user_id"])


def downgrade() -> None:
    op.drop_table("post_votes")
    op.drop_table("posts")
