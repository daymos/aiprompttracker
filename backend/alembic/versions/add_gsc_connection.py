"""add gsc connection

Revision ID: add_gsc_connection
Revises: cff87eecf716
Create Date: 2025-11-06 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'add_gsc_connection'
down_revision = 'cff87eecf716'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add GSC access token to users (encrypted, refreshable)
    op.add_column('users', sa.Column('gsc_access_token', sa.String(), nullable=True))
    op.add_column('users', sa.Column('gsc_refresh_token', sa.String(), nullable=True))
    op.add_column('users', sa.Column('gsc_token_expires_at', sa.DateTime(timezone=True), nullable=True))
    
    # Add GSC property URL to projects
    op.add_column('projects', sa.Column('gsc_property_url', sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column('projects', 'gsc_property_url')
    op.drop_column('users', 'gsc_token_expires_at')
    op.drop_column('users', 'gsc_refresh_token')
    op.drop_column('users', 'gsc_access_token')

