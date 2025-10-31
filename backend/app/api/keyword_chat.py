from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid
import re

from ..database import get_db
from ..models.user import User
from ..models.conversation import Conversation, Message
from ..services.keyword_service import KeywordService
from ..services.llm_service import LLMService
from .auth import get_current_user

router = APIRouter(prefix="/chat", tags=["chat"])

keyword_service = KeywordService()
llm_service = LLMService()

class ChatRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None

class ChatResponse(BaseModel):
    message: str
    conversation_id: str

class ConversationListItem(BaseModel):
    id: str
    title: str
    created_at: str
    message_count: int

@router.post("/message", response_model=ChatResponse)
async def send_message(
    request: ChatRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Send a message and get keyword research advice"""
    
    # Extract token from Authorization header
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    # Check subscription status (for now, allow free tier)
    # TODO: Add subscription check via RevenueCat
    
    # Create or get conversation
    if request.conversation_id:
        conversation = db.query(Conversation).filter(
            Conversation.id == request.conversation_id,
            Conversation.user_id == user.id
        ).first()
        
        if not conversation:
            raise HTTPException(status_code=404, detail="Conversation not found")
    else:
        # Create new conversation
        conversation = Conversation(
            id=str(uuid.uuid4()),
            user_id=user.id,
            title=request.message[:50]  # Use first 50 chars as title
        )
        db.add(conversation)
        db.commit()
        db.refresh(conversation)
    
    # Save user message
    user_message = Message(
        id=str(uuid.uuid4()),
        conversation_id=conversation.id,
        role="user",
        content=request.message
    )
    db.add(user_message)
    db.commit()
    
    # Get conversation history
    messages = db.query(Message).filter(
        Message.conversation_id == conversation.id
    ).order_by(Message.created_at).all()
    
    conversation_history = [
        {"role": msg.role, "content": msg.content}
        for msg in messages[:-1]  # Exclude the message we just added
    ]
    
    # Check if user is asking for keyword research
    keyword_data = None
    if should_fetch_keyword_data(request.message):
        # Extract potential keywords from the message
        keywords = extract_keywords_from_message(request.message)
        if keywords:
            # Fetch keyword data from DataForSEO
            keyword_data = await keyword_service.analyze_keywords(keywords[0], limit=10)
    
    # Generate response with LLM
    assistant_response = await llm_service.generate_keyword_advice(
        user_message=request.message,
        keyword_data=keyword_data,
        conversation_history=conversation_history
    )
    
    # Save assistant message
    assistant_message = Message(
        id=str(uuid.uuid4()),
        conversation_id=conversation.id,
        role="assistant",
        content=assistant_response,
        message_metadata={"keyword_data": keyword_data} if keyword_data else None
    )
    db.add(assistant_message)
    db.commit()
    
    return ChatResponse(
        message=assistant_response,
        conversation_id=conversation.id
    )

@router.get("/conversations", response_model=List[ConversationListItem])
async def get_conversations(
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get list of user's conversations"""
    
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    conversations = db.query(Conversation).filter(
        Conversation.user_id == user.id
    ).order_by(Conversation.updated_at.desc()).all()
    
    result = []
    for conv in conversations:
        message_count = db.query(Message).filter(
            Message.conversation_id == conv.id
        ).count()
        
        result.append(ConversationListItem(
            id=conv.id,
            title=conv.title or "Untitled Conversation",
            created_at=conv.created_at.isoformat(),
            message_count=message_count
        ))
    
    return result

@router.get("/conversation/{conversation_id}")
async def get_conversation(
    conversation_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get a specific conversation with all messages"""
    
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == user.id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    messages = db.query(Message).filter(
        Message.conversation_id == conversation_id
    ).order_by(Message.created_at).all()
    
    return {
        "id": conversation.id,
        "title": conversation.title,
        "created_at": conversation.created_at.isoformat(),
        "messages": [
            {
                "id": msg.id,
                "role": msg.role,
                "content": msg.content,
                "created_at": msg.created_at.isoformat()
            }
            for msg in messages
        ]
    }

def should_fetch_keyword_data(message: str) -> bool:
    """Determine if we should fetch keyword data based on the message"""
    keywords_triggers = [
        "keyword", "keywords", "search volume", "rank", "ranking",
        "target", "should i", "what about", "traffic", "seo"
    ]
    message_lower = message.lower()
    return any(trigger in message_lower for trigger in keywords_triggers)

def extract_keywords_from_message(message: str) -> List[str]:
    """Extract potential keywords from user message"""
    # Look for quoted phrases first
    quoted = re.findall(r'"([^"]+)"', message)
    if quoted:
        return quoted
    
    # Look for phrases after "for", "about", "targeting"
    patterns = [
        r'(?:for|about|targeting)\s+([a-zA-Z\s]+?)(?:\.|$|\?)',
        r'keyword[s]?\s+like\s+([a-zA-Z\s]+?)(?:\.|$|\?)'
    ]
    
    for pattern in patterns:
        matches = re.findall(pattern, message, re.IGNORECASE)
        if matches:
            return [m.strip() for m in matches]
    
    # Fallback: just return meaningful words
    words = message.split()
    if len(words) > 2:
        return [' '.join(words[:3])]
    
    return []

