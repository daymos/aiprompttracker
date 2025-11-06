"""add_is_active_to_tracked_keywords

Revision ID: 9bf224912207
Revises: 536a24a615c9
Create Date: 2025-11-06 12:08:07.518319

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '9bf224912207'
down_revision = '536a24a615c9'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add is_active column to tracked_keywords table
    op.add_column('tracked_keywords', sa.Column('is_active', sa.Integer(), nullable=True))
    
    # Set existing keywords to active (1) by default
    op.execute("UPDATE tracked_keywords SET is_active = 1 WHERE is_active IS NULL")
    
    # Make the column non-nullable after setting defaults
    op.alter_column('tracked_keywords', 'is_active', nullable=False, server_default='1')


def downgrade() -> None:
    # Remove is_active column
    op.drop_column('tracked_keywords', 'is_active')






