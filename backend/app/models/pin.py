from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Integer
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base

class PinnedItem(Base):
    __tablename__ = "pinned_items"

    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    project_id = Column(String, ForeignKey("projects.id"), nullable=True)
    content_type = Column(String, nullable=False) # e.g., 'insight', 'analysis', 'recommendation', 'note', 'message'
    title = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    source_message_id = Column(String, nullable=True) # Original message ID if pinned from chat
    source_conversation_id = Column(String, nullable=True) # Original conversation ID if pinned from chat

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", backref="pinned_items")
    project = relationship("Project", backref="pinned_items")

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "project_id": self.project_id,
            "content_type": self.content_type,
            "title": self.title,
            "content": self.content,
            "source_message_id": self.source_message_id,
            "source_conversation_id": self.source_conversation_id,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
