import httpx
import logging
from typing import List, Dict, Any, Optional
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class KeywordService:
    """Service for fetching keyword data from RapidAPI (Google Keyword Insight)"""
    
    def __init__(self):
        self.base_url = "https://google-keyword-insight1.p.rapidapi.com"
        self.headers = {
            "x-rapidapi-key": settings.RAPIDAPI_KEY,
            "x-rapidapi-host": "google-keyword-insight1.p.rapidapi.com"
        }
    
    async def get_keyword_ideas(self, seed_keyword: str, location: str = "us") -> List[Dict[str, Any]]:
        """Get keyword ideas using Google Keyword Insight API (supports global and location-specific)"""
        
        # Auto-detect if input is a URL and use appropriate endpoint
        is_url = seed_keyword.startswith(("http://", "https://", "www.")) or "." in seed_keyword.split()[0]
        
        if is_url:
            logger.info(f"🌐 Detected URL input, using URL endpoint")
            return await self.get_url_keyword_ideas(seed_keyword, location)
        
        # Check if global or location-specific search
        is_global = location.lower() == "global"
        
        if is_global:
            url = f"{self.base_url}/globalkey/"
            params = {
                "keyword": seed_keyword,
                "lang": "en",
                "return_intent": "true"
            }
            logger.info(f"🌍 Using global keyword endpoint (worldwide data)")
        else:
            url = f"{self.base_url}/keysuggest/"
            params = {
                "keyword": seed_keyword,
                "location": location.upper(),  # e.g., "US", "UK"
                "lang": "en",
                "return_intent": "true"  # Include search intent
            }
            logger.info(f"📍 Using location-specific endpoint ({location.upper()})")
        
        # Check if API key is configured
        if not settings.RAPIDAPI_KEY:
            logger.error("❌ RAPIDAPI_KEY not configured - keyword research cannot work")
            raise ValueError("RAPIDAPI_KEY environment variable not set")
        
        # Log the request details
        masked_key = settings.RAPIDAPI_KEY[:8] + "..." if settings.RAPIDAPI_KEY else "MISSING"
        logger.info(f"🔍 Fetching keyword data for: '{seed_keyword}'")
        logger.info(f"📡 API Endpoint: {url}")
        logger.info(f"🔑 API Key (masked): {masked_key}")
        logger.info(f"📋 Request params: {params}")
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(url, headers=self.headers, params=params, timeout=30.0)
                
                # Log response status
                logger.info(f"📥 Response status: {response.status_code}")
                
                # If not successful, log the full response
                if response.status_code != 200:
                    logger.error(f"❌ API returned error status: {response.status_code}")
                    logger.error(f"Response headers: {dict(response.headers)}")
                    logger.error(f"Response body: {response.text[:500]}")  # First 500 chars
                
                response.raise_for_status()
                data = response.json()
                
                # Parse Google Keyword Insight API response (/keysuggest endpoint)
                logger.info(f"✅ Successfully received data from Google Keyword Insight API")
                
                # API returns an array of keyword objects directly
                if isinstance(data, list):
                    logger.info(f"Found {len(data)} keywords with volume/competition data")
                    return data
                
                # If empty dict/null, no keywords found
                if isinstance(data, dict) and not data:
                    logger.warning(f"No keywords found for '{seed_keyword}'")
                    return []
                
                logger.error(f"❌ Unexpected data format received: {type(data)}")
                logger.error(f"Expected list, got: {str(data)[:200]}")
                raise ValueError(f"Unexpected API response format: expected array of keywords")
                
        except httpx.HTTPStatusError as e:
            logger.error(f"❌ HTTP error fetching keyword data: {e.response.status_code}")
            logger.error(f"URL: {e.request.url}")
            logger.error(f"Response body: {e.response.text[:1000]}")
            
            # Provide specific error guidance based on status code
            if e.response.status_code == 404:
                logger.error("🔍 API returned 404 - This API endpoint may not exist or has been changed")
                logger.error("💡 Check RapidAPI dashboard: https://rapidapi.com/rhmueed/api/google-keyword-insight1")
                logger.error("💡 Verify the endpoint URL and your subscription plan")
            elif e.response.status_code == 403:
                logger.error("🔒 API returned 403 - Access forbidden (check API key or subscription)")
            elif e.response.status_code == 429:
                logger.error("⚠️  API returned 429 - Rate limit exceeded")
            
            raise httpx.HTTPStatusError(
                message=f"Keyword API failed: {e.response.status_code}",
                request=e.request,
                response=e.response
            )
        except httpx.TimeoutException as e:
            logger.error(f"⏱️  Timeout fetching keyword data (>30s)")
            raise TimeoutError("Keyword API request timed out after 30 seconds")
        except Exception as e:
            logger.error(f"❌ Unexpected error fetching keyword data: {e}", exc_info=True)
            raise
    
    async def get_url_keyword_ideas(self, url: str, location: str = "us") -> List[Dict[str, Any]]:
        """Get keyword ideas for a URL using Google Keyword Insight API (supports global and location-specific)"""
        
        # Clean URL (remove protocol if present for API)
        clean_url = url.replace("http://", "").replace("https://", "").split("/")[0]
        
        # Check if global or location-specific search
        is_global = location.lower() == "global"
        
        if is_global:
            endpoint = f"{self.base_url}/globalurl/"
            params = {
                "url": clean_url,
                "lang": "en",
                "return_intent": "true"
            }
            logger.info(f"🌍 Using global URL endpoint (worldwide data)")
        else:
            endpoint = f"{self.base_url}/urlkeysuggest/"
            params = {
                "url": clean_url,
                "location": location.upper(),
                "lang": "en",
                "return_intent": "true"
            }
            logger.info(f"📍 Using location-specific URL endpoint ({location.upper()})")
        
        if not settings.RAPIDAPI_KEY:
            logger.error("❌ RAPIDAPI_KEY not configured - keyword research cannot work")
            raise ValueError("RAPIDAPI_KEY environment variable not set")
        
        masked_key = settings.RAPIDAPI_KEY[:8] + "..." if settings.RAPIDAPI_KEY else "MISSING"
        logger.info(f"🔍 Fetching keyword data for URL: '{clean_url}'")
        logger.info(f"📡 API Endpoint: {endpoint}")
        logger.info(f"🔑 API Key (masked): {masked_key}")
        logger.info(f"📋 Request params: {params}")
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(endpoint, headers=self.headers, params=params, timeout=30.0)
                
                logger.info(f"📥 Response status: {response.status_code}")
                
                if response.status_code != 200:
                    logger.error(f"❌ API returned error status: {response.status_code}")
                    logger.error(f"Response headers: {dict(response.headers)}")
                    logger.error(f"Response body: {response.text[:500]}")
                
                response.raise_for_status()
                data = response.json()
                
                logger.info(f"✅ Successfully received data from Google Keyword Insight API (URL endpoint)")
                
                if isinstance(data, list):
                    logger.info(f"Found {len(data)} keyword suggestions for URL")
                    return data
                
                if isinstance(data, dict) and not data:
                    logger.warning(f"No keywords found for URL '{clean_url}'")
                    return []
                
                logger.error(f"❌ Unexpected data format received: {type(data)}")
                logger.error(f"Expected list, got: {str(data)[:200]}")
                raise ValueError(f"Unexpected API response format: expected array of keywords")
                
        except httpx.HTTPStatusError as e:
            logger.error(f"❌ HTTP error fetching URL keyword data: {e.response.status_code}")
            logger.error(f"URL: {e.request.url}")
            logger.error(f"Response body: {e.response.text[:1000]}")
            
            if e.response.status_code == 404:
                logger.error("🔍 API returned 404 - This API endpoint may not exist or has been changed")
                logger.error("💡 Check RapidAPI dashboard: https://rapidapi.com/rhmueed/api/google-keyword-insight1")
            elif e.response.status_code == 403:
                logger.error("🔒 API returned 403 - Access forbidden (check API key or subscription)")
            elif e.response.status_code == 429:
                logger.error("⚠️  API returned 429 - Rate limit exceeded")
            
            raise httpx.HTTPStatusError(
                message=f"Keyword API failed: {e.response.status_code}",
                request=e.request,
                response=e.response
            )
        except Exception as e:
            logger.error(f"❌ Unexpected error fetching URL keyword data: {e}")
            raise
    
    async def get_opportunity_keywords(self, seed_keyword: str, location: str = "us", num: int = 10) -> List[Dict[str, Any]]:
        """Get opportunity keywords (high-potential, easier to rank) using /topkeys endpoint"""
        
        endpoint = f"{self.base_url}/topkeys/"
        
        params = {
            "keyword": seed_keyword,
            "location": location.upper(),
            "lang": "en",
            "num": num
        }
        
        if not settings.RAPIDAPI_KEY:
            logger.error("❌ RAPIDAPI_KEY not configured - keyword research cannot work")
            raise ValueError("RAPIDAPI_KEY environment variable not set")
        
        masked_key = settings.RAPIDAPI_KEY[:8] + "..." if settings.RAPIDAPI_KEY else "MISSING"
        logger.info(f"🎯 Fetching opportunity keywords for: '{seed_keyword}'")
        logger.info(f"📡 API Endpoint: {endpoint}")
        logger.info(f"🔑 API Key (masked): {masked_key}")
        logger.info(f"📋 Request params: {params}")
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(endpoint, headers=self.headers, params=params, timeout=30.0)
                
                logger.info(f"📥 Response status: {response.status_code}")
                
                if response.status_code != 200:
                    logger.error(f"❌ API returned error status: {response.status_code}")
                    logger.error(f"Response headers: {dict(response.headers)}")
                    logger.error(f"Response body: {response.text[:500]}")
                
                response.raise_for_status()
                data = response.json()
                
                logger.info(f"✅ Successfully received opportunity keywords from Google Keyword Insight API")
                
                if isinstance(data, list):
                    logger.info(f"Found {len(data)} opportunity keywords")
                    return data
                
                if isinstance(data, dict) and not data:
                    logger.warning(f"No opportunity keywords found for '{seed_keyword}'")
                    return []
                
                logger.error(f"❌ Unexpected data format received: {type(data)}")
                logger.error(f"Expected list, got: {str(data)[:200]}")
                raise ValueError(f"Unexpected API response format: expected array of keywords")
                
        except httpx.HTTPStatusError as e:
            logger.error(f"❌ HTTP error fetching opportunity keywords: {e.response.status_code}")
            logger.error(f"URL: {e.request.url}")
            logger.error(f"Response body: {e.response.text[:1000]}")
            
            if e.response.status_code == 404:
                logger.error("🔍 API returned 404 - This API endpoint may not exist or has been changed")
                logger.error("💡 Check RapidAPI dashboard: https://rapidapi.com/rhmueed/api/google-keyword-insight1")
            elif e.response.status_code == 403:
                logger.error("🔒 API returned 403 - Access forbidden (check API key or subscription)")
            elif e.response.status_code == 429:
                logger.error("⚠️  API returned 429 - Rate limit exceeded")
            
            raise httpx.HTTPStatusError(
                message=f"Keyword API failed: {e.response.status_code}",
                request=e.request,
                response=e.response
            )
        except Exception as e:
            logger.error(f"❌ Unexpected error fetching opportunity keywords: {e}")
            raise
    
    async def get_serp_data(self, keyword: str, location: str = "us") -> Optional[Dict[str, Any]]:
        """Get SERP data for a keyword to estimate difficulty"""
        # For now, return None - can add dedicated SERP difficulty API later if needed
        return None
    
    async def analyze_keywords(self, seed_keyword: str, location: str = "us", limit: int = 10) -> List[Dict[str, Any]]:
        """Analyze keywords using Google Keyword Insight API with real metrics"""
        
        scope = "global" if location.lower() == "global" else location.upper()
        logger.info(f"🔍 Starting keyword analysis for: '{seed_keyword}' (scope: {scope}, limit: {limit})")
        
        keyword_data = await self.get_keyword_ideas(seed_keyword, location=location)
        
        if not keyword_data:
            logger.warning(f"No keywords found for '{seed_keyword}'")
            return []
        
        logger.info(f"📊 Processing {len(keyword_data)} keywords from API response")
        
        results = []
        for i, item in enumerate(keyword_data[:limit], 1):
            # Google Keyword Insight API (/keysuggest) returns:
            # {"text": "api marketplace", "volume": 9900, "competition_level": "LOW", 
            #  "competition_index": 12, "low_bid": 0.72, "high_bid": 7.94, "trend": 0.73, "intent": "commercial"}
            keyword_text = item.get("text", seed_keyword)
            volume = item.get("volume", 0)
            competition = item.get("competition_level", "UNKNOWN")
            avg_cpc = (item.get("low_bid", 0) + item.get("high_bid", 0)) / 2 if item.get("high_bid") else 0
            
            keyword_result = {
                "keyword": keyword_text,
                "search_volume": volume,
                "competition": competition,
                "competition_index": item.get("competition_index", 0),
                "cpc": round(avg_cpc, 2),
                "low_bid": item.get("low_bid", 0),
                "high_bid": item.get("high_bid", 0),
                "trend": item.get("trend", 0),
                "intent": item.get("intent", "unknown")  # Search intent (informational, commercial, etc.)
            }
            results.append(keyword_result)
            
            intent_label = f" | Intent: {keyword_result['intent']}" if keyword_result['intent'] != "unknown" else ""
            logger.debug(f"  {i}. {keyword_result['keyword']} | Vol: {volume:,} | Comp: {competition} | CPC: ${avg_cpc:.2f}{intent_label}")
        
        logger.info(f"✅ Returning {len(results)} analyzed keywords with real data (including search intent)")
        return results

