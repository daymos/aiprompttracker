"""
Handlers for SEO Agent function calling tools
"""
import logging
import uuid
from typing import Dict, Any, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from cryptography.fernet import Fernet
import base64

from ..models.seo_agent import (
    ProjectIntegration,
    ContentToneProfile,
    GeneratedContent,
    ContentGenerationJob
)
from ..models.project import Project
from ..services.cms_service import create_cms_service
from ..services.content_generator import ContentGeneratorService
from ..config import get_settings

logger = logging.getLogger(__name__)

# Simple encryption for passwords (in production, use proper key management)
def _get_encryption_key() -> bytes:
    """Get or create encryption key"""
    settings = get_settings()
    # In production, store this securely (env var, secrets manager)
    key = getattr(settings, 'ENCRYPTION_KEY', None)
    if not key:
        # Generate a key if not exists (for development only!)
        key = Fernet.generate_key()
    elif isinstance(key, str):
        key = key.encode()
    return key


def _encrypt_password(password: str) -> str:
    """Encrypt a password"""
    f = Fernet(_get_encryption_key())
    return f.encrypt(password.encode()).decode()


def _decrypt_password(encrypted: str) -> str:
    """Decrypt a password"""
    f = Fernet(_get_encryption_key())
    return f.decrypt(encrypted.encode()).decode()


async def handle_connect_cms(
    db: AsyncSession,
    project_id: str,
    cms_type: str,
    cms_url: str,
    username: str,
    password: str
) -> Dict[str, Any]:
    """Handle connect_cms tool call"""
    try:
        # Verify project exists
        result = await db.execute(select(Project).where(Project.id == project_id))
        project = result.scalar_one_or_none()
        
        if not project:
            return {
                "success": False,
                "error": "Project not found"
            }
        
        # Test connection first
        cms_service = create_cms_service(cms_type, cms_url=cms_url, username=username, password=password)
        if not cms_service:
            return {
                "success": False,
                "error": f"Unsupported CMS type: {cms_type}"
            }
        
        test_result = await cms_service.test_connection()
        
        if not test_result.get("success"):
            return {
                "success": False,
                "error": test_result.get("error", "Connection test failed")
            }
        
        # Encrypt password
        encrypted_password = _encrypt_password(password)
        
        # Check if integration already exists
        result = await db.execute(
            select(ProjectIntegration).where(
                ProjectIntegration.project_id == project_id,
                ProjectIntegration.cms_type == cms_type
            )
        )
        existing_integration = result.scalar_one_or_none()
        
        if existing_integration:
            # Update existing
            existing_integration.cms_url = cms_url
            existing_integration.username = username
            existing_integration.encrypted_password = encrypted_password
            existing_integration.is_active = True
            existing_integration.last_tested_at = func.now()
            existing_integration.last_test_status = "success"
            existing_integration.last_test_error = None
            await db.commit()
            
            return {
                "success": True,
                "message": f"{cms_type.title()} connection updated successfully",
                "integration_id": existing_integration.id,
                "user_info": test_result.get("user")
            }
        else:
            # Create new integration
            integration = ProjectIntegration(
                id=str(uuid.uuid4()),
                project_id=project_id,
                cms_type=cms_type,
                cms_url=cms_url,
                username=username,
                encrypted_password=encrypted_password,
                is_active=True,
                last_test_status="success"
            )
            
            db.add(integration)
            await db.commit()
            
            return {
                "success": True,
                "message": f"{cms_type.title()} connected successfully!",
                "integration_id": integration.id,
                "user_info": test_result.get("user")
            }
            
    except Exception as e:
        logger.error(f"Error connecting CMS: {e}")
        await db.rollback()
        return {
            "success": False,
            "error": str(e)
        }


async def handle_test_cms_connection(
    db: AsyncSession,
    project_id: str
) -> Dict[str, Any]:
    """Handle test_cms_connection tool call"""
    try:
        # Get integration
        result = await db.execute(
            select(ProjectIntegration).where(
                ProjectIntegration.project_id == project_id,
                ProjectIntegration.is_active == True
            )
        )
        integration = result.scalar_one_or_none()
        
        if not integration:
            return {
                "success": False,
                "error": "No CMS integration found for this project"
            }
        
        # Decrypt password and test
        password = _decrypt_password(integration.encrypted_password)
        cms_service = create_cms_service(
            integration.cms_type,
            cms_url=integration.cms_url,
            username=integration.username,
            password=password
        )
        
        test_result = await cms_service.test_connection()
        
        # Update integration status
        from sqlalchemy import func
        integration.last_tested_at = func.now()
        integration.last_test_status = "success" if test_result.get("success") else "failed"
        integration.last_test_error = test_result.get("error")
        await db.commit()
        
        return test_result
        
    except Exception as e:
        logger.error(f"Error testing CMS connection: {e}")
        return {
            "success": False,
            "error": str(e)
        }


