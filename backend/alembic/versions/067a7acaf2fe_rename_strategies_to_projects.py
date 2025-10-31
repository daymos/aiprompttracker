"""rename_strategies_to_projects

Revision ID: 067a7acaf2fe
Revises: 47ba49cefba2
Create Date: 2025-10-31 15:10:15.533551

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '067a7acaf2fe'
down_revision = '47ba49cefba2'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Rename strategies table to projects
    op.rename_table('strategies', 'projects')
    
    # Rename strategy_id column to project_id in tracked_keywords table
    op.alter_column('tracked_keywords', 'strategy_id', new_column_name='project_id')


def downgrade() -> None:
    # Revert: Rename project_id back to strategy_id
    op.alter_column('tracked_keywords', 'project_id', new_column_name='strategy_id')
    
    # Revert: Rename projects table back to strategies
    op.rename_table('projects', 'strategies')

