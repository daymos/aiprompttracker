import logging
from typing import List, Dict, Any
from openai import AsyncOpenAI
from ..config import get_settings

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

Keep responses conversational and concise. Don't overwhelm with data - give clear recommendations.

When keyword data is provided, analyze it and give specific advice about which keywords to target and why.

Format your responses in a friendly, chat-like way. Use bullet points for clarity when listing keywords."""

        messages = [{"role": "system", "content": system_prompt}]
        
        # Add conversation history if provided
        if conversation_history:
            messages.extend(conversation_history[-5:])  # Last 5 messages for context
        
        # Add keyword data if available
        user_content = user_message
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

