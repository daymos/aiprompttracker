import httpx
import logging
from typing import List, Dict, Any, Optional
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class KeywordService:
    """Service for fetching keyword data from RapidAPI"""
    
    def __init__(self):
        self.base_url = "https://google-keyword-research1.p.rapidapi.com"
        self.headers = {
            "X-RapidAPI-Key": settings.RAPIDAPI_KEY,
            "X-RapidAPI-Host": "google-keyword-research1.p.rapidapi.com"
        }
    
    async def get_keyword_ideas(self, seed_keyword: str, location: str = "us") -> List[Dict[str, Any]]:
        """Get keyword ideas and search volume from RapidAPI"""
        
        url = f"{self.base_url}/keyword-research"
        
        params = {
            "keyword": seed_keyword,
            "country": location
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(url, headers=self.headers, params=params, timeout=30.0)
                response.raise_for_status()
                data = response.json()
                
                # RapidAPI returns data in different format
                if isinstance(data, dict) and "results" in data:
                    return data.get("results", [])
                elif isinstance(data, list):
                    return data
                
                return []
                
        except Exception as e:
            logger.error(f"Error fetching keyword data: {e}")
            # Return mock data for testing if API fails
            return self._get_mock_data(seed_keyword)
    
    def _get_mock_data(self, seed_keyword: str) -> List[Dict[str, Any]]:
        """Return mock data for testing when API is unavailable"""
        logger.info("Using mock keyword data for testing")
        
        base_keywords = [
            f"{seed_keyword}",
            f"{seed_keyword} online",
            f"{seed_keyword} tool",
            f"{seed_keyword} free",
            f"best {seed_keyword}",
            f"{seed_keyword} app",
            f"{seed_keyword} software",
            f"how to {seed_keyword}",
            f"{seed_keyword} guide",
            f"{seed_keyword} tutorial"
        ]
        
        return [
            {
                "keyword": kw,
                "search_volume": 1000 + (i * 200),
                "competition": "LOW" if i < 5 else "MEDIUM",
                "cpc": 0.5 + (i * 0.2)
            }
            for i, kw in enumerate(base_keywords)
        ]
    
    async def get_serp_data(self, keyword: str, location: str = "us") -> Optional[Dict[str, Any]]:
        """Get SERP data for a keyword to estimate difficulty"""
        
        # For now, return None or basic mock data
        # Can add SERP API later if needed
        return None
    
    async def analyze_keywords(self, seed_keyword: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Analyze keywords and return simplified data for LLM"""
        
        keyword_data = await self.get_keyword_ideas(seed_keyword)
        
        results = []
        for item in keyword_data[:limit]:
            # Handle different response formats
            results.append({
                "keyword": item.get("keyword", item.get("text", seed_keyword)),
                "search_volume": item.get("search_volume", item.get("volume", 0)),
                "competition": item.get("competition", item.get("difficulty", "UNKNOWN")),
                "cpc": item.get("cpc", item.get("cost", 0)),
            })
        
        return results

