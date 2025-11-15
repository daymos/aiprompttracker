"""
API endpoints for managing projects and running scans
"""

from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from typing import List, Optional, Dict
import uuid
from datetime import datetime, timedelta

from ..config import get_settings
from ..database import get_db
from ..models.user import User
from ..models.project import Project, Scan, ScanResult, VisibilityScore
from ..api.auth import get_current_user
from ..services.scanner import ScannerService

router = APIRouter(prefix="/projects", tags=["projects"])
settings = get_settings()


# Request/Response Models
class ProjectCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    domain: str = Field(..., min_length=1, max_length=255)
    brand_terms: List[str] = Field(..., min_items=1)
    keywords: List[str] = Field(default=[])
    competitors: List[str] = Field(default=[])
    use_cases: List[str] = Field(default=[])
    enabled_providers: List[str] = Field(default=["openai"])


class ProjectUpdate(BaseModel):
    name: Optional[str] = None
    keywords: Optional[List[str]] = None
    competitors: Optional[List[str]] = None
    use_cases: Optional[List[str]] = None
    enabled_providers: Optional[List[str]] = None
    is_active: Optional[bool] = None
    scan_frequency: Optional[str] = None


class ProjectResponse(BaseModel):
    id: str
    name: str
    domain: str
    brand_terms: List[str]
    keywords: List[str]
    competitors: List[str]
    use_cases: List[str]
    enabled_providers: List[str]
    is_active: bool
    scan_frequency: str
    last_scanned_at: Optional[datetime]
    current_score: Optional[float]
    previous_score: Optional[float]
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True


class ScanTriggerRequest(BaseModel):
    scan_type: str = Field(default="full", pattern="^(full|quick|custom)$")
    providers: Optional[List[str]] = None  # Override default providers


class ScanResponse(BaseModel):
    id: str
    project_id: str
    scan_type: str
    status: str
    total_prompts: int
    prompts_with_mention: int
    providers_checked: List[str]
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    duration_seconds: Optional[float]
    error_message: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class ScanResultResponse(BaseModel):
    id: str
    provider: str
    model: str
    prompt_type: str
    prompt_text: str
    response_text: str
    brand_found: bool
    brand_mentions: List[str]
    context_snippets: List[str]
    mention_rank: Optional[int]
    created_at: datetime

    class Config:
        from_attributes = True


class VisibilityScoreResponse(BaseModel):
    id: str
    date: datetime
    overall_score: float
    provider_scores: Dict[str, float]
    total_prompts_tested: int
    prompts_with_mention: int
    mention_rate: float
    score_change: Optional[float]
    score_trend: Optional[str]

    class Config:
        from_attributes = True


# Helper to get user's project
def get_user_project(project_id: str, user: User, db: Session) -> Project:
    """Get project belonging to user or raise 404"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    return project


# Endpoints

@router.post("", response_model=ProjectResponse, status_code=201)
async def create_project(
    project_data: ProjectCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new project for tracking brand visibility"""
    
    # Check user's project limit
    project_count = db.query(Project).filter(Project.user_id == user.id).count()
    if project_count >= user.projects_limit:
        raise HTTPException(
            status_code=403,
            detail=f"Project limit reached. Upgrade to create more projects."
        )
    
    # Create project
    project = Project(
        id=str(uuid.uuid4()),
        user_id=user.id,
        name=project_data.name,
        domain=project_data.domain,
        brand_terms=project_data.brand_terms,
        keywords=project_data.keywords,
        competitors=project_data.competitors,
        use_cases=project_data.use_cases,
        enabled_providers=project_data.enabled_providers
    )
    
    db.add(project)
    db.commit()
    db.refresh(project)
    
    return project


