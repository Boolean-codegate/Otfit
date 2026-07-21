"""users.moderation_strikes / is_banned — 유해 업로드 반복 시 계정 제한

Revision ID: 0008_moderation_ban
Revises: 0007_user_bio
"""
import sqlalchemy as sa
from alembic import op

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("moderation_strikes", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "users",
        sa.Column("is_banned", sa.Boolean(), nullable=False, server_default="false"),
    )


def downgrade() -> None:
    op.drop_column("users", "is_banned")
    op.drop_column("users", "moderation_strikes")
