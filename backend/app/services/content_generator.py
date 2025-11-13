"""
Content Generation Service - AI-powered SEO content creation
"""
import logging
import re
from typing import Dict, Any, Optional, List
from openai import AsyncOpenAI
from ..config import get_settings

logger = logging.getLogger(__name__)


class ContentGeneratorService:
    """Service for generating SEO-optimized content using LLM"""
    
    def __init__(self):
        self._client = None
        self.model = "llama-3.3-70b-versatile"  # Good balance of quality and speed
    
    @property
    def client(self):
        """Lazy initialization of the OpenAI client"""
        if self._client is None:
            try:
                settings = get_settings()
                api_key = getattr(settings, 'GROQ_API_KEY', None)
                if api_key and api_key.strip():
                    self._client = AsyncOpenAI(
                        api_key=api_key,
                        base_url="https://api.groq.com/openai/v1"
                    )
                else:
                    logger.warning("GROQ_API_KEY not configured")
            except Exception as e:
                logger.warning(f"Failed to initialize content generator client: {e}")
        return self._client
    
    async def generate_outline(
        self,
        topic: str,
        target_keywords: List[str],
        tone_description: Optional[str] = None,
        word_count_target: int = 1500
    ) -> Dict[str, Any]:
        """
        Generate an article outline based on topic and keywords
        
        Args:
            topic: Main topic/title for the article
            target_keywords: List of keywords to target
            tone_description: Optional tone profile description
            word_count_target: Target word count
        """
        if self.client is None:
            return {
                "success": False,
                "error": "LLM client not available"
            }
        
        keywords_str = ", ".join(f'"{kw}"' for kw in target_keywords)
        tone_instruction = f"\n\nTone: {tone_description}" if tone_description else ""
        
        system_prompt = f"""You are an expert SEO content strategist and writer. 
Create detailed, well-structured article outlines optimized for search engines and readers.{tone_instruction}"""
        
        user_prompt = f"""Create a detailed outline for an SEO-optimized article about: "{topic}"

Target Keywords: {keywords_str}
Target Length: ~{word_count_target} words

Requirements:
1. Compelling H1 title that includes primary keyword naturally
2. Brief introduction (2-3 sentences) explaining what the article covers
3. 5-8 main sections with H2 headings
4. 2-3 subsections (H3) under each H2 where relevant
5. Each section should naturally incorporate target keywords
6. Include a conclusion section
7. Suggest meta description (150-160 characters)

Format your response as:
```
TITLE: [H1 title]

META DESCRIPTION: [150-160 char meta description]

INTRODUCTION:
[2-3 sentence introduction]

OUTLINE:
## H2: [Section 1 title]
- [Key points to cover]
### H3: [Subsection if needed]

## H2: [Section 2 title]
- [Key points to cover]

[Continue with all sections...]

## H2: Conclusion
- [Summary points]
```"""
        
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.7,
                max_tokens=2000
            )
            
            outline_text = response.choices[0].message.content
            
            # Parse the outline
            parsed = self._parse_outline(outline_text)
            
            return {
                "success": True,
                "outline_text": outline_text,
                "parsed": parsed
            }
            
        except Exception as e:
            logger.error(f"Error generating outline: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def _parse_outline(self, outline_text: str) -> Dict[str, Any]:
        """Parse structured outline from LLM response"""
        lines = outline_text.split('\n')
        
        title = None
        meta_description = None
        introduction = None
        sections = []
        
        current_section = None
        current_subsection = None
        in_intro = False
        
        for line in lines:
            line = line.strip()
            
            # Extract title
            if line.startswith('TITLE:'):
                title = line.replace('TITLE:', '').strip()
            
            # Extract meta description
            elif line.startswith('META DESCRIPTION:'):
                meta_description = line.replace('META DESCRIPTION:', '').strip()
            
            # Detect introduction section
            elif line.startswith('INTRODUCTION:'):
                in_intro = True
                introduction = []
            
            # H2 section
            elif line.startswith('##') and not line.startswith('###'):
                in_intro = False
                if current_section:
                    sections.append(current_section)
                current_section = {
                    "level": "h2",
                    "title": line.replace('##', '').replace('H2:', '').strip(),
                    "points": [],
                    "subsections": []
                }
                current_subsection = None
            
            # H3 subsection
            elif line.startswith('###'):
                if current_section:
                    if current_subsection:
                        current_section["subsections"].append(current_subsection)
                    current_subsection = {
                        "level": "h3",
                        "title": line.replace('###', '').replace('H3:', '').strip(),
                        "points": []
                    }
            
            # Bullet points
            elif line.startswith('-') or line.startswith('•'):
                point = line.lstrip('-•').strip()
                if current_subsection:
                    current_subsection["points"].append(point)
                elif current_section:
                    current_section["points"].append(point)
                elif in_intro and introduction is not None:
                    introduction.append(point)
            
            # Regular text in intro
            elif in_intro and line and introduction is not None:
                introduction.append(line)
        
        # Add last section
        if current_subsection and current_section:
            current_section["subsections"].append(current_subsection)
        if current_section:
            sections.append(current_section)
        
        return {
            "title": title,
            "meta_description": meta_description,
            "introduction": ' '.join(introduction) if isinstance(introduction, list) else introduction,
            "sections": sections
        }
    
    async def generate_full_article(
        self,
        outline: Dict[str, Any],
        target_keywords: List[str],
        tone_description: Optional[str] = None,
        word_count_target: int = 1500
    ) -> Dict[str, Any]:
        """
        Generate full article content from outline
        
        Args:
            outline: Parsed outline from generate_outline()
            target_keywords: Keywords to target
            tone_description: Optional tone profile
            word_count_target: Target word count
        """
        if self.client is None:
            return {
                "success": False,
                "error": "LLM client not available"
            }
        
        keywords_str = ", ".join(f'"{kw}"' for kw in target_keywords)
        tone_instruction = f"\n\nTone: {tone_description}" if tone_description else ""
        
        # Build outline text
        outline_text = f"# {outline.get('title', 'Article')}\n\n"
        outline_text += f"Introduction: {outline.get('introduction', '')}\n\n"
        
        for section in outline.get('sections', []):
            outline_text += f"## {section['title']}\n"
            for subsection in section.get('subsections', []):
                outline_text += f"### {subsection['title']}\n"
        
        system_prompt = f"""You are an expert SEO content writer who creates engaging, informative articles.
Write in a natural, readable style while incorporating keywords seamlessly.{tone_instruction}"""
        
        user_prompt = f"""Write a complete, SEO-optimized article based on this outline:

{outline_text}

Requirements:
1. Target length: ~{word_count_target} words
2. Naturally incorporate these keywords: {keywords_str}
3. Write in engaging, clear prose
4. Use short paragraphs (2-4 sentences each)
5. Include transitions between sections
6. Write in HTML format with proper heading tags (h2, h3, p)
7. Add relevant examples and explanations
8. Make it valuable and informative for readers

Format as clean HTML with:
- <h2> for main sections
- <h3> for subsections  
- <p> for paragraphs
- <ul>/<li> for lists when appropriate
- <strong> for emphasis

Start writing the full article now:"""
        
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.7,
                max_tokens=4000
            )
            
            content = response.choices[0].message.content
            
            # Calculate metrics
            word_count = len(content.split())
            seo_score = self._calculate_seo_score(content, target_keywords, outline.get('title', ''))
            
            return {
                "success": True,
                "content": content,
                "word_count": word_count,
                "seo_score": seo_score,
                "keywords_used": self._count_keyword_usage(content, target_keywords)
            }
            
        except Exception as e:
            logger.error(f"Error generating article: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def _calculate_seo_score(self, content: str, keywords: List[str], title: str) -> int:
        """Calculate basic SEO score (0-100)"""
        score = 0
        content_lower = content.lower()
        
        # Word count check (50-100 points for 800-2000 words)
        word_count = len(content.split())
        if 800 <= word_count <= 2000:
            score += 20
        elif word_count > 500:
            score += 10
        
        # Keyword in title
        title_lower = title.lower()
        if any(kw.lower() in title_lower for kw in keywords):
            score += 15
        
        # Keyword usage (not too much, not too little)
        for keyword in keywords:
            count = content_lower.count(keyword.lower())
            if 2 <= count <= 10:
                score += 10
            elif count >= 1:
                score += 5
        
        # Has headings
        if '<h2>' in content or '<h3>' in content:
            score += 15
        
        # Has paragraphs
        if '<p>' in content:
            score += 10
        
        # Content length per section
        if word_count > 1000:
            score += 10
        
        return min(score, 100)
    
    def _count_keyword_usage(self, content: str, keywords: List[str]) -> Dict[str, int]:
        """Count how many times each keyword appears"""
        content_lower = content.lower()
        return {kw: content_lower.count(kw.lower()) for kw in keywords}
    
    async def analyze_tone(self, sample_texts: List[str]) -> Dict[str, Any]:
        """
        Analyze writing tone/style from sample texts
        
        Args:
            sample_texts: List of text samples to analyze
        """
        if self.client is None:
            return {
                "success": False,
                "error": "LLM client not available"
            }
        
        combined_sample = "\n\n---\n\n".join(sample_texts[:5])  # Max 5 samples
        
        system_prompt = """You are a writing style analyst. Analyze the tone, voice, and style of the provided text samples."""
        
        user_prompt = f"""Analyze the writing style and tone of these text samples:

{combined_sample}

Provide a concise description (2-3 sentences) of:
1. Tone (formal/casual, professional/conversational, etc.)
2. Voice (active/passive, first/third person, etc.)
3. Style characteristics (sentence length, vocabulary level, use of examples, etc.)

Your analysis will be used to match this style in future AI-generated content."""
        
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=0.3,
                max_tokens=500
            )
            
            tone_description = response.choices[0].message.content
            
            return {
                "success": True,
                "tone_description": tone_description,
                "samples_analyzed": len(sample_texts)
            }
            
        except Exception as e:
            logger.error(f"Error analyzing tone: {e}")
            return {
                "success": False,
                "error": str(e)
            }