async def handle_analyze_content_tone(
    db: AsyncSession,
    project_id: str,
    num_posts: int = 5
) -> Dict[str, Any]:
    """Handle analyze_content_tone tool call"""
    try:
        # Get CMS integration
        result = await db.execute(
            select(ProjectIntegration).where(
                ProjectIntegration.project_id == project_id,
                ProjectIntegration.is_active == True
            )
        )
        integration = result.scalar_one_or_none()
        
        if not integration:
            return {
                "success": False,
                "error": "No CMS integration found"
            }
        
        # Get posts from CMS
        password = _decrypt_password(integration.encrypted_password)
        cms_service = create_cms_service(
            integration.cms_type,
            cms_url=integration.cms_url,
            username=integration.username,
            password=password
        )
        
        tone_data = await cms_service.analyze_tone_from_posts(num_posts=num_posts)
        
        if not tone_data.get("success"):
            return tone_data
        
        # Analyze tone with LLM
        content_generator = ContentGeneratorService()
        sample_texts = [sample["content"] for sample in tone_data.get("samples", [])]
        
        tone_analysis = await content_generator.analyze_tone(sample_texts)
        
        if not tone_analysis.get("success"):
            return tone_analysis
        
        # Save or update tone profile
        result = await db.execute(
            select(ContentToneProfile).where(ContentToneProfile.project_id == project_id)
        )
        existing_profile = result.scalar_one_or_none()
        
        if existing_profile:
            existing_profile.tone_description = tone_analysis["tone_description"]
            existing_profile.analyzed_posts_count = len(sample_texts)
            existing_profile.sample_content = "\n\n---\n\n".join(sample_texts[:2])  # Store first 2 samples
        else:
            profile = ContentToneProfile(
                id=str(uuid.uuid4()),
                project_id=project_id,
                tone_description=tone_analysis["tone_description"],
                analyzed_posts_count=len(sample_texts),
                sample_content="\n\n---\n\n".join(sample_texts[:2])
            )
            db.add(profile)
        
        await db.commit()
        
        return {
            "success": True,
            "tone_description": tone_analysis["tone_description"],
            "posts_analyzed": len(sample_texts)
        }
        
    except Exception as e:
        logger.error(f"Error analyzing content tone: {e}")
        await db.rollback()
        return {
            "success": False,
            "error": str(e)
        }


async def handle_generate_content_outline(
    db: AsyncSession,
    project_id: str,
    topic: str,
    target_keywords: list,
    word_count_target: int = 1500
) -> Dict[str, Any]:
    """Handle generate_content_outline tool call"""
    try:
        # Get tone profile if exists
        result = await db.execute(
            select(ContentToneProfile).where(ContentToneProfile.project_id == project_id)
        )
        tone_profile = result.scalar_one_or_none()
        tone_description = tone_profile.tone_description if tone_profile else None
        
        # Generate outline
        content_generator = ContentGeneratorService()
        outline_result = await content_generator.generate_outline(
            topic=topic,
            target_keywords=target_keywords,
            tone_description=tone_description,
            word_count_target=word_count_target
        )
        
        if not outline_result.get("success"):
            return outline_result
        
        # Save as draft content (outline stage)
        content = GeneratedContent(
            id=str(uuid.uuid4()),
            project_id=project_id,
            title=outline_result["parsed"].get("title", topic),
            content=outline_result["outline_text"],  # Store outline as content initially
            target_keywords=target_keywords,
            status="outline",  # Custom status for outline stage
            tone_profile_id=tone_profile.id if tone_profile else None,
            generation_metadata={
                "stage": "outline",
                "word_count_target": word_count_target
            }
        )
        
        db.add(content)
        await db.commit()
        
        return {
            "success": True,
            "outline_id": content.id,
            "title": content.title,
            "outline": outline_result["outline_text"],
            "parsed": outline_result["parsed"]
        }
        
    except Exception as e:
        logger.error(f"Error generating outline: {e}")
        await db.rollback()
        return {
            "success": False,
            "error": str(e)
        }


async def handle_generate_full_article(
    db: AsyncSession,
    project_id: str,
    outline_id: str,
    modifications: Optional[str] = None
) -> Dict[str, Any]:
    """Handle generate_full_article tool call"""
    try:
        # Get the outline content
        result = await db.execute(
            select(GeneratedContent).where(
                GeneratedContent.id == outline_id,
                GeneratedContent.project_id == project_id
            )
        )
        outline_content = result.scalar_one_or_none()
        
        if not outline_content:
            return {
                "success": False,
                "error": "Outline not found"
            }
        
        # Parse the outline from metadata
        outline_data = outline_content.generation_metadata or {}
        
        # Get tone profile
        result = await db.execute(
            select(ContentToneProfile).where(ContentToneProfile.project_id == project_id)
        )
        tone_profile = result.scalar_one_or_none()
        
        # Generate full article
        content_generator = ContentGeneratorService()
        
        # Build outline dict from stored data
        outline_dict = {
            "title": outline_content.title,
            "introduction": "Generate based on title and keywords",
            "sections": []  # Would parse from content.content if needed
        }
        
        article_result = await content_generator.generate_full_article(
            outline=outline_dict,
            target_keywords=outline_content.target_keywords or [],
            tone_description=tone_profile.tone_description if tone_profile else None,
            word_count_target=outline_data.get("word_count_target", 1500)
        )
        
        if not article_result.get("success"):
            return article_result
        
        # Update the content record
        outline_content.content = article_result["content"]
        outline_content.word_count = article_result["word_count"]
        outline_content.seo_score = article_result["seo_score"]
        outline_content.status = "draft"
        outline_content.generation_metadata = {
            **outline_data,
            "stage": "complete",
            "keywords_used": article_result.get("keywords_used", {})
        }
        
        await db.commit()
        
        return {
            "success": True,
            "content_id": outline_content.id,
            "title": outline_content.title,
            "word_count": article_result["word_count"],
            "seo_score": article_result["seo_score"],
            "preview": article_result["content"][:500] + "..."
        }
        
    except Exception as e:
        logger.error(f"Error generating full article: {e}")
        await db.rollback()
        return {
            "success": False,
            "error": str(e)
        }


