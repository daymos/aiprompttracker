from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base

class Project(Base):
    """User's SEO project with tracked keywords"""
    __tablename__ = "projects"
    
    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    target_url = Column(String, nullable=False)  # The website they're trying to rank
    name = Column(String, nullable=True)  # Optional project name
    gsc_property_url = Column(String, nullable=True)  # Google Search Console property URL
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    tracked_keywords = relationship("TrackedKeyword", back_populates="project", cascade="all, delete-orphan")
    backlink_analysis = relationship("BacklinkAnalysis", back_populates="project", uselist=False, cascade="all, delete-orphan")
    technical_audits = relationship("TechnicalAudit", back_populates="project", cascade="all, delete-orphan")
    integrations = relationship("ProjectIntegration", back_populates="project", cascade="all, delete-orphan")
    user = relationship("User", back_populates="projects")

class TrackedKeyword(Base):
    """Individual keyword being tracked in a project"""
    __tablename__ = "tracked_keywords"
    
    id = Column(String, primary_key=True)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False, index=True)
    keyword = Column(String, nullable=False)
    search_volume = Column(Integer, nullable=True)
    competition = Column(String, nullable=True)  # LOW, MEDIUM, HIGH (Google Ads competition)
    seo_difficulty = Column(Integer, nullable=True)  # 0-100 organic ranking difficulty
    intent = Column(String, nullable=True)  # Search intent: informational, commercial, transactional, navigational
    cpc = Column(Float, nullable=True)  # Cost per click
    trend = Column(Float, nullable=True)  # Trend percentage
    target_position = Column(Integer, default=10)  # Goal ranking position
    target_page = Column(String, nullable=True)  # Specific page to track (e.g., "/blog/seo-tips")
    source = Column(String, default="manual")  # "manual" or "auto_detected"
    is_active = Column(Integer, default=1)  # 1 for active (tracked), 0 for inactive (suggestion only). Manual keywords are active by default, auto_detected start inactive.
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    project = relationship("Project", back_populates="tracked_keywords")
    rankings = relationship("KeywordRanking", back_populates="tracked_keyword", order_by="KeywordRanking.checked_at.desc()", cascade="all, delete-orphan")

class KeywordRanking(Base):
    """Historical ranking data for a tracked keyword"""
    __tablename__ = "keyword_rankings"
    
    id = Column(String, primary_key=True)
    tracked_keyword_id = Column(String, ForeignKey("tracked_keywords.id"), nullable=False, index=True)
    position = Column(Integer, nullable=True)  # NULL if not in top 100
    page_url = Column(String, nullable=True)  # Which page ranked
    checked_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    
    tracked_keyword = relationship("TrackedKeyword", back_populates="rankings")