@router.get("", response_model=List[ProjectResponse])
async def list_projects(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """List all projects for the current user"""
    projects = db.query(Project).filter(Project.user_id == user.id).all()
    return projects


@router.get("/{project_id}", response_model=ProjectResponse)
async def get_project(
    project_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific project"""
    project = get_user_project(project_id, user, db)
    return project


@router.patch("/{project_id}", response_model=ProjectResponse)
async def update_project(
    project_id: str,
    update_data: ProjectUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update a project"""
    project = get_user_project(project_id, user, db)
    
    # Update fields
    for field, value in update_data.dict(exclude_unset=True).items():
        setattr(project, field, value)
    
    db.commit()
    db.refresh(project)
    
    return project


@router.delete("/{project_id}", status_code=204)
async def delete_project(
    project_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a project and all its data"""
    project = get_user_project(project_id, user, db)
    db.delete(project)
    db.commit()
    return None


@router.post("/{project_id}/scan", response_model=ScanResponse, status_code=202)
async def trigger_scan(
    project_id: str,
    scan_request: ScanTriggerRequest,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Trigger a new scan for a project"""
    project = get_user_project(project_id, user, db)
    
    # Check scan limits for non-subscribed users
    if not user.is_subscribed:
        # Reset counter if needed
        if user.usage_reset_at < datetime.utcnow():
            user.scans_used_this_month = 0
            user.usage_reset_at = datetime.utcnow() + timedelta(days=30)
            db.commit()
        
        if user.scans_used_this_month >= user.scans_per_month:
            raise HTTPException(
                status_code=403,
                detail=f"Monthly scan limit reached. Upgrade to scan more projects."
            )
    
    # Create scan record
    scan = Scan(
        id=str(uuid.uuid4()),
        project_id=project.id,
        scan_type=scan_request.scan_type,
        status="pending",
        providers_checked=scan_request.providers or project.enabled_providers
    )
    
    db.add(scan)
    
    # Increment usage counter
    if not user.is_subscribed:
        user.scans_used_this_month += 1
    
    db.commit()
    db.refresh(scan)
    
    # Run scan in background
    background_tasks.add_task(run_scan_task, scan.id, db)
    
    return scan


@router.get("/{project_id}/scans", response_model=List[ScanResponse])
async def list_scans(
    project_id: str,
    limit: int = 10,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """List scans for a project"""
    project = get_user_project(project_id, user, db)
    
    scans = db.query(Scan).filter(
        Scan.project_id == project.id
    ).order_by(Scan.created_at.desc()).limit(limit).all()
    
    return scans


@router.get("/{project_id}/scans/{scan_id}", response_model=ScanResponse)
async def get_scan(
    project_id: str,
    scan_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific scan"""
    project = get_user_project(project_id, user, db)
    
    scan = db.query(Scan).filter(
        Scan.id == scan_id,
        Scan.project_id == project.id
    ).first()
    
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")
    
    return scan


@router.get("/{project_id}/scans/{scan_id}/results", response_model=List[ScanResultResponse])
async def get_scan_results(
    project_id: str,
    scan_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get results for a specific scan"""
    project = get_user_project(project_id, user, db)
    
    scan = db.query(Scan).filter(
        Scan.id == scan_id,
        Scan.project_id == project.id
    ).first()
    
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")
    
    results = db.query(ScanResult).filter(ScanResult.scan_id == scan.id).all()
    
    return results


@router.get("/{project_id}/scores", response_model=List[VisibilityScoreResponse])
async def get_visibility_scores(
    project_id: str,
    days: int = 30,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get historical visibility scores for a project"""
    project = get_user_project(project_id, user, db)
    
    since = datetime.utcnow() - timedelta(days=days)
    
    scores = db.query(VisibilityScore).filter(
        VisibilityScore.project_id == project.id,
        VisibilityScore.date >= since
    ).order_by(VisibilityScore.date.desc()).all()
    
    return scores


# Background task
async def run_scan_task(scan_id: str, db: Session):
    """Run scan in background"""
    from ..services.scanner import ScannerService
    
    scanner = ScannerService(db)
    await scanner.execute_scan(scan_id)

