"""
CMS Integration Service - Base class and WordPress implementation
"""
import logging
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, List
import httpx
from datetime import datetime

logger = logging.getLogger(__name__)


class CMSService(ABC):
    """Abstract base class for CMS integrations"""
    
    @abstractmethod
    async def test_connection(self) -> Dict[str, Any]:
        """Test if connection credentials are valid"""
        pass
    
    @abstractmethod
    async def publish_post(
        self,
        title: str,
        content: str,
        status: str = "draft",
        excerpt: Optional[str] = None,
        categories: Optional[List[str]] = None,
        tags: Optional[List[str]] = None,
        featured_image_url: Optional[str] = None
    ) -> Dict[str, Any]:
        """Publish a post to the CMS"""
        pass
    
    @abstractmethod
    async def update_post(
        self,
        post_id: str,
        title: Optional[str] = None,
        content: Optional[str] = None,
        status: Optional[str] = None,
        excerpt: Optional[str] = None
    ) -> Dict[str, Any]:
        """Update an existing post"""
        pass
    
    @abstractmethod
    async def get_post(self, post_id: str) -> Dict[str, Any]:
        """Get a specific post"""
        pass
    
    @abstractmethod
    async def list_posts(self, limit: int = 10, offset: int = 0) -> List[Dict[str, Any]]:
        """List recent posts"""
        pass
    
    @abstractmethod
    async def delete_post(self, post_id: str) -> bool:
        """Delete a post"""
        pass
    
    @abstractmethod
    async def get_categories(self) -> List[Dict[str, Any]]:
        """Get available categories"""
        pass


