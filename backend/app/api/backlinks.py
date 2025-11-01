"""
API endpoints for backlink management
"""
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from typing import List, Dict, Any
import logging
import jwt

from app.database import get_db
from app.models.user import User
from app.models.project import Project
from app.services.backlink_service import BacklinkService
from app.config import get_settings

router = APIRouter(prefix="/api/v1/backlinks", tags=["backlinks"])
logger = logging.getLogger(__name__)
backlink_service = BacklinkService()
settings = get_settings()


@router.get("/project/{project_id}/submissions")
async def get_project_backlinks(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get all backlink submissions for a project"""
    
    # Verify token and get user
    try:
        token = authorization.replace("Bearer ", "")
        logger.info(f"Decoding token for backlinks request")
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("user_id")  # Fixed: use "user_id" not "sub"
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            logger.error(f"User not found for ID: {user_id}")
            raise HTTPException(status_code=401, detail="Invalid authentication")
        logger.info(f"Auth successful for user: {user_id}")
    except jwt.InvalidTokenError as e:
        logger.error(f"JWT decode error: {e}")
        raise HTTPException(status_code=401, detail="Invalid authentication")
    except Exception as e:
        logger.error(f"Unexpected auth error: {e}")
        raise HTTPException(status_code=401, detail="Invalid authentication")
    
    # Verify project belongs to user
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Get all submissions
    submissions = backlink_service.get_project_submissions(db, project_id)
    
    # Get campaign info if exists
    from app.models.backlink import BacklinkCampaign
    latest_campaign = db.query(BacklinkCampaign).filter(
        BacklinkCampaign.project_id == project_id
    ).order_by(BacklinkCampaign.created_at.desc()).first()
    
    # Count by status
    status_counts = {
        "pending": 0,
        "submitted": 0,
        "approved": 0,
        "indexed": 0,
        "rejected": 0
    }
    
    for sub in submissions:
        status = sub.get('status', 'pending')
        if status in status_counts:
            status_counts[status] += 1
    
    return {
        "project_id": project_id,
        "project_name": project.name or project.target_url,
        "total_submissions": len(submissions),
        "status_breakdown": status_counts,
        "submissions": submissions,
        "campaign": {
            "id": latest_campaign.id if latest_campaign else None,
            "created_at": latest_campaign.created_at.isoformat() if latest_campaign else None,
            "total_directories": latest_campaign.total_directories if latest_campaign else 0
        } if latest_campaign else None
    }


@router.get("/project/{project_id}/campaigns")
async def get_project_campaigns(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get all backlink campaigns for a project"""
    
    # Verify token and get user
    try:
        token = authorization.replace("Bearer ", "")
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("user_id")  # Fixed: use "user_id" not "sub"
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=401, detail="Invalid authentication")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid authentication")
    
    # Verify project belongs to user
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    from app.models.backlink import BacklinkCampaign
    campaigns = db.query(BacklinkCampaign).filter(
        BacklinkCampaign.project_id == project_id
    ).order_by(BacklinkCampaign.created_at.desc()).all()
    
    results = []
    for campaign in campaigns:
        results.append({
            "id": campaign.id,
            "created_at": campaign.created_at.isoformat(),
            "total_directories": campaign.total_directories,
            "category_filter": campaign.category_filter
        })
    
    return {
        "project_id": project_id,
        "campaigns": results
    }

