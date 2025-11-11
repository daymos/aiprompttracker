import httpx
import logging
from typing import List, Dict, Any, Optional
from ..config import get_settings
from .google_keyword_insight_service import GoogleKeywordInsightService
from .dataforseo_service import DataForSEOService

logger = logging.getLogger(__name__)
settings = get_settings()

class KeywordService:
    """Service for fetching keyword data using Google Keyword Insight API
    
    Migrated from DataForSEO to Google Keyword Insight (RapidAPI) for:
    - 75x cost reduction ($9.99/mo vs $0.075/keyword with DataForSEO)
    - Predictable pricing (subscription vs pay-per-use)
    - Same data quality (Google Ads API source)
    - Dedicated keyword research endpoints
    
    Still uses DataForSEO for:
    - SEO keyword difficulty scores (not available in Google Ads API)
    - Backlink analysis
    - Rank checking
    """
    
    def __init__(self):
        self.google_kw = GoogleKeywordInsightService()
        self.dataforseo = DataForSEOService()
    
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
        """Find opportunity keywords (high volume, low SEO difficulty) using Google Keyword Insight + DataForSEO
        
        Strategy:
        1. Get candidates from Google Keyword Insight's /topkeys (high volume + low ad competition)
        2. Enrich with SEO difficulty from DataForSEO
        3. Re-sort by REAL opportunity: high volume + LOW SEO difficulty
        """
        
        logger.info(f"💎 Finding opportunity keywords for '{seed_keyword}'")
        
        try:
            # Step 1: Get opportunity candidates (fetches 3x to ensure good results after filtering)
            opportunities = await self.google_kw.get_opportunity_keywords(
                keyword=seed_keyword,
                location=location,
                num=num * 3  # Get more candidates for better filtering
            )
            
            if not opportunities:
                logger.warning(f"No opportunity keywords found for '{seed_keyword}'")
                return []
            
            # Step 2: Extract keyword strings for SEO difficulty lookup
            keyword_strings = [kw['keyword'] for kw in opportunities if kw.get('keyword')]
            
            if not keyword_strings:
                return opportunities[:num]
            
            # Step 3: Enrich with SEO difficulty from DataForSEO
            logger.info(f"📊 Fetching SEO difficulty for {len(keyword_strings)} opportunity candidates...")
            difficulty_scores = await self.dataforseo.get_keyword_difficulty(
                keywords=keyword_strings,
                location=location
            )
            
            # Step 4: Enrich and calculate REAL opportunity score
            for kw in opportunities:
                keyword_text = kw.get('keyword', '')
                
                # Rename ad competition for clarity
                if 'competition' in kw:
                    kw['ad_competition'] = kw.pop('competition')
                
                # Add SEO difficulty
                seo_diff = difficulty_scores.get(keyword_text)
                kw['seo_difficulty'] = seo_diff
                
                # Recalculate opportunity score using ORGANIC difficulty (not ad competition)
                # Formula: volume * (1 - difficulty/100) = higher is better
                if seo_diff is not None:
                    volume = kw.get('search_volume', 0)
                    # Normalize SEO difficulty to 0-1 scale and invert (lower difficulty = better)
                    difficulty_factor = 1 - (seo_diff / 100.0)
                    kw['real_opportunity_score'] = volume * difficulty_factor
                else:
                    # Fall back to ad competition if SEO difficulty unavailable
                    kw['real_opportunity_score'] = kw.get('opportunity_score', 0)
            
            # Step 5: Sort by REAL opportunity (organic ranking potential)
            opportunities.sort(key=lambda x: x.get('real_opportunity_score', 0), reverse=True)
            
            # Return top N with best organic ranking potential
            result = opportunities[:num]
            logger.info(f"✅ Found {len(result)} opportunity keywords (with SEO difficulty)")
            
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
        
        Returns enriched keyword data with:
        - Search volume
        - Ad competition (Google Ads bidding competition)
        - SEO difficulty (organic ranking difficulty 0-100)
        - CPC data
        - Trends
        """
        
        logger.info(f"📊 Analyzing keywords for: '{seed_keyword}'")
        
        try:
            # Get keyword suggestions from Google Keyword Insight
            keywords = await self.get_keyword_ideas(seed_keyword, location)
            
            if not keywords:
                return []
            
            # Limit results
            keywords = keywords[:limit]
            
            # Extract keyword strings for difficulty lookup
            keyword_strings = [kw['keyword'] for kw in keywords if kw.get('keyword')]
            
            # Fetch SEO difficulty scores from DataForSEO
            difficulty_scores = {}
            if keyword_strings:
                logger.info(f"📊 Fetching SEO difficulty for {len(keyword_strings)} keywords...")
                difficulty_scores = await self.dataforseo.get_keyword_difficulty(
                    keywords=keyword_strings,
                    location=location
                )
            
            # Enrich keywords with SEO difficulty
            for kw in keywords:
                keyword_text = kw.get('keyword', '')
                
                # Rename 'competition' to 'ad_competition' for clarity
                if 'competition' in kw:
                    kw['ad_competition'] = kw.pop('competition')
                
                # Add SEO difficulty
                kw['seo_difficulty'] = difficulty_scores.get(keyword_text, None)
            
            logger.info(f"✅ Analyzed {len(keywords)} keywords with SEO difficulty")
            
            return keywords
            
        except Exception as e:
            logger.error(f"Error analyzing keywords: {e}", exc_info=True)
            return []
