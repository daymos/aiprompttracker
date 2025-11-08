import httpx
import logging
from typing import List, Dict, Any, Optional
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class GoogleKeywordInsightService:
    """Service for Google Keyword Insight API via RapidAPI
    
    Replaces DataForSEO for keyword research to save ~75x on costs.
    
    Pricing: $9.99-33.99/mo subscription (vs DataForSEO $0.075/keyword)
    API Docs: https://rapidapi.com/rhmueed/api/google-keyword-insight1
    """
    
    def __init__(self):
        self.base_url = "https://google-keyword-insight1.p.rapidapi.com"
        self.rapidapi_key = settings.RAPIDAPI_KEY
        
    def _get_headers(self) -> Dict[str, str]:
        """Generate headers for RapidAPI"""
        return {
            "x-rapidapi-host": "google-keyword-insight1.p.rapidapi.com",
            "x-rapidapi-key": self.rapidapi_key
        }
    
    async def get_keyword_suggestions(
        self, 
        keyword: str,
        location: str = "us",
        language: str = "en",
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """
        Get keyword suggestions using /keysuggest endpoint
        
        Args:
            keyword: Seed keyword to get suggestions for
            location: Country code (us, uk, ca, etc.) - default 'us'
            language: Language code (en, es, fr, etc.) - default 'en'
            limit: Max results to return (API returns up to 100)
        
        Returns:
            List of keywords with volume, CPC, competition data
        """
        
        logger.info(f"🔍 Fetching keyword suggestions for: '{keyword}' (location: {location})")
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/keysuggest",
                    headers=self._get_headers(),
                    params={
                        "keyword": keyword,
                        "location": location.upper(),
                        "lang": language.lower()
                    }
                )
                
                response.raise_for_status()
                data = response.json()
                
                # API returns list directly (not wrapped in object)
                keywords_raw = data if isinstance(data, list) else data.get("keywords", [])
                
                if not keywords_raw:
                    logger.warning(f"⚠️ No keywords found for '{keyword}'")
                    return []
                
                # Transform to our standard format
                keywords = []
                for kw in keywords_raw[:limit]:
                    # API uses 0-100 scale, convert to 0-1 for consistency
                    competition_index_100 = kw.get("competition_index", 0)
                    competition_index = competition_index_100 / 100.0
                    
                    keywords.append({
                        "keyword": kw.get("text", ""),  # API uses 'text' not 'keyword'
                        "search_volume": kw.get("volume", 0),  # API uses 'volume' not 'search_volume'
                        "competition": kw.get("competition_level", "UNKNOWN"),  # Already formatted as LOW/MEDIUM/HIGH
                        "competition_index": competition_index,  # Convert 0-100 to 0-1 scale
                        "cpc": (kw.get("low_bid", 0.0) + kw.get("high_bid", 0.0)) / 2.0,  # Average of low/high bid
                        "low_bid": kw.get("low_bid", 0.0),
                        "high_bid": kw.get("high_bid", 0.0),
                        "intent": "informational",  # API doesn't provide this, default value
                        "trend": kw.get("trend", 0)  # Percentage change trend
                    })
                
                logger.info(f"✅ Got {len(keywords)} keyword suggestions from Google Keyword Insight")
                return keywords
                
        except httpx.HTTPStatusError as e:
            logger.error(f"❌ HTTP error fetching keywords: {e.response.status_code} - {e.response.text}")
            return []
        except Exception as e:
            logger.error(f"❌ Error fetching keyword suggestions: {e}", exc_info=True)
            return []
    
    async def get_url_keyword_suggestions(
        self,
        url: str,
        location: str = "us",
        language: str = "en",
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """
        Get keyword suggestions from a URL using /urlkeysuggest endpoint
        
        Perfect for competitor analysis - analyzes what keywords a URL/site ranks for
        
        Args:
            url: Target URL or domain (e.g., "example.com" or "https://example.com/page")
            location: Country code (us, uk, ca, etc.)
            language: Language code (en, es, fr, etc.)
            limit: Max results to return
        
        Returns:
            List of keywords the URL ranks for
        """
        
        logger.info(f"🌐 Getting keywords from URL: {url}")
        
        try:
            # Clean URL - remove protocol if present
            clean_url = url.replace("https://", "").replace("http://", "")
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/urlkeysuggest",
                    headers=self._get_headers(),
                    params={
                        "url": clean_url,
                        "location": location.upper(),
                        "lang": language.lower()
                    }
                )
                
                response.raise_for_status()
                data = response.json()
                
                # API can return: list directly OR { "keywords": [...] }
                if isinstance(data, list):
                    keywords_raw = data
                else:
                    keywords_raw = data.get("keywords", [])
                
                if not keywords_raw:
                    logger.warning(f"⚠️ No keywords found for URL: {url}")
                    return []
                
                # Transform to standard format
                keywords = []
                for kw in keywords_raw[:limit]:
                    # API uses 0-100 scale, convert to 0-1
                    competition_index_100 = kw.get("competition_index", 0)
                    competition_index = competition_index_100 / 100.0
                    
                    keywords.append({
                        "keyword": kw.get("text", ""),
                        "search_volume": kw.get("volume", 0),
                        "competition": kw.get("competition_level", "UNKNOWN"),
                        "competition_index": competition_index,
                        "cpc": (kw.get("low_bid", 0.0) + kw.get("high_bid", 0.0)) / 2.0,
                        "low_bid": kw.get("low_bid", 0.0),
                        "high_bid": kw.get("high_bid", 0.0),
                        "intent": "informational",
                        "trend": kw.get("trend", 0)
                    })
                
                logger.info(f"✅ Found {len(keywords)} keywords for URL: {url}")
                return keywords
                
        except httpx.HTTPStatusError as e:
            logger.error(f"❌ HTTP error fetching URL keywords: {e.response.status_code} - {e.response.text}")
            return []
        except Exception as e:
            logger.error(f"❌ Error getting keywords from URL: {e}", exc_info=True)
            return []
    
    async def get_opportunity_keywords(
        self,
        keyword: str,
        location: str = "us",
        language: str = "en",
        num: int = 10
    ) -> List[Dict[str, Any]]:
        """
        Find opportunity keywords using /topkeys endpoint
        
        Returns high-volume, low-competition keywords (the sweet spot!)
        
        Args:
            keyword: Seed keyword for opportunity analysis
            location: Country code
            language: Language code
            num: Number of opportunities to return
        
        Returns:
            List of opportunity keywords sorted by potential
        """
        
        logger.info(f"💎 Finding opportunity keywords for '{keyword}'")
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/topkeys",
                    headers=self._get_headers(),
                    params={
                        "keyword": keyword,
                        "location": location.upper(),
                        "lang": language.lower()
                    }
                )
                
                response.raise_for_status()
                data = response.json()
                
                # API can return: list directly OR { "keywords": [...] }
                if isinstance(data, list):
                    keywords_raw = data
                else:
                    keywords_raw = data.get("keywords", [])
                
                if not keywords_raw:
                    logger.warning(f"⚠️ No opportunity keywords found for '{keyword}'")
                    return []
                
                # Transform and calculate opportunity score
                opportunities = []
                for kw in keywords_raw:
                    search_vol = kw.get("volume", 0)
                    competition_index_100 = kw.get("competition_index", 0)
                    competition_idx = competition_index_100 / 100.0  # Convert to 0-1 scale
                    
                    # Opportunity score: Higher volume + Lower competition = Better
                    opportunity_score = search_vol * (1 - competition_idx) if search_vol > 0 else 0
                    
                    opportunities.append({
                        "keyword": kw.get("text", ""),
                        "search_volume": search_vol,
                        "competition": kw.get("competition_level", "UNKNOWN"),
                        "competition_index": competition_idx,
                        "cpc": (kw.get("low_bid", 0.0) + kw.get("high_bid", 0.0)) / 2.0,
                        "low_bid": kw.get("low_bid", 0.0),
                        "high_bid": kw.get("high_bid", 0.0),
                        "intent": "informational",
                        "trend": kw.get("trend", 0),
                        "opportunity_score": opportunity_score
                    })
                
                # Sort by opportunity score (best first)
                opportunities.sort(key=lambda x: x.get("opportunity_score", 0), reverse=True)
                
                # Return top N
                result = opportunities[:num]
                logger.info(f"✅ Found {len(result)} opportunity keywords")
                return result
                
        except httpx.HTTPStatusError as e:
            logger.error(f"❌ HTTP error fetching opportunity keywords: {e.response.status_code} - {e.response.text}")
            return []
        except Exception as e:
            logger.error(f"❌ Error finding opportunity keywords: {e}", exc_info=True)
            return []
    
    async def get_keyword_details(
        self,
        keyword: str,
        location: str = "us",
        language: str = "en"
    ) -> Optional[Dict[str, Any]]:
        """
        Get detailed data for a single keyword
        
        Args:
            keyword: The specific keyword to analyze
            location: Country code
            language: Language code
        
        Returns:
            Detailed keyword data with volume, CPC, competition, trends
        """
        
        logger.info(f"📊 Getting detailed data for keyword: '{keyword}'")
        
        try:
            # Use keysuggest and filter for exact match
            suggestions = await self.get_keyword_suggestions(
                keyword=keyword,
                location=location,
                language=language,
                limit=50
            )
            
            # Find exact match
            for kw in suggestions:
                if kw.get("keyword", "").lower() == keyword.lower():
                    logger.info(f"✅ Found detailed data for '{keyword}'")
                    return kw
            
            # If no exact match, return first result if available
            if suggestions:
                logger.info(f"⚠️ No exact match for '{keyword}', returning closest match")
                return suggestions[0]
            
            logger.warning(f"❌ No data found for keyword: '{keyword}'")
            return None
            
        except Exception as e:
            logger.error(f"❌ Error getting keyword details: {e}", exc_info=True)
            return None

