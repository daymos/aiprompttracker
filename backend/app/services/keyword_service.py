import httpx
import logging
from typing import List, Dict, Any, Optional
from ..config import get_settings
from .dataforseo_service import DataForSEOService

logger = logging.getLogger(__name__)
settings = get_settings()

class KeywordService:
    """Service for fetching keyword data using DataForSEO Keywords Data API
    
    Migrated from RapidAPI to DataForSEO for:
    - Better rate limits (40,000 req/min vs 10 req/min)
    - Lower cost for variable usage
    - Consolidation with existing SERP/rank tracking
    """
    
    def __init__(self):
        self.dataforseo = DataForSEOService()
    
    async def get_keyword_ideas(self, seed_keyword: str, location: str = "us") -> List[Dict[str, Any]]:
        """Get keyword ideas using DataForSEO (supports global and location-specific)"""
        
        # Auto-detect if input is a URL and use appropriate endpoint
        is_url = seed_keyword.startswith(("http://", "https://", "www.")) or "." in seed_keyword.split()[0]
        
        if is_url:
            logger.info(f"🌐 Detected URL input, using URL endpoint")
            return await self.get_url_keyword_ideas(seed_keyword, location)
        
        # Use DataForSEO keyword suggestions
        logger.info(f"🔍 Fetching keyword suggestions for: '{seed_keyword}' (location: {location})")
        
        try:
            keywords = await self.dataforseo.get_keyword_suggestions(
                seed_keyword=seed_keyword,
                location=location,
                limit=100
            )
            
            if keywords:
                logger.info(f"✅ Got {len(keywords)} keyword suggestions from DataForSEO")
            else:
                logger.warning(f"No keywords found for '{seed_keyword}'")
            
            return keywords
            
        except Exception as e:
            logger.error(f"Error fetching keyword ideas: {e}", exc_info=True)
            return []
    
    async def get_url_keyword_ideas(self, url: str, location: str = "us") -> List[Dict[str, Any]]:
        """Get keyword ideas from a URL using DataForSEO"""
        
        logger.info(f"🌐 Getting keywords from URL: {url}")
        
        try:
            keywords = await self.dataforseo.get_keyword_ideas_from_url(
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
        """Find opportunity keywords (high volume, low competition) using DataForSEO"""
        
        logger.info(f"💎 Finding opportunity keywords for '{seed_keyword}'")
        
        try:
            # Get all keyword suggestions
            all_keywords = await self.dataforseo.get_keyword_suggestions(
                seed_keyword=seed_keyword,
                location=location,
                limit=200  # Get more to filter from
            )
            
            if not all_keywords:
                return []
            
            # Filter for opportunity keywords
            # Criteria: competition_index < 0.5 (LOW to MEDIUM) and search_volume > 100
            opportunities = []
            for kw in all_keywords:
                competition_idx = kw.get('competition_index', 1.0)
                search_vol = kw.get('search_volume', 0)
                
                # Opportunity = decent volume + low competition
                if competition_idx < 0.5 and search_vol >= 100:
                    # Calculate opportunity score
                    # Higher score = better opportunity (high volume, low competition)
                    opportunity_score = search_vol * (1 - competition_idx)
                    kw['opportunity_score'] = opportunity_score
                    opportunities.append(kw)
            
            # Sort by opportunity score (best first)
            opportunities.sort(key=lambda x: x.get('opportunity_score', 0), reverse=True)
            
            # Return top N
            result = opportunities[:num]
            
            logger.info(f"✅ Found {len(result)} opportunity keywords")
            
            return result
            
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
            
            # Transform to expected format for AI/frontend
            enriched_keywords = []
            for kw in keywords:
                enriched_keywords.append({
                    'keyword': kw.get('keyword', ''),
                    'search_volume': kw.get('search_volume', 0),
                    'competition': kw.get('competition', 'UNKNOWN'),
                    'competition_index': kw.get('competition_index', 0),
                    'cpc': kw.get('cpc', 0),
                    'low_bid': kw.get('low_bid', 0),
                    'high_bid': kw.get('high_bid', 0),
                    'intent': kw.get('intent', 'informational'),
                    'keyword_difficulty': kw.get('keyword_difficulty', 0)
                })
            
            logger.info(f"✅ Analyzed {len(enriched_keywords)} keywords")
            
            return enriched_keywords
            
        except Exception as e:
            logger.error(f"Error analyzing keywords: {e}", exc_info=True)
            return []
