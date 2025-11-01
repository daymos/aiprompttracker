from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, Enum, Text
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from ..database import Base

class SubmissionStatus(str, enum.Enum):
    PENDING = "pending"
    SUBMITTED = "submitted"
    APPROVED = "approved"
    REJECTED = "rejected"
    INDEXED = "indexed"
    FAILED = "failed"

class Directory(Base):
    """Master list of directories to submit to"""
    __tablename__ = "directories"
    
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    url = Column(String, nullable=False)
    category = Column(String)  # e.g., "AI Tools", "SaaS", "Startup Directories"
    submission_url = Column(String)  # Where to submit
    is_active = Column(Integer, default=1)
    requires_manual = Column(Integer, default=0)  # 1 if can't be automated
    automation_method = Column(String)  # 'manual', 'form_post', 'api', 'none'
    form_fields = Column(Text)  # JSON of required fields for automation
    domain_authority = Column(Integer)  # Estimated DA
    tier = Column(String)  # 'top' (manual), 'mid' (can automate), 'volume' (bulk indexation)
    notes = Column(Text)
    
    # Relationships
    submissions = relationship("BacklinkSubmission", back_populates="directory")

class BacklinkSubmission(Base):
    """Track submissions to directories"""
    __tablename__ = "backlink_submissions"
    
    id = Column(String, primary_key=True)
    campaign_id = Column(String, ForeignKey("backlink_campaigns.id"), nullable=False)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    directory_id = Column(String, ForeignKey("directories.id"), nullable=False)
    status = Column(String, default="pending")  # pending, submitted, approved, rejected, indexed
    submission_url = Column(String)  # Direct link to submit to this directory
    submitted_at = Column(DateTime)
    indexed_at = Column(DateTime)
    notes = Column(Text, nullable=True)  # Track approval emails, rejection reasons, etc.
    
    # Relationships
    campaign = relationship("BacklinkCampaign", back_populates="submissions")
    project = relationship("Project", back_populates="backlink_submissions")
    directory = relationship("Directory", back_populates="submissions")

class BacklinkCampaign(Base):
    """Track bulk submission campaigns"""
    __tablename__ = "backlink_campaigns"
    
    id = Column(String, primary_key=True)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    total_directories = Column(Integer, default=0)
    category_filter = Column(String)  # e.g., "AI Tools", "SaaS"
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    project = relationship("Project")
    user = relationship("User")
    submissions = relationship("BacklinkSubmission", back_populates="campaign")

