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
        self.model = "openai/gpt-oss-120b"  # GPT-OSS 120B via Groq
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
        conversation_history: List[Dict[str, str]] = None,
        mode: str = "ask"
    ) -> str:
        """Generate conversational keyword research advice"""
        
        # Select system prompt based on mode
        if mode == "agent":
            system_prompt = self._get_agent_mode_prompt()
        else:
            system_prompt = self._get_ask_mode_prompt()
        
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
            logger.info(f"Detected URL in message: {url} - starting full site analysis")
            # Use full site analysis (sitemap + multi-page crawl)
            website_data = await self.web_scraper.analyze_full_site(url)
            
            if website_data and 'error' in website_data:
                logger.warning(f"Website fetch failed for {url}: {website_data['error']}")
            elif website_data:
                pages_analyzed = website_data.get('pages_analyzed', 1)
                sitemap_found = website_data.get('sitemap_found', False)
                logger.info(f"Successfully analyzed {url}: {pages_analyzed} pages, sitemap: {sitemap_found}")
        
        # Build user content with all available data
        user_content = self._build_user_content(user_message, website_data, keyword_data)
        
        messages.append({"role": "user", "content": user_content})
        
        logger.info(f"Sending request to LLM with {len(messages)} messages (mode: {mode})")
        
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
    
    def _get_ask_mode_prompt(self) -> str:
        """System prompt for ASK mode - user-driven commands"""
        return """You are an expert SEO keyword researcher who gives simple, actionable advice.

Your job is to help users find keywords they can actually rank for. Focus on:
- High search volume (1000+ monthly searches is good)
- Low to medium competition
- Relevance to their business/topic
- Actionable recommendations (which keywords to target first)

**YOUR CAPABILITIES:**
- You CAN analyze websites when URLs are provided (automatic scraping)
- You CAN access real keyword data from APIs when appropriate
- You CANNOT browse the web independently or access sites that fail to load

**CRITICAL RULES - READ CAREFULLY:**

1. **NEVER HALLUCINATE KEYWORD DATA**
   - ONLY provide keyword recommendations when you have REAL keyword data in your context
   - If you don't have keyword data, ASK questions to understand the business first
   - DO NOT make up search volumes, competition levels, or keywords

2. **UNDERSTAND THE BUSINESS FIRST (but don't interrogate)**
   - Before recommending keywords, try to understand:
     * What the product/service actually does
     * Who the target audience is
     * What problem it solves or value it provides
   - If the user is vague, ask 1-2 clarifying questions MAX, then work with what you have
   - Don't ask the same questions repeatedly - use conversation history
   - If you have enough context (website data + any user description), provide recommendations
   - User context like "I created an MVP" is NOT a keyword - it's background information

3. **HANDLE WEBSITE FETCH ERRORS PROPERLY**
   - If website data shows an error (DNS failure, timeout, HTTP error), acknowledge it clearly
   - Example: "I tried to analyze [domain] but couldn't reach it (DNS error). Is the site live yet?"
   - Then ask for manual information: "Can you describe what the site offers?"
   - DO NOT claim you "don't have browsing capability" - you do, the specific site just failed to load

4. **USE CONVERSATION HISTORY**
   - You have access to the conversation history. Pay attention to previous messages.
   - If the user asks to filter/refine/prioritize keywords you ALREADY provided, use those previous keywords
   - DO NOT make up new keywords when the user is asking to narrow down existing recommendations
   - Examples: "give me the top 5", "show me only the low competition ones", "which have highest volume?"

**WORKFLOW:**

Step 1: If user mentions a URL → Full site analysis runs automatically:
   - Fetches main page
   - Attempts to find and parse sitemap.xml
   - Crawls up to 5 key pages (prioritizing about, features, pricing, etc.)
   - Aggregates all titles, H1s, H2s, and content

Step 2: When you receive full site analysis data:
   - Review all page titles, headings, and content
   - Identify the business model, target audience, and value proposition
   - Provide keyword analysis/recommendations based on the comprehensive data
   - Be proactive - don't ask for info you can infer from the site

Step 3: If keyword data is also available:
   - Combine website analysis with real keyword metrics
   - Give specific, actionable recommendations with search volumes

Step 4: Only ask questions if:
   - The website fetch completely failed (DNS error, timeout, etc.)
   - The site exists but content is minimal/unclear
   - You need clarification on a specific strategic decision

**BE PROACTIVE:**
- When you have full site data, provide analysis immediately
- Infer business details from page titles and headings
- Suggest keyword themes based on what you learned from crawling
- Don't wait for the user to explain what you can see yourself

**PROVIDING RECOMMENDATIONS:**

WITH REAL KEYWORD DATA:
- Show keyword table with actual search volumes and competition
- Format as:

| Keyword | Avg. Monthly Searches | Competition | Why it's a good target |
|---------|---------------------|-------------|----------------------|
| keyword name | volume number | LOW/MEDIUM/HIGH | brief reason |

WITHOUT KEYWORD DATA (but you understand the business):
- Suggest keyword themes/topics they should research
- Explain why those themes are relevant based on their business
- Be clear you're suggesting directions, not providing data
- Example: "Based on your voice AI assistant, you should research keywords around: voice assistant, AI chat, personal AI, etc. Would you like me to fetch real data for any of these?"

**BALANCE:**
Ask questions when truly needed, but prioritize being helpful over being perfectly informed."""
    
    def _get_agent_mode_prompt(self) -> str:
        """System prompt for AGENT mode - AI-guided workflow"""
        return """You are an SEO keyword research agent conducting a structured analysis workflow.

**YOUR ROLE:**
Guide the user through a complete SEO keyword strategy, taking initiative and using all available tools.

**AGENT WORKFLOW (follow these steps):**

1. **WEBSITE ANALYSIS PHASE**
   - When given a URL, you automatically analyze the full site (main page + sitemap + key pages)
   - Review all page titles, headings, and content to understand:
     * What the business does
     * Who they target
     * Their value proposition
     * Current SEO state
   - Summarize findings clearly

2. **KEYWORD DISCOVERY PHASE**
   - Based on website analysis, propose 3-5 keyword themes to research
   - Ask user which direction interests them most
   - Fetch real keyword data for chosen themes
   - Present data with specific recommendations

3. **STRATEGY RECOMMENDATION PHASE**
   - Analyze keyword opportunities (volume vs. competition)
   - Recommend top 5-10 keywords to target
   - Explain priority (which to focus on first and why)
   - Suggest content strategy for each keyword

4. **ACTION PLAN PHASE**
   - Provide specific next steps
   - Offer to set up keyword tracking
   - Ask if they want to analyze competitors
   - Suggest content ideas

**CAPABILITIES YOU HAVE:**
- Full website crawling (automatically done when URL mentioned)
- Real keyword data from RapidAPI (search volume, competition, CPC)
- Rank checking for their domain
- Sitemap analysis

**AGENT BEHAVIOR:**
- Be proactive - don't wait to be asked
- Take initiative at each phase
- Ask directional questions (not info you can find yourself)
- Move the workflow forward
- Be conversational but structured
- Show progress through the workflow

**CURRENT WORKFLOW STATE:**
Track where you are in the process and guide the user to the next logical step.

**PROVIDING RECOMMENDATIONS:**

WITH REAL KEYWORD DATA:
- Show keyword table with actual search volumes and competition
- Format as:

| Keyword | Avg. Monthly Searches | Competition | Why it's a good target |
|---------|---------------------|-------------|----------------------|
| keyword name | volume number | LOW/MEDIUM/HIGH | brief reason |

WITHOUT KEYWORD DATA:
- Suggest keyword themes to research based on site analysis
- Ask which themes to explore further
- Explain why those themes matter

**REMEMBER:**
You're guiding a journey from "here's my website" to "here's your complete keyword strategy." Take charge and lead."""
    
    def _build_user_content(self, user_message: str, website_data: Optional[Dict[str, Any]], keyword_data: Optional[List[Dict[str, Any]]]) -> str:
        """Build user content with all available data"""
        user_content = user_message
        
        if website_data:
            if 'error' in website_data:
                # Provide clear error context to the LLM
                error_msg = website_data['error']
                user_content += f"\n\n[WEBSITE FETCH FAILED for {website_data['url']}]"
                user_content += f"\nError Type: {error_msg}"
                
                # Give helpful hints based on error type
                if 'nodename' in error_msg or 'DNS' in error_msg or 'not known' in error_msg:
                    user_content += "\nLikely Reason: Domain doesn't exist or isn't live yet"
                    user_content += "\nSuggestion: Ask the user if the site is deployed, or request them to describe what it offers"
                elif 'timeout' in error_msg.lower():
                    user_content += "\nLikely Reason: Site took too long to respond"
                    user_content += "\nSuggestion: The site may be slow or down. Ask for alternative information."
                elif 'HTTP' in error_msg:
                    user_content += "\nLikely Reason: Server returned an error"
                    user_content += "\nSuggestion: Site may be private or restricted. Ask the user for details."
                else:
                    user_content += "\nSuggestion: Unable to access the website. Ask the user to describe their business/product instead."
                
                user_content += "\n\nIMPORTANT: You DO have website scraping capability. This specific site just failed to load. Don't claim you can't browse - you can, this particular fetch just didn't work.\n"
            else:
                analysis_type = website_data.get('analysis_type', 'single_page')
                
                if analysis_type == 'full_site':
                    # Multi-page analysis
                    user_content += f"\n\n[FULL SITE ANALYSIS COMPLETED for {website_data['url']}]\n"
                    user_content += f"Pages Analyzed: {website_data.get('pages_analyzed', 1)}\n"
                    user_content += f"Sitemap Found: {'Yes' if website_data.get('sitemap_found') else 'No'}\n"
                    if website_data.get('sitemap_found'):
                        user_content += f"Total URLs in Sitemap: {website_data.get('total_sitemap_urls', 0)}\n"
                    
                    user_content += f"\nMain Page:\n"
                    user_content += f"- Title: {website_data.get('title', 'N/A')}\n"
                    user_content += f"- Meta Description: {website_data.get('meta_description', 'N/A')}\n"
                    if website_data.get('meta_keywords'):
                        user_content += f"- Meta Keywords: {website_data['meta_keywords']}\n"
                    
                    user_content += f"\nAll Page Titles Across Site:\n"
                    for title in website_data.get('all_page_titles', [])[:10]:
                        user_content += f"  - {title}\n"
                    
                    user_content += f"\nAll H1 Headings Across Site:\n"
                    for h1 in website_data.get('all_h1_headings', [])[:10]:
                        user_content += f"  - {h1}\n"
                    
                    user_content += f"\nKey H2 Headings:\n"
                    for h2 in website_data.get('all_h2_headings', [])[:10]:
                        user_content += f"  - {h2}\n"
                    
                    user_content += f"\nMain Content Preview: {website_data.get('main_content_preview', '')}\n"
                    
                else:
                    # Single page fallback
                    user_content += f"\n\n[WEBSITE ANALYSIS SUCCESSFUL for {website_data['url']}]\n"
                    user_content += f"Title: {website_data.get('title', 'N/A')}\n"
                    user_content += f"Meta Description: {website_data.get('meta_description', 'N/A')}\n"
                    if website_data.get('meta_keywords'):
                        user_content += f"Meta Keywords: {website_data['meta_keywords']}\n"
                    
                    headings = website_data.get('headings', {})
                    if headings:
                        user_content += f"H1 Headings: {headings.get('h1', [])}\n"
                        user_content += f"H2 Headings: {headings.get('h2', [])[:5]}\n"
                    
                    user_content += f"Content Preview: {website_data.get('main_content', '')[:500]}\n"
        
        if keyword_data:
            user_content += f"\n\n[REAL KEYWORD DATA AVAILABLE]\n"
            user_content += f"Source: RapidAPI keyword research\n"
            user_content += f"Data: {keyword_data}\n"
            user_content += f"\nProvide specific keyword recommendations using this REAL data.\n"
        else:
            user_content += f"\n\n[NO KEYWORD DATA AVAILABLE]\n"
            
            if website_data and 'error' not in website_data:
                # Have website data, can provide analysis
                user_content += f"You have comprehensive website data above. Provide keyword analysis:\n"
                user_content += f"1. Analyze what the business does based on the page content\n"
                user_content += f"2. Suggest specific keyword themes and directions they should target\n"
                user_content += f"3. Explain why those keywords are relevant based on the site analysis\n"
                user_content += f"4. Offer to fetch real search volume data for specific keywords\n"
            else:
                # No website data either
                user_content += f"No website or keyword data available. Options:\n"
                user_content += f"1. Ask the user for a URL to analyze\n"
                user_content += f"2. Ask what their business/product does (if not already asked)\n"
                user_content += f"3. If you have some context, suggest keyword themes\n"
            
            user_content += f"\nDo NOT make up search volumes or competition levels. You can suggest keywords to research.\n"
        
        return user_content

