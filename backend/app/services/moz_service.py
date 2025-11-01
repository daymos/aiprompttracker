import httpx
import logging
import base64
from typing import List, Dict, Any, Optional
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class MozBacklinkService:
    """Service for Moz Links API ($5/month starter plan)"""
    
    def __init__(self):
        self.base_url = "https://lsapi.seomoz.com/v1"
        self.access_id = settings.MOZ_ACCESS_ID
        self.secret_key = settings.MOZ_SECRET_KEY
        
    def _get_moz_headers(self) -> Dict[str, str]:
        """Generate Basic Auth headers for Moz API"""
        # Moz uses Basic Auth: base64(access_id:secret_key)
        credentials = f"{self.access_id}:{self.secret_key}"
        encoded = base64.b64encode(credentials.encode()).decode()
        
        return {
            "Authorization": f"Basic {encoded}",
            "Content-Type": "application/json"
        }
    
    async def get_backlinks(
        self, 
        domain: str, 
        limit: int = 50,
        scope: str = "page"  # "page" or "subdomain" or "root_domain"
    ) -> Dict[str, Any]:
        """
        Get backlinks for a domain using Moz Links API
        
        Args:
            domain: Target domain (e.g., "example.com" or "https://example.com/page")
            limit: Number of backlinks to return (max 50 for $5 plan)
            scope: "page", "subdomain", or "root_domain"
        
        Returns:
            {
                "target": "example.com",
                "backlinks": [
                    {
                        "source_url": "referring-site.com/page",
                        "target_url": "example.com/page",
                        "anchor_text": "example",
                        "domain_authority": 45,
                        "page_authority": 38,
                        "spam_score": 3,
                        "first_seen": "2024-01-15",
                        "last_seen": "2025-01-20"
                    }
                ],
                "total_backlinks": 1250,
                "referring_domains": 89,
                "rows_used": 50,
                "error": None
            }
        """
        try:
            # Ensure domain has https:// prefix for Moz API
            if not domain.startswith(('http://', 'https://')):
                domain = f"https://{domain}"
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                # Moz Links API legacy endpoint for backlinks
                url = f"{self.base_url}/url_links"
                
                params = {
                    "target": domain,
                    "limit": min(limit, 50)  # Cap at 50 for starter plan
                }
                
                logger.info(f"Fetching {limit} backlinks for {domain} from Moz Links API")
                logger.info(f"Request URL: {url}")
                logger.info(f"Request params: {params}")
                
                response = await client.get(
                    url,
                    params=params,
                    headers=self._get_moz_headers()
                )
                
                logger.info(f"Moz API response status: {response.status_code}")
                logger.info(f"Moz API response body (first 500 chars): {response.text[:500]}")
                
                if response.status_code != 200:
                    error_body = response.text
                    logger.error(f"Moz API error: {response.status_code} - {error_body}")
                    
                    if response.status_code == 404:
                        return {
                            "error": f"Domain not found in Moz database. This could mean the site is new, has no backlinks, or Moz hasn't indexed it yet. Try a well-known domain like 'moz.com' to test the API.",
                            "rows_used": 0
                        }
                    elif response.status_code == 401:
                        return {
                            "error": "Authentication failed. Check your Moz API credentials.",
                            "rows_used": 0
                        }
                    else:
                        return {
                            "error": f"API error {response.status_code}: {error_body}",
                            "rows_used": 0
                        }
                
                data = response.json()
                logger.info(f"Successfully fetched backlinks for {domain}")
                
                # Parse backlinks
                backlinks = []
                for link in data.get("links", []):
                    backlinks.append({
                        "source_url": link.get("source_url"),
                        "target_url": link.get("target_url"),
                        "anchor_text": link.get("anchor_text"),
                        "domain_authority": link.get("source_domain_authority"),
                        "page_authority": link.get("source_page_authority"),
                        "spam_score": link.get("source_spam_score"),
                        "first_seen": link.get("first_seen"),
                        "last_seen": link.get("last_seen")
                    })
                
                return {
                    "target": domain,
                    "backlinks": backlinks,
                    "total_backlinks": data.get("total_backlinks", len(backlinks)),
                    "referring_domains": data.get("referring_domains", 0),
                    "rows_used": len(backlinks),  # Each backlink = 1 row
                    "error": None
                }
                
        except httpx.TimeoutException:
            logger.error(f"Timeout fetching backlinks for {domain}")
            return {
                "error": "Request timeout",
                "rows_used": 0
            }
        except Exception as e:
            logger.error(f"Error fetching backlinks: {e}")
            return {
                "error": str(e),
                "rows_used": 0
            }
    
    async def get_domain_authority(self, domain: str) -> Dict[str, Any]:
        """
        Get just DA/PA metrics (uses fewer rows than full backlink list)
        """
        try:
            # Ensure domain has https:// prefix for Moz API
            if not domain.startswith(('http://', 'https://')):
                domain = f"https://{domain}"
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                # Legacy v1 endpoint for domain metrics
                url = f"{self.base_url}/url_metrics"
                
                params = {
                    "target": domain
                }
                
                logger.info(f"Fetching DA/PA for {domain}")
                
                response = await client.get(
                    url,
                    params=params,
                    headers=self._get_moz_headers()
                )
                
                if response.status_code != 200:
                    logger.error(f"Moz API error: {response.status_code} - {response.text}")
                    return {
                        "error": f"API error: {response.status_code}",
                        "rows_used": 0
                    }
                
                data = response.json()
                
                return {
                    "domain": domain,
                    "domain_authority": data.get("domain_authority", 0),
                    "page_authority": data.get("page_authority", 0),
                    "spam_score": data.get("spam_score", 0),
                    "external_links": data.get("external_links_to_root_domain", 0),
                    "linking_root_domains": data.get("root_domains_to_root_domain", 0),
                    "rows_used": 1,  # DA/PA lookup is cheap
                    "error": None
                }
                
        except httpx.TimeoutException:
            logger.error(f"Timeout fetching DA/PA for {domain}")
            return {
                "error": "Request timeout",
                "rows_used": 0
            }
        except Exception as e:
            logger.error(f"Error fetching DA/PA: {e}")
            return {
                "error": str(e),
                "rows_used": 0
            }
    
    async def compare_backlinks(
        self, 
        my_domain: str, 
        competitor_domain: str,
        limit_per_domain: int = 25
    ) -> Dict[str, Any]:
        """
        Compare backlinks between your site and a competitor
        
        Returns backlinks that competitor has but you don't (link gap analysis)
        Uses 2x rows (one query for each domain)
        """
        try:
            # Ensure domains have https:// prefix
            if not my_domain.startswith(('http://', 'https://')):
                my_domain = f"https://{my_domain}"
            if not competitor_domain.startswith(('http://', 'https://')):
                competitor_domain = f"https://{competitor_domain}"
            
            # Fetch both backlink profiles
            my_backlinks = await self.get_backlinks(my_domain, limit=limit_per_domain)
            competitor_backlinks = await self.get_backlinks(competitor_domain, limit=limit_per_domain)
            
            if my_backlinks.get("error") or competitor_backlinks.get("error"):
                return {
                    "error": "Failed to fetch backlinks for comparison",
                    "rows_used": 0
                }
            
            # Extract source domains
            my_sources = {bl["source_url"].split("/")[2] for bl in my_backlinks["backlinks"]}
            competitor_sources = {bl["source_url"].split("/")[2] for bl in competitor_backlinks["backlinks"]}
            
            # Find gaps (sites linking to competitor but not you)
            gaps = [
                bl for bl in competitor_backlinks["backlinks"]
                if bl["source_url"].split("/")[2] not in my_sources
            ]
            
            return {
                "my_domain": my_domain,
                "competitor_domain": competitor_domain,
                "my_backlinks_count": len(my_backlinks["backlinks"]),
                "competitor_backlinks_count": len(competitor_backlinks["backlinks"]),
                "link_gaps": gaps,  # Opportunities for you
                "gap_count": len(gaps),
                "rows_used": my_backlinks["rows_used"] + competitor_backlinks["rows_used"],
                "error": None
            }
            
        except Exception as e:
            logger.error(f"Error comparing backlinks: {e}")
            return {
                "error": str(e),
                "rows_used": 0
            }
    

