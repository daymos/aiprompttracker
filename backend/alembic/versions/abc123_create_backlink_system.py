"""create_backlink_system

Revision ID: abc123
Revises: e78e47cc5ba5
Create Date: 2025-11-01 20:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'abc123'
down_revision = 'e78e47cc5ba5'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create directories table
    op.create_table(
        'directories',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('url', sa.String(), nullable=False),
        sa.Column('category', sa.String(), nullable=True),
        sa.Column('submission_url', sa.String(), nullable=True),
        sa.Column('is_active', sa.Integer(), nullable=True, server_default='1'),
        sa.Column('requires_manual', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('automation_method', sa.String(), nullable=True),
        sa.Column('form_fields', sa.Text(), nullable=True),
        sa.Column('domain_authority', sa.Integer(), nullable=True),
        sa.Column('tier', sa.String(), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('name')
    )
    
    # Create backlink_campaigns table
    op.create_table(
        'backlink_campaigns',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('project_id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('total_directories', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('category_filter', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['project_id'], ['projects.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_backlink_campaigns_project_id'), 'backlink_campaigns', ['project_id'], unique=False)
    op.create_index(op.f('ix_backlink_campaigns_user_id'), 'backlink_campaigns', ['user_id'], unique=False)
    
    # Create backlink_submissions table
    op.create_table(
        'backlink_submissions',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('campaign_id', sa.String(), nullable=False),
        sa.Column('directory_id', sa.String(), nullable=False),
        sa.Column('project_id', sa.String(), nullable=False),
        sa.Column('status', sa.String(), nullable=True, server_default='pending'),
        sa.Column('submission_url', sa.String(), nullable=True),
        sa.Column('submitted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('indexed_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['campaign_id'], ['backlink_campaigns.id'], ),
        sa.ForeignKeyConstraint(['directory_id'], ['directories.id'], ),
        sa.ForeignKeyConstraint(['project_id'], ['projects.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_backlink_submissions_campaign_id'), 'backlink_submissions', ['campaign_id'], unique=False)
    op.create_index(op.f('ix_backlink_submissions_directory_id'), 'backlink_submissions', ['directory_id'], unique=False)
    op.create_index(op.f('ix_backlink_submissions_project_id'), 'backlink_submissions', ['project_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_backlink_submissions_project_id'), table_name='backlink_submissions')
    op.drop_index(op.f('ix_backlink_submissions_directory_id'), table_name='backlink_submissions')
    op.drop_index(op.f('ix_backlink_submissions_campaign_id'), table_name='backlink_submissions')
    op.drop_table('backlink_submissions')
    
    op.drop_index(op.f('ix_backlink_campaigns_user_id'), table_name='backlink_campaigns')
    op.drop_index(op.f('ix_backlink_campaigns_project_id'), table_name='backlink_campaigns')
    op.drop_table('backlink_campaigns')
    
    op.drop_table('directories')

