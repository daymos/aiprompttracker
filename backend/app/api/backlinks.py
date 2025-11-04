"""
API endpoints for backlink management
"""
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
import logging
from jose import jwt
from datetime import datetime

from app.database import get_db
from app.models.user import User
from app.models.project import Project
from app.models.backlink import BacklinkSubmission
from app.models.backlink_analysis import BacklinkAnalysis
from app.services.backlink_service import BacklinkService
from app.services.rapidapi_backlinks_service import RapidAPIBacklinkService
from app.services.backlink_verifier import BacklinkVerifier
from app.config import get_settings

router = APIRouter(prefix="/api/v1/backlinks", tags=["backlinks"])
logger = logging.getLogger(__name__)
backlink_service = BacklinkService()
rapidapi_backlink_service = RapidAPIBacklinkService()
backlink_verifier = BacklinkVerifier()
settings = get_settings()


class UpdateSubmissionRequest(BaseModel):
    status: str  # pending, submitted, approved, rejected, indexed
    notes: Optional[str] = None


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


@router.patch("/submission/{submission_id}")
async def update_submission_status(
    submission_id: str,
    request: UpdateSubmissionRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Update the status of a backlink submission"""
    
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
    
    # Get submission
    submission = db.query(BacklinkSubmission).filter(
        BacklinkSubmission.id == submission_id
    ).first()
    
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")
    
    # Verify user owns the project
    project = db.query(Project).filter(
        Project.id == submission.project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Validate status
    valid_statuses = ["pending", "submitted", "approved", "rejected", "indexed"]
    if request.status not in valid_statuses:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid status. Must be one of: {', '.join(valid_statuses)}"
        )
    
    # Update submission
    old_status = submission.status
    submission.status = request.status
    
    # Update timestamps
    if request.status == "submitted" and not submission.submitted_at:
        submission.submitted_at = datetime.utcnow()
    elif request.status == "indexed" and not submission.indexed_at:
        submission.indexed_at = datetime.utcnow()
    
    # Add notes to existing notes (append)
    if request.notes:
        existing_notes = submission.notes or ""
        timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M")
        new_note = f"[{timestamp}] {request.notes}"
        submission.notes = f"{existing_notes}\n{new_note}".strip() if existing_notes else new_note
    
    db.commit()
    
    logger.info(f"Updated submission {submission_id}: {old_status} → {request.status}")
    
    return {
        "message": "Submission updated successfully",
        "submission": {
            "id": submission.id,
            "directory_name": submission.directory.name,
            "status": submission.status,
            "notes": submission.notes,
            "submitted_at": submission.submitted_at.isoformat() if submission.submitted_at else None,
            "indexed_at": submission.indexed_at.isoformat() if submission.indexed_at else None
        }
    }


@router.post("/submission/{submission_id}/verify")
async def verify_submission(
    submission_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Verify if a backlink submission is live on the directory"""
    
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
    
    # Get submission
    submission = db.query(BacklinkSubmission).filter(
        BacklinkSubmission.id == submission_id
    ).first()
    
    if not submission:
        raise HTTPException(status_code=404, detail="Submission not found")
    
    # Verify user owns the project
    project = db.query(Project).filter(
        Project.id == submission.project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=403, detail="Access denied")
    
    # Check if directory URL exists
    directory_url = submission.directory.url
    if not directory_url:
        return {
            "verified": False,
            "error": "Directory URL not available for verification"
        }
    
    # Verify the backlink
    verification = await backlink_verifier.verify_backlink(
        directory_url=directory_url,
        target_domain=project.target_url.replace('https://', '').replace('http://', '').split('/')[0],
        target_url=project.target_url
    )
    
    # Auto-update status based on verification
    old_status = submission.status
    
    if verification["found"]:
        if verification["indexed"]:
            submission.status = "indexed"
            submission.indexed_at = datetime.utcnow()
        else:
            submission.status = "approved"
        
        # Add verification note
        timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M")
        note = f"[{timestamp}] Auto-verified: Backlink found on directory page"
        if verification["link_url"]:
            note += f" ({verification['link_url']})"
        
        existing_notes = submission.notes or ""
        submission.notes = f"{existing_notes}\n{note}".strip() if existing_notes else note
        
        db.commit()
        
        logger.info(f"Verified submission {submission_id}: {old_status} → {submission.status}")
    else:
        # Still pending/submitted
        if verification.get("error"):
            logger.warning(f"Error verifying {submission_id}: {verification['error']}")
    
    return {
        "submission_id": submission_id,
        "directory_name": submission.directory.name,
        "old_status": old_status,
        "new_status": submission.status,
        "verification": verification
    }


@router.post("/project/{project_id}/verify-all")
async def verify_all_submissions(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Verify all backlink submissions for a project"""
    
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
    
    # Verify project belongs to user
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Get all submissions
    submissions = db.query(BacklinkSubmission).filter(
        BacklinkSubmission.project_id == project_id,
        BacklinkSubmission.status.in_(["submitted", "pending"])  # Only check pending/submitted
    ).all()
    
    if not submissions:
        return {
            "message": "No submissions to verify",
            "total": 0,
            "verified": 0,
            "found": 0
        }
    
    # Verify each submission
    results = []
    found_count = 0
    
    for submission in submissions:
        if not submission.directory.url:
            continue
        
        verification = await backlink_verifier.verify_backlink(
            directory_url=submission.directory.url,
            target_domain=project.target_url.replace('https://', '').replace('http://', '').split('/')[0],
            target_url=project.target_url
        )
        
        old_status = submission.status
        
        if verification["found"]:
            found_count += 1
            
            if verification["indexed"]:
                submission.status = "indexed"
                submission.indexed_at = datetime.utcnow()
            else:
                submission.status = "approved"
            
            # Add verification note
            timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M")
            note = f"[{timestamp}] Auto-verified: Backlink found"
            existing_notes = submission.notes or ""
            submission.notes = f"{existing_notes}\n{note}".strip() if existing_notes else note
            
            results.append({
                "directory": submission.directory.name,
                "old_status": old_status,
                "new_status": submission.status,
                "found": True
            })
        else:
            results.append({
                "directory": submission.directory.name,
                "status": submission.status,
                "found": False
            })
    
    db.commit()
    
    logger.info(f"Verified {len(submissions)} submissions for project {project_id}: {found_count} found")
    
    return {
        "message": f"Verified {len(submissions)} submissions, found {found_count} backlinks",
        "total": len(submissions),
        "verified": len(results),
        "found": found_count,
        "results": results
    }

