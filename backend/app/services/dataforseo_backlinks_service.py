import httpx
import logging
from typing import List, Dict, Any, Optional
from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class DataForSEOBacklinksService:
    """
    Service for DataForSEO Backlinks API
    
    Enterprise-grade backlink data - same provider as Ahrefs!
    
    Features:
    - Summary: Domain metrics, backlink counts, domain rank
    - Backlinks: Individual backlink list with spam scores
    - Referring Domains: Domains linking to you
    - Anchors: Anchor text distribution
    - Broken Backlinks: Find and fix broken links
    
    Cost: ~$0.001-0.005 per request (much cheaper than alternatives!)
    Trial: 14 days active
    
    Docs: https://docs.dataforseo.com/v3/backlinks/
    """
    
    def __init__(self):
        self.base_url = "https://api.dataforseo.com/v3/backlinks"
        self.login = settings.DATAFORSEO_LOGIN
        self.password = settings.DATAFORSEO_PASSWORD
        
    async def get_backlink_summary(self, domain: str) -> Optional[Dict[str, Any]]:
        """
        Get comprehensive backlink summary for a domain
        
        Args:
            domain: Target domain (e.g., "boostramp.com")
            
        Returns:
            {
                "target": "boostramp.com",
                "backlinks": 2083,
                "referring_domains": 127,
                "referring_ips": 109,
                "domain_rank": 301,
                "backlinks_spam_score": 8,
                "broken_backlinks": 20,
                "broken_pages": 4,
                "first_seen": "2023-05-02",
                "crawled_pages": 285
            }
        """
        logger.info(f"🔗 Fetching backlink summary for {domain}")
        
        if not self.login or not self.password:
            logger.error("DataForSEO credentials not configured")
            return None
        
        try:
            # Clean domain
            domain = domain.replace('https://', '').replace('http://', '').replace('www.', '').split('/')[0]
            
            endpoint = f"{self.base_url}/summary/live"
            
            payload = [{
                "target": domain
            }]
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    endpoint,
                    json=payload,
                    auth=(self.login, self.password)
                )
                
                if response.status_code != 200:
                    logger.error(f"API error: {response.status_code} - {response.text}")
                    return None
                
                data = response.json()
                
                if data.get("status_code") != 20000:
                    logger.error(f"DataForSEO error: {data.get('status_message')}")
                    return None
                
                tasks = data.get("tasks", [])
                if not tasks or not tasks[0].get("result"):
                    logger.warning(f"No backlink data found for {domain}")
                    return None
                
                result = tasks[0]["result"][0]
                
                logger.info(f"✅ Summary: {result.get('backlinks')} backlinks from {result.get('referring_domains')} domains")
                
                return {
                    "target": result.get("target"),
                    "backlinks": result.get("backlinks", 0),
                    "referring_domains": result.get("referring_domains", 0),
                    "referring_ips": result.get("referring_ips", 0),
                    "domain_rank": result.get("rank", 0),
                    "backlinks_spam_score": result.get("backlinks_spam_score", 0),
                    "broken_backlinks": result.get("broken_backlinks", 0),
                    "broken_pages": result.get("broken_pages", 0),
                    "first_seen": result.get("first_seen"),
                    "crawled_pages": result.get("crawled_pages", 0),
                    "internal_links_count": result.get("internal_links_count", 0),
                    "external_links_count": result.get("external_links_count", 0),
                    "referring_pages": result.get("referring_pages", 0)
                }
                
        except Exception as e:
            logger.error(f"Error fetching backlink summary: {e}")
            return None
    
    async def get_backlinks(
        self, 
        domain: str, 
        limit: int = 100,
        include_subdomains: bool = True
    ) -> Dict[str, Any]:
        """
        Get individual backlinks for a domain
        
        Args:
            domain: Target domain
            limit: Max number of backlinks to return (default 100)
            include_subdomains: Include backlinks to subdomains (default True)
            
        Returns:
            {
                "target": "boostramp.com",
                "total_count": 1768,
                "backlinks": [
                    {
                        "url_from": "https://barvanet.com/",
                        "url_to": "https://boostramp.com/",
                        "anchor": "Boostramp SEO",
                        "rank": 351,
                        "spam_score": 55,
                        "first_seen": "2023-06-15",
                        "is_new": false,
                        "is_lost": false,
                        "dofollow": true
                    }
                ]
            }
        """
        logger.info(f"🔗 Fetching backlinks for {domain} (limit: {limit})")
        
        if not self.login or not self.password:
            logger.error("DataForSEO credentials not configured")
            return {"backlinks": [], "total_count": 0}
        
        try:
            domain = domain.replace('https://', '').replace('http://', '').replace('www.', '').split('/')[0]
            
            endpoint = f"{self.base_url}/backlinks/live"
            
            payload = [{
                "target": domain,
                "limit": limit,
                "include_subdomains": include_subdomains,
                "order_by": ["rank,desc"]  # Order by rank (highest first)
            }]
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    endpoint,
                    json=payload,
                    auth=(self.login, self.password)
                )
                
                if response.status_code != 200:
                    logger.error(f"API error: {response.status_code}")
                    return {"backlinks": [], "total_count": 0}
                
                data = response.json()
                
                if data.get("status_code") != 20000:
                    logger.error(f"DataForSEO error: {data.get('status_message')}")
                    return {"backlinks": [], "total_count": 0}
                
                tasks = data.get("tasks", [])
                if not tasks or not tasks[0].get("result"):
                    return {"backlinks": [], "total_count": 0}
                
                result = tasks[0]["result"][0]
                items = result.get("items", [])
                
                # Format backlinks
                backlinks = []
                for item in items:
                    backlinks.append({
                        "url_from": item.get("url_from"),
                        "url_to": item.get("url_to"),
                        "anchor": item.get("anchor", ""),
                        "rank": item.get("rank", 0),
                        "page_rank": item.get("page_from_rank", 0),
                        "domain_rank": item.get("domain_from_rank", 0),
                        "spam_score": item.get("backlink_spam_score", 0),
                        "first_seen": item.get("first_seen"),
                        "is_new": item.get("is_new", False),
                        "is_lost": item.get("is_lost", False),
                        "dofollow": item.get("dofollow", True),
                        "domain_from": item.get("domain_from"),
                        "text_pre": item.get("text_pre", ""),
                        "text_post": item.get("text_post", "")
                    })
                
                logger.info(f"✅ Found {len(backlinks)} backlinks (total: {result.get('total_count')})")
                
                return {
                    "target": result.get("target"),
                    "total_count": result.get("total_count", 0),
                    "items_count": result.get("items_count", 0),
                    "backlinks": backlinks
                }
                
        except Exception as e:
            logger.error(f"Error fetching backlinks: {e}")
            return {"backlinks": [], "total_count": 0}
    
    async def get_referring_domains(
        self, 
        domain: str, 
        limit: int = 50
    ) -> Dict[str, Any]:
        """
        Get domains linking to your site
        
        Args:
            domain: Target domain
            limit: Max number of referring domains (default 50)
            
        Returns:
            {
                "total_count": 124,
                "referring_domains": [
                    {
                        "domain": "fesh.store",
                        "rank": 253,
                        "backlinks": 216,
                        "spam_score": 4,
                        "first_seen": "2023-06-15"
                    }
                ]
            }
        """
        logger.info(f"🔗 Fetching referring domains for {domain}")
        
        if not self.login or not self.password:
            logger.error("DataForSEO credentials not configured")
            return {"referring_domains": [], "total_count": 0}
        
        try:
            domain = domain.replace('https://', '').replace('http://', '').replace('www.', '').split('/')[0]
            
            endpoint = f"{self.base_url}/referring_domains/live"
            
            payload = [{
                "target": domain,
                "limit": limit,
                "order_by": ["rank,desc"]
            }]
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    endpoint,
                    json=payload,
                    auth=(self.login, self.password)
                )
                
                if response.status_code != 200:
                    logger.error(f"API error: {response.status_code}")
                    return {"referring_domains": [], "total_count": 0}
                
                data = response.json()
                
                if data.get("status_code") != 20000:
                    logger.error(f"DataForSEO error: {data.get('status_message')}")
                    return {"referring_domains": [], "total_count": 0}
                
                tasks = data.get("tasks", [])
                if not tasks or not tasks[0].get("result"):
                    return {"referring_domains": [], "total_count": 0}
                
                result = tasks[0]["result"][0]
                items = result.get("items", [])
                
                # Format domains
                referring_domains = []
                for item in items:
                    referring_domains.append({
                        "domain": item.get("domain"),
                        "rank": item.get("rank", 0),
                        "backlinks": item.get("backlinks", 0),
                        "spam_score": item.get("backlinks_spam_score", 0),
                        "first_seen": item.get("first_seen"),
                        "referring_pages": item.get("referring_pages", 0)
                    })
                
                logger.info(f"✅ Found {len(referring_domains)} referring domains")
                
                return {
                    "total_count": result.get("total_count", 0),
                    "referring_domains": referring_domains
                }
                
        except Exception as e:
            logger.error(f"Error fetching referring domains: {e}")
            return {"referring_domains": [], "total_count": 0}
    
    async def get_anchors(
        self, 
        domain: str, 
        limit: int = 50
    ) -> Dict[str, Any]:
        """
        Get anchor text distribution for backlinks
        
        Args:
            domain: Target domain
            limit: Max number of anchors (default 50)
            
        Returns:
            {
                "total_count": 112,
                "anchors": [
                    {
                        "anchor": "SEO API",
                        "backlinks": 353,
                        "referring_domains": 3,
                        "rank": 264
                    }
                ]
            }
        """
        logger.info(f"🔗 Fetching anchor texts for {domain}")
        
        if not self.login or not self.password:
            logger.error("DataForSEO credentials not configured")
            return {"anchors": [], "total_count": 0}
        
        try:
            domain = domain.replace('https://', '').replace('http://', '').replace('www.', '').split('/')[0]
            
            endpoint = f"{self.base_url}/anchors/live"
            
            payload = [{
                "target": domain,
                "limit": limit,
                "order_by": ["backlinks,desc"]  # Most used anchors first
            }]
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    endpoint,
                    json=payload,
                    auth=(self.login, self.password)
                )
                
                if response.status_code != 200:
                    logger.error(f"API error: {response.status_code}")
                    return {"anchors": [], "total_count": 0}
                
                data = response.json()
                
                if data.get("status_code") != 20000:
                    logger.error(f"DataForSEO error: {data.get('status_message')}")
                    return {"anchors": [], "total_count": 0}
                
                tasks = data.get("tasks", [])
                if not tasks or not tasks[0].get("result"):
                    return {"anchors": [], "total_count": 0}
                
                result = tasks[0]["result"][0]
                items = result.get("items", [])
                
                # Format anchors
                anchors = []
                for item in items:
                    anchors.append({
                        "anchor": item.get("anchor"),
                        "backlinks": item.get("backlinks", 0),
                        "referring_domains": item.get("referring_domains", 0),
                        "rank": item.get("rank", 0),
                        "first_seen": item.get("first_seen")
                    })
                
                logger.info(f"✅ Found {len(anchors)} unique anchors")
                
                return {
                    "total_count": result.get("total_count", 0),
                    "anchors": anchors
                }
                
        except Exception as e:
            logger.error(f"Error fetching anchors: {e}")
            return {"anchors": [], "total_count": 0}
    
    async def get_full_analysis(self, domain: str) -> Dict[str, Any]:
        """
        Get comprehensive backlink analysis (all data in one call)
        
        Combines: Summary + Sample Backlinks + Referring Domains + Anchors
        
        Perfect for dashboard display!
        """
        logger.info(f"🔗 Getting full backlink analysis for {domain}")
        
        # Fetch all data in parallel
        import asyncio
        
        summary, backlinks, referring_domains, anchors = await asyncio.gather(
            self.get_backlink_summary(domain),
            self.get_backlinks(domain, limit=50),
            self.get_referring_domains(domain, limit=20),
            self.get_anchors(domain, limit=20),
            return_exceptions=True
        )
        
        # Handle errors
        if isinstance(summary, Exception):
            logger.error(f"Summary error: {summary}")
            summary = None
        if isinstance(backlinks, Exception):
            logger.error(f"Backlinks error: {backlinks}")
            backlinks = {"backlinks": [], "total_count": 0}
        if isinstance(referring_domains, Exception):
            logger.error(f"Referring domains error: {referring_domains}")
            referring_domains = {"referring_domains": [], "total_count": 0}
        if isinstance(anchors, Exception):
            logger.error(f"Anchors error: {anchors}")
            anchors = {"anchors": [], "total_count": 0}
        
        return {
            "domain": domain,
            "summary": summary or {},
            "backlinks": backlinks.get("backlinks", []),
            "total_backlinks": backlinks.get("total_count", 0),
            "referring_domains": referring_domains.get("referring_domains", []),
            "total_referring_domains": referring_domains.get("total_count", 0),
            "anchors": anchors.get("anchors", []),
            "total_anchors": anchors.get("total_count", 0)
        }

