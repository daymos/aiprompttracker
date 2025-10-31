import httpx
import logging
from typing import Optional, Dict, Any
from bs4 import BeautifulSoup
from urllib.parse import urlparse

logger = logging.getLogger(__name__)

class WebScraperService:
    """Service for fetching and analyzing websites for SEO keyword research"""
    
    def __init__(self):
        self.timeout = 10.0
        self.max_content_length = 500000  # 500KB max
    
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
                
                # Check content length
                if len(response.content) > self.max_content_length:
                    logger.warning(f"Content too large for {url}")
                    return {
                        'url': url,
                        'error': 'Content too large to analyze'
                    }
                
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
        Returns first ~2000 characters
        """
        # Remove unwanted elements
        for element in soup(['script', 'style', 'nav', 'footer', 'header', 'aside']):
            element.decompose()
        
        # Get text from main content areas (try common patterns)
        main_content = (
            soup.find('main') or 
            soup.find('article') or 
            soup.find('div', class_=['content', 'main-content', 'post-content']) or
            soup.find('body')
        )
        
        if main_content:
            text = main_content.get_text(separator=' ', strip=True)
            # Clean up whitespace
            text = ' '.join(text.split())
            # Return first 2000 chars
            return text[:2000] + ('...' if len(text) > 2000 else '')
        
        return ''

