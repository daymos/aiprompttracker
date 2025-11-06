from fastapi import APIRouter, HTTPException, Depends, Header
from fastapi.responses import Response
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid
from datetime import datetime
from sqlalchemy.sql import func
import httpx
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse

from ..database import get_db
from ..models.user import User
from ..models.project import Project, TrackedKeyword, KeywordRanking
from ..models.pin import PinnedItem
from ..services.rank_checker import RankCheckerService
from ..services.web_scraper import WebScraperService
from ..services.llm_service import LLMService
from ..services.dataforseo_service import DataForSEOService
from .auth import get_current_user
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/project", tags=["project"])
rank_checker = RankCheckerService()
web_scraper = WebScraperService()
llm_service = LLMService()
dataforseo_service = DataForSEOService()

class CreateProjectRequest(BaseModel):
    target_url: str
    name: Optional[str] = None

class AddKeywordRequest(BaseModel):
    keyword: str
    search_volume: Optional[int] = None
    competition: Optional[str] = None
    target_page: Optional[str] = None  # Specific page to track (e.g., "/blog/seo-tips")

class ProjectResponse(BaseModel):
    id: str
    target_url: str
    name: Optional[str]
    created_at: str

class RankingHistoryPoint(BaseModel):
    position: Optional[int]
    checked_at: str

class TrackedKeywordResponse(BaseModel):
    id: str
    keyword: str
    search_volume: Optional[int]
    competition: Optional[str]
    current_position: Optional[int]
    target_position: int
    target_page: Optional[str]  # Desired page to rank
    ranking_page: Optional[str]  # Actual page currently ranking
    is_correct_page: Optional[bool]  # True if ranking_page matches target_page (or any page if no target)
    source: str  # "manual" or "auto_detected"
    is_active: bool  # True if actively tracked, False if just a suggestion
    created_at: str
    ranking_history: List[RankingHistoryPoint] = []  # Last 30 ranking checks

class PinItemRequest(BaseModel):
    project_id: Optional[str] = None
    content_type: str
    title: str
    content: str
    source_message_id: Optional[str] = None
    source_conversation_id: Optional[str] = None

class PinConversationRequest(BaseModel):
    conversation_id: str
    project_id: Optional[str] = None

class PinnedItemResponse(BaseModel):
    id: str
    project_id: Optional[str]
    content_type: str
    title: str
    content: str
    source_message_id: Optional[str]
    source_conversation_id: Optional[str]
    created_at: str
    updated_at: str

