import httpx
import base64
import logging
from typing import List, Dict, Any, Optional
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class KeywordService:
    """Service for fetching keyword data from DataForSEO"""
    
    def __init__(self):
        self.base_url = "https://api.dataforseo.com/v3"
        self.auth = base64.b64encode(
            f"{settings.DATAFORSEO_LOGIN}:{settings.DATAFORSEO_PASSWORD}".encode()
        ).decode()
    
    async def get_keyword_ideas(self, seed_keyword: str, location: str = "United States") -> List[Dict[str, Any]]:
        """Get keyword ideas and search volume from DataForSEO"""
        
        url = f"{self.base_url}/keywords_data/google_ads/search_volume/live"
        
        headers = {
            "Authorization": f"Basic {self.auth}",
            "Content-Type": "application/json"
        }
        
        payload = [{
            "keywords": [seed_keyword],
            "location_name": location,
            "language_name": "English"
        }]
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(url, json=payload, headers=headers, timeout=30.0)
                response.raise_for_status()
                data = response.json()
                
                if data.get("status_code") == 20000:
                    tasks = data.get("tasks", [])
                    if tasks and tasks[0].get("result"):
                        return tasks[0]["result"]
                
                logger.error(f"DataForSEO API error: {data}")
                return []
                
        except Exception as e:
            logger.error(f"Error fetching keyword data: {e}")
            return []
    
    async def get_serp_data(self, keyword: str, location: str = "United States") -> Optional[Dict[str, Any]]:
        """Get SERP data for a keyword to estimate difficulty"""
        
        url = f"{self.base_url}/serp/google/organic/live/advanced"
        
        headers = {
            "Authorization": f"Basic {self.auth}",
            "Content-Type": "application/json"
        }
        
        payload = [{
            "keyword": keyword,
            "location_name": location,
            "language_name": "English",
            "device": "desktop",
            "os": "windows"
        }]
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(url, json=payload, headers=headers, timeout=30.0)
                response.raise_for_status()
                data = response.json()
                
                if data.get("status_code") == 20000:
                    tasks = data.get("tasks", [])
                    if tasks and tasks[0].get("result"):
                        return tasks[0]["result"][0]
                
                return None
                
        except Exception as e:
            logger.error(f"Error fetching SERP data: {e}")
            return None
    
    async def analyze_keywords(self, seed_keyword: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Analyze keywords and return simplified data for LLM"""
        
        keyword_data = await self.get_keyword_ideas(seed_keyword)
        
        results = []
        for item in keyword_data[:limit]:
            keyword_info = item.get("keyword_info", {})
            results.append({
                "keyword": item.get("keyword"),
                "search_volume": keyword_info.get("search_volume"),
                "competition": keyword_info.get("competition"),
                "cpc": keyword_info.get("cpc"),
                "monthly_searches": keyword_info.get("monthly_searches", [])
            })
        
        return results

