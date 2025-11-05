"""add_target_page_to_tracked_keywords

Revision ID: 64b57f5ecd14
Revises: ed0fee787b9c
Create Date: 2025-11-05 20:15:34.240564

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '64b57f5ecd14'
down_revision = 'ed0fee787b9c'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add target_page column to tracked_keywords table
    op.add_column('tracked_keywords', sa.Column('target_page', sa.String(), nullable=True))


def downgrade() -> None:
    # Remove target_page column from tracked_keywords table
    op.drop_column('tracked_keywords', 'target_page')