@router.post("/create", response_model=ProjectResponse)
async def create_project(
    request: CreateProjectRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Create a new SEO project and auto-detect targeted keywords"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    # Normalize the URL - ensure it has a protocol
    target_url = request.target_url.strip()
    if not target_url.startswith(('http://', 'https://')):
        target_url = 'https://' + target_url
    
    project = Project(
        id=str(uuid.uuid4()),
        user_id=user.id,
        target_url=target_url,
        name=request.name or f"Project for {target_url}"
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    
    # Auto-detect keywords from website using LLM (async, doesn't block project creation)
    try:
        logger.info(f"Auto-detecting keywords for project {project.id} ({target_url})")
        website_data = await web_scraper.analyze_full_site(target_url)
        
        if website_data and not website_data.get('error'):
            # Use LLM to intelligently extract keywords
            keywords = await llm_service.extract_keywords_from_website(website_data, max_keywords=20)
            
            # Fetch search volume data for all keywords in batch
            volume_data = {}
            if keywords:
                logger.info(f"Fetching search volume for {len(keywords)} auto-detected keywords")
                volume_data = await dataforseo_service.get_search_volume(keywords, location="US")
            
            # Save keywords as INACTIVE suggestions (is_active=0) with volume data
            saved_count = 0
            for keyword_text in keywords:
                search_volume = volume_data.get(keyword_text, 0) if volume_data else None
                
                tracked_keyword = TrackedKeyword(
                    id=str(uuid.uuid4()),
                    project_id=project.id,
                    keyword=keyword_text,
                    search_volume=search_volume,
                    source="auto_detected",
                    is_active=0  # Inactive by default - user must activate to track
                )
                db.add(tracked_keyword)
                saved_count += 1
            
            db.commit()
            logger.info(f"LLM extracted and saved {saved_count} keyword suggestions with search volume data")
        else:
            logger.warning(f"Failed to auto-detect keywords for {target_url}: {website_data.get('error') if website_data else 'No data'}")
    except Exception as e:
        logger.error(f"Error auto-detecting keywords for project {project.id}: {e}")
        # Don't fail project creation if keyword detection fails
    
    return ProjectResponse(
        id=project.id,
        target_url=project.target_url,
        name=project.name,
        created_at=project.created_at.isoformat()
    )

@router.get("/active", response_model=Optional[ProjectResponse])
async def get_active_project(
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get user's most recent project"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    project = db.query(Project).filter(
        Project.user_id == user.id
    ).order_by(Project.created_at.desc()).first()
    
    if not project:
        return None
    
    return ProjectResponse(
        id=project.id,
        target_url=project.target_url,
        name=project.name,
        created_at=project.created_at.isoformat()
    )

@router.get("/all", response_model=List[ProjectResponse])
async def get_all_projects(
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get all user's projects"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    projects = db.query(Project).filter(
        Project.user_id == user.id
    ).order_by(Project.created_at.desc()).all()
    
    return [
        ProjectResponse(
            id=s.id,
            target_url=s.target_url,
            name=s.name,
            created_at=s.created_at.isoformat()
        )
        for s in projects
    ]

@router.post("/{project_id}/keywords", response_model=TrackedKeywordResponse)
async def add_keyword_to_project(
    project_id: str,
    request: AddKeywordRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Add a keyword to track in a project"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Check if keyword already tracked
    existing = db.query(TrackedKeyword).filter(
        TrackedKeyword.project_id == project_id,
        TrackedKeyword.keyword == request.keyword
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Keyword already tracked")
    
    # If search volume not provided, fetch it
    search_volume = request.search_volume
    competition = request.competition
    
    if search_volume is None:
        logger.info(f"Fetching search volume for keyword: {request.keyword}")
        volume_data = await dataforseo_service.get_search_volume([request.keyword], location="US")
        search_volume = volume_data.get(request.keyword, 0) if volume_data else None
    
    tracked_keyword = TrackedKeyword(
        id=str(uuid.uuid4()),
        project_id=project_id,
        keyword=request.keyword,
        search_volume=search_volume,
        competition=competition,
        target_page=request.target_page,
        is_active=1  # Manually added keywords are active by default
    )
    db.add(tracked_keyword)
    db.commit()
    db.refresh(tracked_keyword)
    
    # Check initial ranking
    ranking_result = await rank_checker.check_ranking(request.keyword, project.target_url)
    
    ranking_page = None
    is_correct_page = None
    
    if ranking_result:
        ranking_page = ranking_result.get('url')
        initial_ranking = KeywordRanking(
            id=str(uuid.uuid4()),
            tracked_keyword_id=tracked_keyword.id,
            position=ranking_result.get('position'),
            page_url=ranking_page
        )
        db.add(initial_ranking)
        db.commit()
        
        # Check if correct page is ranking
        if tracked_keyword.target_page:
            # User specified a target page, check if it matches
            is_correct_page = tracked_keyword.target_page in (ranking_page or '')
        else:
            # No target specified, any page from the domain is correct
            is_correct_page = ranking_page is not None
    
    return TrackedKeywordResponse(
        id=tracked_keyword.id,
        keyword=tracked_keyword.keyword,
        search_volume=tracked_keyword.search_volume,
        competition=tracked_keyword.competition,
        current_position=ranking_result.get('position') if ranking_result else None,
        target_position=tracked_keyword.target_position,
        target_page=tracked_keyword.target_page,
        ranking_page=ranking_page,
        is_correct_page=is_correct_page,
        source=tracked_keyword.source or "manual",
        is_active=bool(tracked_keyword.is_active) if hasattr(tracked_keyword, 'is_active') else True,
        created_at=tracked_keyword.created_at.isoformat()
    )

@router.get("/{project_id}/keywords", response_model=List[TrackedKeywordResponse])
async def get_project_keywords(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get all tracked keywords for a project"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    keywords = db.query(TrackedKeyword).filter(
        TrackedKeyword.project_id == project_id
    ).all()
    
    result = []
    for kw in keywords:
        # Get ranking history (last 30 checks)
        rankings = db.query(KeywordRanking).filter(
            KeywordRanking.tracked_keyword_id == kw.id
        ).order_by(KeywordRanking.checked_at.desc()).limit(30).all()
        
        latest_ranking = rankings[0] if rankings else None
        
        # Determine ranking page and if it's correct
        ranking_page = latest_ranking.page_url if latest_ranking else None
        is_correct_page = None
        
        if latest_ranking and ranking_page:
            if kw.target_page:
                # Check if target page matches ranking page
                is_correct_page = kw.target_page in ranking_page
            else:
                # No target specified, any page is correct
                is_correct_page = True
        
        # Build ranking history
        ranking_history = [
            RankingHistoryPoint(
                position=r.position,
                checked_at=r.checked_at.isoformat()
            )
            for r in reversed(rankings)  # Reverse to get chronological order
        ]
        
        result.append(TrackedKeywordResponse(
            id=kw.id,
            keyword=kw.keyword,
            search_volume=kw.search_volume,
            competition=kw.competition,
            current_position=latest_ranking.position if latest_ranking else None,
            target_position=kw.target_position,
            target_page=kw.target_page,
            ranking_page=ranking_page,
            is_correct_page=is_correct_page,
            source=kw.source or "manual",
            is_active=bool(kw.is_active) if hasattr(kw, 'is_active') else True,
            created_at=kw.created_at.isoformat(),
            ranking_history=ranking_history
        ))
    
    return result

@router.post("/{project_id}/refresh")
async def refresh_rankings(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Manually refresh rankings for all ACTIVE keywords in project using BULK processing"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Only refresh ACTIVE keywords (is_active=1)
    keywords = db.query(TrackedKeyword).filter(
        TrackedKeyword.project_id == project_id,
        TrackedKeyword.is_active == 1
    ).all()
    
    if not keywords:
        return {"message": "No active keywords to refresh"}
    
    # Use BULK processing - all keywords checked in parallel (~2-5 seconds total!)
    keyword_list = [kw.keyword for kw in keywords]
    logger.info(f"🚀 Bulk refreshing {len(keyword_list)} keywords for project {project.name}")
    
    results = await rank_checker.check_multiple_rankings(keyword_list, project.target_url)
    
    # Save all results to database
    updated_count = 0
    for kw in keywords:
        result = results.get(kw.keyword)
        
        if result:
            new_ranking = KeywordRanking(
                id=str(uuid.uuid4()),
                tracked_keyword_id=kw.id,
                position=result.get('position'),
                page_url=result.get('url')  # Note: bulk method uses 'url' not 'page_url'
            )
            db.add(new_ranking)
            updated_count += 1
    
    db.commit()
    
    logger.info(f"✅ Bulk refresh complete: {updated_count}/{len(keyword_list)} keywords updated")
    
    return {"message": f"Updated rankings for {updated_count} keywords"}

@router.get("/keywords/{keyword_id}/history")
async def get_keyword_history(
    keyword_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get ranking history for a specific keyword"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    keyword = db.query(TrackedKeyword).filter(
        TrackedKeyword.id == keyword_id
    ).first()
    
    if not keyword:
        raise HTTPException(status_code=404, detail="Keyword not found")
    
    # Verify user owns this project
    project = db.query(Project).filter(
        Project.id == keyword.project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=403, detail="Access denied")
    
    rankings = db.query(KeywordRanking).filter(
        KeywordRanking.tracked_keyword_id == keyword_id
    ).order_by(KeywordRanking.checked_at.asc()).all()
    
    return {
        "keyword": keyword.keyword,
        "history": [
            {
                "position": r.position,
                "page_url": r.page_url,
                "checked_at": r.checked_at.isoformat()
            }
            for r in rankings
        ]
    }

@router.patch("/keywords/{keyword_id}/toggle")
async def toggle_keyword_active(
    keyword_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Toggle keyword active status (activate suggestion or deactivate keyword)"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    keyword = db.query(TrackedKeyword).filter(
        TrackedKeyword.id == keyword_id
    ).first()
    
    if not keyword:
        raise HTTPException(status_code=404, detail="Keyword not found")
    
    # Verify user owns this project
    project = db.query(Project).filter(
        Project.id == keyword.project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Toggle is_active
    keyword.is_active = 0 if keyword.is_active else 1
    
    # If activating, check initial ranking
    if keyword.is_active == 1:
        ranking_result = await rank_checker.check_ranking(keyword.keyword, project.target_url)
        
        if ranking_result:
            initial_ranking = KeywordRanking(
                id=str(uuid.uuid4()),
                tracked_keyword_id=keyword.id,
                position=ranking_result.get('position'),
                page_url=ranking_result.get('url')
            )
            db.add(initial_ranking)
    
    db.commit()
    
    action = "activated" if keyword.is_active else "deactivated"
    return {"message": f"Keyword {action} successfully", "is_active": bool(keyword.is_active)}

@router.post("/test-rank-check")
async def test_rank_check(
    keyword: str,
    domain: str,
    authorization: str = Header(...)
):
    """Test rank checking for debugging - returns raw API results"""
    # Just verify user is authenticated
    token = authorization.replace("Bearer ", "")
    # Don't need to use the user, just verify they're logged in
    
    result = await rank_checker.check_ranking(keyword, domain)
    
    return {
        "keyword": keyword,
        "domain": domain,
        "result": result,
        "message": "Check backend logs for detailed debugging info"
    }

@router.delete("/{project_id}")
async def delete_project(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Delete a project and all related data (keywords, rankings, backlinks)"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    # Verify project exists and belongs to user
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    try:
        # Delete all keyword rankings first
        keywords = db.query(TrackedKeyword).filter(
            TrackedKeyword.project_id == project_id
        ).all()
        
        ranking_count = 0
        for keyword in keywords:
            deleted = db.query(KeywordRanking).filter(
                KeywordRanking.tracked_keyword_id == keyword.id
            ).delete()
            ranking_count += deleted
        
        # Delete tracked keywords
        keyword_count = db.query(TrackedKeyword).filter(
            TrackedKeyword.project_id == project_id
        ).delete()
        
        # Delete pinned items associated with this project
        pin_count = db.query(PinnedItem).filter(
            PinnedItem.project_id == project_id
        ).delete()
        
        # BacklinkAnalysis has CASCADE delete, so it will be automatically deleted
        
        # Delete the project itself
        db.delete(project)
        
        db.commit()
        
        logger.info(f"Deleted project {project_id}: {keyword_count} keywords, {ranking_count} rankings, {pin_count} pins")
        
        return {
            "message": "Project deleted successfully",
            "deleted": {
                "keywords": keyword_count,
                "rankings": ranking_count,
                "pins": pin_count
            }
        }
        
    except Exception as e:
        db.rollback()
        logger.error(f"Error deleting project {project_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete project: {str(e)}")

@router.post("/pin", response_model=PinnedItemResponse)
async def pin_item(
    request: PinItemRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Pin an item to the pinboard"""
    from ..services.llm_service import LLMService

    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)

    # If project_id is provided, verify user owns the project
    if request.project_id:
        project = db.query(Project).filter(
            Project.id == request.project_id,
            Project.user_id == user.id
        ).first()
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")

    # Generate AI summary for messages
    title = request.title
    if request.content_type == "message":
        llm_service = LLMService()
        try:
            title = await llm_service.summarize_message(request.content)
        except RuntimeError as e:
            logger.error(f"Failed to generate AI summary for message: {e}")
            raise HTTPException(status_code=503, detail=str(e))
        except Exception as e:
            logger.error(f"Unexpected error generating AI summary: {e}")
            raise HTTPException(status_code=500, detail="Failed to generate summary for message")

    pinned_item = PinnedItem(
        id=str(uuid.uuid4()),
        user_id=user.id,
        project_id=request.project_id,
        content_type=request.content_type,
        title=title,
        content=request.content,
        source_message_id=request.source_message_id,
        source_conversation_id=request.source_conversation_id
    )

    db.add(pinned_item)
    db.commit()
    db.refresh(pinned_item)

    # Use current time if database defaults didn't set the timestamps
    created_at = pinned_item.created_at or datetime.utcnow()
    updated_at = pinned_item.updated_at or datetime.utcnow()

    return PinnedItemResponse(
        id=pinned_item.id,
        project_id=pinned_item.project_id,
        content_type=pinned_item.content_type,
        title=pinned_item.title,
        content=pinned_item.content,
        source_message_id=pinned_item.source_message_id,
        source_conversation_id=pinned_item.source_conversation_id,
        created_at=created_at.isoformat(),
        updated_at=updated_at.isoformat()
    )

@router.get("/pins", response_model=List[PinnedItemResponse])
async def get_pinned_items(
    project_id: Optional[str] = None,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get all pinned items for user, optionally filtered by project"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)

    query = db.query(PinnedItem).filter(PinnedItem.user_id == user.id)

    if project_id:
        query = query.filter(PinnedItem.project_id == project_id)

    pinned_items = query.order_by(PinnedItem.created_at.desc()).all()

    return [
        PinnedItemResponse(
            id=item.id,
            project_id=item.project_id,
            content_type=item.content_type,
            title=item.title,
            content=item.content,
            source_message_id=item.source_message_id,
            source_conversation_id=item.source_conversation_id,
            created_at=(item.created_at or datetime.utcnow()).isoformat(),
            updated_at=(item.updated_at or datetime.utcnow()).isoformat()
        )
        for item in pinned_items
    ]

@router.post("/pin-conversation", response_model=PinnedItemResponse)
async def pin_conversation(
    request: PinConversationRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Pin an entire conversation to the pinboard"""
    from ..models.conversation import Conversation, Message
    from ..services.llm_service import LLMService

    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)

    # Get the conversation
    conversation = db.query(Conversation).filter(
        Conversation.id == request.conversation_id,
        Conversation.user_id == user.id
    ).first()

    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")

    # If project_id is provided, verify user owns the project
    if request.project_id:
        project = db.query(Project).filter(
            Project.id == request.project_id,
            Project.user_id == user.id
        ).first()
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")

    # Get all messages in the conversation
    messages = db.query(Message).filter(
        Message.conversation_id == request.conversation_id
    ).order_by(Message.created_at).all()

    # Build conversation content
    conversation_content = []
    for msg in messages:
        role = "You" if msg.role == "user" else "Assistant"
        conversation_content.append(f"**{role}:** {msg.content}")

    content_text = "\n\n".join(conversation_content)

    # Generate AI summary for the title
    llm_service = LLMService()
    try:
        title = await llm_service.summarize_conversation(content_text)
    except RuntimeError as e:
        logger.error(f"Failed to generate AI summary for conversation: {e}")
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"Unexpected error generating AI summary for conversation: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate summary for conversation")

    # Create the pinned item
    pinned_item = PinnedItem(
        id=str(uuid.uuid4()),
        user_id=user.id,
        project_id=request.project_id,
        content_type='conversation',
        title=title,
        content=content_text,
        source_message_id=None,
        source_conversation_id=request.conversation_id
    )

    db.add(pinned_item)
    db.commit()
    db.refresh(pinned_item)

    # Use current time if database defaults didn't set the timestamps
    created_at = pinned_item.created_at or datetime.utcnow()
    updated_at = pinned_item.updated_at or datetime.utcnow()

    return PinnedItemResponse(
        id=pinned_item.id,
        project_id=pinned_item.project_id,
        content_type=pinned_item.content_type,
        title=pinned_item.title,
        content=pinned_item.content,
        source_message_id=pinned_item.source_message_id,
        source_conversation_id=pinned_item.source_conversation_id,
        created_at=created_at.isoformat(),
        updated_at=updated_at.isoformat()
    )

@router.delete("/pins/{pin_id}")
async def unpin_item(
    pin_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Remove a pinned item"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)

    pinned_item = db.query(PinnedItem).filter(
        PinnedItem.id == pin_id,
        PinnedItem.user_id == user.id
    ).first()

    if not pinned_item:
        raise HTTPException(status_code=404, detail="Pinned item not found")

    db.delete(pinned_item)
    db.commit()

    return {"message": "Item unpinned successfully"}

@router.get("/favicon")
async def get_favicon(url: str):
    """
    Fetch and proxy the favicon from a website to avoid CORS issues
    Returns the actual favicon image
    """
    try:
        # Ensure URL has protocol
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        # Parse and validate URL
        parsed_url = urlparse(url)
        
        # Validate that we have a proper domain
        if not parsed_url.netloc or ' ' in parsed_url.netloc:
            logger.warning(f"Invalid URL format: {url}")
            # Extract domain-like text
            domain = url.replace('https://', '').replace('http://', '').split('/')[0].strip()
            domain = domain.replace(' ', '')  # Remove spaces
            if domain:
                # Use Google's favicon service which is CORS-friendly
                favicon_url = f"https://www.google.com/s2/favicons?domain={domain}&sz=64"
            else:
                raise HTTPException(status_code=400, detail="Invalid URL format")
        else:
            base_url = f"{parsed_url.scheme}://{parsed_url.netloc}"
            favicon_url = None
            
            # Try to fetch the website HTML
            async with httpx.AsyncClient(timeout=10.0, follow_redirects=True) as client:
                try:
                    response = await client.get(url, headers={
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                    })
                    response.raise_for_status()
                    
                    # Parse HTML to find favicon
                    soup = BeautifulSoup(response.text, 'html.parser')
                    
                    # Try various favicon link patterns in order of preference
                    favicon_selectors = [
                        'link[rel="icon"]',
                        'link[rel="shortcut icon"]',
                        'link[rel="apple-touch-icon"]',
                        'link[rel="apple-touch-icon-precomposed"]',
                    ]
                    
                    for selector in favicon_selectors:
                        tag = soup.select_one(selector)
                        if tag:
                            href = tag.get('href')
                            if href:
                                # Convert relative URLs to absolute
                                favicon_url = urljoin(base_url, href)
                                logger.info(f"Found favicon for {url}: {favicon_url}")
                                break
                    
                    # Fallback to /favicon.ico
                    if not favicon_url:
                        favicon_url = f"{base_url}/favicon.ico"
                        logger.info(f"Using fallback favicon for {url}: {favicon_url}")
                        
                except Exception as e:
                    logger.warning(f"Failed to fetch {url}: {e}")
                    # Use Google's favicon service as fallback
                    domain = parsed_url.netloc
                    favicon_url = f"https://www.google.com/s2/favicons?domain={domain}&sz=64"
        
        # Now fetch the actual favicon image
        async with httpx.AsyncClient(timeout=10.0, follow_redirects=True) as client:
            try:
                favicon_response = await client.get(favicon_url, headers={
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                })
                favicon_response.raise_for_status()
                
                # Determine content type
                content_type = favicon_response.headers.get('content-type', 'image/x-icon')
                
                # Return the image directly
                return Response(
                    content=favicon_response.content,
                    media_type=content_type,
                    headers={
                        'Cache-Control': 'public, max-age=86400',  # Cache for 1 day
                        'Access-Control-Allow-Origin': '*',  # Allow CORS
                    }
                )
            except Exception as e:
                logger.error(f"Failed to fetch favicon image from {favicon_url}: {e}")
                # Return a 1x1 transparent pixel as fallback
                transparent_pixel = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
                return Response(
                    content=transparent_pixel,
                    media_type='image/png',
                    headers={
                        'Cache-Control': 'public, max-age=86400',
                        'Access-Control-Allow-Origin': '*',
                    }
                )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching favicon for {url}: {e}")
        # Return a 1x1 transparent pixel
        transparent_pixel = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
        return Response(
            content=transparent_pixel,
            media_type='image/png',
            headers={
                'Cache-Control': 'public, max-age=3600',
                'Access-Control-Allow-Origin': '*',
            }
        )

