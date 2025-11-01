"""
Service to verify if backlinks are live and indexed
"""
import httpx
import logging
from typing import Optional, Dict, Any
from datetime import datetime
from bs4 import BeautifulSoup
from urllib.parse import urlparse

logger = logging.getLogger(__name__)


class BacklinkVerifier:
    """Verify if backlinks are live on directory pages"""
    
    def __init__(self):
        self.timeout = 10.0
        self.user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    
    async def verify_backlink(
        self,
        directory_url: str,
        target_domain: str,
        target_url: str
    ) -> Dict[str, Any]:
        """
        Check if a backlink exists on a directory page
        
        Args:
            directory_url: The directory page to check (e.g., directory listing page)
            target_domain: The domain to look for (e.g., "keywords.chat")
            target_url: The full URL to look for (e.g., "https://keywords.chat")
        
        Returns:
            {
                "found": bool,
                "indexed": bool,
                "status": str,  # "approved" if found, "pending" if not
                "link_url": str or None,  # The actual link found
                "checked_at": str
            }
        """
        
        result = {
            "found": False,
            "indexed": False,
            "status": "pending",
            "link_url": None,
            "checked_at": datetime.utcnow().isoformat(),
            "error": None
        }
        
        try:
            # Fetch the directory page
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(
                    directory_url,
                    headers={"User-Agent": self.user_agent},
                    follow_redirects=True
                )
                
                if response.status_code != 200:
                    result["error"] = f"Failed to fetch directory (status {response.status_code})"
                    return result
                
                # Parse HTML and look for links
                soup = BeautifulSoup(response.text, 'html.parser')
                
                # Find all links
                links = soup.find_all('a', href=True)
                
                # Check if target domain/URL appears in any link
                for link in links:
                    href = link.get('href', '')
                    
                    # Check if this link points to our domain
                    if target_domain in href or target_url in href:
                        result["found"] = True
                        result["status"] = "approved"
                        result["link_url"] = href
                        logger.info(f"✓ Found backlink to {target_domain} on {directory_url}")
                        break
                
                if not result["found"]:
                    logger.info(f"✗ Backlink to {target_domain} not found on {directory_url}")
                
                # Check if indexed in Google (simplified check)
                # In production, you'd use Google Search Console API or a proper indexing checker
                is_indexed = await self._check_google_index(directory_url, target_domain)
                result["indexed"] = is_indexed
                
                if result["found"] and is_indexed:
                    result["status"] = "indexed"
                
        except httpx.TimeoutException:
            result["error"] = "Timeout while checking directory"
            logger.warning(f"Timeout checking {directory_url}")
        except Exception as e:
            result["error"] = str(e)
            logger.error(f"Error verifying backlink on {directory_url}: {e}")
        
        return result
    
    async def _check_google_index(self, directory_url: str, target_domain: str) -> bool:
        """
        Check if the backlink page is indexed in Google (simplified)
        
        In production, you'd want to:
        1. Use Google Search Console API
        2. Use a proper indexing checker service
        3. Or do a site: search on Google
        
        For now, this is a placeholder that returns False
        """
        # This would require Google Search API or web scraping Google
        # which is against their ToS for automated queries
        # 
        # Better approach: Use Google Search Console API
        # or ask user to manually verify indexing
        
        return False  # Placeholder - implement with proper API
    
    async def bulk_verify(
        self,
        submissions: list,
        target_url: str
    ) -> Dict[str, Any]:
        """
        Verify multiple backlinks at once
        
        Args:
            submissions: List of {directory_url, submission_id}
            target_url: The target URL to look for
        
        Returns:
            {
                "total": int,
                "verified": int,
                "found": int,
                "results": [...]
            }
        """
        
        target_domain = urlparse(target_url).netloc
        
        results = []
        found_count = 0
        
        for submission in submissions:
            directory_url = submission.get('directory_url')
            submission_id = submission.get('submission_id')
            
            if not directory_url:
                continue
            
            verification = await self.verify_backlink(
                directory_url,
                target_domain,
                target_url
            )
            
            verification['submission_id'] = submission_id
            results.append(verification)
            
            if verification['found']:
                found_count += 1
        
        return {
            "total": len(submissions),
            "verified": len(results),
            "found": found_count,
            "results": results
        }

