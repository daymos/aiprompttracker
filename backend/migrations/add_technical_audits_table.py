"""
Migration: Add technical_audits table for tracking audit history

Run this with: python -m migrations.add_technical_audits_table
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from app.config import get_settings

settings = get_settings()

def upgrade():
    """Create technical_audits table"""
    engine = create_engine(settings.DATABASE_URL)
    
    with engine.begin() as conn:
        # Create technical_audits table
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS technical_audits (
                id VARCHAR PRIMARY KEY,
                project_id VARCHAR NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                url VARCHAR NOT NULL,
                audit_type VARCHAR NOT NULL,
                
                -- Performance metrics
                performance_score FLOAT,
                fcp_value VARCHAR,
                fcp_score FLOAT,
                lcp_value VARCHAR,
                lcp_score FLOAT,
                cls_value VARCHAR,
                cls_score FLOAT,
                tbt_value VARCHAR,
                tbt_score FLOAT,
                tti_value VARCHAR,
                tti_score FLOAT,
                
                -- SEO issues count
                seo_issues_count INTEGER DEFAULT 0,
                seo_issues_high INTEGER DEFAULT 0,
                seo_issues_medium INTEGER DEFAULT 0,
                seo_issues_low INTEGER DEFAULT 0,
                
                -- AI Bot accessibility
                bots_checked INTEGER DEFAULT 0,
                bots_allowed INTEGER DEFAULT 0,
                bots_blocked INTEGER DEFAULT 0,
                
                -- Full audit data (JSON)
                full_audit_data JSONB,
                
                -- Metadata
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                created_by VARCHAR REFERENCES users(id),
                
                -- Indexes
                CONSTRAINT fk_project FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
                CONSTRAINT fk_user FOREIGN KEY (created_by) REFERENCES users(id)
            );
        """))
        
        # Create indexes
        conn.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_technical_audits_project 
            ON technical_audits(project_id);
        """))
        
        conn.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_technical_audits_created 
            ON technical_audits(created_at DESC);
        """))
        
        print("✅ Created technical_audits table with indexes")

def downgrade():
    """Drop technical_audits table"""
    engine = create_engine(settings.DATABASE_URL)
    
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS technical_audits CASCADE;"))
        print("✅ Dropped technical_audits table")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--downgrade", action="store_true", help="Revert the migration")
    args = parser.parse_args()
    
    if args.downgrade:
        print("⬇️  Running downgrade...")
        downgrade()
    else:
        print("⬆️  Running upgrade...")
        upgrade()

