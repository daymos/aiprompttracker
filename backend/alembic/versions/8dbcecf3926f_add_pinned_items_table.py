"""add_pinned_items_table

Revision ID: 8dbcecf3926f
Revises: 7331defdedcc
Create Date: 2025-11-03 22:05:23.014569

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '8dbcecf3926f'
down_revision = '7331defdedcc'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create table without foreign key constraints first
    op.create_table(
        'pinned_items',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), nullable=False),
        sa.Column('project_id', sa.String(), nullable=True),
        sa.Column('content_type', sa.String(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('source_message_id', sa.String(), nullable=True),
        sa.Column('source_conversation_id', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )

    # Add foreign key constraints after table creation
    op.create_foreign_key('fk_pinned_items_user_id', 'pinned_items', 'users', ['user_id'], ['id'])
    op.create_foreign_key('fk_pinned_items_project_id', 'pinned_items', 'projects', ['project_id'], ['id'])


def downgrade() -> None:
    op.drop_table('pinned_items')





