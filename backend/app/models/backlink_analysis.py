"""
Database model for storing backlink analysis results
"""
from sqlalchemy import Column, String, Integer, DateTime, Text, ForeignKey, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.database import Base


class BacklinkAnalysis(Base):
    """Stores cached backlink analysis results from RapidAPI"""
    __tablename__ = "backlink_analyses"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    project_id = Column(String, ForeignKey("projects.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Summary metrics
    total_backlinks = Column(Integer, default=0)
    referring_domains = Column(Integer, default=0)
    domain_authority = Column(Integer, default=0)
    
    # Full API response stored as JSON
    raw_data = Column(JSON, nullable=False)
    
    # Timestamps
    analyzed_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # Relationships
    project = relationship("Project", back_populates="backlink_analysis")

    def to_dict(self):
        """Convert to dictionary for API responses"""
        return {
            "id": self.id,
            "project_id": self.project_id,
            "total_backlinks": self.total_backlinks,
            "referring_domains": self.referring_domains,
            "domain_authority": self.domain_authority,
            "analyzed_at": self.analyzed_at.isoformat() if self.analyzed_at else None,
            "backlinks": self.raw_data.get("backlinks", []) if self.raw_data else [],
            "domain": self.raw_data.get("domain") if self.raw_data else None,
            "trends": self.raw_data.get("trends") if self.raw_data else None,
            "anchor_texts": self.raw_data.get("anchor_texts") if self.raw_data else None,
            "overtime": self.raw_data.get("overtime", []) if self.raw_data else [],
        }

