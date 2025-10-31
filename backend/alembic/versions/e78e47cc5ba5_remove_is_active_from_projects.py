"""remove_is_active_from_projects

Revision ID: e78e47cc5ba5
Revises: 067a7acaf2fe
Create Date: 2025-10-31 15:35:53.017963

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'e78e47cc5ba5'
down_revision = '067a7acaf2fe'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Remove is_active column from projects table
    op.drop_column('projects', 'is_active')


def downgrade() -> None:
    # Add back is_active column (if needed to rollback)
    op.add_column('projects', sa.Column('is_active', sa.Boolean(), server_default='true', nullable=False))

