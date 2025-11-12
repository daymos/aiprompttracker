import httpx
import logging
from typing import Optional, Dict, Any, List
from bs4 import BeautifulSoup
from urllib.parse import urlparse, urljoin
import xml.etree.ElementTree as ET

logger = logging.getLogger(__name__)

class WebScraperService:
    """Service for fetching and analyzing websites for SEO keyword research"""
    
    def __init__(self):
        self.timeout = 15.0  # Increased from 10s for larger pages
        self.max_content_length = 5000000  # 5MB max (raw HTML/assets)
        self.max_text_length = 50000  # 50KB max for extracted text
        self.max_pages_to_crawl = 5  # Limit crawling to avoid abuse
    
    async def fetch_website(self, url: str) -> Optional[Dict[str, Any]]:
        """
        Fetch a website and extract SEO-relevant information
        
        Returns:
            Dictionary with title, description, headings, content, etc.
        """
        
        # Validate URL
        if not url.startswith(('http://', 'https://')):
            url = f'https://{url}'
        
        try:
            parsed = urlparse(url)
            if not parsed.netloc:
                logger.error(f"Invalid URL: {url}")
                return None
            
            async with httpx.AsyncClient(follow_redirects=True) as client:
                response = await client.get(
                    url,
                    timeout=self.timeout,
                    headers={
                        'User-Agent': 'Mozilla/5.0 (compatible; KeywordsChatBot/1.0; +https://keywordschat.com)',
                    }
                )
                response.raise_for_status()
                
                # Check raw content length (prevent extremely large downloads)
                content_size = len(response.content)
                if content_size > self.max_content_length:
                    logger.warning(f"Content too large for {url}: {content_size} bytes (max: {self.max_content_length})")
                    return {
                        'url': url,
                        'error': f'Page too large to analyze ({content_size / 1024 / 1024:.1f}MB)'
                    }
                
                logger.debug(f"Fetched {url}: {content_size / 1024:.1f}KB")
                
                # Parse HTML
                soup = BeautifulSoup(response.content, 'html.parser')
                
                # Extract SEO elements
                result = {
                    'url': url,
                    'title': self._get_title(soup),
                    'meta_description': self._get_meta_description(soup),
                    'meta_keywords': self._get_meta_keywords(soup),
                    'headings': self._get_headings(soup),
                    'main_content': self._get_main_content(soup),
                    'links_count': len(soup.find_all('a')),
                    'images_count': len(soup.find_all('img')),
                }
                
                return result
                
        except httpx.TimeoutException:
            logger.error(f"Timeout fetching {url}")
            return {'url': url, 'error': 'Request timed out'}
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error {e.response.status_code} for {url}")
            return {'url': url, 'error': f'HTTP {e.response.status_code}'}
        except Exception as e:
            logger.error(f"Error fetching {url}: {e}")
            return {'url': url, 'error': str(e)}
    
    def _get_title(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract page title"""
        title_tag = soup.find('title')
        return title_tag.get_text().strip() if title_tag else None
    
    def _get_meta_description(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract meta description"""
        meta = soup.find('meta', attrs={'name': 'description'})
        return meta.get('content', '').strip() if meta else None
    
    def _get_meta_keywords(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract meta keywords (rarely used anymore but still relevant)"""
        meta = soup.find('meta', attrs={'name': 'keywords'})
        return meta.get('content', '').strip() if meta else None
    
    def _get_headings(self, soup: BeautifulSoup) -> Dict[str, list]:
        """Extract all heading tags (H1-H3)"""
        return {
            'h1': [h.get_text().strip() for h in soup.find_all('h1')][:5],
            'h2': [h.get_text().strip() for h in soup.find_all('h2')][:10],
            'h3': [h.get_text().strip() for h in soup.find_all('h3')][:10],
        }
    
    def _get_main_content(self, soup: BeautifulSoup) -> str:
        """
        Extract main text content, removing scripts, styles, etc.
        Returns first ~3000 characters (increased from 2000)
        """
        # Remove unwanted elements
        for element in soup(['script', 'style', 'nav', 'footer', 'header', 'aside', 'form', 'iframe']):
            element.decompose()
        
        # Get text from main content areas (try common patterns)
        main_content = (
            soup.find('main') or 
            soup.find('article') or 
            soup.find('div', class_=['content', 'main-content', 'post-content', 'container']) or
            soup.find('body')
        )
        
        if main_content:
            text = main_content.get_text(separator=' ', strip=True)
            # Clean up whitespace
            text = ' '.join(text.split())
            
            # Check if extracted text is too long (safety check)
            max_chars = 3000
            if len(text) > self.max_text_length:
                logger.warning(f"Extracted text is very long ({len(text)} chars), truncating to {max_chars}")
            
            # Return first 3000 chars
            return text[:max_chars] + ('...' if len(text) > max_chars else '')
        
        return ''
    
    async def fetch_sitemap(self, base_url: str) -> List[str]:
        """
        Fetch sitemap.xml and return list of URLs
        Returns empty list if sitemap not found
        """
        if not base_url.startswith(('http://', 'https://')):
            base_url = f'https://{base_url}'
        
        parsed = urlparse(base_url)
        sitemap_urls = [
            f"{parsed.scheme}://{parsed.netloc}/sitemap.xml",
            f"{parsed.scheme}://{parsed.netloc}/sitemap_index.xml",
            f"{parsed.scheme}://{parsed.netloc}/sitemap-index.xml",
        ]
        
        for sitemap_url in sitemap_urls:
            try:
                async with httpx.AsyncClient(follow_redirects=True) as client:
                    response = await client.get(sitemap_url, timeout=self.timeout)
                    response.raise_for_status()
                    
                    # Parse XML
                    root = ET.fromstring(response.content)
                    
                    # Handle both sitemap and sitemap index
                    urls = []
                    
                    # Standard sitemap namespace
                    ns = {'ns': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
                    
                    # Try to find URLs
                    for loc in root.findall('.//ns:loc', ns):
                        url = loc.text
                        if url:
                            urls.append(url)
                    
                    # Also try without namespace (some sites don't use it)
                    if not urls:
                        for loc in root.findall('.//loc'):
                            url = loc.text
                            if url:
                                urls.append(url)
                    
                    if urls:
                        logger.info(f"Found sitemap at {sitemap_url} with {len(urls)} URLs")
                        return urls[:self.max_pages_to_crawl * 2]  # Return more URLs for filtering
                    
            except Exception as e:
                logger.debug(f"No sitemap at {sitemap_url}: {e}")
                continue
        
        logger.info(f"No sitemap found for {base_url}")
        return []
    
    async def analyze_full_site(self, url: str) -> Dict[str, Any]:
        """
        Comprehensive site analysis: main page + sitemap + key pages
        Returns aggregated data for SEO keyword analysis
        """
        if not url.startswith(('http://', 'https://')):
            url = f'https://{url}'
        
        parsed = urlparse(url)
        base_url = f"{parsed.scheme}://{parsed.netloc}"
        
        logger.info(f"Starting full site analysis for {url}")
        
        # Fetch main page
        main_page = await self.fetch_website(url)
        
        if main_page and 'error' in main_page:
            # If main page fails, return error with more helpful message
            logger.error(f"Failed to analyze {url}: {main_page.get('error')}")
            return main_page
        
        # Try to get sitemap
        sitemap_urls = await self.fetch_sitemap(base_url)
        
        # Determine which pages to crawl
        pages_to_crawl = []
        
        if sitemap_urls:
            # Prioritize important pages from sitemap
            priority_paths = ['about', 'features', 'pricing', 'product', 'service', 'how-it-works', 'solutions']
            
            # Add homepage if not already in sitemap
            if url not in sitemap_urls and base_url not in sitemap_urls:
                pages_to_crawl.append(url)
            
            # Find priority pages
            for sitemap_url in sitemap_urls:
                if any(path in sitemap_url.lower() for path in priority_paths):
                    pages_to_crawl.append(sitemap_url)
                    if len(pages_to_crawl) >= self.max_pages_to_crawl:
                        break
            
            # Fill remaining slots with other pages
            if len(pages_to_crawl) < self.max_pages_to_crawl:
                for sitemap_url in sitemap_urls:
                    if sitemap_url not in pages_to_crawl:
                        pages_to_crawl.append(sitemap_url)
                        if len(pages_to_crawl) >= self.max_pages_to_crawl:
                            break
        else:
            # No sitemap - just analyze main page
            pages_to_crawl = [url]
        
        logger.info(f"Crawling {len(pages_to_crawl)} pages: {pages_to_crawl}")
        
        # Fetch all pages
        pages_data = []
        for page_url in pages_to_crawl:
            page_data = await self.fetch_website(page_url)
            if page_data and 'error' not in page_data:
                pages_data.append(page_data)
        
        # Aggregate data from all pages
        return self._aggregate_site_data(main_page, pages_data, sitemap_urls)
    
    def _aggregate_site_data(self, main_page: Dict[str, Any], pages_data: List[Dict[str, Any]], sitemap_urls: List[str]) -> Dict[str, Any]:
        """
        Combine data from multiple pages into a comprehensive analysis
        """
        # Start with main page data
        result = {
            'url': main_page['url'],
            'title': main_page.get('title'),
            'meta_description': main_page.get('meta_description'),
            'meta_keywords': main_page.get('meta_keywords'),
            'main_page_h1s': main_page.get('headings', {}).get('h1', []),
            'main_page_h2s': main_page.get('headings', {}).get('h2', []),
            'main_content_preview': main_page.get('main_content', '')[:500],
            'pages_analyzed': len(pages_data),
            'sitemap_found': len(sitemap_urls) > 0,
            'total_sitemap_urls': len(sitemap_urls),
        }
        
        # Aggregate all H1s and H2s from all pages
        all_h1s = list(main_page.get('headings', {}).get('h1', []))
        all_h2s = list(main_page.get('headings', {}).get('h2', []))
        all_titles = [main_page.get('title')] if main_page.get('title') else []
        
        for page in pages_data:
            page_title = page.get('title')
            if page_title and page_title not in all_titles:
                all_titles.append(page_title)
            
            for h1 in page.get('headings', {}).get('h1', []):
                if h1 not in all_h1s:
                    all_h1s.append(h1)
            
            for h2 in page.get('headings', {}).get('h2', []):
                if h2 not in all_h2s and len(all_h2s) < 20:  # Limit to avoid overwhelming
                    all_h2s.append(h2)
        
        result['all_page_titles'] = all_titles
        result['all_h1_headings'] = all_h1s
        result['all_h2_headings'] = all_h2s[:15]  # Top 15 H2s
        
        # Extract common themes/keywords from content
        result['analysis_type'] = 'full_site'
        
        return result






