"""add_source_to_tracked_keywords

Revision ID: 7f9183758b0e
Revises: add_backlink_analysis
Create Date: 2025-11-04 21:57:11.946059

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '7f9183758b0e'
down_revision = 'add_backlink_analysis'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add source column to tracked_keywords table
    op.add_column('tracked_keywords', sa.Column('source', sa.String(), nullable=True))
    
    # Set default value for existing records
    op.execute("UPDATE tracked_keywords SET source = 'manual' WHERE source IS NULL")
    
    # Make the column non-nullable after setting defaults
    op.alter_column('tracked_keywords', 'source', nullable=False, server_default='manual')


def downgrade() -> None:
    # Remove source column from tracked_keywords table
    op.drop_column('tracked_keywords', 'source')





