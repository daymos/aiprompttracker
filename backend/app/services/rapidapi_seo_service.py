import httpx
from typing import Dict, Any
import logging
from urllib.parse import urlparse
from ..config import get_settings

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
    
    def _get_api_key(self):
        """Get API key from settings"""
        if not self.api_key:
            logger.error("RAPIDAPI_KEY not configured in settings")
        return self.api_key
    
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
                # Call onpagepro endpoint for full audit with suggestions
                response = await client.get(
                    f"{self.base_url}/onpagepro.php",
                    params={"website": domain},
                    headers=self.headers
                )
                response.raise_for_status()
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
                response = await client.get(
                    f"{self.base_url}/aiseo.php",
                    params={"url": domain},
                    headers=self.headers
                )
                response.raise_for_status()
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
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{self.base_url}/speed.php",
                    params={"website": domain},
                    headers=self.headers
                )
                response.raise_for_status()
                data = response.json()
                
                logger.info(f"✅ Performance analysis completed")
                return self._parse_performance_results(data, url)
                
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
        import asyncio
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
        
        # Add Performance metrics
        if not performance_results.get("error") and performance_results.get("metrics"):
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
        
        logger.info(f"✅ Comprehensive audit completed: {len(all_items)} items analyzed")
        
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

