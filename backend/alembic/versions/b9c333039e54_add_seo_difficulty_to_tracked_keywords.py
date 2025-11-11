"""add_seo_difficulty_to_tracked_keywords

Revision ID: b9c333039e54
Revises: 9bf224912207
Create Date: 2025-11-11 14:20:34.662763

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'b9c333039e54'
down_revision = '9bf224912207'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add seo_difficulty column to tracked_keywords
    op.add_column('tracked_keywords', sa.Column('seo_difficulty', sa.Integer(), nullable=True))


def downgrade() -> None:
    # Remove seo_difficulty column from tracked_keywords
    op.drop_column('tracked_keywords', 'seo_difficulty')






