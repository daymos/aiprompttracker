import logging
from typing import Optional, Dict, Any
from .dataforseo_service import DataForSEOService

logger = logging.getLogger(__name__)

class RankCheckerService:
    """Service for checking Google rankings for keywords
    
    This service now uses DataForSEO API which provides:
    - Batch processing (check multiple keywords in one API call)
    - More accurate ranking data
    - Better rate limits (1,200 QPM instead of ~100 QPD)
    - Richer data (title, description, etc.)
    """
    
    def __init__(self):
        self.dataforseo = DataForSEOService()
    
    async def check_ranking(self, keyword: str, target_domain: str, location: str = "United States") -> Optional[Dict[str, Any]]:
        """
        Check where target_domain ranks for a keyword
        
        Args:
            keyword: Search keyword
            target_domain: Domain to check (e.g., "outloud.tech")
            location: Location name (default: "United States")
        
        Returns:
            {
                'position': int or None,  # Position in results (1-100), None if not found
                'page_url': str or None,  # The specific page that ranked
                'domain': str,
                'title': str or None,
                'description': str or None
            }
        """
        return await self.dataforseo.check_ranking(keyword, target_domain, location)
    
    async def check_multiple_rankings(self, keywords: list, target_domain: str, location: str = "United States") -> Dict[str, Dict[str, Any]]:
        """
        Check rankings for multiple keywords using BATCH processing
        
        This is MUCH faster than the old sequential approach:
        - Old: 20 keywords × 2 sec = 40 seconds
        - New: All 20 keywords in ~5-10 seconds (batch request)
        
        Args:
            keywords: List of keywords to check
            target_domain: Domain to check
            location: Location name
            
        Returns:
            Dict mapping keyword to ranking result
        """
        return await self.dataforseo.check_multiple_rankings(keywords, target_domain, location)
    
    async def get_serp_analysis(self, keyword: str, location: str = "United States") -> Optional[Dict[str, Any]]:
        """
        Get top 10 SERP results and analyze competitiveness
        
        Returns:
            {
                'top_domains': ['example.com', 'another.com', ...],
                'analysis': 'Very Hard' | 'Hard' | 'Medium' | 'Good Opportunity',
                'insight': 'Human-readable insight for LLM'
            }
        """
        return await self.dataforseo.get_serp_analysis(keyword, location)
