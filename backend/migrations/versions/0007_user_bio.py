"""users.bio (소개글)

Revision ID: 0007
Revises: 0006
"""
from alembic import op
import sqlalchemy as sa

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("bio", sa.String(200), nullable=False, server_default=""))


def downgrade() -> None:
    op.drop_column("users", "bio")
