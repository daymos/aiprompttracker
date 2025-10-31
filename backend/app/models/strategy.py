from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base

class Strategy(Base):
    """User's active SEO strategy with tracked keywords"""
    __tablename__ = "strategies"
    
    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    target_url = Column(String, nullable=False)  # The website they're trying to rank
    name = Column(String, nullable=True)  # Optional strategy name
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    tracked_keywords = relationship("TrackedKeyword", back_populates="strategy")
    user = relationship("User", back_populates="strategies")

class TrackedKeyword(Base):
    """Individual keyword being tracked in a strategy"""
    __tablename__ = "tracked_keywords"
    
    id = Column(String, primary_key=True)
    strategy_id = Column(String, ForeignKey("strategies.id"), nullable=False, index=True)
    keyword = Column(String, nullable=False)
    search_volume = Column(Integer, nullable=True)
    competition = Column(String, nullable=True)  # LOW, MEDIUM, HIGH
    target_position = Column(Integer, default=10)  # Goal ranking position
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    strategy = relationship("Strategy", back_populates="tracked_keywords")
    rankings = relationship("KeywordRanking", back_populates="tracked_keyword", order_by="KeywordRanking.checked_at.desc()")

class KeywordRanking(Base):
    """Historical ranking data for a tracked keyword"""
    __tablename__ = "keyword_rankings"
    
    id = Column(String, primary_key=True)
    tracked_keyword_id = Column(String, ForeignKey("tracked_keywords.id"), nullable=False, index=True)
    position = Column(Integer, nullable=True)  # NULL if not in top 100
    page_url = Column(String, nullable=True)  # Which page ranked
    checked_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    
    tracked_keyword = relationship("TrackedKeyword", back_populates="rankings")

