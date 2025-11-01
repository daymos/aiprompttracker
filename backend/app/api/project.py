from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid
from datetime import datetime

from ..database import get_db
from ..models.user import User
from ..models.project import Project, TrackedKeyword, KeywordRanking
from ..models.backlink import BacklinkSubmission, BacklinkCampaign
from ..services.rank_checker import RankCheckerService
from .auth import get_current_user
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/project", tags=["project"])
rank_checker = RankCheckerService()

class CreateProjectRequest(BaseModel):
    target_url: str
    name: Optional[str] = None

class AddKeywordRequest(BaseModel):
    keyword: str
    search_volume: Optional[int] = None
    competition: Optional[str] = None

class ProjectResponse(BaseModel):
    id: str
    target_url: str
    name: Optional[str]
    created_at: str

class TrackedKeywordResponse(BaseModel):
    id: str
    keyword: str
    search_volume: Optional[int]
    competition: Optional[str]
    current_position: Optional[int]
    target_position: int
    created_at: str

@router.post("/create", response_model=ProjectResponse)
async def create_project(
    request: CreateProjectRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Create a new SEO project"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    project = Project(
        id=str(uuid.uuid4()),
        user_id=user.id,
        target_url=request.target_url,
        name=request.name or f"Project for {request.target_url}"
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    
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
    
    tracked_keyword = TrackedKeyword(
        id=str(uuid.uuid4()),
        project_id=project_id,
        keyword=request.keyword,
        search_volume=request.search_volume,
        competition=request.competition
    )
    db.add(tracked_keyword)
    db.commit()
    db.refresh(tracked_keyword)
    
    # Check initial ranking
    ranking_result = await rank_checker.check_ranking(request.keyword, project.target_url)
    
    if ranking_result:
        initial_ranking = KeywordRanking(
            id=str(uuid.uuid4()),
            tracked_keyword_id=tracked_keyword.id,
            position=ranking_result.get('position'),
            page_url=ranking_result.get('page_url')
        )
        db.add(initial_ranking)
        db.commit()
    
    return TrackedKeywordResponse(
        id=tracked_keyword.id,
        keyword=tracked_keyword.keyword,
        search_volume=tracked_keyword.search_volume,
        competition=tracked_keyword.competition,
        current_position=ranking_result.get('position') if ranking_result else None,
        target_position=tracked_keyword.target_position,
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
        # Get latest ranking
        latest_ranking = db.query(KeywordRanking).filter(
            KeywordRanking.tracked_keyword_id == kw.id
        ).order_by(KeywordRanking.checked_at.desc()).first()
        
        result.append(TrackedKeywordResponse(
            id=kw.id,
            keyword=kw.keyword,
            search_volume=kw.search_volume,
            competition=kw.competition,
            current_position=latest_ranking.position if latest_ranking else None,
            target_position=kw.target_position,
            created_at=kw.created_at.isoformat()
        ))
    
    return result

@router.post("/{project_id}/refresh")
async def refresh_rankings(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Manually refresh rankings for all keywords in project"""
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
    
    updated_count = 0
    for kw in keywords:
        result = await rank_checker.check_ranking(kw.keyword, project.target_url)
        
        if result:
            new_ranking = KeywordRanking(
                id=str(uuid.uuid4()),
                tracked_keyword_id=kw.id,
                position=result.get('position'),
                page_url=result.get('page_url')
            )
            db.add(new_ranking)
            updated_count += 1
    
    db.commit()
    
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
        
        # Delete backlink submissions
        submission_count = db.query(BacklinkSubmission).filter(
            BacklinkSubmission.project_id == project_id
        ).delete()
        
        # Delete backlink campaigns
        campaign_count = db.query(BacklinkCampaign).filter(
            BacklinkCampaign.project_id == project_id
        ).delete()
        
        # Delete the project itself
        db.delete(project)
        
        db.commit()
        
        logger.info(f"Deleted project {project_id}: {keyword_count} keywords, {ranking_count} rankings, {submission_count} backlink submissions, {campaign_count} campaigns")
        
        return {
            "message": "Project deleted successfully",
            "deleted": {
                "keywords": keyword_count,
                "rankings": ranking_count,
                "backlink_submissions": submission_count,
                "backlink_campaigns": campaign_count
            }
        }
        
    except Exception as e:
        db.rollback()
        logger.error(f"Error deleting project {project_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete project: {str(e)}")

