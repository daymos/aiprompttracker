import httpx
import asyncio
import logging
from typing import Optional, Dict, Any, List
from urllib.parse import urlparse
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class DataForSEOService:
    """Service for DataForSEO API - handles rank checking, SERP analysis, and keyword research
    
    All APIs use LIVE mode for instant results:
    - Rank checking: ~2 sec, $0.0125/keyword (instant!)
    - SERP analysis: ~2 sec, $0.0125/request (instant!)
    - Keyword research: ~2 sec, $0.002/request (instant!)
    
    Rate limits: 40,000 requests/min (no bottleneck!)
    
    Docs: https://docs.dataforseo.com/
    """
    
    def __init__(self):
        self.base_url = "https://api.dataforseo.com/v3"
        # DataForSEO uses login:password for Basic Auth
        self.login = settings.DATAFORSEO_LOGIN
        self.password = settings.DATAFORSEO_PASSWORD
        
    def _get_location_code(self, location: str) -> int:
        """Convert location name to DataForSEO location code"""
        location_map = {
            "United States": 2840,
            "us": 2840,
            "US": 2840,
            "United Kingdom": 2826,
            "uk": 2826,
            "UK": 2826,
            "Canada": 2124,
            "ca": 2124,
            "CA": 2124,
            "Australia": 2036,
            "au": 2036,
            "AU": 2036,
            "Germany": 2276,
            "de": 2276,
            "DE": 2276,
            "France": 2250,
            "fr": 2250,
            "FR": 2250,
            "Spain": 2724,
            "es": 2724,
            "ES": 2724,
            "Italy": 2380,
            "it": 2380,
            "IT": 2380,
            "Netherlands": 2528,
            "nl": 2528,
            "NL": 2528,
            "Brazil": 2076,
            "br": 2076,
            "BR": 2076,
            "India": 2356,
            "in": 2356,
            "IN": 2356,
        }
        return location_map.get(location, 2840)  # Default to US
    
    # ==================== KEYWORD RESEARCH METHODS ====================
    
    async def get_keyword_suggestions(self, seed_keyword: str, location: str = "US", limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get keyword suggestions using DataForSEO Keywords for Keywords endpoint
        
        Cost: ~$0.002 per request
        Rate limit: 40,000 requests/min (no bottleneck!)
        
        Args:
            seed_keyword: Seed keyword to get suggestions for
            location: Country code (US, UK, CA, etc.) or "global"
            limit: Max number of keywords to return (default 100)
            
        Returns:
            List of keyword objects with search_volume, competition, cpc, etc.
        """
        
        logger.info(f"🔍 Getting keyword suggestions for '{seed_keyword}' (location: {location})")
        
        if not self.login or not self.password:
            logger.error("DataForSEO credentials not configured")
            return []
        
        try:
            # DataForSEO Keywords Data API
            endpoint = f"{self.base_url}/keywords_data/google/keywords_for_keywords/live"
            
            payload = [{
                "keywords": [seed_keyword],
                "location_code": self._get_location_code(location),
                "language_code": "en",
                "include_serp_info": False,  # Don't need SERP data for suggestions
                "limit": limit
            }]
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    endpoint,
                    auth=(self.login, self.password),
                    json=payload,
                    timeout=30.0
                )
                response.raise_for_status()
                data = response.json()
                
                if data.get('status_code') != 20000:
                    error_msg = data.get('status_message', 'Unknown error')
                    logger.error(f"DataForSEO API error: {error_msg}")
                    return []
                
                # Parse results
                tasks = data.get('tasks', [])
                if not tasks or not tasks[0].get('result'):
                    logger.warning(f"No keyword suggestions found for '{seed_keyword}'")
                    return []
                
                result = tasks[0]['result'][0]
                items = result.get('items', [])
                
                logger.info(f"Got {len(items)} keyword suggestions from DataForSEO")
                
                # Transform to our format
                keywords = []
                for item in items:
                    keyword_data = item.get('keyword_data', {})
                    keywords.append({
                        'keyword': item.get('keyword', ''),
                        'search_volume': keyword_data.get('keyword_info', {}).get('search_volume', 0),
                        'competition': self._map_competition(keyword_data.get('keyword_info', {}).get('competition', 0)),
                        'competition_index': keyword_data.get('keyword_info', {}).get('competition', 0),
                        'cpc': keyword_data.get('keyword_info', {}).get('cpc', 0),
                        'low_bid': keyword_data.get('keyword_info', {}).get('low_top_of_page_bid', 0),
                        'high_bid': keyword_data.get('keyword_info', {}).get('high_top_of_page_bid', 0),
                        'intent': self._detect_intent(item.get('keyword', '')),
                        'keyword_difficulty': keyword_data.get('keyword_properties', {}).get('keyword_difficulty', 0)
                    })
                
                return keywords
                
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                logger.warning(f"Keywords API not available on your DataForSEO plan")
            else:
                logger.error(f"HTTP error: {e.response.status_code}")
            return []
        except Exception as e:
            logger.error(f"Error getting keyword suggestions: {e}", exc_info=True)
            return []
    
    async def get_keyword_ideas_from_url(self, url: str, location: str = "US", limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get keyword ideas by analyzing a URL using DataForSEO Keywords for Site endpoint
        
        Args:
            url: URL to analyze
            location: Country code
            limit: Max keywords to return
            
        Returns:
            List of keywords the URL could rank for
        """
        
        logger.info(f"🌐 Getting keyword ideas from URL: {url}")
        
        if not self.login or not self.password:
            logger.error("DataForSEO credentials not configured")
            return []
        
        try:
            endpoint = f"{self.base_url}/keywords_data/google/keywords_for_site/live"
            
            # Clean URL
            if not url.startswith(('http://', 'https://')):
                url = 'https://' + url
            
            payload = [{
                "target": url,
                "location_code": self._get_location_code(location),
                "language_code": "en",
                "limit": limit
            }]
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    endpoint,
                    auth=(self.login, self.password),
                    json=payload,
                    timeout=30.0
                )
                response.raise_for_status()
                data = response.json()
                
                if data.get('status_code') != 20000:
                    error_msg = data.get('status_message', 'Unknown error')
                    logger.error(f"DataForSEO API error: {error_msg}")
                    return []
                
                tasks = data.get('tasks', [])
                if not tasks or not tasks[0].get('result'):
                    logger.warning(f"No keywords found for URL: {url}")
                    return []
                
                result = tasks[0]['result'][0]
                items = result.get('items', [])
                
                logger.info(f"Found {len(items)} keywords for URL")
                
                # Transform to our format
                keywords = []
                for item in items:
                    keyword_data = item.get('keyword_data', {})
                    keywords.append({
                        'keyword': item.get('keyword', ''),
                        'search_volume': keyword_data.get('keyword_info', {}).get('search_volume', 0),
                        'competition': self._map_competition(keyword_data.get('keyword_info', {}).get('competition', 0)),
                        'competition_index': keyword_data.get('keyword_info', {}).get('competition', 0),
                        'cpc': keyword_data.get('keyword_info', {}).get('cpc', 0),
                        'intent': self._detect_intent(item.get('keyword', ''))
                    })
                
                return keywords
                
        except Exception as e:
            logger.error(f"Error getting keywords from URL: {e}", exc_info=True)
            return []
    
    async def get_search_volume(self, keywords: List[str], location: str = "US", use_task_mode: bool = False) -> Dict[str, int]:
        """
        Get search volume for multiple keywords
        
        Cost: ~$0.001 per keyword (much cheaper than suggestions!)
        Task mode: ~50% cheaper but takes 1-5 minutes
        
        Args:
            keywords: List of keywords to check
            location: Country code
            use_task_mode: If True, use task mode (slower, cheaper). If False, use live mode (instant)
            
        Returns:
            Dict mapping keyword to search volume
        """
        
        logger.info(f"📊 Getting search volume for {len(keywords)} keywords (mode: {'task' if use_task_mode else 'live'})")
        
        if not self.login or not self.password:
            logger.error("DataForSEO credentials not configured")
            return {}
        
        try:
            if use_task_mode:
                # Task mode: POST task, wait for completion, GET results (cheaper)
                endpoint = f"{self.base_url}/keywords_data/google/search_volume/task_post"
            else:
                # Live mode: Instant results (more expensive)
                endpoint = f"{self.base_url}/keywords_data/google/search_volume/live"
            
            payload = [{
                "keywords": keywords,
                "location_code": self._get_location_code(location),
                "language_code": "en"
            }]
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    endpoint,
                    auth=(self.login, self.password),
                    json=payload,
                    timeout=30.0
                )
                response.raise_for_status()
                data = response.json()
                
                if data.get('status_code') != 20000:
                    logger.error(f"API error: {data.get('status_message')}")
                    return {}
                
                # Handle task mode - need to wait for completion
                if use_task_mode:
                    tasks = data.get('tasks', [])
                    if not tasks:
                        return {}
                    
                    task_id = tasks[0].get('id')
                    if not task_id:
                        return {}
                    
                    logger.info(f"⏳ Task submitted: {task_id}, waiting for completion...")
                    
                    # Poll for results (DataForSEO tasks usually complete in 1-5 min)
                    max_attempts = 60  # 5 minutes with 5-second intervals
                    for attempt in range(max_attempts):
                        await asyncio.sleep(5)  # Wait 5 seconds between checks
                        
                        get_endpoint = f"{self.base_url}/keywords_data/google/search_volume/task_get/{task_id}"
                        get_response = await client.get(
                            get_endpoint,
                            auth=(self.login, self.password),
                            timeout=30.0
                        )
                        
                        if get_response.status_code != 200:
                            continue
                        
                        result_data = get_response.json()
                        if result_data.get('status_code') != 20000:
                            continue
                        
                        result_tasks = result_data.get('tasks', [])
                        if not result_tasks:
                            continue
                        
                        task_status = result_tasks[0].get('status_message')
                        if task_status == 'Ok.':
                            # Task complete!
                            logger.info(f"✅ Task complete after {(attempt + 1) * 5} seconds")
                            data = result_data
                            break
                        elif 'error' in task_status.lower():
                            logger.error(f"Task failed: {task_status}")
                            return {}
                    else:
                        logger.error("Task timeout after 5 minutes")
                        return {}
                
                # Parse results (same for both live and task mode)
                tasks = data.get('tasks', [])
                if not tasks or not tasks[0].get('result'):
                    return {}
                
                result = tasks[0]['result'][0]
                items = result.get('items', [])
                
                # Map keywords to search volume
                volume_map = {}
                for item in items:
                    keyword = item.get('keyword', '')
                    search_volume = item.get('search_volume', 0)
                    volume_map[keyword] = search_volume
                
                logger.info(f"✅ Got search volume for {len(volume_map)} keywords")
                return volume_map
                
        except Exception as e:
            logger.error(f"Error getting search volume: {e}", exc_info=True)
            return {}
    
    def _map_competition(self, competition_value: float) -> str:
        """Map DataForSEO competition (0-1) to LOW/MEDIUM/HIGH"""
        if competition_value < 0.33:
            return "LOW"
        elif competition_value < 0.67:
            return "MEDIUM"
        else:
            return "HIGH"
    
    def _detect_intent(self, keyword: str) -> str:
        """Simple intent detection based on keyword patterns"""
        keyword_lower = keyword.lower()
        
        # Commercial intent
        if any(word in keyword_lower for word in ['buy', 'price', 'cost', 'cheap', 'deal', 'discount', 'shop', 'store', 'purchase']):
            return 'commercial'
        
        # Transactional intent
        if any(word in keyword_lower for word in ['download', 'free', 'trial', 'demo', 'signup', 'register']):
            return 'transactional'
        
        # Informational intent (questions)
        if any(keyword_lower.startswith(word) for word in ['how', 'what', 'why', 'when', 'where', 'who', 'which']):
            return 'informational'
        
        # Navigational intent (brand names)
        if any(word in keyword_lower for word in ['login', 'account', 'dashboard', 'app', 'official']):
            return 'navigational'
        
        # Default to informational
        return 'informational'
    
    # ==================== RANK CHECKING METHODS ====================
    
    async def check_ranking(self, keyword: str, target_domain: str, location: str = "United States") -> Optional[Dict[str, Any]]:
        """
        Check keyword ranking using DataForSEO SERP API (live/instant)
        
        Cost: ~$0.0125 per keyword
        Time: ~2 seconds (instant results!)
        
        Args:
            keyword: Keyword to check
            target_domain: Domain to check ranking for (e.g., "keywords.chat")
            location: Location name or code
            
        Returns:
            {
                "position": 5,  # Ranking position (1-100, None if not found)
                "url": "https://keywords.chat/...",  # URL that ranked
                "title": "Page Title",
                "description": "Meta description",
                "competitiveness": 0.75,  # 0-1 scale
                "total_results": 1500000
            }
        """
        logger.info(f"🔍 Checking ranking for '{keyword}' targeting {target_domain}")
        
        if not self.login or not self.password:
            logger.error("DataForSEO credentials not configured")
            return None
        
        try:
            location_code = self._get_location_code(location)
            
            # Clean target domain (remove protocol, www, trailing slash)
            clean_domain = target_domain.lower()
            for prefix in ['https://', 'http://', 'www.']:
                clean_domain = clean_domain.replace(prefix, '')
            clean_domain = clean_domain.rstrip('/')
            
            # Use Live API for instant results
            live_endpoint = f"{self.base_url}/serp/google/organic/live/advanced"
            
            payload = [{
                "keyword": keyword,
                "location_code": location_code,
                "language_code": "en",
                "device": "desktop",
                "os": "windows",
                "depth": 100  # Check top 100 results
            }]
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    live_endpoint,
                    json=payload,
                    auth=(self.login, self.password)
                )
                
                if response.status_code != 200:
                    logger.error(f"Live API failed: {response.status_code} - {response.text}")
                    return None
                
                result = response.json()
                
                if result.get("status_code") != 20000:
                    logger.error(f"API error: {result.get('status_message')}")
                    return None
                
                # Parse results
                tasks = result.get('tasks', [])
                if not tasks or not tasks[0].get('result'):
                    logger.warning("No results returned from live API")
                    return None
                
                task_result = tasks[0]['result'][0]
                items = task_result.get('items', [])
                
                # Find our domain in results
                position = None
                ranked_url = None
                title = None
                description = None
                
                for item in items:
                    if item.get('type') == 'organic':
                        item_url = item.get('url', '')
                        # Check if this result is from our domain
                        if clean_domain in item_url.lower():
                            position = item.get('rank_absolute')
                            ranked_url = item_url
                            title = item.get('title', '')
                            description = item.get('description', '')
                            logger.info(f"✅ Found {target_domain} at position {position}")
                            break
                
                if position is None:
                    logger.info(f"❌ {target_domain} not found in top 100 for '{keyword}'")
                
                return {
                    "position": position,
                    "url": ranked_url,
                    "title": title,
                    "description": description,
                    "competitiveness": task_result.get('se_results_count', 0) / 10000000,  # Rough estimate
                    "total_results": task_result.get('se_results_count', 0)
                }
                
        except Exception as e:
            logger.error(f"Error checking ranking: {e}")
            return None
    
    async def check_multiple_rankings(self, keywords: List[str], target_domain: str, location: str = "United States") -> Dict[str, Dict[str, Any]]:
        """
        Batch check rankings for multiple keywords (parallel processing)
        
        Cost: ~$0.0125 per keyword
        Time: ~2 seconds total (all checked in parallel!)
        """
        logger.info(f"🔍 Batch checking {len(keywords)} keywords for {target_domain}")
        
        # Process all keywords in parallel
        tasks = [
            self.check_ranking(keyword, target_domain, location)
            for keyword in keywords
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Build result dict
        result_dict = {}
        for keyword, result in zip(keywords, results):
            if isinstance(result, Exception):
                logger.error(f"Error checking '{keyword}': {result}")
                result_dict[keyword] = None
            else:
                result_dict[keyword] = result
        
        logger.info(f"✅ Batch check complete: {sum(1 for r in result_dict.values() if r)} successful")
        
        return result_dict
    
    async def get_serp_analysis(self, keyword: str, location: str = "United States") -> Optional[Dict[str, Any]]:
        """
        Get SERP analysis (competitive analysis, featured snippets, etc.)
        
        Uses live API for instant results
        Returns detailed SERP data including top 10 results
        """
        logger.info(f"🔍 Getting SERP analysis for '{keyword}'")
        
        if not self.login or not self.password:
            logger.error("DataForSEO credentials not configured")
            return None
        
        try:
            location_code = self._get_location_code(location)
            
            # Use Live API
            live_endpoint = f"{self.base_url}/serp/google/organic/live/advanced"
            
            payload = [{
                "keyword": keyword,
                "location_code": location_code,
                "language_code": "en",
                "device": "desktop",
                "os": "windows",
                "depth": 10  # Top 10 for analysis
            }]
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    live_endpoint,
                    json=payload,
                    auth=(self.login, self.password)
                )
                
                if response.status_code != 200:
                    logger.error(f"Live API failed: {response.status_code}")
                    return None
                
                result = response.json()
                
                if result.get("status_code") != 20000:
                    logger.error(f"API error: {result.get('status_message')}")
                    return None
                
                tasks = result.get('tasks', [])
                if not tasks or not tasks[0].get('result'):
                    return None
                
                task_result = tasks[0]['result'][0]
                
                return {
                    "keyword": keyword,
                    "total_results": task_result.get('se_results_count', 0),
                    "top_results": [
                        {
                            "position": item.get('rank_absolute'),
                            "url": item.get('url'),
                            "domain": item.get('domain'),
                            "title": item.get('title'),
                            "description": item.get('description')
                        }
                        for item in task_result.get('items', [])
                        if item.get('type') == 'organic'
                    ][:10]
                }
                
        except Exception as e:
            logger.error(f"Error getting SERP analysis: {e}")
            return None
