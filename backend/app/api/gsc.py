"""Google Search Console API endpoints"""
from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
import logging

from ..database import get_db
from ..models.user import User
from ..models.project import Project
from ..services.gsc_service import GSCService
from .auth import get_current_user

router = APIRouter(prefix="/gsc", tags=["gsc"])
logger = logging.getLogger(__name__)

gsc_service = GSCService()


class GSCAuthRequest(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    expires_at: Optional[str] = None  # ISO format datetime


class GSCPropertyRequest(BaseModel):
    project_id: str
    property_url: str


class GSCAnalyticsRequest(BaseModel):
    project_id: str
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    dimensions: Optional[List[str]] = None


@router.post("/connect")
async def connect_gsc(
    request: GSCAuthRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Save GSC OAuth tokens for the user"""
    try:
        token = authorization.replace("Bearer ", "")
        user = get_current_user(token, db)
        
        # Parse expiration time
        expires_at = None
        if request.expires_at:
            try:
                expires_at = datetime.fromisoformat(request.expires_at.replace('Z', '+00:00'))
            except:
                logger.warning(f"Failed to parse expires_at: {request.expires_at}")
        
        # Save tokens to user
        user.gsc_access_token = request.access_token
        user.gsc_refresh_token = request.refresh_token
        user.gsc_token_expires_at = expires_at
        
        db.commit()
        
        return {
            "success": True,
            "message": "Google Search Console connected successfully"
        }
        
    except Exception as e:
        logger.error(f"Error connecting GSC: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/properties")
async def get_gsc_properties(
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get list of GSC properties the user has access to"""
    try:
        token = authorization.replace("Bearer ", "")
        user = get_current_user(token, db)
        
        if not user.gsc_access_token:
            raise HTTPException(
                status_code=400,
                detail="Google Search Console not connected. Please connect first."
            )
        
        # Fetch properties
        properties = await gsc_service.get_site_list(
            access_token=user.gsc_access_token,
            refresh_token=user.gsc_refresh_token
        )
        
        return {
            "properties": properties
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching GSC properties: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/project/link")
async def link_project_to_property(
    request: GSCPropertyRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Link a project to a GSC property"""
    try:
        token = authorization.replace("Bearer ", "")
        user = get_current_user(token, db)
        
        # Get project
        project = db.query(Project).filter(
            Project.id == request.project_id,
            Project.user_id == user.id
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        # Update project with GSC property
        project.gsc_property_url = request.property_url
        db.commit()
        
        return {
            "success": True,
            "message": f"Project linked to {request.property_url}"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error linking project to GSC property: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/project/{project_id}/analytics")
async def get_project_analytics(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get GSC analytics data for a project"""
    try:
        token = authorization.replace("Bearer ", "")
        user = get_current_user(token, db)
        
        if not user.gsc_access_token:
            raise HTTPException(
                status_code=400,
                detail="Google Search Console not connected"
            )
        
        # Get project
        project = db.query(Project).filter(
            Project.id == project_id,
            Project.user_id == user.id
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        if not project.gsc_property_url:
            raise HTTPException(
                status_code=400,
                detail="Project not linked to a GSC property"
            )
        
        # Fetch analytics data
        data = await gsc_service.get_search_analytics(
            access_token=user.gsc_access_token,
            site_url=project.gsc_property_url,
            refresh_token=user.gsc_refresh_token
        )
        
        return data
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching project analytics: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/project/{project_id}/queries")
async def get_project_top_queries(
    project_id: str,
    limit: int = 20,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get top performing queries for a project"""
    try:
        token = authorization.replace("Bearer ", "")
        user = get_current_user(token, db)
        
        if not user.gsc_access_token:
            raise HTTPException(
                status_code=400,
                detail="Google Search Console not connected"
            )
        
        # Get project
        project = db.query(Project).filter(
            Project.id == project_id,
            Project.user_id == user.id
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        if not project.gsc_property_url:
            raise HTTPException(
                status_code=400,
                detail="Project not linked to a GSC property"
            )
        
        # Fetch top queries
        queries = await gsc_service.get_top_queries(
            access_token=user.gsc_access_token,
            site_url=project.gsc_property_url,
            limit=limit,
            refresh_token=user.gsc_refresh_token
        )
        
        return {"queries": queries}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching top queries: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/project/{project_id}/pages")
async def get_project_top_pages(
    project_id: str,
    limit: int = 20,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get top performing pages for a project"""
    try:
        token = authorization.replace("Bearer ", "")
        user = get_current_user(token, db)
        
        if not user.gsc_access_token:
            raise HTTPException(
                status_code=400,
                detail="Google Search Console not connected"
            )
        
        # Get project
        project = db.query(Project).filter(
            Project.id == project_id,
            Project.user_id == user.id
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        if not project.gsc_property_url:
            raise HTTPException(
                status_code=400,
                detail="Project not linked to a GSC property"
            )
        
        # Fetch top pages
        pages = await gsc_service.get_top_pages(
            access_token=user.gsc_access_token,
            site_url=project.gsc_property_url,
            limit=limit,
            refresh_token=user.gsc_refresh_token
        )
        
        return {"pages": pages}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching top pages: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/project/{project_id}/sitemaps")
async def get_project_sitemaps(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get sitemap status for a project"""
    try:
        token = authorization.replace("Bearer ", "")
        user = get_current_user(token, db)
        
        if not user.gsc_access_token:
            raise HTTPException(
                status_code=400,
                detail="Google Search Console not connected"
            )
        
        # Get project
        project = db.query(Project).filter(
            Project.id == project_id,
            Project.user_id == user.id
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        if not project.gsc_property_url:
            raise HTTPException(
                status_code=400,
                detail="Project not linked to a GSC property"
            )
        
        # Fetch sitemaps
        sitemaps = await gsc_service.get_sitemaps(
            access_token=user.gsc_access_token,
            site_url=project.gsc_property_url,
            refresh_token=user.gsc_refresh_token
        )
        
        return {"sitemaps": sitemaps}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching sitemaps: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/project/{project_id}/indexing")
async def get_project_indexing(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get indexing status for a project"""
    try:
        token = authorization.replace("Bearer ", "")
        user = get_current_user(token, db)
        
        if not user.gsc_access_token:
            raise HTTPException(
                status_code=400,
                detail="Google Search Console not connected"
            )
        
        # Get project
        project = db.query(Project).filter(
            Project.id == project_id,
            Project.user_id == user.id
        ).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        if not project.gsc_property_url:
            raise HTTPException(
                status_code=400,
                detail="Project not linked to a GSC property"
            )
        
        # Fetch index coverage
        coverage = await gsc_service.get_index_coverage(
            access_token=user.gsc_access_token,
            site_url=project.gsc_property_url,
            refresh_token=user.gsc_refresh_token
        )
        
        return coverage
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching indexing status: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/disconnect")
async def disconnect_gsc(
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Disconnect GSC from user account"""
    try:
        token = authorization.replace("Bearer ", "")
        user = get_current_user(token, db)
        
        # Clear GSC tokens
        user.gsc_access_token = None
        user.gsc_refresh_token = None
        user.gsc_token_expires_at = None
        
        db.commit()
        
        return {
            "success": True,
            "message": "Google Search Console disconnected"
        }
        
    except Exception as e:
        logger.error(f"Error disconnecting GSC: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

