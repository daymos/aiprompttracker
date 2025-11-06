"""add_source_to_tracked_keywords

Revision ID: 536a24a615c9
Revises: add_gsc_connection
Create Date: 2025-11-06 11:55:26.635802

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '536a24a615c9'
down_revision = 'add_gsc_connection'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add source column to tracked_keywords table
    op.add_column('tracked_keywords', sa.Column('source', sa.String(), nullable=True))
    
    # Set existing keywords to 'manual' by default
    op.execute("UPDATE tracked_keywords SET source = 'manual' WHERE source IS NULL")
    
    # Make the column non-nullable after setting defaults
    op.alter_column('tracked_keywords', 'source', nullable=False, server_default='manual')


def downgrade() -> None:
    # Remove source column
    op.drop_column('tracked_keywords', 'source')






