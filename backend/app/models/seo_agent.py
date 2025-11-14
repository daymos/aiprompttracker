from sqlalchemy import Column, String, Integer, Float, Text, DateTime, ForeignKey, JSON, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base

class ProjectIntegration(Base):
    """CMS integration for a project (WordPress, etc.)"""
    __tablename__ = "project_integrations"
    
    id = Column(String, primary_key=True)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False, index=True)
    cms_type = Column(String, nullable=False)  # "wordpress", "webflow", "ghost", etc.
    cms_url = Column(String, nullable=False)  # Base URL of CMS
    username = Column(String, nullable=True)  # CMS username
    encrypted_password = Column(Text, nullable=True)  # Encrypted password/token
    connection_metadata = Column(JSON, nullable=True)  # Additional CMS-specific config
    is_active = Column(Boolean, default=True)
    last_tested_at = Column(DateTime(timezone=True), nullable=True)
    last_test_status = Column(String, nullable=True)  # "success", "failed", "pending"
    last_test_error = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    project = relationship("Project", back_populates="integrations")
    generated_content = relationship("GeneratedContent", back_populates="integration", cascade="all, delete-orphan")


class ContentToneProfile(Base):
    """Analyzed tone/style profile from existing content"""
    __tablename__ = "content_tone_profiles"
    
    id = Column(String, primary_key=True)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False, unique=True, index=True)
    tone_description = Column(Text, nullable=True)  # LLM-generated description
    analyzed_posts_count = Column(Integer, default=0)
    sample_content = Column(Text, nullable=True)  # Sample text used for analysis
    tone_metadata = Column(JSON, nullable=True)  # Structured tone attributes (formality, emotion, etc.)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    project = relationship("Project", backref="tone_profile")


class GeneratedContent(Base):
    """AI-generated content for SEO"""
    __tablename__ = "generated_content"
    
    id = Column(String, primary_key=True)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False, index=True)
    integration_id = Column(String, ForeignKey("project_integrations.id"), nullable=True, index=True)
    
    # Content details
    title = Column(String, nullable=False)
    content = Column(Text, nullable=False)  # HTML or markdown
    excerpt = Column(Text, nullable=True)
    target_keywords = Column(JSON, nullable=True)  # List of keywords targeted
    
    # SEO metrics
    seo_score = Column(Integer, nullable=True)  # 0-100 calculated SEO score
    word_count = Column(Integer, nullable=True)
    readability_score = Column(Float, nullable=True)
    
    # Publishing status
    status = Column(String, default="draft")  # "draft", "published", "scheduled", "failed"
    published_at = Column(DateTime(timezone=True), nullable=True)
    published_url = Column(String, nullable=True)  # URL on the CMS after publishing
    cms_post_id = Column(String, nullable=True)  # ID in the CMS system
    
    # Generation metadata
    generation_prompt = Column(Text, nullable=True)  # Original prompt used
    tone_profile_id = Column(String, ForeignKey("content_tone_profiles.id"), nullable=True)
    generation_metadata = Column(JSON, nullable=True)  # Model used, tokens, etc.
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    project = relationship("Project", backref="generated_content")
    integration = relationship("ProjectIntegration", back_populates="generated_content")
    tone_profile = relationship("ContentToneProfile")
    generation_job = relationship("ContentGenerationJob", back_populates="generated_content", uselist=False)


class ContentGenerationJob(Base):
    """Async job tracking for content generation"""
    __tablename__ = "content_generation_jobs"
    
    id = Column(String, primary_key=True)
    project_id = Column(String, ForeignKey("projects.id"), nullable=False, index=True)
    generated_content_id = Column(String, ForeignKey("generated_content.id"), nullable=True, index=True)
    
    # Job details
    job_type = Column(String, nullable=False)  # "generate", "publish", "tone_analysis"
    status = Column(String, default="pending")  # "pending", "processing", "completed", "failed"
    progress_percentage = Column(Integer, default=0)
    
    # Input/Output
    input_params = Column(JSON, nullable=True)  # Original request parameters
    result_data = Column(JSON, nullable=True)  # Job results
    error_message = Column(Text, nullable=True)
    
    # Timing
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    project = relationship("Project", backref="content_jobs")
    generated_content = relationship("GeneratedContent", back_populates="generation_job")

