from sqlalchemy import Column, String, DateTime, Boolean
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
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    conversations = relationship("Conversation", back_populates="user")
    projects = relationship("Project", back_populates="user")

