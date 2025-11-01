import httpx
import logging
from typing import Optional, Dict, Any, List
from datetime import datetime
import uuid
from sqlalchemy.orm import Session

from ..models.backlink import Directory, BacklinkSubmission, BacklinkCampaign, SubmissionStatus
from ..models.project import Project
from ..data.directories import DIRECTORY_DATABASE

logger = logging.getLogger(__name__)

class BacklinkService:
    """Service for managing backlink submissions to directories"""
    
    # Legacy - keeping for backwards compatibility but using DIRECTORY_DATABASE now
    STARTER_DIRECTORIES_LEGACY = [
        {
            "name": "Product Hunt",
            "url": "https://producthunt.com",
            "category": "Startup Directories",
            "submission_url": "https://producthunt.com/posts/new",
            "requires_manual": 1,
            "domain_authority": 92
        },
        {
            "name": "Hacker News",
            "url": "https://news.ycombinator.com",
            "category": "Tech Communities",
            "submission_url": "https://news.ycombinator.com/submit",
            "requires_manual": 1,
            "domain_authority": 95
        },
        {
            "name": "GetMoreBacklinks",
            "url": "https://getmorebacklinks.org",
            "category": "Backlink Directories",
            "submission_url": "https://getmorebacklinks.org/submit",
            "requires_manual": 1,
            "domain_authority": 45
        },
        {
            "name": "StartupStash",
            "url": "https://startupstash.com",
            "category": "Startup Directories",
            "submission_url": "https://startupstash.com/submit",
            "requires_manual": 1,
            "domain_authority": 62
        },
        {
            "name": "BetaList",
            "url": "https://betalist.com",
            "category": "Startup Directories",
            "submission_url": "https://betalist.com/submit",
            "requires_manual": 1,
            "domain_authority": 71
        },
        {
            "name": "SaaS Hub",
            "url": "https://saashub.com",
            "category": "SaaS Directories",
            "submission_url": "https://saashub.com/submit",
            "requires_manual": 1,
            "domain_authority": 58
        },
        {
            "name": "There's An AI For That",
            "url": "https://theresanaiforthat.com",
            "category": "AI Directories",
            "submission_url": "https://theresanaiforthat.com/submit",
            "requires_manual": 1,
            "domain_authority": 67
        },
        {
            "name": "AI Tools Directory",
            "url": "https://aitoolsdirectory.com",
            "category": "AI Directories",
            "submission_url": "https://aitoolsdirectory.com/submit",
            "requires_manual": 1,
            "domain_authority": 42
        },
        {
            "name": "Futurepedia",
            "url": "https://futurepedia.io",
            "category": "AI Directories",
            "submission_url": "https://futurepedia.io/submit",
            "requires_manual": 1,
            "domain_authority": 65
        },
        {
            "name": "TopAI.tools",
            "url": "https://topai.tools",
            "category": "AI Directories",
            "submission_url": "https://topai.tools/submit",
            "requires_manual": 1,
            "domain_authority": 48
        }
    ]
    
    def __init__(self):
        pass
    
    def seed_directories(self, db: Session) -> int:
        """Seed database with all directories from DIRECTORY_DATABASE"""
        added_count = 0
        
        for dir_data in DIRECTORY_DATABASE:
            try:
                # Check if already exists
                existing = db.query(Directory).filter(Directory.name == dir_data["name"]).first()
                if not existing:
                    directory = Directory(
                        id=str(uuid.uuid4()),
                        name=dir_data["name"],
                        url=dir_data["url"],
                        category=dir_data["category"],
                        submission_url=dir_data.get("submission_url"),
                        requires_manual=dir_data.get("requires_manual", 1),
                        automation_method=dir_data.get("automation_method"),
                        form_fields=dir_data.get("form_fields"),
                        domain_authority=dir_data.get("domain_authority"),
                        tier=dir_data.get("tier"),
                        notes=dir_data.get("notes"),
                        is_active=1
                    )
                    db.add(directory)
                    added_count += 1
            except Exception as e:
                logger.warning(f"Failed to add directory {dir_data.get('name')}: {str(e)}")
                continue
        
        try:
            db.commit()
            logger.info(f"Seeded {added_count} directories from database of {len(DIRECTORY_DATABASE)} total")
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to commit directories: {str(e)}")
            raise
        
        return added_count
    
    def _calculate_relevance_score(self, directory: Directory, description: str) -> int:
        """Calculate relevance score for a directory based on product description"""
        score = 0
        description_lower = description.lower()
        category = directory.category.lower() if directory.category else ""
        
        # AI products
        if any(word in description_lower for word in ['ai', 'artificial intelligence', 'machine learning', 'gpt', 'llm']):
            if 'ai' in category:
                score += 10
            elif 'tech' in category or 'startup' in category:
                score += 3
        
        # SaaS products
        if any(word in description_lower for word in ['saas', 'software', 'platform', 'tool', 'service']):
            if 'saas' in category:
                score += 10
            elif 'startup' in category or 'productivity' in category:
                score += 5
        
        # Startup/early stage
        if any(word in description_lower for word in ['startup', 'launch', 'new', 'beta']):
            if 'startup' in category:
                score += 8
            elif 'tech' in category:
                score += 4
        
        # Productivity/tools
        if any(word in description_lower for word in ['productivity', 'automation', 'workflow']):
            if 'productivity' in category:
                score += 10
            elif 'tool' in category or 'saas' in category:
                score += 5
        
        # Boost high DA directories
        if directory.domain_authority:
            if directory.domain_authority >= 70:
                score += 3
            elif directory.domain_authority >= 50:
                score += 2
            elif directory.domain_authority >= 30:
                score += 1
        
        # Always include some general directories
        if any(word in category for word in ['startup', 'backlink']):
            score += 2
        
        return score
    
    async def create_submission_campaign(
        self,
        db: Session,
        project_id: str,
        user_id: str,
        category_filter: Optional[str] = None,
        project_description: str = ""
    ) -> BacklinkCampaign:
        """
        Create a backlink submission campaign for a project
        
        Args:
            project_id: The project to submit
            user_id: User creating the campaign
            category_filter: Optional filter (e.g., "AI", "SaaS", "Startup")
            project_description: Description of the product for smart recommendations
        
        Returns:
            BacklinkCampaign object with top relevant directories
        """
        
        # Get project
        project = db.query(Project).filter(Project.id == project_id).first()
        if not project:
            raise ValueError(f"Project {project_id} not found")
        
        # Strategy: Get ALL automated directories + top manual ones
        all_dirs = db.query(Directory).filter(Directory.is_active == 1).all()
        
        # Split by automation capability
        automated_dirs = [d for d in all_dirs if d.automation_method in ['form_post', 'api']]
        manual_dirs = [d for d in all_dirs if d.automation_method == 'manual' or d.tier == 'top']
        
        logger.info(f"Found {len(automated_dirs)} automated directories and {len(manual_dirs)} manual directories")
        
        # Filter automated by relevance if we have description
        if project_description:
            # Score automated directories
            scored_auto = []
            for d in automated_dirs:
                score = self._calculate_relevance_score(d, project_description)
                scored_auto.append((d, score))
            scored_auto.sort(key=lambda x: x[1], reverse=True)
            automated_dirs = [d[0] for d in scored_auto]  # Take all automated
            logger.info(f"Scored and sorted {len(automated_dirs)} automated directories")
        
        # Get top 5-8 manual directories
        if project_description:
            scored_manual = []
            for d in manual_dirs:
                score = self._calculate_relevance_score(d, project_description)
                scored_manual.append((d, score))
            scored_manual.sort(key=lambda x: (x[1], x[0].domain_authority or 0), reverse=True)
            manual_dirs = [d[0] for d in scored_manual[:8]]  # Top 8 manual
        else:
            # Sort manual by DA
            manual_dirs.sort(key=lambda d: d.domain_authority or 0, reverse=True)
            manual_dirs = manual_dirs[:8]
        
        # Combine: All automated + top manual
        directories = automated_dirs + manual_dirs
        
        logger.info(f"Total directories for campaign: {len(directories)} ({len(automated_dirs)} automated + {len(manual_dirs)} manual)")
        
        # Create campaign
        campaign = BacklinkCampaign(
            id=str(uuid.uuid4()),
            project_id=project_id,
            user_id=user_id,
            category_filter=category_filter,
            total_directories=len(directories)
        )
        db.add(campaign)
        
        # Create submission records for each directory
        for directory in directories:
            # Check if already submitted
            existing = db.query(BacklinkSubmission).filter(
                BacklinkSubmission.project_id == project_id,
                BacklinkSubmission.directory_id == directory.id
            ).first()
            
            if not existing:
                # Auto-submit if directory allows it
                initial_status = "pending"
                if directory.automation_method == 'form_post':
                    # Will be auto-submitted
                    initial_status = "submitted"
                elif directory.automation_method == 'api':
                    initial_status = "submitted"
                    
                submission = BacklinkSubmission(
                    id=str(uuid.uuid4()),
                    campaign_id=campaign.id,
                    project_id=project_id,
                    directory_id=directory.id,
                    submission_url=directory.submission_url,
                    status=initial_status,
                    submitted_at=datetime.utcnow() if initial_status == "submitted" else None
                )
                db.add(submission)
        
        db.commit()
        db.refresh(campaign)
        
        logger.info(f"Created campaign {campaign.id} with {len(directories)} directories")
        return campaign
    
    def get_campaign_status(
        self,
        db: Session,
        campaign_id: str
    ) -> Dict[str, Any]:
        """Get detailed status of a submission campaign"""
        
        campaign = db.query(BacklinkCampaign).filter(BacklinkCampaign.id == campaign_id).first()
        if not campaign:
            raise ValueError(f"Campaign {campaign_id} not found")
        
        # Get submission breakdown
        submissions = db.query(BacklinkSubmission).filter(
            BacklinkSubmission.project_id == campaign.project_id
        ).all()
        
        status_counts = {}
        for submission in submissions:
            status_counts[submission.status] = status_counts.get(submission.status, 0) + 1
        
        return {
            "campaign_id": campaign.id,
            "project_id": campaign.project_id,
            "category_filter": campaign.category_filter,
            "total_directories": campaign.total_directories,
            "status_breakdown": status_counts,
            "created_at": campaign.created_at
        }
    
    def get_project_submissions(
        self,
        db: Session,
        project_id: str,
        campaign_id: str = None
    ) -> List[Dict[str, Any]]:
        """Get all submissions for a project with directory details"""
        
        query = db.query(BacklinkSubmission).filter(
            BacklinkSubmission.project_id == project_id
        )
        
        if campaign_id:
            query = query.filter(BacklinkSubmission.campaign_id == campaign_id)
        
        submissions = query.all()
        
        results = []
        for sub in submissions:
            results.append({
                "id": sub.id,
                "directory": {
                    "name": sub.directory.name,
                    "url": sub.directory.url,
                    "category": sub.directory.category,
                    "domain_authority": sub.directory.domain_authority,
                    "tier": sub.directory.tier
                },
                "status": sub.status,
                "submission_url": sub.submission_url,
                "submitted_at": sub.submitted_at,
                "indexed_at": sub.indexed_at
            })
        
        return results
    
    async def simulate_submission(
        self,
        db: Session,
        submission_id: str
    ) -> bool:
        """
        Simulate submitting to a directory
        (In reality, most require manual submission via their forms)
        
        Returns True if submission was updated
        """
        
        submission = db.query(BacklinkSubmission).filter(
            BacklinkSubmission.id == submission_id
        ).first()
        
        if not submission:
            return False
        
        # Mark as submitted (user will need to manually submit)
        submission.status = SubmissionStatus.SUBMITTED
        submission.submitted_at = datetime.utcnow()
        
        db.commit()
        
        logger.info(f"Marked submission {submission_id} as SUBMITTED")
        return True

