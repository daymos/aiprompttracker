import httpx
import logging
from typing import Optional, Dict, Any
from urllib.parse import urlparse
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class RankCheckerService:
    """Service for checking Google rankings for keywords"""
    
    def __init__(self):
        self.base_url = "https://google-search74.p.rapidapi.com"
        self.headers = {
            "X-RapidAPI-Key": settings.RAPIDAPI_KEY,
            "X-RapidAPI-Host": "google-search74.p.rapidapi.com"
        }
    
    async def check_ranking(self, keyword: str, target_domain: str, location: str = "us") -> Optional[Dict[str, Any]]:
        """
        Check where target_domain ranks for a keyword
        
        Returns:
            {
                'position': int or None,  # Position in results (1-100), None if not found
                'page_url': str or None,  # The specific page that ranked
            }
        """
        
        # Extract domain from target URL
        parsed = urlparse(target_domain if target_domain.startswith('http') else f'https://{target_domain}')
        domain = parsed.netloc or parsed.path
        # Remove www. prefix for more flexible matching
        domain = domain.replace('www.', '')
        
        logger.info(f"Checking ranking for keyword '{keyword}' and domain '{domain}'")
        
        # Check if API key is configured
        if not settings.RAPIDAPI_KEY:
            logger.error("RAPIDAPI_KEY not configured - rank checking will not work")
            return {
                'position': None,
                'page_url': None
            }
        
        try:
            # Search Google via RapidAPI (google-search74)
            params = {
                "query": keyword,
                "limit": "100",  # Get top 100 results
                "related_keywords": "false"
            }
            
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    self.base_url,
                    headers=self.headers,
                    params=params,
                    timeout=15.0
                )
                response.raise_for_status()
                data = response.json()
                
                logger.info(f"API response status: {response.status_code}")
                logger.debug(f"API response data keys: {list(data.keys())}")
                
                # Search for our domain in results
                # The API may return results in different formats, check both
                results = data.get('results', []) or data.get('organic_results', [])
                logger.info(f"Got {len(results)} results from API")
                
                # Log first few results for debugging
                for i, result in enumerate(results[:5], 1):
                    result_url = result.get('url', result.get('link', ''))
                    logger.debug(f"Result {i}: {result_url}")
                
                for i, result in enumerate(results, 1):
                    # Try both 'url' and 'link' field names
                    result_url = result.get('url', result.get('link', ''))
                    # Remove www. from result URL too for comparison
                    result_url_normalized = result_url.replace('www.', '')
                    
                    if domain.lower() in result_url_normalized.lower():
                        logger.info(f"Found domain '{domain}' at position {i}: {result_url}")
                        return {
                            'position': i,
                            'page_url': result_url
                        }
                
                # Not found in top 100
                logger.info(f"Domain '{domain}' not found in top 100 results for '{keyword}'")
                return {
                    'position': None,
                    'page_url': None
                }
                
        except httpx.TimeoutException:
            logger.error(f"Timeout checking ranking for '{keyword}'")
            return None
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error checking ranking: {e.response.status_code}")
            logger.error(f"Response body: {e.response.text if hasattr(e.response, 'text') else 'N/A'}")
            return None
        except Exception as e:
            logger.error(f"Error checking ranking for '{keyword}': {e}", exc_info=True)
            return None
    
    async def check_multiple_rankings(self, keywords: list, target_domain: str) -> Dict[str, Dict[str, Any]]:
        """Check rankings for multiple keywords"""
        results = {}
        
        for keyword in keywords:
            result = await self.check_ranking(keyword, target_domain)
            if result:
                results[keyword] = result
        
        return results

