"""add_backlink_usage_tracking

Revision ID: a50da388e316
Revises: abc123
Create Date: 2025-11-01 22:30:31.986558

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a50da388e316'
down_revision = 'abc123'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add backlink usage tracking columns to users table
    op.add_column('users', sa.Column('backlink_rows_used', sa.Integer(), nullable=False, server_default='0'))
    op.add_column('users', sa.Column('backlink_rows_limit', sa.Integer(), nullable=False, server_default='100'))
    op.add_column('users', sa.Column('backlink_usage_reset_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True))


def downgrade() -> None:
    # Remove backlink usage tracking columns from users table
    op.drop_column('users', 'backlink_usage_reset_at')
    op.drop_column('users', 'backlink_rows_limit')
    op.drop_column('users', 'backlink_rows_used')



