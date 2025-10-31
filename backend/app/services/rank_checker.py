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
        self.base_url = "https://google-search-api1.p.rapidapi.com"
        self.headers = {
            "X-RapidAPI-Key": settings.RAPIDAPI_KEY,
            "X-RapidAPI-Host": "google-search-api1.p.rapidapi.com"
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
        
        try:
            # Search Google via RapidAPI
            params = {
                "query": keyword,
                "gl": location,
                "num": "100"  # Get top 100 results
            }
            
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{self.base_url}/search",
                    headers=self.headers,
                    params=params,
                    timeout=15.0
                )
                response.raise_for_status()
                data = response.json()
                
                # Search for our domain in results
                results = data.get('organic_results', [])
                
                for i, result in enumerate(results, 1):
                    result_url = result.get('link', '')
                    if domain.lower() in result_url.lower():
                        return {
                            'position': i,
                            'page_url': result_url
                        }
                
                # Not found in top 100
                return {
                    'position': None,
                    'page_url': None
                }
                
        except httpx.TimeoutException:
            logger.error(f"Timeout checking ranking for '{keyword}'")
            return None
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error checking ranking: {e.response.status_code}")
            return None
        except Exception as e:
            logger.error(f"Error checking ranking for '{keyword}': {e}")
            return None
    
    async def check_multiple_rankings(self, keywords: list, target_domain: str) -> Dict[str, Dict[str, Any]]:
        """Check rankings for multiple keywords"""
        results = {}
        
        for keyword in keywords:
            result = await self.check_ranking(keyword, target_domain)
            if result:
                results[keyword] = result
        
        return results

