"""increase_backlink_quota_for_testing

Revision ID: cff87eecf716
Revises: 64b57f5ecd14
Create Date: 2025-11-05 20:56:29.412949

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'cff87eecf716'
down_revision = '64b57f5ecd14'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Update all existing users to have 1000 backlink requests/month for testing
    op.execute("UPDATE users SET backlink_rows_limit = 1000, backlink_rows_used = 0")


def downgrade() -> None:
    # Restore original limit of 5 requests/month
    op.execute("UPDATE users SET backlink_rows_limit = 5")





