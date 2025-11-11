from sqlalchemy import Column, String, Integer, Float, DateTime, JSON, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from ..database import Base

class TechnicalAudit(Base):
    """Store technical SEO audit results for tracking over time"""
    __tablename__ = "technical_audits"
    
    id = Column(String, primary_key=True)
    project_id = Column(String, ForeignKey('projects.id'), nullable=False)
    url = Column(String, nullable=False)
    audit_type = Column(String, nullable=False)  # 'comprehensive', 'performance_only', 'seo_only'
    
    # Performance metrics
    performance_score = Column(Float)
    fcp_value = Column(String)
    fcp_score = Column(Float)
    lcp_value = Column(String)
    lcp_score = Column(Float)
    cls_value = Column(String)
    cls_score = Column(Float)
    tbt_value = Column(String)
    tbt_score = Column(Float)
    tti_value = Column(String)
    tti_score = Column(Float)
    
    # SEO issues count
    seo_issues_count = Column(Integer, default=0)
    seo_issues_high = Column(Integer, default=0)
    seo_issues_medium = Column(Integer, default=0)
    seo_issues_low = Column(Integer, default=0)
    
    # AI Bot accessibility
    bots_checked = Column(Integer, default=0)
    bots_allowed = Column(Integer, default=0)
    bots_blocked = Column(Integer, default=0)
    
    # Full audit data (for detailed view)
    full_audit_data = Column(JSON)
    
    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow)
    created_by = Column(String, ForeignKey('users.id'))
    
    # Relationships
    project = relationship("Project", back_populates="technical_audits")
    user = relationship("User", back_populates="technical_audits")

