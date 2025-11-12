import httpx
from typing import Dict, Any, List
import logging
from urllib.parse import urlparse, urljoin
from ..config import get_settings
import xml.etree.ElementTree as ET
import asyncio
from .rate_limited_queue import rapidapi_queue

logger = logging.getLogger(__name__)
settings = get_settings()


class RapidAPISEOService:
    def __init__(self):
        self.base_url = "https://website-analyze-and-seo-audit-pro.p.rapidapi.com"
        self.api_key = settings.RAPIDAPI_KEY
        self.headers = {
            "x-rapidapi-host": "website-analyze-and-seo-audit-pro.p.rapidapi.com",
            "x-rapidapi-key": self.api_key
        }
        self.queue = rapidapi_queue  # Global rate-limited queue
    
    def _get_api_key(self):
        """Get API key from settings"""
        if not self.api_key:
            logger.error("RAPIDAPI_KEY not configured in settings")
        return self.api_key
    
    async def _make_api_request(self, client: httpx.AsyncClient, url: str, params: Dict[str, Any]) -> httpx.Response:
        """
        Make API request through rate-limited queue
        
        Args:
            client: httpx AsyncClient
            url: Full URL to request
            params: Query parameters
            
        Returns:
            httpx.Response
        """
        async def _do_request():
            response = await client.get(url, params=params, headers=self.headers)
            response.raise_for_status()
            return response
        
        # Execute through rate-limited queue
        return await self.queue.execute(_do_request)
    
    async def analyze_technical_seo(self, url: str) -> Dict[str, Any]:
        """
        Perform technical SEO audit using RapidAPI
        
        Args:
            url: Website URL to audit
            
        Returns:
            Dict with issues and summary
        """
        logger.info(f"🔍 Starting RapidAPI technical SEO audit for: {url}")
        
        api_key = self._get_api_key()
        if not api_key:
            return {"error": "RapidAPI key not configured", "issues": []}
        
        try:
            # Clean URL - RapidAPI expects domain without protocol
            parsed = urlparse(url)
            domain = parsed.netloc if parsed.netloc else parsed.path
            
            # Remove any remaining protocol
            domain = domain.replace('http://', '').replace('https://', '')
            
            logger.info(f"📤 Calling RapidAPI for: {domain}")
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                # Call onpagepro endpoint for full audit (via rate-limited queue)
                response = await self._make_api_request(
                    client,
                    f"{self.base_url}/onpagepro.php",
                    {"website": domain}
                )
                data = response.json()
                
                logger.info(f"✅ RapidAPI audit completed successfully")
                
                # Parse the response into our standard format
                return self._parse_audit_results(data, url)
                
        except Exception as e:
            logger.error(f"Error performing RapidAPI technical SEO audit: {e}", exc_info=True)
            return {"error": str(e), "issues": []}
    
    def _parse_audit_results(self, data: Dict[str, Any], base_url: str) -> Dict[str, Any]:
        """Parse RapidAPI results into structured issue list"""
        
        issues = []
        summary = {
            "total_issues": 0,
            "high": 0,
            "medium": 0,
            "low": 0,
            "pages_crawled": 1
        }
        
        # Title issues
        if data.get('webtitle'):
            title_data = data['webtitle']
            title_length = title_data.get('length', 0)
            suggestion = title_data.get('suggestion', '')
            
            if title_length > 60:
                issues.append({
                    "type": "Title Too Long",
                    "severity": "medium",
                    "page": "/",
                    "element": f"<title>{title_data.get('title', '')[:50]}...</title>",
                    "description": f"Title is {title_length} characters (recommended: 50-60)",
                    "recommendation": "Shorten title to 50-60 characters"
                })
                summary["medium"] += 1
            elif title_length < 30:
                issues.append({
                    "type": "Title Too Short",
                    "severity": "medium",
                    "page": "/",
                    "element": f"<title>{title_data.get('title', '')}</title>",
                    "description": f"Title is only {title_length} characters (recommended: 50-60)",
                    "recommendation": "Expand title to 50-60 characters"
                })
                summary["medium"] += 1
        
        # Meta description issues
        if data.get('metadescription'):
            desc_data = data['metadescription']
            desc_length = desc_data.get('length', 0)
            suggestion = desc_data.get('suggestion', '')
            
            if not desc_data.get('description'):
                issues.append({
                    "type": "Missing Meta Description",
                    "severity": "high",
                    "page": "/",
                    "element": "<meta name='description'>",
                    "description": "Page lacks meta description for search results",
                    "recommendation": "Add unique 150-160 character meta description"
                })
                summary["high"] += 1
            elif desc_length < 120:
                issues.append({
                    "type": "Meta Description Too Short",
                    "severity": "medium",
                    "page": "/",
                    "element": f"<meta name='description' content='{desc_data.get('description', '')[:50]}...'>",
                    "description": f"Meta description is {desc_length} characters (recommended: 120-160)",
                    "recommendation": suggestion if suggestion else "Expand to 120-160 characters"
                })
                summary["medium"] += 1
            elif desc_length > 160:
                issues.append({
                    "type": "Meta Description Too Long",
                    "severity": "low",
                    "page": "/",
                    "element": f"<meta name='description'>",
                    "description": f"Meta description is {desc_length} characters (recommended: 120-160)",
                    "recommendation": "Shorten to 120-160 characters"
                })
                summary["low"] += 1
        
        # Heading issues
        if data.get('headings'):
            headings = data['headings']
            h1_count = headings.get('h1', {}).get('count', 0)
            h2_count = headings.get('h2', {}).get('count', 0)
            suggestions = headings.get('suggestion', [])
            
            if h1_count == 0:
                issues.append({
                    "type": "Missing H1",
                    "severity": "high",
                    "page": "/",
                    "element": "<h1>",
                    "description": "Page has no H1 heading tag",
                    "recommendation": "Add descriptive H1 tag with primary keyword"
                })
                summary["high"] += 1
            elif h1_count > 1:
                issues.append({
                    "type": "Multiple H1 Tags",
                    "severity": "medium",
                    "page": "/",
                    "element": f"{h1_count} <h1> tags found",
                    "description": "Page has multiple H1 tags (confuses search engines)",
                    "recommendation": "Use only one H1 tag per page"
                })
                summary["medium"] += 1
            
            if h2_count == 0:
                issues.append({
                    "type": "Missing H2 Headings",
                    "severity": "medium",
                    "page": "/",
                    "element": "<h2>",
                    "description": "No H2 headings found for content structure",
                    "recommendation": "Add sub-headings (H2) to organize content"
                })
                summary["medium"] += 1
        
        # Image optimization
        if data.get('images'):
            image_count = data['images'].get('count', 0)
            suggestion = data['images'].get('suggestion', '')
            
            if image_count > 30:
                issues.append({
                    "type": "Too Many Images",
                    "severity": "low",
                    "page": "/",
                    "element": f"{image_count} images",
                    "description": f"Page has {image_count} images (may affect load speed)",
                    "recommendation": suggestion if suggestion else "Optimize and compress images"
                })
                summary["low"] += 1
        
        # Link issues
        if data.get('links'):
            link_suggestion = data['links'].get('suggestion', '')
            if link_suggestion and 'broken' in link_suggestion.lower():
                issues.append({
                    "type": "Broken Links",
                    "severity": "medium",
                    "page": "/",
                    "element": "<a> links",
                    "description": "Page contains broken or empty links",
                    "recommendation": link_suggestion
                })
                summary["medium"] += 1
        
        # Sitemap/robots check
        if data.get('sitemap_robots'):
            files = data['sitemap_robots']
            if 'sitemap.xml' not in files:
                issues.append({
                    "type": "Missing Sitemap",
                    "severity": "high",
                    "page": "/sitemap.xml",
                    "element": "sitemap.xml",
                    "description": "No XML sitemap found",
                    "recommendation": "Create and submit sitemap.xml to search engines"
                })
                summary["high"] += 1
            
            if 'robots.txt' not in files:
                issues.append({
                    "type": "Missing Robots.txt",
                    "severity": "medium",
                    "page": "/robots.txt",
                    "element": "robots.txt",
                    "description": "No robots.txt file found",
                    "recommendation": "Create robots.txt to control crawler access"
                })
                summary["medium"] += 1
        
        summary["total_issues"] = len(issues)
        
        logger.info(f"✅ Found {summary['total_issues']} issues: {summary['high']} high, {summary['medium']} medium, {summary['low']} low")
        
        return {
            "issues": issues,
            "summary": summary
        }
    
    async def check_ai_bot_access(self, url: str) -> Dict[str, Any]:
        """
        Check which AI bots can access the website
        
        Args:
            url: Website URL to check
            
        Returns:
            Dict with AI bot access status
        """
        logger.info(f"🤖 Checking AI bot access for: {url}")
        
        api_key = self._get_api_key()
        if not api_key:
            return {"error": "RapidAPI key not configured"}
        
        try:
            # Clean URL
            parsed = urlparse(url)
            domain = parsed.netloc if parsed.netloc else parsed.path
            domain = domain.replace('http://', '').replace('https://', '')
            
            async with httpx.AsyncClient(timeout=15.0) as client:
                # Make request via rate-limited queue
                response = await self._make_api_request(
                    client,
                    f"{self.base_url}/aiseo.php",
                    {"url": domain}
                )
                data = response.json()
                
                logger.info(f"✅ AI bot access check completed")
                return self._parse_bot_access_results(data, url)
                
        except Exception as e:
            logger.error(f"Error checking AI bot access: {e}", exc_info=True)
            return {"error": str(e)}
    
    def _parse_bot_access_results(self, data: Dict[str, Any], url: str) -> Dict[str, Any]:
        """Parse RapidAPI bot access results into structured table format"""
        bots = []
        
        # Extract bot access information from the API response
        # The API returns data about various AI bots and their access status
        ai_bots = data.get('ai_bots', {})
        robots_txt = data.get('robots_txt', {})
        
        # Common AI bots to check
        bot_list = [
            {'name': 'GPTBot (ChatGPT)', 'user_agent': 'GPTBot', 'purpose': 'OpenAI ChatGPT web crawler'},
            {'name': 'Claude-Web (Anthropic)', 'user_agent': 'Claude-Web', 'purpose': 'Anthropic Claude web crawler'},
            {'name': 'PerplexityBot', 'user_agent': 'PerplexityBot', 'purpose': 'Perplexity AI search crawler'},
            {'name': 'Google-Extended', 'user_agent': 'Google-Extended', 'purpose': 'Google Bard/Gemini crawler'},
            {'name': 'Amazonbot', 'user_agent': 'Amazonbot', 'purpose': 'Amazon Alexa crawler'},
            {'name': 'Applebot-Extended', 'user_agent': 'Applebot-Extended', 'purpose': 'Apple AI/Siri crawler'},
            {'name': 'anthropic-ai', 'user_agent': 'anthropic-ai', 'purpose': 'Anthropic AI training'},
            {'name': 'Bytespider', 'user_agent': 'Bytespider', 'purpose': 'TikTok/ByteDance crawler'},
            {'name': 'CCBot', 'user_agent': 'CCBot', 'purpose': 'Common Crawl bot'},
            {'name': 'Diffbot', 'user_agent': 'Diffbot', 'purpose': 'Diffbot AI crawler'},
        ]
        
        # Check each bot against robots.txt rules
        for bot_info in bot_list:
            bot_name = bot_info['name']
            user_agent = bot_info['user_agent']
            
            # Check if bot is mentioned in the response data
            is_blocked = False
            status = "Allowed"
            
            # Check robots_txt data if available
            if robots_txt:
                disallowed_agents = robots_txt.get('disallowed_user_agents', [])
                if user_agent in disallowed_agents or user_agent.lower() in [a.lower() for a in disallowed_agents]:
                    is_blocked = True
                    status = "Blocked"
            
            # Check ai_bots specific data if available
            if ai_bots and user_agent in ai_bots:
                bot_status = ai_bots[user_agent].get('status', 'allowed')
                if bot_status.lower() in ['blocked', 'disallowed']:
                    is_blocked = True
                    status = "Blocked"
            
            bots.append({
                "bot_name": bot_name,
                "status": status,
                "user_agent": user_agent,
                "purpose": bot_info['purpose']
            })
        
        summary = {
            "total_bots": len(bots),
            "blocked": sum(1 for b in bots if b['status'] == 'Blocked'),
            "allowed": sum(1 for b in bots if b['status'] == 'Allowed'),
            "url": url
        }
        
        return {
            "bots": bots,
            "summary": summary,
            "url": url
        }
    
    async def analyze_performance(self, url: str) -> Dict[str, Any]:
        """
        Analyze website performance and Core Web Vitals
        
        Args:
            url: Website URL to analyze
            
        Returns:
            Dict with performance metrics and audit results
        """
        logger.info(f"⚡ Starting performance analysis for: {url}")
        
        api_key = self._get_api_key()
        if not api_key:
            return {"error": "RapidAPI key not configured"}
        
        try:
            # Clean URL
            parsed = urlparse(url)
            domain = parsed.netloc if parsed.netloc else parsed.path
            domain = domain.replace('http://', '').replace('https://', '')
            
            # Increased timeout for performance analysis (sites with many images take longer)
            async with httpx.AsyncClient(timeout=60.0) as client:
                # Make request via rate-limited queue
                response = await self._make_api_request(
                    client,
                    f"{self.base_url}/speed.php",
                    {"website": domain}
                )
                data = response.json()
                
                logger.info(f"✅ Performance analysis completed")
                return self._parse_performance_results(data, url)
                
        except httpx.ReadTimeout:
            logger.warning(f"⏱️  Performance analysis timed out for {url} (this is common for sites with many images/assets)")
            return {
                "error": "Performance analysis timed out - site may have too many assets to analyze quickly",
                "timeout": True
            }
        except Exception as e:
            logger.error(f"Error analyzing performance: {e}", exc_info=True)
            return {"error": str(e)}
    
    def _parse_performance_results(self, data: Dict[str, Any], url: str) -> Dict[str, Any]:
        """Parse RapidAPI performance results into structured table format"""
        metrics = []
        
        # Extract overall score from 'speed' object
        speed_data = data.get('speed', {})
        performance_score = speed_data.get('score', 0)
        
        # Add overall performance score
        metrics.append({
            "metric_name": "Performance Score",
            "value": f"{performance_score}/100",
            "score": performance_score,
            "rating": self._get_rating(performance_score),
            "description": "Overall performance score"
        })
        
        # Parse audit items
        audit_items = data.get('audit', [])
        
        # Map of audit titles to our metric names and descriptions
        metric_map = {
            "First Contentful Paint": {
                "name": "First Contentful Paint (FCP)",
                "description": "Time until first text or image is painted"
            },
            "Largest Contentful Paint": {
                "name": "Largest Contentful Paint (LCP)",
                "description": "Time until largest text or image is painted"
            },
            "Cumulative Layout Shift": {
                "name": "Cumulative Layout Shift (CLS)",
                "description": "Visual stability - measures unexpected layout shifts"
            },
            "Total Blocking Time": {
                "name": "Total Blocking Time (TBT)",
                "description": "Time the main thread is blocked from responding"
            },
            "Speed Index": {
                "name": "Speed Index",
                "description": "How quickly content is visually displayed"
            },
            "Time to Interactive": {
                "name": "Time to Interactive (TTI)",
                "description": "Time until page is fully interactive"
            },
            "Max Potential First Input Delay": {
                "name": "First Input Delay (FID)",
                "description": "Maximum time to respond to user input"
            }
        }
        
        # Extract Core Web Vitals from audit array
        for item in audit_items:
            title = item.get('title', '')
            if title in metric_map:
                metric_info = metric_map[title]
                score = item.get('score', 0)
                display_value = item.get('displayValue')
                
                metrics.append({
                    "metric_name": metric_info["name"],
                    "value": display_value if display_value else 'N/A',
                    "score": score,
                    "rating": self._get_rating(score),
                    "description": metric_info["description"]
                })
        
        logger.info(f"📊 Parsed {len(metrics)} performance metrics (overall + {len(metrics)-1} Core Web Vitals)")
        
        summary = {
            "overall_score": performance_score,
            "total_metrics": len(metrics),
            "url": url
        }
        
        return {
            "metrics": metrics,
            "summary": summary,
            "url": url
        }
    
    def _get_rating(self, score: float) -> str:
        """Convert score to rating"""
        if score >= 90:
            return "Good"
        elif score >= 50:
            return "Needs Improvement"
        else:
            return "Poor"
    
    async def comprehensive_technical_audit(self, url: str) -> Dict[str, Any]:
        """
        Run comprehensive technical audit combining:
        1. Technical SEO (meta tags, headings, links)
        2. Performance (Core Web Vitals)
        3. AI Bot Access
        
        Returns unified results for display in data panel
        """
        logger.info(f"🔍 Starting comprehensive technical audit for: {url}")
        
        # Run all three audits in parallel
        # The rate-limited queue handles API rate limiting automatically
        seo_task = self.analyze_technical_seo(url)
        performance_task = self.analyze_performance(url)
        bot_task = self.check_ai_bot_access(url)
        
        seo_results, performance_results, bot_results = await asyncio.gather(
            seo_task, performance_task, bot_task
        )
        
        # Combine all results into unified structure
        all_items = []
        
        # Add SEO issues
        if not seo_results.get("error") and seo_results.get("issues"):
            for issue in seo_results["issues"]:
                all_items.append({
                    "category": "Technical SEO",
                    "item_name": issue["type"],
                    "status": issue["severity"].title(),
                    "value": issue.get("element", ""),
                    "location": issue.get("page", "/"),
                    "recommendation": issue.get("recommendation", "")
                })
        
        # Add Performance metrics (handle errors gracefully)
        if performance_results.get("error"):
            # Add a notice about the error but CONTINUE with SEO results
            if performance_results.get("timeout"):
                logger.warning(f"⏱️ Performance timed out - continuing with SEO results")
                all_items.append({
                    "category": "Performance",
                    "item_name": "Performance Analysis",
                    "status": "Timeout",
                    "value": "Timed out (60s)",
                    "location": "Overall",
                    "recommendation": "Site has many assets. Performance check timed out after 60s. SEO audit completed successfully."
                })
            else:
                logger.warning(f"⚠️ Performance failed: {performance_results.get('error')} - continuing with SEO")
                all_items.append({
                    "category": "Performance",
                    "item_name": "Performance Analysis",
                    "status": "Error",
                    "value": "Analysis failed",
                    "location": "Overall",
                    "recommendation": f"Performance analysis error: {performance_results.get('error')}"
                })
        elif performance_results.get("metrics"):
            for metric in performance_results["metrics"]:
                all_items.append({
                    "category": "Performance",
                    "item_name": metric["metric_name"],
                    "status": metric["rating"],
                    "value": metric["value"],
                    "location": "Overall",
                    "recommendation": metric.get("description", "")
                })
        
        # Add AI Bot access
        if not bot_results.get("error") and bot_results.get("bots"):
            for bot in bot_results["bots"]:
                all_items.append({
                    "category": "AI Bot Access",
                    "item_name": bot["bot_name"],
                    "status": bot["status"],
                    "value": bot["user_agent"],
                    "location": "robots.txt",
                    "recommendation": bot.get("purpose", "")
                })
        
        # Create summary
        summary = {
            "total_items": len(all_items),
            "seo_issues": seo_results.get("summary", {}).get("total_issues", 0),
            "performance_score": performance_results.get("summary", {}).get("overall_score", 0),
            "bots_checked": bot_results.get("summary", {}).get("total_bots", 0),
            "bots_allowed": bot_results.get("summary", {}).get("allowed", 0),
            "url": url
        }
        
        # Log comprehensive status
        seo_count = len([i for i in all_items if i["category"] == "Technical SEO"])
        perf_count = len([i for i in all_items if i["category"] == "Performance"])
        bot_count = len([i for i in all_items if i["category"] == "AI Bot Access"])
        
        logger.info(f"✅ Audit completed: {seo_count} SEO issues, {perf_count} performance items, {bot_count} bot checks")
        
        # Ensure we have results even if performance failed
        if len(all_items) == 0:
            logger.error("⚠️ All audit components failed - no data collected")
        
        return {
            "audit_items": all_items,
            "summary": summary,
            "url": url,
            "raw_data": {
                "seo": seo_results,
                "performance": performance_results,
                "bots": bot_results
            }
        }
    
    async def fetch_sitemap_urls(self, url: str, limit: int = 15) -> List[str]:
        """
        Fetch and parse sitemap.xml to get list of URLs
        
        Args:
            url: Base website URL
            limit: Maximum number of URLs to return
            
        Returns:
            List of URLs from sitemap
        """
        parsed = urlparse(url)
        base_url = f"{parsed.scheme}://{parsed.netloc}" if parsed.scheme else f"https://{parsed.netloc if parsed.netloc else parsed.path}"
        sitemap_url = urljoin(base_url, '/sitemap.xml')
        
        logger.info(f"🗺️  Fetching sitemap from: {sitemap_url}")
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(sitemap_url)
                
                if response.status_code != 200:
                    logger.warning(f"Sitemap not found at {sitemap_url}, using base URL only")
                    return [url]
                
                # Parse XML
                root = ET.fromstring(response.content)
                
                # Handle different sitemap formats
                # Standard sitemap namespace
                ns = {'ns': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
                
                # Try to find URLs with namespace
                urls = [loc.text for loc in root.findall('.//ns:loc', ns) if loc.text]
                
                # If no URLs found, try without namespace
                if not urls:
                    urls = [loc.text for loc in root.findall('.//loc') if loc.text]
                
                if not urls:
                    logger.warning("No URLs found in sitemap, using base URL only")
                    return [url]
                
                # Limit the number of URLs
                urls = urls[:limit]
                logger.info(f"✅ Found {len(urls)} URLs in sitemap (limited to {limit})")
                return urls
                
        except Exception as e:
            logger.error(f"Error fetching sitemap: {e}")
            return [url]  # Fallback to single URL
    
    async def comprehensive_site_audit(self, url: str, mode: str = "single") -> Dict[str, Any]:
        """
        Run comprehensive audit - single page or full site based on mode
        
        Args:
            url: Website URL
            mode: "single" for single page, "full" for sitemap-based full site audit
                
        Returns:
            Audit results with aggregated stats for full mode
        """
        if mode == "single":
            # Current behavior - audit single page
            return await self.comprehensive_technical_audit(url)
        
        # Full site audit - fetch sitemap and audit multiple pages
        logger.info(f"🌐 Starting FULL SITE audit for: {url}")
        
        # Get URLs from sitemap
        urls = await self.fetch_sitemap_urls(url, limit=15)
        logger.info(f"📋 Will audit {len(urls)} pages")
        
        # Run audits in parallel with controlled concurrency
        # The rate-limited queue handles API rate limiting, but we still
        # limit concurrency to avoid too many simultaneous operations
        semaphore = asyncio.Semaphore(5)  # Max 5 concurrent page audits
        
        async def audit_with_semaphore(page_url: str):
            async with semaphore:
                try:
                    result = await self.comprehensive_technical_audit(page_url)
                    result['url'] = page_url  # Ensure URL is included
                    return result
                except Exception as e:
                    logger.error(f"Error auditing {page_url}: {e}")
                    return None
        
        # Run all audits in parallel
        audit_results = await asyncio.gather(*[audit_with_semaphore(u) for u in urls])
        
        # Filter out failed audits
        audit_results = [r for r in audit_results if r is not None]
        
        if not audit_results:
            logger.error("All page audits failed")
            return {"error": "Failed to audit any pages", "pages": []}
        
        logger.info(f"✅ Completed audits for {len(audit_results)} pages")
        
        # Aggregate results
        return self._aggregate_site_audit(audit_results, url)
    
    def _aggregate_site_audit(self, page_audits: List[Dict[str, Any]], base_url: str) -> Dict[str, Any]:
        """
        Aggregate multiple page audits into site-wide summary
        
        Args:
            page_audits: List of individual page audit results
            base_url: Base website URL
            
        Returns:
            Aggregated audit results
        """
        total_pages = len(page_audits)
        
        # Aggregate performance scores
        perf_scores = []
        all_seo_issues = []
        all_bot_data = []
        
        # Aggregate Core Web Vitals
        fcp_values = []
        lcp_values = []
        cls_values = []
        tbt_values = []
        tti_values = []
        
        # Per-page summary for detailed view
        page_summaries = []
        
        for audit in page_audits:
            raw_data = audit.get('raw_data', {})
            page_url = audit.get('url', 'Unknown')
            
            # Performance
            perf_data = raw_data.get('performance', {})
            perf_metrics = perf_data.get('metrics', [])
            
            # Extract overall performance score
            perf_score_metric = next((m for m in perf_metrics if 'Performance Score' in m.get('metric_name', '')), None)
            perf_score = perf_score_metric.get('score', 0) if perf_score_metric else 0
            perf_scores.append(perf_score)
            
            # Extract Core Web Vitals
            for metric in perf_metrics:
                name = metric.get('metric_name', '')
                value = metric.get('value')
                score = metric.get('score', 0)
                
                if 'FCP' in name and value:
                    fcp_values.append({'value': value, 'score': score})
                elif 'LCP' in name and value:
                    lcp_values.append({'value': value, 'score': score})
                elif 'CLS' in name and value:
                    cls_values.append({'value': value, 'score': score})
                elif 'TBT' in name and value:
                    tbt_values.append({'value': value, 'score': score})
                elif 'TTI' in name and value:
                    tti_values.append({'value': value, 'score': score})
            
            # SEO issues
            seo_data = raw_data.get('seo', {})
            seo_issues = seo_data.get('issues', [])
            
            # Add page context to each issue
            for issue in seo_issues:
                issue['page_url'] = page_url
                all_seo_issues.append(issue)
            
            # Bots (just use first page's data since it's site-wide)
            if not all_bot_data:
                bot_data = raw_data.get('bots', {})
                all_bot_data = bot_data.get('bots', [])
            
            # Create page summary
            page_summaries.append({
                'url': page_url,
                'performance_score': perf_score,
                'seo_issues_count': len(seo_issues),
                'seo_issues_high': sum(1 for i in seo_issues if i.get('severity') == 'high'),
                'seo_issues_medium': sum(1 for i in seo_issues if i.get('severity') == 'medium'),
                'seo_issues_low': sum(1 for i in seo_issues if i.get('severity') == 'low'),
            })
        
        # Calculate aggregates (exclude failed audits with score 0)
        valid_perf_scores = [s for s in perf_scores if s > 0]
        avg_performance = sum(valid_perf_scores) / len(valid_perf_scores) if valid_perf_scores else 0
        total_seo_issues = len(all_seo_issues)
        
        # Calculate average Core Web Vitals
        avg_fcp_score = sum(m['score'] for m in fcp_values) / len(fcp_values) if fcp_values else 0
        avg_lcp_score = sum(m['score'] for m in lcp_values) / len(lcp_values) if lcp_values else 0
        avg_cls_score = sum(m['score'] for m in cls_values) / len(cls_values) if cls_values else 0
        avg_tbt_score = sum(m['score'] for m in tbt_values) / len(tbt_values) if tbt_values else 0
        avg_tti_score = sum(m['score'] for m in tti_values) / len(tti_values) if tti_values else 0
        
        # Use the first value as representative (or could show range)
        avg_fcp_value = fcp_values[0]['value'] if fcp_values else 'N/A'
        avg_lcp_value = lcp_values[0]['value'] if lcp_values else 'N/A'
        avg_cls_value = cls_values[0]['value'] if cls_values else 'N/A'
        avg_tbt_value = tbt_values[0]['value'] if tbt_values else 'N/A'
        avg_tti_value = tti_values[0]['value'] if tti_values else 'N/A'
        
        # Find most common issues
        issue_types = {}
        for issue in all_seo_issues:
            issue_type = issue.get('type', 'Unknown')
            if issue_type not in issue_types:
                issue_types[issue_type] = []
            issue_types[issue_type].append(issue)
        
        common_issues = [
            {
                'type': issue_type,
                'count': len(issues),
                'severity': issues[0].get('severity', 'low'),
                'example_page': issues[0].get('page_url', ''),
                'recommendation': issues[0].get('recommendation', '')
            }
            for issue_type, issues in sorted(issue_types.items(), key=lambda x: len(x[1]), reverse=True)
        ][:10]  # Top 10 most common issues
        
        # Create aggregate performance metrics including Core Web Vitals
        successful_audits = len(valid_perf_scores)
        performance_metrics = [
            {
                'metric_name': 'Performance Score',
                'score': round(avg_performance, 1),
                'value': f'{round(avg_performance, 1)}/100',
                'rating': 'Good' if avg_performance >= 90 else ('Needs Improvement' if avg_performance >= 50 else 'Poor'),
                'description': f'Average performance score across {successful_audits} pages' + (f' ({total_pages - successful_audits} failed)' if total_pages != successful_audits else '')
            }
        ]
        
        # Add Core Web Vitals if available
        if fcp_values:
            performance_metrics.append({
                'metric_name': 'FCP (First Contentful Paint)',
                'score': round(avg_fcp_score, 1),
                'value': avg_fcp_value,
                'rating': 'Good' if avg_fcp_score >= 90 else ('Needs Improvement' if avg_fcp_score >= 50 else 'Poor'),
                'description': 'First Contentful Paint - when first content appears'
            })
        
        if lcp_values:
            performance_metrics.append({
                'metric_name': 'LCP (Largest Contentful Paint)',
                'score': round(avg_lcp_score, 1),
                'value': avg_lcp_value,
                'rating': 'Good' if avg_lcp_score >= 90 else ('Needs Improvement' if avg_lcp_score >= 50 else 'Poor'),
                'description': 'Largest Contentful Paint - when main content loads'
            })
        
        if cls_values:
            performance_metrics.append({
                'metric_name': 'CLS (Cumulative Layout Shift)',
                'score': round(avg_cls_score, 1),
                'value': avg_cls_value,
                'rating': 'Good' if avg_cls_score >= 90 else ('Needs Improvement' if avg_cls_score >= 50 else 'Poor'),
                'description': 'Cumulative Layout Shift - visual stability'
            })
        
        if tbt_values:
            performance_metrics.append({
                'metric_name': 'TBT (Total Blocking Time)',
                'score': round(avg_tbt_score, 1),
                'value': avg_tbt_value,
                'rating': 'Good' if avg_tbt_score >= 90 else ('Needs Improvement' if avg_tbt_score >= 50 else 'Poor'),
                'description': 'Total Blocking Time - how long page is blocked from user input'
            })
        
        if tti_values:
            performance_metrics.append({
                'metric_name': 'TTI (Time to Interactive)',
                'score': round(avg_tti_score, 1),
                'value': avg_tti_value,
                'rating': 'Good' if avg_tti_score >= 90 else ('Needs Improvement' if avg_tti_score >= 50 else 'Poor'),
                'description': 'Time to Interactive - when page becomes fully interactive'
            })
        
        # Build summary
        summary = {
            'mode': 'full',
            'total_pages_audited': total_pages,
            'avg_performance_score': round(avg_performance, 1),
            'total_seo_issues': total_seo_issues,
            'total_issues_high': sum(1 for i in all_seo_issues if i.get('severity') == 'high'),
            'total_issues_medium': sum(1 for i in all_seo_issues if i.get('severity') == 'medium'),
            'total_issues_low': sum(1 for i in all_seo_issues if i.get('severity') == 'low'),
            'bots_allowed': sum(1 for b in all_bot_data if b.get('status') == 'Allowed'),
            'bots_checked': len(all_bot_data),
            'url': base_url
        }
        
        return {
            'summary': summary,
            'common_issues': common_issues,
            'page_summaries': page_summaries,
            'raw_data': {
                'seo': {'issues': all_seo_issues},
                'performance': {
                    'metrics': performance_metrics,
                    'avg_score': avg_performance
                },
                'bots': {'bots': all_bot_data}
            }
        }

