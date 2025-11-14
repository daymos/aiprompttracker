"""Add intent, cpc, and trend columns to tracked_keywords

Revision ID: add_intent_cpc_trend
Revises: 
Create Date: 2024-01-15 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'add_intent_cpc_trend'
down_revision = 'c20ff9124741'  # Latest migration
branch_labels = None
depends_on = None


def upgrade():
    # Add new columns to tracked_keywords table
    op.add_column('tracked_keywords', sa.Column('intent', sa.String(), nullable=True))
    op.add_column('tracked_keywords', sa.Column('cpc', sa.Float(), nullable=True))
    op.add_column('tracked_keywords', sa.Column('trend', sa.Float(), nullable=True))


def downgrade():
    # Remove columns if we need to rollback
    op.drop_column('tracked_keywords', 'trend')
    op.drop_column('tracked_keywords', 'cpc')
    op.drop_column('tracked_keywords', 'intent')

