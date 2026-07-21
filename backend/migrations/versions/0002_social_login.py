"""social login: provider fields + nullable password

Revision ID: 0002
Revises: 0001
Create Date: 2026-07-21

"""
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("provider", sa.String(20), nullable=False, server_default="email"))
    op.add_column("users", sa.Column("provider_id", sa.String(255), nullable=True))
    op.alter_column("users", "hashed_password", existing_type=sa.String(255), nullable=True)
    op.create_index(
        "uq_users_provider_provider_id",
        "users",
        ["provider", "provider_id"],
        unique=True,
        postgresql_where=sa.text("provider_id IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("uq_users_provider_provider_id", table_name="users")
    op.alter_column("users", "hashed_password", existing_type=sa.String(255), nullable=False)
    op.drop_column("users", "provider_id")
    op.drop_column("users", "provider")
