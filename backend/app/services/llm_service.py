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
    
    async def extract_keyword_intent(
        self,
        user_message: str,
        conversation_history: List[Dict[str, str]] = None
    ) -> Optional[str]:
        """
        Use LLM to determine if user wants keyword research and extract the topic.
        Returns the keyword/topic to research, or None if no research needed.
        """
        
        system_prompt = """You are a keyword extraction assistant. Your job is to determine if the user wants keyword research and extract the specific keyword/topic.

Guidelines:
1. If user requests keyword research and provides a topic/niche/website → Extract and return that topic
2. If user mentions their website/product in the conversation history → Use that as the topic
3. If user says "keyword analysis for my site" → Look at conversation history for their site/product
4. Only return NULL if user is asking about something completely unrelated to keyword research

Your response MUST be ONLY:
- The specific keyword/topic to research (e.g., "AI chatbots", "SEO chatbot", "keywords.chat")
- OR the word "NULL" if completely unrelated to keyword research

Be proactive. Infer the topic from context if the user has mentioned their website/product.
Do not explain or add any other text. Just the keyword or NULL."""

        messages = [{"role": "system", "content": system_prompt}]
        
        if conversation_history:
            messages.extend(conversation_history[-3:])  # Last 3 for context
        
        messages.append({"role": "user", "content": user_message})
        
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=0.1,  # Low temperature for consistent extraction
                max_tokens=50
            )
            
            result = response.choices[0].message.content.strip()
            
            if result.upper() == "NULL" or not result:
                return None
            
            return result
            
        except Exception as e:
            logger.error(f"Error extracting keyword intent: {e}")
            return None
    
    async def generate_keyword_advice(
        self, 
        user_message: str,
        keyword_data: List[Dict[str, Any]] = None,
        conversation_history: List[Dict[str, str]] = None,
        mode: str = "ask",
        user_projects: List[Dict[str, Any]] = None
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
        user_content = self._build_user_content(user_message, website_data, keyword_data, user_projects)
        
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
        return """You are an expert SEO assistant with powerful research tools at your disposal.

**IMPORTANT: On first interaction only**, introduce yourself:

"I'm your SEO helper. What do you want me to do?"

That's it. Don't list features unless asked.

After the introduction, respond naturally to user commands.

**YOUR TOOLS & CAPABILITIES:**

1. **Website Analysis** (automatic when URL detected)
   - Scrapes main page + sitemap + key pages
   - Extracts titles, meta tags, all headings, content
   - Analyzes site structure and SEO state

2. **Keyword Research** (on-demand)
   - Real search volume data from RapidAPI
   - Competition levels (LOW/MEDIUM/HIGH)
   - CPC data
   - Related keyword suggestions

3. **Rank Checking** (on-demand)
   - Check where a domain ranks for specific keywords
   - Tracks position in top 100 results

4. **Competitor Analysis** (automatic with URL)
   - Full site crawl of competitor sites
   - Identify their keyword focus
   - Analyze content strategy

5. **User Project Context** (always available)
   - Access to user's existing projects and tracked keywords
   - See what domains they're monitoring
   - View keywords they're already tracking with volumes and competition
   - Provide contextual advice based on their existing work

**CRITICAL RULES:**

1. **NEVER HALLUCINATE DATA**
   - ONLY show keyword tables when you have REAL data in your context
   - If you don't have data, explain what tool to use: "I can fetch keyword data for [topic] - would you like me to search for that?"
   - DO NOT make up search volumes, competition levels, or rankings

2. **RESPOND TO USER COMMANDS**
   - User is in control - they tell you what to do
   - Examples: "analyze example.com", "find keywords for AI chatbots", "check my ranking for [keyword]"
   - Execute commands and show results
   - If unclear, ask for clarification

3. **HANDLE ERRORS CLEARLY**
   - Website fetch failed? Tell them why: "Couldn't reach example.com (DNS error). Is the site live?"
   - You DO have scraping capability - specific fetch just failed
   - Offer alternatives: "Can you describe what the site offers instead?"

4. **USE CONVERSATION HISTORY**
   - Remember previous context
   - If user says "refine to top 5", use keywords you already provided
   - Don't repeat yourself or ask same questions twice

5. **USE USER'S PROJECT CONTEXT**
   - User's existing projects are listed in context for reference
   - If user mentions a SPECIFIC website/URL → focus ONLY on that, ignore other projects
   - If that website matches an existing project → note it's already tracked
   - If that website is NEW (not in projects) → treat as new, don't discuss other projects
   - If user asks "my projects" or "what am I tracking" → discuss ALL their projects
   - Default: Focus on what user explicitly asked about, not unrelated projects

**PROVIDING RESULTS:**

WITH REAL KEYWORD DATA:
| Keyword | Searches/mo | Competition |
|---------|-------------|-------------|
| keyword | volume | LOW/MED/HIGH |

Then: "Want me to track these?"

WITH WEBSITE DATA:
1-2 sentences about what the site does.
List 3-5 specific keyword suggestions (actual phrases, not "themes").
Then: "Should I research '[keyword]' for you?"

WITHOUT DATA:
"What topic should I research?"

**CRITICAL RULES:**
- Keep responses under 5 sentences unless showing data tables
- Execute actions, don't list what you CAN do
- Respond ONLY to what user asked, nothing else
- Stay on topic, don't mention unrelated projects/websites
- Be direct and concise"""
    
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
    
    def _build_user_content(self, user_message: str, website_data: Optional[Dict[str, Any]], keyword_data: Optional[List[Dict[str, Any]]], user_projects: Optional[List[Dict[str, Any]]] = None) -> str:
        """Build user content with all available data"""
        user_content = user_message
        
        if user_projects:
            user_content += f"\n\n[USER'S EXISTING PROJECTS - CONTEXT ONLY]\n"
            user_content += f"The user has {len(user_projects)} project(s):\n\n"
            
            for project in user_projects:
                user_content += f"- {project['name'] or 'Unnamed'} ({project['target_url']})\n"
                if project['tracked_keywords']:
                    user_content += f"  Tracking: {', '.join([kw['keyword'] for kw in project['tracked_keywords'][:3]])}\n"
                user_content += "\n"
        
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
                # Check if user seems to want keyword research
                message_lower = user_message.lower()
                if any(word in message_lower for word in ['keyword', 'research', 'seo', 'rank', 'search volume']):
                    user_content += f"User requested keyword research but didn't specify a topic/niche.\n"
                    user_content += f"You need to know what topic to research before you can fetch data.\n"
                else:
                    user_content += f"No specific keyword research request detected.\n"
                    user_content += f"Respond to their query naturally.\n"
            
            user_content += f"\nDo NOT make up search volumes or competition levels. You can suggest keywords to research.\n"
        
        return user_content

