"""
LLM Provider implementations for tracking brand visibility.

Each provider queries an LLM with prompts and returns responses
that can be analyzed for brand mentions.
"""

from abc import ABC, abstractmethod
from typing import Dict, List, Optional
from dataclasses import dataclass
import logging
import re

logger = logging.getLogger(__name__)


@dataclass
class LLMResponse:
    """Standardized response from any LLM provider"""
    provider: str  # 'openai', 'gemini', 'perplexity', etc.
    model: str  # 'gpt-4', 'gemini-pro', etc.
    prompt: str
    response_text: str
    metadata: Dict = None  # token count, latency, etc.
    error: Optional[str] = None


class BaseLLMProvider(ABC):
    """Base class for all LLM providers"""
    
    def __init__(self, api_key: str):
        self.api_key = api_key
    
    @abstractmethod
    async def query(self, prompt: str, **kwargs) -> LLMResponse:
        """Send a prompt and get a response"""
        pass
    
    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Return the provider name"""
        pass
    
    @property
    @abstractmethod
    def default_model(self) -> str:
        """Return the default model name"""
        pass


class OpenAIProvider(BaseLLMProvider):
    """OpenAI ChatGPT provider"""
    
    def __init__(self, api_key: str, model: str = "gpt-4o-mini"):
        super().__init__(api_key)
        self.model = model
        try:
            from openai import AsyncOpenAI
            self.client = AsyncOpenAI(api_key=api_key)
        except ImportError:
            raise ImportError("openai package is required. Install with: pip install openai")
    
    @property
    def provider_name(self) -> str:
        return "openai"
    
    @property
    def default_model(self) -> str:
        return self.model
    
    async def query(self, prompt: str, **kwargs) -> LLMResponse:
        """Query OpenAI with a prompt"""
        try:
            response = await self.client.chat.completions.create(
                model=kwargs.get('model', self.model),
                messages=[
                    {"role": "system", "content": "You are a helpful assistant providing information about companies, products, and services."},
                    {"role": "user", "content": prompt}
                ],
                temperature=kwargs.get('temperature', 0.7),
                max_tokens=kwargs.get('max_tokens', 500)
            )
            
            response_text = response.choices[0].message.content
            
            return LLMResponse(
                provider=self.provider_name,
                model=self.model,
                prompt=prompt,
                response_text=response_text,
                metadata={
                    'tokens_used': response.usage.total_tokens,
                    'prompt_tokens': response.usage.prompt_tokens,
                    'completion_tokens': response.usage.completion_tokens,
                    'finish_reason': response.choices[0].finish_reason
                }
            )
            
        except Exception as e:
            logger.error(f"OpenAI query failed: {str(e)}")
            return LLMResponse(
                provider=self.provider_name,
                model=self.model,
                prompt=prompt,
                response_text="",
                error=str(e)
            )


class GeminiProvider(BaseLLMProvider):
    """Google Gemini provider (placeholder for future implementation)"""
    
    def __init__(self, api_key: str, model: str = "gemini-pro"):
        super().__init__(api_key)
        self.model = model
    
    @property
    def provider_name(self) -> str:
        return "gemini"
    
    @property
    def default_model(self) -> str:
        return self.model
    
    async def query(self, prompt: str, **kwargs) -> LLMResponse:
        """Query Gemini with a prompt"""
        # TODO: Implement Gemini API integration
        return LLMResponse(
            provider=self.provider_name,
            model=self.model,
            prompt=prompt,
            response_text="",
            error="Gemini provider not yet implemented"
        )


class PerplexityProvider(BaseLLMProvider):
    """Perplexity AI provider (placeholder for future implementation)"""
    
    def __init__(self, api_key: str, model: str = "pplx-7b-online"):
        super().__init__(api_key)
        self.model = model
    
    @property
    def provider_name(self) -> str:
        return "perplexity"
    
    @property
    def default_model(self) -> str:
        return self.model
    
    async def query(self, prompt: str, **kwargs) -> LLMResponse:
        """Query Perplexity with a prompt"""
        # TODO: Implement Perplexity API integration
        return LLMResponse(
            provider=self.provider_name,
            model=self.model,
            prompt=prompt,
            response_text="",
            error="Perplexity provider not yet implemented"
        )


class BrandMentionAnalyzer:
    """Analyzes LLM responses for brand mentions and rankings"""
    
    @staticmethod
    def find_brand_mentions(text: str, brand_terms: List[str]) -> Dict:
        """
        Find if and where brand terms appear in text.
        
        Returns:
            {
                'found': bool,
                'mentions': List[str],
                'positions': List[int],
                'context_snippets': List[str]
            }
        """
        text_lower = text.lower()
        found = False
        mentions = []
        positions = []
        context_snippets = []
        
        for term in brand_terms:
            term_lower = term.lower()
            if term_lower in text_lower:
                found = True
                mentions.append(term)
                
                # Find all occurrences
                pattern = re.compile(re.escape(term_lower), re.IGNORECASE)
                for match in pattern.finditer(text):
                    positions.append(match.start())
                    
                    # Extract context (50 chars before and after)
                    start = max(0, match.start() - 50)
                    end = min(len(text), match.end() + 50)
                    snippet = text[start:end].strip()
                    context_snippets.append(f"...{snippet}...")
        
        return {
            'found': found,
            'mentions': mentions,
            'positions': positions,
            'context_snippets': context_snippets[:3]  # Max 3 snippets
        }
    
    @staticmethod
    def calculate_mention_rank(text: str, brand_terms: List[str], competitor_terms: List[str] = None) -> Optional[int]:
        """
        Calculate the rank/position of brand mention relative to competitors.
        Lower rank = earlier mention = better visibility.
        
        Returns:
            Rank (1-based) or None if not found
        """
        if not competitor_terms:
            competitor_terms = []
        
        all_terms = brand_terms + competitor_terms
        mentions = []
        
        text_lower = text.lower()
        for term in all_terms:
            term_lower = term.lower()
            pos = text_lower.find(term_lower)
            if pos != -1:
                is_brand = term in brand_terms
                mentions.append((pos, term, is_brand))
        
        # Sort by position
        mentions.sort(key=lambda x: x[0])
        
        # Find first brand mention rank
        for idx, (pos, term, is_brand) in enumerate(mentions, 1):
            if is_brand:
                return idx
        
        return None


class PromptTemplateManager:
    """Manages prompt templates for different query types"""
    
    # Standard prompt templates
    TEMPLATES = {
        'brand_awareness': [
            "What do you know about {brand}?",
            "Tell me about {brand}",
            "Can you provide information on {brand}?"
        ],
        'keyword_search': [
            "What are the best {keyword}?",
            "Recommend top {keyword}",
            "I need help finding {keyword}",
            "Show me the leading {keyword}"
        ],
        'comparative': [
            "Compare {brand} to competitors",
            "What are alternatives to {brand}?",
            "How does {brand} compare to other {keyword}?"
        ],
        'use_case': [
            "Best {keyword} for {use_case}",
            "I need {keyword} for {use_case}, what do you recommend?",
            "Top {keyword} solutions for {use_case}"
        ]
    }
    
    @classmethod
    def generate_prompts(cls, brand: str, keywords: List[str] = None, use_cases: List[str] = None) -> List[Dict]:
        """
        Generate a comprehensive list of prompts to test.
        
        Returns:
            List of {type, prompt, metadata} dicts
        """
        prompts = []
        
        # Brand awareness prompts
        for template in cls.TEMPLATES['brand_awareness']:
            prompts.append({
                'type': 'brand_awareness',
                'prompt': template.format(brand=brand),
                'metadata': {'brand': brand}
            })
        
        # Keyword-based prompts
        if keywords:
            for keyword in keywords:
                for template in cls.TEMPLATES['keyword_search']:
                    prompts.append({
                        'type': 'keyword_search',
                        'prompt': template.format(keyword=keyword),
                        'metadata': {'keyword': keyword, 'brand': brand}
                    })
        
        # Use case prompts
        if keywords and use_cases:
            for keyword in keywords:
                for use_case in use_cases[:2]:  # Limit to 2 use cases per keyword
                    template = cls.TEMPLATES['use_case'][0]
                    prompts.append({
                        'type': 'use_case',
                        'prompt': template.format(keyword=keyword, use_case=use_case),
                        'metadata': {'keyword': keyword, 'use_case': use_case, 'brand': brand}
                    })
        
        return prompts


# Provider factory
class LLMProviderFactory:
    """Factory for creating LLM provider instances"""
    
    _providers = {
        'openai': OpenAIProvider,
        'gemini': GeminiProvider,
        'perplexity': PerplexityProvider,
    }
    
    @classmethod
    def create(cls, provider_name: str, api_key: str, **kwargs) -> BaseLLMProvider:
        """Create a provider instance"""
        provider_class = cls._providers.get(provider_name.lower())
        if not provider_class:
            raise ValueError(f"Unknown provider: {provider_name}")
        
        return provider_class(api_key, **kwargs)
    
    @classmethod
    def list_providers(cls) -> List[str]:
        """List available providers"""
        return list(cls._providers.keys())

