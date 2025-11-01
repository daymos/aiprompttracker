"""update_backlink_limit_to_5_for_beta

Revision ID: 7331defdedcc
Revises: a50da388e316
Create Date: 2025-11-01 23:33:13.714673

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '7331defdedcc'
down_revision = 'a50da388e316'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Update existing users to the new free beta limits
    # Reset usage to 0 and set limit to 5 for all non-subscribed users
    op.execute("""
        UPDATE users 
        SET backlink_rows_limit = 5, 
            backlink_rows_used = 0
        WHERE is_subscribed = false
    """)


def downgrade() -> None:
    # Revert to old limits (100 rows/month)
    op.execute("""
        UPDATE users 
        SET backlink_rows_limit = 100
        WHERE is_subscribed = false
    """)



