"""
Project models for tracking brand visibility across LLMs
"""

from sqlalchemy import Column, String, DateTime, Boolean, Integer, Text, ForeignKey, JSON, Float
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class Project(Base):
    """A tracked brand/domain with keywords to monitor"""
    __tablename__ = "projects"
    
    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    
    # Project details
    name = Column(String, nullable=False)  # Display name
    domain = Column(String, nullable=False)  # e.g., "aiprompttracker.io"
    brand_terms = Column(JSON, nullable=False)  # ["AI Prompt Tracker", "aiprompttracker"]
    
    # Tracking configuration
    keywords = Column(JSON, default=list)  # ["AI visibility tracking", "LLM monitoring"]
    competitors = Column(JSON, default=list)  # ["competitor1.com", "competitor2.com"]
    use_cases = Column(JSON, default=list)  # ["marketing agencies", "SEO professionals"]
    
    # LLM providers to track
    enabled_providers = Column(JSON, default=list)  # ["openai", "gemini", "perplexity"]
    
    # Status
    is_active = Column(Boolean, default=True)
    scan_frequency = Column(String, default="daily")  # daily, weekly, manual
    last_scanned_at = Column(DateTime(timezone=True), nullable=True)
    
    # Visibility score (0-100)
    current_score = Column(Float, nullable=True)
    previous_score = Column(Float, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="projects")
    scans = relationship("Scan", back_populates="project", cascade="all, delete-orphan")
    scores = relationship("VisibilityScore", back_populates="project", cascade="all, delete-orphan")


class Scan(Base):
    """A single scan run across all configured LLM providers"""
    __tablename__ = "scans"
    
    id = Column(String, primary_key=True)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False, index=True)
    
    # Scan metadata
    scan_type = Column(String, default="full")  # full, quick, custom
    status = Column(String, default="pending")  # pending, running, completed, failed
    
    # Results summary
    total_prompts = Column(Integer, default=0)
    prompts_with_mention = Column(Integer, default=0)
    providers_checked = Column(JSON, default=list)
    
    # Timing
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    duration_seconds = Column(Float, nullable=True)
    
    # Error tracking
    error_message = Column(Text, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    project = relationship("Project", back_populates="scans")
    results = relationship("ScanResult", back_populates="scan", cascade="all, delete-orphan")


class ScanResult(Base):
    """Individual prompt/response result from a specific LLM provider"""
    __tablename__ = "scan_results"
    
    id = Column(String, primary_key=True)
    scan_id = Column(String, ForeignKey("scans.id"), nullable=False, index=True)
    
    # LLM details
    provider = Column(String, nullable=False, index=True)  # openai, gemini, etc.
    model = Column(String, nullable=False)  # gpt-4, gemini-pro, etc.
    
    # Prompt details
    prompt_type = Column(String, nullable=False)  # brand_awareness, keyword_search, etc.
    prompt_text = Column(Text, nullable=False)
    prompt_metadata = Column(JSON, default=dict)  # {keyword, use_case, etc.}
    
    # Response
    response_text = Column(Text, nullable=False)
    response_metadata = Column(JSON, default=dict)  # tokens, latency, etc.
    
    # Analysis results
    brand_found = Column(Boolean, default=False)
    brand_mentions = Column(JSON, default=list)  # List of found brand terms
    mention_positions = Column(JSON, default=list)  # Character positions
    context_snippets = Column(JSON, default=list)  # Context around mentions
    mention_rank = Column(Integer, nullable=True)  # Rank vs competitors
    
    # Scoring factors
    relevance_score = Column(Float, nullable=True)  # 0-1, how relevant is the mention
    sentiment = Column(String, nullable=True)  # positive, neutral, negative
    
    # Error handling
    error = Column(Text, nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    scan = relationship("Scan", back_populates="results")


class VisibilityScore(Base):
    """Daily/historical visibility scores for a project"""
    __tablename__ = "visibility_scores"
    
    id = Column(String, primary_key=True)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False, index=True)
    
    # Date of score
    date = Column(DateTime(timezone=True), nullable=False, index=True)
    
    # Overall score (0-100)
    overall_score = Column(Float, nullable=False)
    
    # Per-provider scores
    provider_scores = Column(JSON, default=dict)  # {openai: 85, gemini: 72, ...}
    
    # Breakdown metrics
    total_prompts_tested = Column(Integer, default=0)
    prompts_with_mention = Column(Integer, default=0)
    mention_rate = Column(Float, default=0.0)  # percentage
    
    # Average metrics
    avg_mention_rank = Column(Float, nullable=True)
    keywords_covered = Column(Integer, default=0)
    keywords_total = Column(Integer, default=0)
    
    # Changes from previous
    score_change = Column(Float, nullable=True)
    score_trend = Column(String, nullable=True)  # improving, declining, stable
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    project = relationship("Project", back_populates="scores")

