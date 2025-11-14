"""create_seo_agent_tables

Revision ID: c2c8ea6c050a
Revises: add_intent_cpc_trend
Create Date: 2025-01-15 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'c2c8ea6c050a'
down_revision = 'add_intent_cpc_trend'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create project_integrations table
    op.create_table('project_integrations',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('project_id', sa.String(), nullable=False),
        sa.Column('cms_type', sa.String(), nullable=False),
        sa.Column('cms_url', sa.String(), nullable=False),
        sa.Column('username', sa.String(), nullable=True),
        sa.Column('encrypted_password', sa.Text(), nullable=True),
        sa.Column('connection_metadata', postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('last_tested_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('last_test_status', sa.String(), nullable=True),
        sa.Column('last_test_error', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['project_id'], ['projects.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_project_integrations_project_id'), 'project_integrations', ['project_id'], unique=False)

    # Create content_tone_profiles table
    op.create_table('content_tone_profiles',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('project_id', sa.String(), nullable=False),
        sa.Column('tone_description', sa.Text(), nullable=True),
        sa.Column('analyzed_posts_count', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('sample_content', sa.Text(), nullable=True),
        sa.Column('tone_metadata', postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['project_id'], ['projects.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('project_id')
    )
    op.create_index(op.f('ix_content_tone_profiles_project_id'), 'content_tone_profiles', ['project_id'], unique=False)

    # Create generated_content table
    op.create_table('generated_content',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('project_id', sa.String(), nullable=False),
        sa.Column('integration_id', sa.String(), nullable=True),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('excerpt', sa.Text(), nullable=True),
        sa.Column('target_keywords', postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column('seo_score', sa.Integer(), nullable=True),
        sa.Column('word_count', sa.Integer(), nullable=True),
        sa.Column('readability_score', sa.Float(), nullable=True),
        sa.Column('status', sa.String(), nullable=True, server_default='draft'),
        sa.Column('published_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('published_url', sa.String(), nullable=True),
        sa.Column('cms_post_id', sa.String(), nullable=True),
        sa.Column('generation_prompt', sa.Text(), nullable=True),
        sa.Column('tone_profile_id', sa.String(), nullable=True),
        sa.Column('generation_metadata', postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['integration_id'], ['project_integrations.id'], ),
        sa.ForeignKeyConstraint(['project_id'], ['projects.id'], ),
        sa.ForeignKeyConstraint(['tone_profile_id'], ['content_tone_profiles.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_generated_content_integration_id'), 'generated_content', ['integration_id'], unique=False)
    op.create_index(op.f('ix_generated_content_project_id'), 'generated_content', ['project_id'], unique=False)

    # Create content_generation_jobs table
    op.create_table('content_generation_jobs',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('project_id', sa.String(), nullable=False),
        sa.Column('generated_content_id', sa.String(), nullable=True),
        sa.Column('job_type', sa.String(), nullable=False),
        sa.Column('status', sa.String(), nullable=True, server_default='pending'),
        sa.Column('progress_percentage', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('input_params', postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column('result_data', postgresql.JSON(astext_type=sa.Text()), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['generated_content_id'], ['generated_content.id'], ),
        sa.ForeignKeyConstraint(['project_id'], ['projects.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_content_generation_jobs_generated_content_id'), 'content_generation_jobs', ['generated_content_id'], unique=False)
    op.create_index(op.f('ix_content_generation_jobs_project_id'), 'content_generation_jobs', ['project_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_content_generation_jobs_project_id'), table_name='content_generation_jobs')
    op.drop_index(op.f('ix_content_generation_jobs_generated_content_id'), table_name='content_generation_jobs')
    op.drop_table('content_generation_jobs')
    op.drop_index(op.f('ix_generated_content_project_id'), table_name='generated_content')
    op.drop_index(op.f('ix_generated_content_integration_id'), table_name='generated_content')
    op.drop_table('generated_content')
    op.drop_index(op.f('ix_content_tone_profiles_project_id'), table_name='content_tone_profiles')
    op.drop_table('content_tone_profiles')
    op.drop_index(op.f('ix_project_integrations_project_id'), table_name='project_integrations')
    op.drop_table('project_integrations')