async def handle_publish_content(
    db: AsyncSession,
    project_id: str,
    content_id: str,
    status: str = "draft",
    categories: Optional[list] = None
) -> Dict[str, Any]:
    """Handle publish_content tool call"""
    try:
        # Get content
        result = await db.execute(
            select(GeneratedContent).where(
                GeneratedContent.id == content_id,
                GeneratedContent.project_id == project_id
            )
        )
        content = result.scalar_one_or_none()
        
        if not content:
            return {
                "success": False,
                "error": "Content not found"
            }
        
        # Get CMS integration
        result = await db.execute(
            select(ProjectIntegration).where(
                ProjectIntegration.project_id == project_id,
                ProjectIntegration.is_active == True
            )
        )
        integration = result.scalar_one_or_none()
        
        if not integration:
            return {
                "success": False,
                "error": "No CMS integration found"
            }
        
        # Publish to CMS
        password = _decrypt_password(integration.encrypted_password)
        cms_service = create_cms_service(
            integration.cms_type,
            cms_url=integration.cms_url,
            username=integration.username,
            password=password
        )
        
        publish_result = await cms_service.publish_post(
            title=content.title,
            content=content.content,
            status=status,
            excerpt=content.excerpt,
            categories=categories
        )
        
        if not publish_result.get("success"):
            return publish_result
        
        # Update content record
        from sqlalchemy import func
        content.status = "published" if status == "publish" else status
        content.published_at = func.now() if status == "publish" else None
        content.published_url = publish_result.get("post_url")
        content.cms_post_id = str(publish_result.get("post_id"))
        content.integration_id = integration.id
        
        await db.commit()
        
        return {
            "success": True,
            "post_id": content.cms_post_id,
            "post_url": content.published_url,
            "status": content.status
        }
        
    except Exception as e:
        logger.error(f"Error publishing content: {e}")
        await db.rollback()
        return {
            "success": False,
            "error": str(e)
        }


async def handle_list_generated_content(
    db: AsyncSession,
    project_id: str,
    status_filter: str = "all",
    limit: int = 10
) -> Dict[str, Any]:
    """Handle list_generated_content tool call"""
    try:
        query = select(GeneratedContent).where(
            GeneratedContent.project_id == project_id
        )
        
        if status_filter != "all":
            query = query.where(GeneratedContent.status == status_filter)
        
        query = query.order_by(GeneratedContent.created_at.desc()).limit(limit)
        
        result = await db.execute(query)
        contents = result.scalars().all()
        
        content_list = []
        for content in contents:
            content_list.append({
                "id": content.id,
                "title": content.title,
                "status": content.status,
                "word_count": content.word_count,
                "seo_score": content.seo_score,
                "target_keywords": content.target_keywords,
                "published_url": content.published_url,
                "created_at": content.created_at.isoformat() if content.created_at else None
            })
        
        return {
            "success": True,
            "content": content_list,
            "total": len(content_list)
        }
        
    except Exception as e:
        logger.error(f"Error listing content: {e}")
        return {
            "success": False,
            "error": str(e)
        }


async def handle_get_cms_categories(
    db: AsyncSession,
    project_id: str
) -> Dict[str, Any]:
    """Handle get_cms_categories tool call"""
    try:
        # Get CMS integration
        result = await db.execute(
            select(ProjectIntegration).where(
                ProjectIntegration.project_id == project_id,
                ProjectIntegration.is_active == True
            )
        )
        integration = result.scalar_one_or_none()
        
        if not integration:
            return {
                "success": False,
                "error": "No CMS integration found"
            }
        
        # Get categories from CMS
        password = _decrypt_password(integration.encrypted_password)
        cms_service = create_cms_service(
            integration.cms_type,
            cms_url=integration.cms_url,
            username=integration.username,
            password=password
        )
        
        categories = await cms_service.get_categories()
        
        return {
            "success": True,
            "categories": categories
        }
        
    except Exception as e:
        logger.error(f"Error getting categories: {e}")
        return {
            "success": False,
            "error": str(e)
        }


# Export all handlers
__all__ = [
    "handle_connect_cms",
    "handle_test_cms_connection",
    "handle_analyze_content_tone",
    "handle_generate_content_outline",
    "handle_generate_full_article",
    "handle_publish_content",
    "handle_list_generated_content",
    "handle_get_cms_categories",
]

