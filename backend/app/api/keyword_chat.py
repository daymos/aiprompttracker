from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid
import re
import logging

from ..database import get_db
from ..models.user import User
from ..models.conversation import Conversation, Message
from ..models.project import Project, TrackedKeyword
from ..services.keyword_service import KeywordService
from ..services.llm_service import LLMService
from ..services.rank_checker import RankCheckerService
from ..services.moz_service import MozBacklinkService
from .auth import get_current_user

router = APIRouter(prefix="/chat", tags=["chat"])

keyword_service = KeywordService()
llm_service = LLMService()
rank_checker = RankCheckerService()
moz_service = MozBacklinkService()

class ChatRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None
    mode: Optional[str] = "ask"  # "ask" or "agent"

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
    
    # Build conversation history with reasoning included for assistant messages
    conversation_history = []
    for msg in messages[:-1]:  # Exclude the message we just added
        content = msg.content
        
        # For assistant messages, prepend reasoning if available
        if msg.role == "assistant" and msg.message_metadata and msg.message_metadata.get("reasoning"):
            reasoning = msg.message_metadata["reasoning"]
            # Include reasoning in context for LLM (but was hidden from user)
            content = f"<reasoning>{reasoning}</reasoning>\n\n{content}"
        
        conversation_history.append({"role": msg.role, "content": content})
    
    # Debug logging
    import logging
    logger = logging.getLogger(__name__)
    logger.info(f"Conversation has {len(messages)} total messages, passing {len(conversation_history)} as history")
    
    # Use LLM to intelligently extract keywords to research
    keyword_data = None
    
    # Ask LLM if user wants keyword research and what topic
    keyword_to_research = await llm_service.extract_keyword_intent(
        user_message=request.message,
        conversation_history=conversation_history
    )
    
    if keyword_to_research:
        logger.info(f"LLM extracted keyword to research: {keyword_to_research}")
        keyword_data = await keyword_service.analyze_keywords(keyword_to_research, limit=10)
        
        # Enrich top 5 keywords with SERP analysis
        if keyword_data:
            logger.info(f"Enriching top {min(5, len(keyword_data))} keywords with SERP analysis")
            for keyword_item in keyword_data[:5]:  # Only analyze top 5 to avoid rate limits
                keyword = keyword_item.get('keyword')
                if keyword:
                    serp_analysis = await rank_checker.get_serp_analysis(keyword)
                    if serp_analysis:
                        keyword_item['serp_analysis'] = serp_analysis['analysis']
                        keyword_item['serp_insight'] = serp_analysis['insight']
                        logger.info(f"SERP analysis for '{keyword}': {serp_analysis['analysis']}")
                    else:
                        logger.info(f"No SERP analysis available for '{keyword}'")
    else:
        logger.info("LLM determined no specific keyword research needed")
    
    # DISABLED: Backlink analysis (Moz API - need better provider)
    # Use LLM to detect backlink intent and extract domain(s)
    backlink_data = None
    
    # TODO: Re-enable when we have a better backlink API provider
    if False:  # Disabled for now
        backlink_intent = await llm_service.extract_backlink_intent(
            user_message=request.message,
            conversation_history=conversation_history
        )
    else:
        backlink_intent = None
    
    if backlink_intent and False:  # Double-check it's disabled
        logger.info(f"LLM detected backlink intent: {backlink_intent}")
        
        # Check user's backlink quota
        if user.backlink_rows_used >= user.backlink_rows_limit:
            logger.warning(f"User {user.id} has exceeded backlink quota")
            backlink_data = {
                "error": f"You've reached your monthly limit of {user.backlink_rows_limit} backlink rows. Resets on: {user.backlink_usage_reset_at.strftime('%Y-%m-%d')}"
            }
        else:
            action = backlink_intent.get("action")
            
            if action == "compare":
                # Comparison request
                domain1 = backlink_intent.get("domain1")
                domain2 = backlink_intent.get("domain2")
                if domain1 and domain2:
                    logger.info(f"Comparing backlinks: {domain1} vs {domain2}")
                    backlink_data = await moz_service.compare_backlinks(domain1, domain2, limit_per_domain=25)
                else:
                    logger.warning("Comparison requested but missing domains")
                    backlink_data = {"needs_domain": True}
                    
            elif action == "analyze":
                # Single domain analysis
                domain = backlink_intent.get("domain")
                if domain:
                    logger.info(f"Analyzing backlinks for: {domain}")
                    backlink_data = await moz_service.get_backlinks(domain, limit=50)
                else:
                    logger.warning("Analysis requested but no domain provided")
                    backlink_data = {"needs_domain": True}
            
            # Update usage tracking
            if backlink_data and not backlink_data.get("error") and not backlink_data.get("needs_domain"):
                rows_used = backlink_data.get("rows_used", 0)
                user.backlink_rows_used += rows_used
                db.commit()
                logger.info(f"User {user.id} used {rows_used} backlink rows (total: {user.backlink_rows_used}/{user.backlink_rows_limit})")
    else:
        logger.info("LLM determined no backlink analysis needed")
    
    # Get user's projects and tracked keywords for context
    user_projects = db.query(Project).filter(Project.user_id == user.id).all()
    
    user_projects_data = []
    
    for project in user_projects:
        tracked_keywords = db.query(TrackedKeyword).filter(
            TrackedKeyword.project_id == project.id
        ).all()
        
        user_projects_data.append({
            'id': project.id,
            'name': project.name,
            'target_url': project.target_url,
            'tracked_keywords': [
                {
                    'keyword': kw.keyword,
                    'search_volume': kw.search_volume,
                    'competition': kw.competition,
                    'target_position': kw.target_position
                }
                for kw in tracked_keywords
            ]
        })
    
    # Generate response with LLM
    # Generate response (returns tuple: content, reasoning)
    assistant_response, reasoning = await llm_service.generate_keyword_advice(
        user_message=request.message,
        keyword_data=keyword_data,
        backlink_data=backlink_data,
        conversation_history=conversation_history,
        mode=request.mode or "ask",
        user_projects=user_projects_data if user_projects_data else None
    )
    
    # Build metadata with keyword data and reasoning
    metadata = {}
    if keyword_data:
        metadata["keyword_data"] = keyword_data
    if reasoning:
        metadata["reasoning"] = reasoning
    
    # Save assistant message
    assistant_message = Message(
        id=str(uuid.uuid4()),
        conversation_id=conversation.id,
        role="assistant",
        content=assistant_response,
        message_metadata=metadata if metadata else None
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

@router.delete("/conversation/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Delete a conversation and all its messages"""
    
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == user.id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    # Delete all messages first
    db.query(Message).filter(
        Message.conversation_id == conversation_id
    ).delete()
    
    # Delete conversation
    db.delete(conversation)
    db.commit()
    
    return {"message": "Conversation deleted successfully"}

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