class WordPressCMSService(CMSService):
    """WordPress CMS integration using REST API and Application Passwords"""
    
    def __init__(self, site_url: str, username: str, app_password: str):
        """
        Initialize WordPress CMS service
        
        Args:
            site_url: WordPress site URL (e.g., "https://example.com")
            username: WordPress username
            app_password: WordPress Application Password (not regular password)
        """
        self.site_url = site_url.rstrip('/')
        self.username = username
        self.app_password = app_password
        self.api_base = f"{self.site_url}/wp-json/wp/v2"
        
    def _get_auth(self) -> tuple:
        """Get HTTP Basic Auth tuple for WordPress"""
        return (self.username, self.app_password)
    
    async def test_connection(self) -> Dict[str, Any]:
        """Test WordPress connection by fetching site info"""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                # Try to get current user info (requires authentication)
                response = await client.get(
                    f"{self.site_url}/wp-json/wp/v2/users/me",
                    auth=self._get_auth()
                )
                
                if response.status_code == 200:
                    user_data = response.json()
                    return {
                        "success": True,
                        "message": "Connection successful",
                        "user": {
                            "id": user_data.get("id"),
                            "name": user_data.get("name"),
                            "email": user_data.get("email"),
                            "roles": user_data.get("roles", [])
                        }
                    }
                elif response.status_code == 401:
                    return {
                        "success": False,
                        "error": "Authentication failed. Check username and application password."
                    }
                elif response.status_code == 404:
                    return {
                        "success": False,
                        "error": "WordPress REST API not found. Is the site URL correct?"
                    }
                else:
                    return {
                        "success": False,
                        "error": f"Unexpected response: {response.status_code}"
                    }
                    
        except httpx.ConnectError:
            return {
                "success": False,
                "error": "Could not connect to WordPress site. Check the URL."
            }
        except httpx.TimeoutException:
            return {
                "success": False,
                "error": "Connection timeout. Site may be slow or unavailable."
            }
        except Exception as e:
            logger.error(f"WordPress connection test failed: {e}")
            return {
                "success": False,
                "error": f"Connection error: {str(e)}"
            }
    
    async def publish_post(
        self,
        title: str,
        content: str,
        status: str = "draft",
        excerpt: Optional[str] = None,
        categories: Optional[List[int]] = None,
        tags: Optional[List[int]] = None,
        featured_image_url: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Publish a post to WordPress
        
        Args:
            title: Post title
            content: Post content (HTML)
            status: "draft", "publish", "pending", "private"
            excerpt: Optional post excerpt
            categories: List of category IDs
            tags: List of tag IDs
            featured_image_url: URL to featured image
        """
        try:
            post_data = {
                "title": title,
                "content": content,
                "status": status,
            }
            
            if excerpt:
                post_data["excerpt"] = excerpt
            if categories:
                post_data["categories"] = categories
            if tags:
                post_data["tags"] = tags
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.api_base}/posts",
                    json=post_data,
                    auth=self._get_auth()
                )
                
                if response.status_code in [200, 201]:
                    post = response.json()
                    return {
                        "success": True,
                        "post_id": post.get("id"),
                        "post_url": post.get("link"),
                        "status": post.get("status"),
                        "data": post
                    }
                else:
                    error_msg = response.json().get("message", "Unknown error")
                    return {
                        "success": False,
                        "error": f"Failed to publish post: {error_msg}"
                    }
                    
        except Exception as e:
            logger.error(f"Error publishing WordPress post: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    async def update_post(
        self,
        post_id: str,
        title: Optional[str] = None,
        content: Optional[str] = None,
        status: Optional[str] = None,
        excerpt: Optional[str] = None
    ) -> Dict[str, Any]:
        """Update an existing WordPress post"""
        try:
            update_data = {}
            if title is not None:
                update_data["title"] = title
            if content is not None:
                update_data["content"] = content
            if status is not None:
                update_data["status"] = status
            if excerpt is not None:
                update_data["excerpt"] = excerpt
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.api_base}/posts/{post_id}",
                    json=update_data,
                    auth=self._get_auth()
                )
                
                if response.status_code == 200:
                    post = response.json()
                    return {
                        "success": True,
                        "post_id": post.get("id"),
                        "post_url": post.get("link"),
                        "data": post
                    }
                else:
                    return {
                        "success": False,
                        "error": response.json().get("message", "Update failed")
                    }
                    
        except Exception as e:
            logger.error(f"Error updating WordPress post: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    async def get_post(self, post_id: str) -> Dict[str, Any]:
        """Get a specific WordPress post"""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    f"{self.api_base}/posts/{post_id}",
                    auth=self._get_auth()
                )
                
                if response.status_code == 200:
                    return {
                        "success": True,
                        "post": response.json()
                    }
                else:
                    return {
                        "success": False,
                        "error": "Post not found"
                    }
                    
        except Exception as e:
            logger.error(f"Error getting WordPress post: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    async def list_posts(self, limit: int = 10, offset: int = 0) -> List[Dict[str, Any]]:
        """List recent WordPress posts"""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    f"{self.api_base}/posts",
                    params={"per_page": limit, "offset": offset},
                    auth=self._get_auth()
                )
                
                if response.status_code == 200:
                    return response.json()
                else:
                    logger.error(f"Failed to list posts: {response.status_code}")
                    return []
                    
        except Exception as e:
            logger.error(f"Error listing WordPress posts: {e}")
            return []
    
    async def delete_post(self, post_id: str) -> bool:
        """Delete a WordPress post (moves to trash)"""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.delete(
                    f"{self.api_base}/posts/{post_id}",
                    auth=self._get_auth()
                )
                
                return response.status_code == 200
                
        except Exception as e:
            logger.error(f"Error deleting WordPress post: {e}")
            return False
    
    async def get_categories(self) -> List[Dict[str, Any]]:
        """Get WordPress categories"""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    f"{self.api_base}/categories",
                    params={"per_page": 100},
                    auth=self._get_auth()
                )
                
                if response.status_code == 200:
                    return response.json()
                else:
                    return []
                    
        except Exception as e:
            logger.error(f"Error getting WordPress categories: {e}")
            return []
    
    async def analyze_tone_from_posts(self, num_posts: int = 5) -> Dict[str, Any]:
        """
        Fetch recent posts to analyze writing tone/style
        Returns sample content for LLM tone analysis
        """
        try:
            posts = await self.list_posts(limit=num_posts)
            
            if not posts:
                return {
                    "success": False,
                    "error": "No posts found"
                }
            
            # Extract content from posts
            samples = []
            for post in posts:
                # Get plain text from HTML content
                content = post.get("content", {}).get("rendered", "")
                title = post.get("title", {}).get("rendered", "")
                
                if content:
                    samples.append({
                        "title": title,
                        "content": content[:1000],  # First 1000 chars
                        "excerpt": post.get("excerpt", {}).get("rendered", "")
                    })
            
            return {
                "success": True,
                "posts_analyzed": len(samples),
                "samples": samples
            }
            
        except Exception as e:
            logger.error(f"Error analyzing tone from WordPress posts: {e}")
            return {
                "success": False,
                "error": str(e)
            }


def create_cms_service(cms_type: str, **credentials) -> Optional[CMSService]:
    """
    Factory function to create appropriate CMS service
    
    Args:
        cms_type: "wordpress", "webflow", etc.
        **credentials: CMS-specific credentials
    """
    if cms_type == "wordpress":
        return WordPressCMSService(
            site_url=credentials.get("cms_url"),
            username=credentials.get("username"),
            app_password=credentials.get("password")
        )
    else:
        logger.warning(f"Unsupported CMS type: {cms_type}")
        return None

