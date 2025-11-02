import httpx
import logging
from typing import List, Dict, Any, Optional
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class RapidAPIBacklinkService:
    """Service for SEO API Get Backlinks via RapidAPI (per-request pricing)"""
    
    def __init__(self):
        self.base_url = "https://seo-api-get-backlinks.p.rapidapi.com"
        self.rapidapi_key = settings.RAPIDAPI_KEY
        
    def _get_headers(self) -> Dict[str, str]:
        """Generate headers for RapidAPI"""
        return {
            "x-rapidapi-host": "seo-api-get-backlinks.p.rapidapi.com",
            "x-rapidapi-key": self.rapidapi_key
        }
    
    async def get_backlinks(
        self, 
        domain: str,
        limit: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Get backlinks for a domain using RapidAPI SEO Backlinks API
        
        Args:
            domain: Target domain (e.g., "example.com" - no http/https)
            limit: Optional limit on number of backlinks to return (client-side filter)
        
        Returns:
            {
                "target": "example.com",
                "backlinks": [
                    {
                        "url_from": "https://example.com/page",
                        "url_to": "https://target.com/",
                        "title": "Page Title",
                        "anchor": "anchor text",
                        "nofollow": true/false,
                        "inlink_rank": 58,
                        "domain_inlink_rank": 94,
                        "first_seen": "2024-10-11",
                        "last_visited": "2025-09-22",
                        "date_lost": "",
                        "spam_score": 16
                    }
                ],
                "total_backlinks": 8194,
                "referring_domains": 139,
                "domain_authority": 15,
                "overtime": [...],  # Historical trends
                "new_and_lost": [...],  # Daily tracking
                "anchors": [...],  # Anchor text distribution
                "error": None
            }
        """
        # Check if API key is configured
        if not self.rapidapi_key:
            logger.error("RAPIDAPI_KEY not configured - backlink analysis will not work")
            return {"error": "API key not configured"}
        
        try:
            # Clean domain (remove protocol if provided)
            if domain.startswith(('http://', 'https://')):
                domain = domain.replace('https://', '').replace('http://', '').split('/')[0]
            
            # Log request details
            masked_key = self.rapidapi_key[:8] + "..." if self.rapidapi_key else "MISSING"
            logger.info(f"🔗 Fetching backlinks for: '{domain}'")
            logger.info(f"📡 API Endpoint: {self.base_url}/backlinks.php")
            logger.info(f"🔑 API Key (masked): {masked_key}")
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                url = f"{self.base_url}/backlinks.php"
                
                params = {
                    "domain": domain
                }
                
                logger.info(f"📋 Request params: {params}")
                
                response = await client.get(
                    url,
                    params=params,
                    headers=self._get_headers()
                )
                
                logger.info(f"📥 Response status: {response.status_code}")
                
                if response.status_code != 200:
                    error_body = response.text
                    logger.error(f"RapidAPI error: {response.status_code} - {error_body}")
                    
                    if response.status_code == 403:
                        return {
                            "error": "API subscription required. Please check your RapidAPI plan.",
                        }
                    elif response.status_code == 404:
                        return {
                            "error": f"No backlink data found for {domain}. The site may be too new or have no backlinks.",
                        }
                    else:
                        return {
                            "error": f"API error {response.status_code}: {error_body}",
                        }
                
                data = response.json()
                
                # Check for API-level errors
                if "message" in data and "not subscribed" in data["message"].lower():
                    logger.error("❌ API subscription issue detected")
                    return {
                        "error": "API subscription required. Please check your RapidAPI plan.",
                    }
                
                logger.info(f"✅ Successfully fetched backlink data for {domain}")
                logger.debug(f"Response data keys: {list(data.keys())}")
                
                # Extract backlinks
                backlinks = data.get("backlinks", [])
                logger.info(f"📊 Found {len(backlinks)} backlinks in response")
                
                # Apply client-side limit if specified
                if limit and limit > 0:
                    logger.info(f"📉 Applying client-side limit: {limit} backlinks")
                    backlinks = backlinks[:limit]
                
                # Get domain authority from overtime data (most recent)
                overtime = data.get("overtime", [])
                domain_authority = overtime[0].get("da", 0) if overtime else 0
                referring_domains = overtime[0].get("refdomains", 0) if overtime else 0
                total_backlinks = overtime[0].get("backlinks", len(backlinks)) if overtime else len(backlinks)
                
                logger.info(f"✅ Backlink Summary for {domain}:")
                logger.info(f"   - Total backlinks: {total_backlinks}")
                logger.info(f"   - Referring domains: {referring_domains}")
                logger.info(f"   - Domain Authority: {domain_authority}")
                logger.info(f"   - Historical data points: {len(overtime)}")
                logger.info(f"   - Anchor texts tracked: {len(data.get('anchors', []))}")
                
                return {
                    "target": domain,
                    "backlinks": backlinks,
                    "total_backlinks": total_backlinks,
                    "referring_domains": referring_domains,
                    "domain_authority": domain_authority,
                    "overtime": overtime,  # Historical trends
                    "new_and_lost": data.get("new_and_lost", []),  # Daily tracking
                    "anchors": data.get("anchors", []),  # Anchor text distribution
                    "error": None
                }
                
        except httpx.TimeoutException:
            logger.error(f"Timeout fetching backlinks for {domain}")
            return {
                "error": "Request timeout - the API took too long to respond",
            }
        except Exception as e:
            logger.error(f"Error fetching backlinks: {e}")
            return {
                "error": str(e),
            }
    
    async def compare_backlinks(
        self, 
        my_domain: str, 
        competitor_domain: str,
        limit_per_domain: Optional[int] = 50
    ) -> Dict[str, Any]:
        """
        Compare backlinks between your site and a competitor
        
        Returns backlinks that competitor has but you don't (link gap analysis)
        """
        logger.info(f"🔍 Comparing backlinks: {my_domain} vs {competitor_domain}")
        
        try:
            # Fetch both backlink profiles
            logger.info(f"📡 Fetching backlinks for YOUR domain: {my_domain}")
            my_backlinks = await self.get_backlinks(my_domain, limit=limit_per_domain)
            
            logger.info(f"📡 Fetching backlinks for COMPETITOR domain: {competitor_domain}")
            competitor_backlinks = await self.get_backlinks(competitor_domain, limit=limit_per_domain)
            
            if my_backlinks.get("error") or competitor_backlinks.get("error"):
                logger.error(f"❌ Failed to fetch one or both backlink profiles")
                if my_backlinks.get("error"):
                    logger.error(f"   Your domain error: {my_backlinks.get('error')}")
                if competitor_backlinks.get("error"):
                    logger.error(f"   Competitor error: {competitor_backlinks.get('error')}")
                return {
                    "error": "Failed to fetch backlinks for comparison",
                }
            
            logger.info(f"📊 Analyzing link gaps...")
            
            # Extract source domains from backlinks
            my_sources = set()
            for bl in my_backlinks.get("backlinks", []):
                url_from = bl.get("url_from", "")
                if url_from:
                    # Extract domain from URL
                    domain = url_from.replace('https://', '').replace('http://', '').split('/')[0]
                    my_sources.add(domain)
            
            logger.info(f"   Your domain has backlinks from {len(my_sources)} unique sources")
            
            # Find link gaps (sites linking to competitor but not you)
            link_gaps = []
            for bl in competitor_backlinks.get("backlinks", []):
                url_from = bl.get("url_from", "")
                if url_from:
                    domain = url_from.replace('https://', '').replace('http://', '').split('/')[0]
                    if domain not in my_sources:
                        link_gaps.append(bl)
            
            logger.info(f"✅ Found {len(link_gaps)} link gap opportunities")
            logger.info(f"   (sites linking to competitor but not you)")
            
            return {
                "my_domain": my_domain,
                "competitor_domain": competitor_domain,
                "my_backlinks_count": my_backlinks.get("total_backlinks", 0),
                "competitor_backlinks_count": competitor_backlinks.get("total_backlinks", 0),
                "my_referring_domains": my_backlinks.get("referring_domains", 0),
                "competitor_referring_domains": competitor_backlinks.get("referring_domains", 0),
                "link_gaps": link_gaps,  # Opportunities for you
                "gap_count": len(link_gaps),
                "error": None
            }
            
        except Exception as e:
            logger.error(f"Error comparing backlinks: {e}")
            return {
                "error": str(e),
            }

