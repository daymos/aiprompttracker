from sqlalchemy import Column, String, DateTime, Boolean, Integer
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True)  # Will be email or Google ID
    email = Column(String, unique=True, nullable=False, index=True)
    name = Column(String, nullable=True)
    provider = Column(String, nullable=False)  # 'google' or 'apple'
    is_subscribed = Column(Boolean, default=False)
    
    # Backlink usage tracking (resets monthly) - tracks API requests, not rows
    backlink_rows_used = Column(Integer, default=0)  # Actually tracks requests
    backlink_rows_limit = Column(Integer, default=1000)  # Testing mode: 1000 requests/month
    backlink_usage_reset_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Google Search Console integration
    gsc_access_token = Column(String, nullable=True)  # OAuth access token
    gsc_refresh_token = Column(String, nullable=True)  # OAuth refresh token
    gsc_token_expires_at = Column(DateTime(timezone=True), nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    conversations = relationship("Conversation", back_populates="user")
    projects = relationship("Project", back_populates="user")

