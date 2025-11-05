"""
API endpoints for backlink analysis
"""
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
import logging
from jose import jwt
from datetime import datetime

from app.database import get_db
from app.models.user import User
from app.models.project import Project
from app.models.backlink_analysis import BacklinkAnalysis
from app.services.rapidapi_backlinks_service import RapidAPIBacklinkService
from app.config import get_settings

router = APIRouter(prefix="/api/v1/backlinks", tags=["backlinks"])
logger = logging.getLogger(__name__)
rapidapi_backlink_service = RapidAPIBacklinkService()
settings = get_settings()


@router.get("/project/{project_id}/analyze")
async def get_project_backlink_analysis(
    project_id: str,
    refresh: bool = False,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get backlink analysis for a project (cached or fresh from RapidAPI)
    
    Args:
        project_id: Project ID
        refresh: If True, fetch fresh data from RapidAPI. If False, return cached data if available.
    """
    
    # Verify token and get user
    try:
        token = authorization.replace("Bearer ", "")
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("user_id")
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=401, detail="Invalid authentication")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid authentication")
    
    # Get project and verify ownership
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user_id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Check if we have cached data and user doesn't want refresh
    if not refresh:
        existing_analysis = db.query(BacklinkAnalysis).filter(
            BacklinkAnalysis.project_id == project_id
        ).first()
        
        if existing_analysis:
            logger.info(f"Returning cached backlink analysis for project {project_id}")
            return existing_analysis.to_dict()
    
    # Need to fetch fresh data from RapidAPI
    # Extract domain from project URL
    from urllib.parse import urlparse
    parsed = urlparse(project.target_url)
    domain = parsed.netloc or parsed.path
    domain = domain.replace('www.', '')
    
    # Check backlink quota
    if user.backlink_rows_used >= user.backlink_rows_limit:
        raise HTTPException(
            status_code=429,
            detail=f"Backlink limit reached ({user.backlink_rows_limit}/month)"
        )
    
    # Fetch backlinks from RapidAPI
    try:
        logger.info(f"Fetching fresh backlink data for {domain}")
        backlink_data = await rapidapi_backlink_service.get_backlinks(domain, limit=50)
        
        if backlink_data and not backlink_data.get("error"):
            # Increment usage counter
            user.backlink_rows_used += 1
            
            # Store/update in database
            existing = db.query(BacklinkAnalysis).filter(
                BacklinkAnalysis.project_id == project_id
            ).first()
            
            if existing:
                # Update existing record
                existing.total_backlinks = backlink_data.get("total_backlinks", 0)
                existing.referring_domains = backlink_data.get("referring_domains", 0)
                existing.domain_authority = backlink_data.get("domain_authority", 0)
                existing.raw_data = backlink_data
                existing.analyzed_at = datetime.utcnow()
                analysis = existing
            else:
                # Create new record
                analysis = BacklinkAnalysis(
                    project_id=project_id,
                    total_backlinks=backlink_data.get("total_backlinks", 0),
                    referring_domains=backlink_data.get("referring_domains", 0),
                    domain_authority=backlink_data.get("domain_authority", 0),
                    raw_data=backlink_data,
                    analyzed_at=datetime.utcnow()
                )
                db.add(analysis)
            
            db.commit()
            db.refresh(analysis)
            
            logger.info(f"Stored backlink analysis: {analysis.total_backlinks} backlinks from {analysis.referring_domains} domains")
            
            return analysis.to_dict()
        else:
            # API failed - check if we have cached data to return
            error_msg = backlink_data.get("error", "Failed to fetch backlinks")
            logger.warning(f"Backlink API error: {error_msg}")
            
            existing_analysis = db.query(BacklinkAnalysis).filter(
                BacklinkAnalysis.project_id == project_id
            ).first()
            
            if existing_analysis:
                logger.info(f"Returning cached data due to API error")
                result = existing_analysis.to_dict()
                result["is_cached"] = True
                result["cache_note"] = "Using cached data - API quota exceeded"
                return result
            else:
                # No cached data available
                logger.warning(f"No cached data available for project {project_id}")
                return {
                    "domain_authority": 0,
                    "total_backlinks": 0,
                    "referring_domains": 0,
                    "overtime": [],
                    "new_and_lost": [],
                    "backlinks": [],
                    "anchors": [],
                    "is_cached": False,
                    "error": error_msg
                }
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Error analyzing backlinks for {domain}: {error_msg}")
        
        # Try to return cached data instead of throwing error
        existing_analysis = db.query(BacklinkAnalysis).filter(
            BacklinkAnalysis.project_id == project_id
        ).first()
        
        if existing_analysis:
            logger.info(f"Returning cached data due to exception")
            result = existing_analysis.to_dict()
            result["is_cached"] = True
            result["cache_note"] = f"Using cached data - Error: {error_msg}"
            return result
        else:
            # No cached data - return empty response instead of 500 error
            logger.warning(f"No cached data available, returning empty response")
            return {
                "domain_authority": 0,
                "total_backlinks": 0,
                "referring_domains": 0,
                "overtime": [],
                "new_and_lost": [],
                "backlinks": [],
                "anchors": [],
                "is_cached": False,
                "error": error_msg
            }
