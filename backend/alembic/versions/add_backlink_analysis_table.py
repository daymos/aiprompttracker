"""add backlink analysis table

Revision ID: add_backlink_analysis
Revises: fe6cf7bab06f
Create Date: 2025-01-04 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'add_backlink_analysis'
down_revision = '8dbcecf3926f'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('backlink_analyses',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('project_id', sa.String(), nullable=False),
        sa.Column('total_backlinks', sa.Integer(), nullable=True),
        sa.Column('referring_domains', sa.Integer(), nullable=True),
        sa.Column('domain_authority', sa.Integer(), nullable=True),
        sa.Column('raw_data', sa.JSON(), nullable=False),
        sa.Column('analyzed_at', sa.DateTime(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['project_id'], ['projects.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_backlink_analyses_project_id'), 'backlink_analyses', ['project_id'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_backlink_analyses_project_id'), table_name='backlink_analyses')
    op.drop_table('backlink_analyses')

