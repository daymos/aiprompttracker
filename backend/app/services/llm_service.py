import logging
import re
from typing import List, Dict, Any, Optional
from openai import AsyncOpenAI
from ..config import get_settings
from .web_scraper import WebScraperService

logger = logging.getLogger(__name__)
settings = get_settings()

class LLMService:
    """Service for LLM interactions via Groq"""
    
    def __init__(self):
        self.client = AsyncOpenAI(
            api_key=settings.GROQ_API_KEY,
            base_url="https://api.groq.com/openai/v1"
        )
        self.model = "llama-3.3-70b-versatile"
        self.web_scraper = WebScraperService()
    
    def _extract_url(self, text: str) -> Optional[str]:
        """Extract URL from user message"""
        # Simple URL pattern matching
        url_pattern = r'https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9-]+\.(com|net|org|io|co|app|dev)[^\s]*'
        match = re.search(url_pattern, text)
        return match.group(0) if match else None
    
    async def generate_keyword_advice(
        self, 
        user_message: str,
        keyword_data: List[Dict[str, Any]] = None,
        conversation_history: List[Dict[str, str]] = None
    ) -> str:
        """Generate conversational keyword research advice"""
        
        system_prompt = """You are an expert SEO keyword researcher who gives simple, actionable advice.

Your job is to help users find keywords they can actually rank for. Focus on:
- High search volume (1000+ monthly searches is good)
- Low to medium competition
- Relevance to their business/topic
- Actionable recommendations (which keywords to target first)

You can also analyze competitor websites to understand their SEO strategy, keywords they're targeting, and content structure.

Keep responses conversational and concise. Don't overwhelm with data - give clear recommendations.

When keyword data is provided, analyze it and give specific advice about which keywords to target and why.

When website data is provided, analyze the title, meta description, headings, and content to understand what keywords they're targeting and give strategic advice.

Format your responses in a friendly, chat-like way. Use bullet points for clarity when listing keywords."""

        messages = [{"role": "system", "content": system_prompt}]
        
        # Add conversation history if provided
        if conversation_history:
            history_to_add = conversation_history[-5:]  # Last 5 messages for context
            logger.info(f"Adding {len(history_to_add)} messages from conversation history to LLM context")
            messages.extend(history_to_add)
        else:
            logger.info("No conversation history available (new conversation)")
        
        # Check if user is asking about a website
        url = self._extract_url(user_message)
        website_data = None
        if url:
            logger.info(f"Detected URL in message: {url}")
            website_data = await self.web_scraper.fetch_website(url)
        
        # Build user content with all available data
        user_content = user_message
        
        if website_data:
            if 'error' in website_data:
                user_content += f"\n\n[Note: Could not fetch website - {website_data['error']}]"
            else:
                user_content += f"\n\nWebsite Analysis for {website_data['url']}:\n"
                user_content += f"Title: {website_data.get('title', 'N/A')}\n"
                user_content += f"Meta Description: {website_data.get('meta_description', 'N/A')}\n"
                if website_data.get('meta_keywords'):
                    user_content += f"Meta Keywords: {website_data['meta_keywords']}\n"
                user_content += f"H1 Headings: {website_data['headings']['h1']}\n"
                user_content += f"H2 Headings: {website_data['headings']['h2'][:5]}\n"
                user_content += f"Content Preview: {website_data.get('main_content', '')[:500]}\n"
        
        if keyword_data:
            user_content += f"\n\nKeyword Data:\n{keyword_data}"
        
        messages.append({"role": "user", "content": user_content})
        
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=0.7,
                max_tokens=1000
            )
            
            return response.choices[0].message.content
            
        except Exception as e:
            logger.error(f"Error generating LLM response: {e}")
            return "Sorry, I encountered an error. Please try again."

