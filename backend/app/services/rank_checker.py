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
        self.base_url = "https://google-search116.p.rapidapi.com"
        self.headers = {
            "x-rapidapi-key": settings.RAPIDAPI_KEY,
            "x-rapidapi-host": "google-search116.p.rapidapi.com"
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
        
        logger.info(f"🔍 Checking ranking for keyword '{keyword}' and domain '{domain}' (google-search116)")
        
        # Check if API key is configured
        if not settings.RAPIDAPI_KEY:
            logger.error("RAPIDAPI_KEY not configured - rank checking will not work")
            return {
                'position': None,
                'page_url': None
            }
        
        try:
            # Search Google via RapidAPI (google-search116)
            params = {
                "query": keyword,
                "limit": 100,  # Get top 100 results (max allowed)
            }
            
            # Add location if specified
            if location and location.lower() != "us":
                params["country"] = location.upper()
            
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{self.base_url}/search",
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
    
    async def get_serp_analysis(self, keyword: str) -> Optional[Dict[str, Any]]:
        """
        Get top 10 SERP results and analyze competitiveness
        
        Returns:
            {
                'top_domains': ['example.com', 'another.com', ...],
                'analysis': 'Weak opportunity' | 'Mixed competition' | 'Dominated by brands',
                'insight': 'Human-readable insight for LLM'
            }
        """
        
        if not settings.RAPIDAPI_KEY:
            return None
        
        logger.info(f"🔍 Getting SERP analysis for '{keyword}' (google-search116)")
        
        try:
            params = {
                "query": keyword,
                "limit": 10,  # Top 10 results
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
                
                results = data.get('results', []) or data.get('organic_results', [])
                
                if not results:
                    return None
                
                # Extract domains from top 10
                top_domains = []
                for result in results[:10]:
                    url = result.get('url', result.get('link', ''))
                    if url:
                        parsed = urlparse(url if url.startswith('http') else f'https://{url}')
                        domain = (parsed.netloc or parsed.path).replace('www.', '').lower()
                        if domain:
                            top_domains.append(domain)
                
                # Analyze competitiveness
                analysis = self._analyze_serp_competitiveness(top_domains)
                
                return {
                    'top_domains': top_domains[:10],
                    'analysis': analysis['level'],
                    'insight': analysis['insight']
                }
                
        except Exception as e:
            logger.error(f"Error getting SERP analysis for '{keyword}': {e}")
            return None
    
    def _analyze_serp_competitiveness(self, domains: list) -> Dict[str, str]:
        """Analyze SERP competitiveness based on domains"""
        
        # Known strong/authority domains
        major_brands = {
            'amazon.com', 'google.com', 'facebook.com', 'youtube.com', 'wikipedia.org',
            'forbes.com', 'nytimes.com', 'techcrunch.com', 'hubspot.com', 'salesforce.com',
            'microsoft.com', 'apple.com', 'linkedin.com', 'twitter.com', 'reddit.com',
            'medium.com', 'wired.com', 'theverge.com', 'cnet.com', 'zdnet.com',
            'businessinsider.com', 'wsj.com', 'bloomberg.com', 'cnbc.com', 'bbc.com',
            'shopify.com', 'zapier.com', 'slack.com', 'atlassian.com', 'adobe.com'
        }
        
        # Count brand domains in top 10
        brand_count = sum(1 for domain in domains if any(brand in domain for brand in major_brands))
        
        # Analysis based on brand presence
        if brand_count >= 7:
            return {
                'level': 'Very Hard',
                'insight': f'Top 10 dominated by {brand_count} major brands - very competitive'
            }
        elif brand_count >= 4:
            return {
                'level': 'Hard',
                'insight': f'{brand_count} major brands in top 10 - competitive but possible'
            }
        elif brand_count >= 2:
            return {
                'level': 'Medium',
                'insight': f'Mix of {brand_count} brands and smaller sites - moderate opportunity'
            }
        else:
            return {
                'level': 'Good Opportunity',
                'insight': 'Mostly small/medium sites - good ranking opportunity'
            }



