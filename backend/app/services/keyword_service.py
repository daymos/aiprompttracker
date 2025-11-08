import httpx
import logging
from typing import List, Dict, Any, Optional
from ..config import get_settings
from .google_keyword_insight_service import GoogleKeywordInsightService

logger = logging.getLogger(__name__)
settings = get_settings()

class KeywordService:
    """Service for fetching keyword data using Google Keyword Insight API
    
    Migrated from DataForSEO to Google Keyword Insight (RapidAPI) for:
    - 75x cost reduction ($9.99/mo vs $0.075/keyword with DataForSEO)
    - Predictable pricing (subscription vs pay-per-use)
    - Same data quality (Google Ads API source)
    - Dedicated keyword research endpoints
    """
    
    def __init__(self):
        self.google_kw = GoogleKeywordInsightService()
    
    async def get_keyword_ideas(self, seed_keyword: str, location: str = "us") -> List[Dict[str, Any]]:
        """Get keyword ideas using Google Keyword Insight API (supports global locations)"""
        
        # Auto-detect if input is a URL and use appropriate endpoint
        is_url = seed_keyword.startswith(("http://", "https://", "www.")) or "." in seed_keyword.split()[0]
        
        if is_url:
            logger.info(f"🌐 Detected URL input, using URL endpoint")
            return await self.get_url_keyword_ideas(seed_keyword, location)
        
        # Use Google Keyword Insight API
        logger.info(f"🔍 Fetching keyword suggestions for: '{seed_keyword}' (location: {location})")
        
        try:
            keywords = await self.google_kw.get_keyword_suggestions(
                keyword=seed_keyword,
                location=location,
                limit=100
            )
            
            if keywords:
                logger.info(f"✅ Got {len(keywords)} keyword suggestions from Google Keyword Insight")
            else:
                logger.warning(f"No keywords found for '{seed_keyword}'")
            
            return keywords
            
        except Exception as e:
            logger.error(f"Error fetching keyword ideas: {e}", exc_info=True)
            return []
    
    async def get_url_keyword_ideas(self, url: str, location: str = "us") -> List[Dict[str, Any]]:
        """Get keyword ideas from a URL using Google Keyword Insight API (competitor analysis)"""
        
        logger.info(f"🌐 Getting keywords from URL: {url}")
        
        try:
            keywords = await self.google_kw.get_url_keyword_suggestions(
                url=url,
                location=location,
                limit=100
            )
            
            if keywords:
                logger.info(f"✅ Found {len(keywords)} keywords for URL")
            else:
                logger.warning(f"No keywords found for URL: {url}")
            
            return keywords
            
        except Exception as e:
            logger.error(f"Error getting keywords from URL: {e}", exc_info=True)
            return []
    
    async def get_opportunity_keywords(self, seed_keyword: str, location: str = "us", num: int = 10) -> List[Dict[str, Any]]:
        """Find opportunity keywords (high volume, low competition) using Google Keyword Insight API
        
        Uses dedicated /topkeys endpoint optimized for finding the sweet spot keywords
        """
        
        logger.info(f"💎 Finding opportunity keywords for '{seed_keyword}'")
        
        try:
            # Use Google Keyword Insight's dedicated opportunity endpoint
            opportunities = await self.google_kw.get_opportunity_keywords(
                keyword=seed_keyword,
                location=location,
                num=num
            )
            
            if opportunities:
                logger.info(f"✅ Found {len(opportunities)} opportunity keywords")
            else:
                logger.warning(f"No opportunity keywords found for '{seed_keyword}'")
            
            return opportunities
            
        except Exception as e:
            logger.error(f"Error finding opportunity keywords: {e}", exc_info=True)
            return []
    
    async def get_serp_data(self, keyword: str, location: str = "us") -> Optional[Dict[str, Any]]:
        """Get SERP analysis data (handled by DataForSEO service)"""
        return None  # Not implemented in keyword service, use rank_checker instead
    
    async def analyze_keywords(self, seed_keyword: str, location: str = "us", limit: int = 10) -> List[Dict[str, Any]]:
        """
        Analyze keywords - main entry point for keyword research
        
        Returns enriched keyword data with search volume, competition, CPC, etc.
        """
        
        logger.info(f"📊 Analyzing keywords for: '{seed_keyword}'")
        
        try:
            # Get keyword suggestions from DataForSEO
            keywords = await self.get_keyword_ideas(seed_keyword, location)
            
            if not keywords:
                return []
            
            # Limit results
            keywords = keywords[:limit]
            
            # DEBUG: Log first keyword to see format
            if keywords:
                logger.info(f"📊 Sample keyword data: {keywords[0]}")
            
            # Keywords are already in the correct format from GoogleKeywordInsightService
            # No need to transform - just return them directly
            logger.info(f"✅ Analyzed {len(keywords)} keywords")
            
            return keywords
            
        except Exception as e:
            logger.error(f"Error analyzing keywords: {e}", exc_info=True)
            return []
