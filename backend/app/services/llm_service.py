import logging
import re
import asyncio
from typing import List, Dict, Any, Optional
from openai import AsyncOpenAI
from ..config import get_settings
from .web_scraper import WebScraperService
from .seo_knowledge_service import get_seo_knowledge_service

logger = logging.getLogger(__name__)

class LLMService:
    """Service for LLM interactions via Groq"""

    def __init__(self):
        self._client = None
        self.model = "openai/gpt-oss-120b"  # GPT-OSS 120B via Groq
        self.summarization_model = "llama-3.3-70b-versatile"  # Lighter/faster model for summaries
        self.web_scraper = WebScraperService()

    @property
    def client(self):
        """Lazy initialization of the OpenAI client"""
        if self._client is None:
            try:
                from ..config import get_settings
                settings = get_settings()
                api_key = getattr(settings, 'GROQ_API_KEY', None)
                if api_key and api_key.strip():
                    from openai import AsyncOpenAI
                    self._client = AsyncOpenAI(
                        api_key=api_key,
                        base_url="https://api.groq.com/openai/v1"
                    )
                else:
                    logger.warning("GROQ_API_KEY not configured")
            except Exception as e:
                logger.warning(f"Failed to initialize LLM client: {e}")
        return self._client
    
    def _extract_url(self, text: str) -> Optional[str]:
        """Extract URL from user message"""
        # Simple URL pattern matching
        url_pattern = r'https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9-]+\.(com|net|org|io|co|app|dev)[^\s]*'
        match = re.search(url_pattern, text)
        return match.group(0) if match else None

    async def summarize_conversation(self, conversation_content: str, max_retries: int = 3) -> str:
        """
        Generate a concise one-liner summary of a conversation for pinning purposes.
        Uses retry mechanism with exponential backoff.
        """
        # Check if client is available
        if self.client is None:
            raise RuntimeError("LLM client not available - GROQ_API_KEY not configured")

        system_prompt = """You are a helpful assistant that summarizes conversations in one concise sentence.
Focus on the main topic, question, or key insight. Keep it under 100 characters.
Be specific but brief. Capture what was discussed or accomplished."""

        user_prompt = f"Conversation:\n{conversation_content}\n\nProvide a one-sentence summary:"

        for attempt in range(max_retries):
            try:
                logger.info(f"Summarizing conversation (attempt {attempt + 1}/{max_retries})")
                response = await self.client.chat.completions.create(
                    model=self.summarization_model,
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    max_tokens=100,
                    temperature=0.3
                )

                summary = response.choices[0].message.content
                if not summary:
                    raise ValueError("LLM returned empty content")
                
                logger.debug(f"Raw LLM response: {repr(summary)}")
                
                summary = summary.strip()
                # Clean up the summary (remove quotes, extra whitespace)
                summary = summary.strip('"\'')
                
                # Check if summary is empty after cleaning
                if not summary or len(summary) == 0:
                    raise ValueError("LLM returned only quotes or whitespace")
                
                result = summary[:100] if len(summary) > 100 else summary
                logger.info(f"Successfully generated conversation summary: {repr(result)}")
                return result

            except Exception as e:
                wait_time = 2 ** attempt  # Exponential backoff: 1s, 2s, 4s
                logger.warning(f"Attempt {attempt + 1}/{max_retries} failed to summarize conversation: {e}")
                
                if attempt < max_retries - 1:
                    logger.info(f"Retrying in {wait_time} seconds...")
                    await asyncio.sleep(wait_time)
                else:
                    logger.error(f"All {max_retries} attempts failed to summarize conversation")
                    raise RuntimeError(f"Failed to generate conversation summary after {max_retries} attempts: {e}")

    async def extract_keywords_from_website(self, website_data: dict, max_keywords: int = 20) -> list[str]:
        """
        Use LLM to intelligently extract relevant SEO keywords from website content.
        Returns a list of 2-4 word keyword phrases.
        """
        if self.client is None:
            raise RuntimeError("LLM client not available - GROQ_API_KEY not configured")
        
        # Build context from website data
        context_parts = []
        
        if website_data.get('title'):
            context_parts.append(f"Page Title: {website_data['title']}")
        
        if website_data.get('meta_description'):
            context_parts.append(f"Meta Description: {website_data['meta_description']}")
        
        if website_data.get('all_page_titles'):
            titles = website_data['all_page_titles'][:5]  # Top 5 page titles
            context_parts.append(f"Page Titles: {', '.join(titles)}")
        
        if website_data.get('all_h1_headings'):
            h1s = website_data['all_h1_headings'][:5]
            context_parts.append(f"H1 Headings: {', '.join(h1s)}")
        
        if website_data.get('all_h2_headings'):
            h2s = website_data['all_h2_headings'][:10]
            context_parts.append(f"H2 Headings: {', '.join(h2s)}")
        
        context = "\n".join(context_parts)
        
        system_prompt = f"""You are an SEO keyword extraction expert. Extract {max_keywords} relevant SEO keyword phrases from the website content provided.

RULES:
- Each keyword must be 2-4 words long
- Focus on business/product keywords, NOT navigation terms
- Exclude: "click here", "read more", "contact us", "privacy policy", "terms of service", etc.
- Keywords should be what users would search for to find this website
- Keywords should appear multiple times in the content
- Return ONLY the keywords, one per line, no numbering or explanations"""

        user_prompt = f"""Website Content:

{context}

Extract {max_keywords} relevant SEO keywords (2-4 words each) that this website is targeting. Return one keyword per line."""

        try:
            response = await self.client.chat.completions.create(
                model=self.summarization_model,  # Use faster model for extraction
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                max_tokens=500,
                temperature=0.3
            )
            
            content = response.choices[0].message.content
            if not content:
                return []
            
            # Parse keywords from response (one per line)
            keywords = []
            for line in content.strip().split('\n'):
                # Clean up line (remove numbers, bullets, quotes, etc.)
                keyword = line.strip().lstrip('0123456789.-•*').strip().strip('"\'')
                # Validate: 2-4 words, min 10 chars
                words = keyword.split()
                if 2 <= len(words) <= 4 and len(keyword) >= 10 and keyword:
                    keywords.append(keyword.lower())
            
            logger.info(f"LLM extracted {len(keywords)} keywords from website")
            return keywords[:max_keywords]
            
        except Exception as e:
            logger.error(f"Error extracting keywords via LLM: {e}")
            return []
    
    async def summarize_message(self, message_content: str, max_retries: int = 3) -> str:
        """
        Generate a concise one-liner summary of a single message for pinning purposes.
        Uses retry mechanism with exponential backoff.
        """
        # Check if client is available
        if self.client is None:
            raise RuntimeError("LLM client not available - GROQ_API_KEY not configured")

        system_prompt = """You are a helpful assistant that summarizes messages in one concise phrase.
Focus on the key point, insight, or question. Keep it under 80 characters.
Be specific but brief. Capture the essence of the message."""

        user_prompt = f"Message:\n{message_content}\n\nProvide a brief summary in 1-2 words or a short phrase:"

        for attempt in range(max_retries):
            try:
                logger.info(f"Summarizing message with content length: {len(message_content)} (attempt {attempt + 1}/{max_retries})")
                response = await self.client.chat.completions.create(
                    model=self.summarization_model,
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    max_tokens=50,
                    temperature=0.3
                )

                if not response.choices or not response.choices[0].message:
                    raise ValueError("LLM response is empty or malformed")

                summary = response.choices[0].message.content
                if not summary:
                    raise ValueError("LLM returned empty content")

                logger.debug(f"Raw LLM response: {repr(summary)}")
                
                summary = summary.strip()
                # Clean up the summary (remove quotes, extra whitespace)
                summary = summary.strip('"\'')
                
                # Check if summary is empty after cleaning
                if not summary or len(summary) == 0:
                    raise ValueError("LLM returned only quotes or whitespace")
                
                result = summary[:80] if len(summary) > 80 else summary
                logger.info(f"Successfully generated message summary: {repr(result)}")
                return result

            except Exception as e:
                wait_time = 2 ** attempt  # Exponential backoff: 1s, 2s, 4s
                logger.warning(f"Attempt {attempt + 1}/{max_retries} failed to summarize message: {e}")
                
                if attempt < max_retries - 1:
                    logger.info(f"Retrying in {wait_time} seconds...")
                    await asyncio.sleep(wait_time)
                else:
                    logger.error(f"All {max_retries} attempts failed to summarize message")
                    raise RuntimeError(f"Failed to generate message summary after {max_retries} attempts: {e}")

    async def extract_keyword_intent(
        self,
        user_message: str,
        conversation_history: List[Dict[str, str]] = None
    ) -> Optional[str]:
        """
        Use LLM to determine if user wants keyword research and extract the topic.
        Returns the keyword/topic to research, or None if no research needed.
        """
        
        system_prompt = """You extract keywords that the user wants to research.

RULES:
1. Read the FULL conversation history carefully
2. If user says "yes", "sure", "okay", "all of them", "go ahead" → Extract what was offered/mentioned in previous messages
3. If assistant listed keywords and user confirms → Return ALL those keywords comma-separated
4. If user provides a direct topic → Return that topic
5. Return "NULL" ONLY if completely unrelated to keywords/SEO

OUTPUT FORMAT (CRITICAL):
- Just the keyword(s), nothing else
- Multiple keywords: comma-separated
- No explanations, no extra words, no quotes around your answer

EXAMPLES:

Conversation:
Assistant: "Would you like keyword data for: AI chat SEO assistant, chatbot SEO tool?"
User: "yes"
YOUR RESPONSE: AI chat SEO assistant, chatbot SEO tool

Conversation:
User: "research keywords for my SEO toolkit"
YOUR RESPONSE: SEO toolkit

Conversation:
Assistant: "Should I pull data for 'marketing automation'?"
User: "sure"
YOUR RESPONSE: marketing automation

Conversation:
User: "what's the weather"
YOUR RESPONSE: NULL

NOW EXTRACT FROM THE CONVERSATION BELOW:"""

        messages = [{"role": "system", "content": system_prompt}]
        
        if conversation_history:
            messages.extend(conversation_history[-10:])  # Last 10 for full context
        
        messages.append({"role": "user", "content": user_message})
        
        try:
            logger.info(f"🔍 Asking LLM: Does user want keyword research?")
            logger.debug(f"User message: {user_message}")
            logger.debug(f"Conversation context: {len(conversation_history) if conversation_history else 0} messages")
            
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=0.3,  # Slightly higher for better context understanding
                max_tokens=150  # Allow for multiple keywords
            )
            
            result = response.choices[0].message.content.strip()
            
            logger.info(f"📋 LLM intent response: '{result}'")
            
            if result.upper() == "NULL" or not result:
                logger.info("❌ LLM says: No keyword research needed")
                return None
            
            logger.info(f"✅ LLM detected keyword research intent for: '{result}'")
            return result
            
        except Exception as e:
            logger.error(f"Error extracting keyword intent: {e}")
            return None
    
    async def extract_backlink_intent(
        self,
        user_message: str,
        conversation_history: List[Dict[str, str]] = None
    ) -> Optional[Dict[str, Any]]:
        """Use LLM to determine if user wants backlink analysis and extract domain(s)"""
        
        system_prompt = """You are a backlink analysis intent detector. Determine if the user wants backlink analysis and extract domain(s).

Guidelines:
1. If user requests backlinks/links/DA/PA for a domain → Extract that domain
2. If user says "yes", "go ahead", "sure" after being asked for a domain → Extract domain from the conversation
3. If user provides a domain after being asked which domain to analyze → Extract that domain
4. If user wants to compare backlinks between two domains → Extract both domains
5. Only return NULL if completely unrelated to backlink analysis

Your response MUST be valid JSON in one of these formats:

For single domain analysis:
{"action": "analyze", "domain": "example.com"}

For comparison:
{"action": "compare", "domain1": "mysite.com", "domain2": "competitor.com"}

If no backlink intent:
NULL

CRITICAL: Extract domain without http://, https://, or www. prefixes. Just the domain (e.g., "outloud.tech", "keywords.chat")"""

        messages = [{"role": "system", "content": system_prompt}]
        
        if conversation_history:
            messages.extend(conversation_history[-10:])  # Last 10 for context
        
        messages.append({"role": "user", "content": user_message})
        
        try:
            logger.info(f"🔗 Asking LLM: Does user want backlink analysis?")
            logger.debug(f"User message: {user_message}")
            
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=0.1,
                max_tokens=100
            )
            
            result = response.choices[0].message.content.strip()
            
            logger.info(f"📋 LLM backlink intent response: '{result}'")
            
            if result.upper() == "NULL" or not result:
                logger.info("❌ LLM says: No backlink analysis needed")
                return None
            
            # Parse JSON response
            import json
            intent = json.loads(result)
            logger.info(f"✅ LLM detected backlink intent: {intent.get('action')} for domain(s)")
            return intent
            
        except json.JSONDecodeError as e:
            logger.error(f"Error parsing backlink intent JSON: {e}, response: {result}")
            return None
        except Exception as e:
            logger.error(f"Error extracting backlink intent: {e}")
            return None
    
    async def chat_with_tools(
        self,
        user_message: str,
        conversation_history: List[Dict[str, str]] = None,
        available_tools: List[Dict[str, Any]] = None,
        user_projects: List[Dict[str, Any]] = None,
        mode: str = "ask"
    ) -> tuple[str, Optional[str], Optional[List[Dict]]]:
        """
        Chat with function calling support.
        
        Returns:
            (response_text, reasoning, tool_calls)
        """
        
        # Select system prompt based on mode
        if mode == "agent":
            system_prompt = self._get_agent_mode_prompt()
        else:
            system_prompt = self._get_ask_mode_prompt()

        messages = [{"role": "system", "content": system_prompt}]
        
        # DISABLED: SEO knowledge injection was causing LLM quality issues
        # TODO: Re-enable with better filtering and smaller context
        # # In agent mode, try to inject relevant SEO knowledge
        # if mode == "agent":
        #     try:
        #         knowledge_service = get_seo_knowledge_service()
        #         # Build context from user message + recent conversation
        #         context = user_message
        #         if conversation_history:
        #             # Filter out None/empty content from conversation history
        #             recent_messages = [msg.get("content") or "" for msg in conversation_history[-3:]]
        #             recent_context = " ".join([m for m in recent_messages if m])
        #             if recent_context:
        #                 context = recent_context + " " + user_message
        #         
        #         seo_knowledge = knowledge_service.get_relevant_knowledge(context, max_chars=15000)
        #         
        #         if seo_knowledge:
        #             logger.info("✨ Injecting relevant SEO knowledge into agent mode context")
        #             # Add knowledge as a system message after the main prompt
        #             messages.append({
        #                 "role": "system",
        #                 "content": f"\n\n{seo_knowledge}\n\nUse this advanced SEO knowledge to enhance your strategic recommendations when relevant. Reference specific concepts from the book when appropriate, but explain them clearly for the user."
        #             })
        #     except Exception as e:
        #         logger.warning(f"Failed to load SEO knowledge: {e}")
        #         # Continue without knowledge injection
        
        # Add conversation history
        if conversation_history:
            history_to_add = conversation_history[-5:]
            logger.info(f"Adding {len(history_to_add)} messages from conversation history to LLM context")
            messages.extend(history_to_add)
        else:
            logger.info("No conversation history available (new conversation)")
        
        # Add user projects context if available
        if user_projects:
            projects_context = f"\n\n[USER'S EXISTING PROJECTS]\n"
            projects_context += f"The user has {len(user_projects)} project(s):\n"
            for project in user_projects:
                projects_context += f"- {project['name']} ({project['target_url']}) [ID: {project['id']}]\n"
                if project['tracked_keywords']:
                    projects_context += f"  Tracking: {', '.join([kw['keyword'] for kw in project['tracked_keywords'][:3]])}\n"
            
            user_message = user_message + projects_context
        
        messages.append({"role": "user", "content": user_message})
        
        logger.info(f"🤖 Sending chat request to LLM (mode: {mode}, tools available: {len(available_tools) if available_tools else 0})")
        
        # Retry logic for empty responses
        max_retries = 3
        retry_delay = 0.5  # Start with 0.5 seconds
        
        for attempt in range(max_retries):
            try:
                # Make request with tools if available
                request_params = {
                    "model": self.model,
                    "messages": messages,
                    "temperature": 0.7,
                    "max_tokens": 1000
                }
                
                if available_tools:
                    request_params["tools"] = available_tools
                    request_params["tool_choice"] = "auto"  # Let LLM decide when to use tools
                
                response = await self.client.chat.completions.create(**request_params)
                
                message = response.choices[0].message
                
                # Check if LLM wants to call functions
                if hasattr(message, 'tool_calls') and message.tool_calls:
                    logger.info(f"🛠️  LLM requested {len(message.tool_calls)} tool calls")
                    tool_calls = []
                    for tool_call in message.tool_calls:
                        import json
                        tool_calls.append({
                            "id": tool_call.id,
                            "name": tool_call.function.name,
                            "arguments": json.loads(tool_call.function.arguments)
                        })
                        logger.info(f"  - {tool_call.function.name}({tool_call.function.arguments})")
                    
                    return (None, None, tool_calls)  # Return tool calls to execute
                
                # Normal response without tool calls
                full_response = message.content
                
                # Handle case where LLM returns no content
                if not full_response:
                    if attempt < max_retries - 1:
                        logger.warning(f"LLM returned no content (attempt {attempt + 1}/{max_retries}) - retrying in {retry_delay}s...")
                        await asyncio.sleep(retry_delay)
                        retry_delay *= 2  # Exponential backoff
                        continue
                    else:
                        logger.error("LLM returned no content after all retries")
                        return ("I apologize, but I didn't receive a proper response after multiple attempts. Please try again.", None, None)
                
                reasoning, content = self._extract_reasoning(full_response)
                
                logger.info(f"✅ LLM response generated ({len(content)} chars)")
                return (content, reasoning, None)
                
            except Exception as e:
                if attempt < max_retries - 1:
                    logger.warning(f"Error in chat with tools (attempt {attempt + 1}/{max_retries}): {e} - retrying...")
                    await asyncio.sleep(retry_delay)
                    retry_delay *= 2
                    continue
                else:
                    logger.error(f"Error in chat with tools after all retries: {e}", exc_info=True)
                    return ("Sorry, I encountered an error after multiple attempts. Please try again.", None, None)
    
    async def generate_keyword_advice(
        self, 
        user_message: str,
        keyword_data: List[Dict[str, Any]] = None,
        backlink_data: Dict[str, Any] = None,
        conversation_history: List[Dict[str, str]] = None,
        mode: str = "ask",
        user_projects: List[Dict[str, Any]] = None,
        keyword_error: Optional[str] = None
    ) -> tuple[str, Optional[str]]:
        """Generate conversational keyword research advice (DEPRECATED - use chat_with_tools)"""
        
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
        user_content = self._build_user_content(user_message, website_data, keyword_data, backlink_data, user_projects, keyword_error)
        
        messages.append({"role": "user", "content": user_content})
        
        logger.info(f"Sending request to LLM with {len(messages)} messages (mode: {mode})")
        
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=0.7,
                max_tokens=1000
            )
            
            full_response = response.choices[0].message.content
            
            # Extract reasoning and content
            reasoning, content = self._extract_reasoning(full_response)
            
            # Return tuple: (user_facing_content, reasoning)
            return (content, reasoning)
            
        except Exception as e:
            logger.error(f"Error generating LLM response: {e}")
            return ("Sorry, I encountered an error. Please try again.", None)
    
    def _extract_reasoning(self, full_response: str) -> tuple[str, Optional[str]]:
        """Extract reasoning from response and return (reasoning, content)"""
        import re
        
        # Look for <reasoning>...</reasoning> tags (properly closed)
        reasoning_pattern = r'<reasoning>(.*?)</reasoning>'
        match = re.search(reasoning_pattern, full_response, re.DOTALL | re.IGNORECASE)
        
        if match:
            reasoning = match.group(1).strip()
            # Remove the reasoning section from the content
            content = re.sub(reasoning_pattern, '', full_response, flags=re.DOTALL | re.IGNORECASE).strip()
            
            # If content is empty after extraction, the LLM only provided reasoning
            if not content:
                logger.warning("LLM provided reasoning but no user-facing content - using fallback")
                return (reasoning, "Let me help you with that. Could you provide more details?")
            
            logger.info(f"Extracted reasoning ({len(reasoning)} chars) from response")
            return (reasoning, content)
        else:
            # Check for unclosed reasoning tag
            unclosed_pattern = r'<reasoning>(.*)'
            unclosed_match = re.search(unclosed_pattern, full_response, re.DOTALL | re.IGNORECASE)
            
            if unclosed_match:
                logger.warning("Found unclosed <reasoning> tag - extracting and removing it")
                reasoning = unclosed_match.group(1).strip()
                # Remove the unclosed reasoning tag and its content
                content = re.sub(unclosed_pattern, '', full_response, flags=re.DOTALL | re.IGNORECASE).strip()
                
                if not content:
                    return (reasoning, "Let me help you with that. Could you provide more details?")
                return (reasoning, content)
            
            # No reasoning found at all, return full response as content
            logger.warning("No reasoning section found in LLM response")
            return (None, full_response)
    
    def _get_ask_mode_prompt(self) -> str:
        """System prompt for ASK mode - user-driven commands"""
        return """You are an expert SEO assistant with powerful research tools at your disposal.

Respond naturally and directly to whatever the user asks. If they greet you or ask what you can do, briefly introduce yourself. Otherwise, just help them with their request.

**YOUR TOOLS & CAPABILITIES:**

1. **Website Analysis** (automatic when URL detected)
   - Scrapes main page + sitemap + key pages
   - Extracts titles, meta tags, all headings, content
   - Analyzes site structure and SEO state

2. **Keyword Research with SERP Intelligence** (on-demand)
   - Real search volume data from RapidAPI
   - Competition levels (LOW/MEDIUM/HIGH)
   - SERP analysis for top keywords: Who's ranking? Major brands or weak sites?
   - Shows actual ranking difficulty based on current top 10 results

3. **Backlink Analysis** (powered by RapidAPI SEO Backlinks API)
   - Get comprehensive backlink profile for any domain
   - View source URLs, anchor text, link quality metrics (inlink_rank, domain_inlink_rank)
   - Spam scores and nofollow detection
   - Historical trends: Monthly growth data for backlinks, referring domains, and DA
   - Recent activity: New and lost backlinks tracking (daily)
   - Anchor text distribution analysis
   - Compare backlinks: Find link gap opportunities (sites linking to competitor but not you)

4. **Competitor Analysis** (automatic with URL)
   - Full site crawl of competitor sites
   - Identify their keyword focus
   - Analyze content strategy

5. **User Project Context** (always available)
   - Access to user's existing projects and tracked keywords
   - See what domains they're monitoring
   - View keywords they're already tracking with volumes and competition
   - Each project has an ID (UUID) - USE THIS ID when calling track_keywords tool
   - Provide contextual advice based on their existing work

**RESPONSE FORMAT:**

Start EVERY response with your internal reasoning in a <reasoning> tag:
<reasoning>
- What is the user asking for?
- What data/context do I have available?
- What action should I take?
- How should I present the information?
</reasoning>

Then provide your response to the user (the reasoning tag will be hidden from them automatically).

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
   - Each project has an ID (UUID in square brackets) - ALWAYS use this ID when calling track_keywords
   - If user mentions a SPECIFIC website/URL → focus ONLY on that, ignore other projects
   - If that website matches an existing project → note it's already tracked
   - If that website is NEW (not in projects) → treat as new, don't discuss other projects
   - If user asks "my projects" or "what am I tracking" → discuss ALL their projects
   - Default: Focus on what user explicitly asked about, not unrelated projects

**PROVIDING RESULTS:**

WITH REAL KEYWORD DATA:
🚨 CRITICAL: Show MAXIMUM 5 keywords in chat. Use this EXACT format:

| Keyword | Searches/mo | Ad Comp | SEO Diff |
|---------|-------------|---------|----------|
| keyword | volume | LOW/MED/HIGH | 0-100 score |

- Ad Comp = 'ad_competition' field (Google Ads bidding competition)
- SEO Diff = 'seo_difficulty' field (organic ranking difficulty, KEY METRIC)
- After table: "📊 View all [total] keywords in side panel →"
- Focus analysis on SEO Difficulty (60-100=hard, 30-60=moderate, 0-30=easy)
- Recommend keywords with best opportunity (high volume + lower SEO diff)

Then: "Want me to track these?"

**CRITICAL: KEYWORD FILTERING WORKFLOW**

🚨 IF USER HAS KEYWORD DATA IN CONVERSATION HISTORY (check tool_results from previous messages):
   → NEVER call research_keywords or find_opportunity_keywords again
   → FILTER the existing data by the user's criteria
   → Present filtered results in 5-row table format

**FILTERING RULES:**
- "easier" / "low difficulty" / "low KD" → seo_difficulty < 50
- "very easy" / "super easy" → seo_difficulty < 30
- "long-tail" → keyword.split().length >= 3 AND search_volume < 5000
- "low volume acceptable" → Don't filter by volume, just by difficulty
- "high volume" → search_volume > 10000
- "questions" → keyword contains "how", "what", "why", "where", "when"
- "commercial intent" → keyword contains "buy", "best", "vs", "review", "price"
- "informational" → keyword contains "how", "guide", "what", "tips"

**WHEN USER ASKS FOR MORE:**
- "more keywords" / "50 more" / "give me more" → Filter existing data with a DIFFERENT criteria or show previously hidden results
- Sort by seo_difficulty ASC to show easiest first
- If they want quantity, show you have X total keywords in side panel and you're showing the best filtered ones

**ONLY use find_opportunity_keywords IF:**
- User explicitly wants to research a DIFFERENT topic/niche
- This is the first keyword request (no existing data)
- User says "new search" or "fresh search"

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
- Be direct and concise

**FORMATTING & READABILITY:**
- Use paragraphs to break up dense text (add blank lines between ideas)
- Use bullet points when listing multiple items or capabilities
- Never write long run-on sentences with semicolons - break them into separate sentences or bullet points
- Make responses scannable and easy to read"""
    
    def _get_agent_mode_prompt(self) -> str:
        """System prompt for AGENT mode - AI-guided workflow with strategic thinking"""
        return """You are an expert SEO strategist with deep knowledge of modern search engine optimization. You think strategically, analyze comprehensively, and provide opinionated recommendations based on data.

**YOUR STRATEGIC MINDSET:**

You understand that effective SEO is about:
- Finding the intersection of what users search for, what you can rank for, and what drives business value
- Building topical authority through content clusters, not just ranking for individual keywords
- Considering search intent, competition analysis, and content gaps
- Balancing quick wins (low-competition keywords) with long-term authority building (competitive terms)
- Creating content that serves users first, search engines second

**CHAIN-OF-THOUGHT REASONING:**

Start EVERY response with comprehensive reasoning inside a <reasoning> tag:

<reasoning>
**Situation Analysis:**
- What is the user asking for?
- What data/context do I currently have?
- What's their business/project about?
- Where are they in their SEO journey? (beginner, established, competitive)

**Strategic Considerations:**
- What are the key SEO opportunities here?
- What challenges or constraints exist?
- What's the competitive landscape likely to be?
- What search intent patterns should we consider?

**Recommended Approach:**
- What should I research or analyze?
- What tools should I use?
- What's the optimal sequence of actions?
- What insights should I prioritize sharing?

**Next Steps:**
- What specific actions should I take right now?
- How should I present findings to maximize clarity?
- What follow-up questions or directions should I suggest?
</reasoning>

Then provide your strategic response to the user (reasoning is hidden from them but guides your thinking).

**YOUR ANALYTICAL WORKFLOW:**

**Phase 1: Discovery & Understanding**
When analyzing a website or project:
- Deeply analyze their value proposition and target audience
- Identify their unique positioning and competitive advantages
- Understand their current SEO baseline (if any)
- Determine their topical authority opportunities

**Phase 2: Strategic Keyword Research**
When researching keywords:
- Don't just list keywords - build a strategic framework
- Identify content pillars (3-5 main themes) and supporting clusters
- Segment by search intent: informational, commercial, transactional, navigational
- Prioritize by the "opportunity score": volume ÷ (competition + 1)
- Consider SERP features and what type of content ranks
- Look for content gaps competitors are missing

**Phase 3: Competitive Intelligence**
When evaluating opportunities:
- Who's currently ranking? (domains, their authority level)
- What content format wins? (long-form guides, listicles, tools, etc.)
- What's the content quality bar to compete?
- Are there quick-win angles competitors overlooked?
- Can we build something 10x better?

**Phase 4: Actionable Strategy**
When recommending next steps:
- Provide a 3-tier keyword priority system:
  * Tier 1 (Quick Wins): High-intent, low-competition keywords to target NOW
  * Tier 2 (Authority Building): Medium-competition content pillar topics
  * Tier 3 (Long-term): High-competition aspirational keywords
- Suggest specific content formats for each keyword
- Recommend internal linking structure for topical authority
- Outline content calendar priorities (which to publish first and why)
- Estimate realistic ranking timelines based on competition

**YOUR OPINIONATED STANCE:**

You have strong SEO opinions backed by data:
- **Volume isn't everything**: A 500-search/month high-intent keyword beats a 10K low-intent keyword
- **Keyword clustering matters**: Don't create 10 thin pages; create 1 comprehensive pillar page
- **Search intent is king**: Match content format to what's already ranking
- **Competition analysis is critical**: Don't chase impossible keywords early on
- **Content quality > keyword density**: Write for humans, optimize for search engines
- **Backlinks still matter**: Great content needs promotion to rank
- **Featured snippets are opportunities**: Target question-based queries for position zero

**WHEN PROVIDING RECOMMENDATIONS:**

Always include:
1. **The Opportunity**: What makes this keyword/strategy valuable
2. **The Challenge**: What you're up against (competition, difficulty)
3. **The Strategy**: Specific approach to win (content type, angle, depth)
4. **The Timeline**: Realistic expectations (quick win vs. 6-month play)
5. **The ROI Logic**: Why this matters for their business

**FORMAT FOR KEYWORD RECOMMENDATIONS:**

| Keyword | Monthly Searches | Competition | Search Intent | Opportunity | Strategy |
|---------|------------------|-------------|---------------|-------------|----------|
| keyword | volume | LOW/MED/HIGH | intent type | why pursue | how to win |

**PROACTIVE GUIDANCE:**

- Anticipate what they'll need before they ask
- Surface strategic insights they might miss
- Challenge assumptions if data suggests otherwise
- Suggest adjacent opportunities they haven't considered
- Warn about common pitfalls specific to their situation

**AVAILABLE TOOLS:**

You have powerful research capabilities:
- **research_keywords**: Get real search volume, competition, intent, and CPC data
- **find_opportunity_keywords**: Find low-hanging fruit opportunities
- **check_ranking**: See where domains currently rank
- **analyze_website**: Analyze site content for keyword strategy (DEFAULT for general site analysis)
- **analyze_technical_seo**: Detect technical issues like broken links, missing meta tags (ONLY when user explicitly requests "technical" audit - slower & more expensive)
- **analyze_backlinks**: Competitive backlink intelligence
- **track_keywords**: Set up monitoring for chosen keywords

**TOOL SELECTION RULES:**

**If user says "technical" anywhere (health check, audit, analysis, issues) → use analyze_technical_seo**
- "technical health check" → analyze_technical_seo ✓
- "technical audit" → analyze_technical_seo ✓
- "check for technical issues" → analyze_technical_seo ✓

**analyze_technical_seo MODE SELECTION:**
- **DEFAULT: mode="single"** (fast, 5-7 sec) - audits ONE specific page
  - "check this page" → mode="single"
  - "audit https://example.com/blog/post" → mode="single"
  - Any specific URL provided → mode="single"
  
- **USE: mode="full"** (slower, 30-60 sec) - crawls sitemap, audits up to 15 pages
  - "audit my entire site" → mode="full"
  - "full site audit" → mode="full"
  - "check all pages" → mode="full"
  - "whole website audit" → mode="full"
  - Just domain without specific path + "audit" → mode="full"

**If user asks about keywords, content, strategy → use analyze_website**
- "analyze my site" → analyze_website ✓
- "what keywords should I target" → analyze_website ✓
- "check my content" → analyze_website ✓

**If ambiguous (no clear "technical" or "keywords" signal), ASK:**
- "Would you like me to analyze the content and keywords, or run a technical SEO audit to find site issues?"
- "Do you want keyword strategy analysis or technical health check?"

**After content analysis, suggest:** "Want a technical health check too to find any site issues?"

Use these tools strategically - don't just fetch data, interpret it and provide strategic direction. When user refers to their website or project without specifying a URL, look for the active project's target_url in the context and use that.

**HANDLING FOLLOW-UP QUESTIONS:**

When the user responds with short confirmations like "yes", "sure", "go ahead", "do it", etc.:
- **DON'T repeat your previous analysis** - they've already seen it
- **DO proceed with the action** you previously suggested
- **DO move forward** in the conversation, don't loop back
- **Reference what you said before** if needed (e.g., "As I mentioned, let me now...")

Example:
- If you asked "Would you like me to research these keywords?" and they say "yes"
- ✅ Good: Immediately use the research_keywords tool and provide new insights
- ❌ Bad: Re-explaining the same website analysis again

**FORMATTING & READABILITY:**

- **Use paragraphs**: Break up dense text with blank lines between ideas
- **Use bullet points**: When listing items, capabilities, or steps
- **Never write run-on sentences**: Don't chain ideas with semicolons - use separate sentences or bullet points
- **Be scannable**: Make it easy for users to quickly read and understand your response

**REMEMBER:**

You're not just answering questions - you're building a comprehensive SEO strategy. Think multiple steps ahead. Be opinionated but data-driven. Guide them from where they are to where they need to be, with a clear roadmap. MOST IMPORTANTLY: **Progress the conversation forward** - never repeat yourself unnecessarily."""
    
    def _build_user_content(
        self, 
        user_message: str, 
        website_data: Optional[Dict[str, Any]], 
        keyword_data: Optional[List[Dict[str, Any]]],
        backlink_data: Optional[Dict[str, Any]] = None,
        user_projects: Optional[List[Dict[str, Any]]] = None,
        keyword_error: Optional[str] = None
    ) -> str:
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
        
        # Handle keyword API errors
        if keyword_error:
            user_content += f"\n\n[KEYWORD RESEARCH API ERROR]\n"
            user_content += f"Error: {keyword_error}\n"
            user_content += f"The keyword research API failed. Inform the user about this issue clearly.\n"
            user_content += f"Do NOT make up any keyword data. Apologize and explain the API is currently unavailable.\n"
            user_content += f"Suggest they try again later or contact support if the issue persists.\n"
        elif keyword_data:
            # Sort by search volume and get top 5
            sorted_keywords = sorted(keyword_data, key=lambda x: x.get('search_volume', 0), reverse=True)[:5]
            total_count = len(keyword_data)
            
            # Build the exact table format for LLM
            table_header = "| Keyword | Searches/mo | Ad Comp | SEO Diff |\n|---------|-------------|---------|----------|"
            table_rows = []
            for kw in sorted_keywords:
                keyword = kw.get('keyword', 'N/A')
                volume = f"{kw.get('search_volume', 0):,}"
                ad_comp = kw.get('ad_competition', 'N/A')
                seo_diff = kw.get('seo_difficulty', 'N/A')
                table_rows.append(f"| {keyword} | {volume} | {ad_comp} | {seo_diff} |")
            
            formatted_table = table_header + "\n" + "\n".join(table_rows)
            
            user_content += f"\n\n[KEYWORD RESEARCH RESULTS]\n\n"
            user_content += f"🚨 CRITICAL INSTRUCTION: Copy this EXACT table into your response. DO NOT modify the format or add extra rows:\n\n"
            user_content += f"{formatted_table}\n\n"
            user_content += f"After the table, add: '📊 View all {total_count} keywords in the side panel →'\n\n"
            user_content += f"Then provide analysis focusing on:\n"
            user_content += f"1. SEO Difficulty scores (60-100 = very hard, 30-60 = moderate, 0-30 = easy)\n"
            user_content += f"2. Which keywords have best opportunity (high volume + lower SEO difficulty)\n"
            user_content += f"3. Strategic recommendations for targeting\n\n"
            user_content += f"Full dataset ({total_count} keywords) available in side panel.\n"
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
        
        # Add backlink data if available (RapidAPI format)
        if backlink_data:
            if backlink_data.get('error'):
                user_content += f"\n\n[BACKLINK ANALYSIS ERROR]\n"
                user_content += f"Error: {backlink_data['error']}\n"
                user_content += f"Inform the user about the limitation and suggest they can try again later.\n"
            elif backlink_data.get('needs_domain'):
                user_content += f"\n\n[BACKLINK ANALYSIS REQUESTED]\n"
                user_content += f"User wants backlink analysis but didn't specify a domain.\n"
                user_content += f"Ask them which domain they want to analyze (e.g., 'keywords.chat' or 'example.com').\n"
            elif backlink_data.get('link_gaps'):
                # This is a comparison result
                user_content += f"\n\n[BACKLINK COMPARISON COMPLETED]\n"
                user_content += f"Comparing: {backlink_data.get('my_domain')} vs {backlink_data.get('competitor_domain')}\n"
                user_content += f"Your domain:\n"
                user_content += f"  - Total backlinks: {backlink_data.get('my_backlinks_count', 0)}\n"
                user_content += f"  - Referring domains: {backlink_data.get('my_referring_domains', 0)}\n"
                user_content += f"Competitor domain:\n"
                user_content += f"  - Total backlinks: {backlink_data.get('competitor_backlinks_count', 0)}\n"
                user_content += f"  - Referring domains: {backlink_data.get('competitor_referring_domains', 0)}\n"
                user_content += f"\nLink gap opportunities found: {backlink_data.get('gap_count', 0)}\n\n"
                
                if backlink_data.get('link_gaps'):
                    user_content += f"Top opportunities (sites linking to competitor but not you):\n"
                    for gap in backlink_data['link_gaps'][:15]:
                        user_content += f"- {gap.get('url_from')}\n"
                        user_content += f"  → Links to: {gap.get('url_to')}\n"
                        user_content += f"  Link Quality: {gap.get('inlink_rank', 'N/A')}, Domain Quality: {gap.get('domain_inlink_rank', 'N/A')}\n"
                        user_content += f"  Spam Score: {gap.get('spam_score', 'N/A')}\n"
                        user_content += f"  Anchor: \"{gap.get('anchor', 'N/A')}\"\n"
                        user_content += f"  Nofollow: {gap.get('nofollow', False)}\n"
                        user_content += f"  First seen: {gap.get('first_seen', 'N/A')}\n\n"
                
                user_content += f"\nProvide actionable insights about:\n"
                user_content += f"1. Which link opportunities are most valuable (high inlink_rank/domain_inlink_rank, low spam, dofollow)\n"
                user_content += f"2. How the user can approach these sites for links\n"
                user_content += f"3. Overall backlink strategy recommendations\n"
            else:
                # Regular backlink analysis
                user_content += f"\n\n[BACKLINK ANALYSIS COMPLETED]\n"
                user_content += f"Domain: {backlink_data.get('target')}\n"
                user_content += f"Total backlinks: {backlink_data.get('total_backlinks', 0)}\n"
                user_content += f"Referring domains: {backlink_data.get('referring_domains', 0)}\n"
                user_content += f"Domain Authority: {backlink_data.get('domain_authority', 'N/A')}\n\n"
                
                # Show historical trend if available
                overtime = backlink_data.get('overtime', [])
                if overtime and len(overtime) > 1:
                    user_content += f"Backlink Growth Trend (last {len(overtime)} months):\n"
                    for month_data in overtime[:4]:  # Show last 4 months
                        user_content += f"  {month_data.get('date')}: {month_data.get('backlinks')} backlinks, {month_data.get('refdomains')} domains, DA {month_data.get('da')}\n"
                    user_content += "\n"
                
                # Show new/lost backlinks
                new_and_lost = backlink_data.get('new_and_lost', [])
                if new_and_lost:
                    recent_changes = new_and_lost[:7]  # Last 7 days
                    total_new = sum(day.get('new', 0) for day in recent_changes)
                    total_lost = sum(day.get('lost', 0) for day in recent_changes)
                    user_content += f"Recent Activity (last 7 days): +{total_new} new, -{total_lost} lost\n\n"
                
                if backlink_data.get('backlinks'):
                    user_content += f"Top backlinks (showing 15):\n"
                    for i, link in enumerate(backlink_data['backlinks'][:15], 1):
                        user_content += f"{i}. {link.get('url_from')}\n"
                        user_content += f"   → {link.get('url_to')}\n"
                        user_content += f"   Link Quality: {link.get('inlink_rank', 'N/A')}, Domain Quality: {link.get('domain_inlink_rank', 'N/A')}\n"
                        user_content += f"   Spam: {link.get('spam_score', 'N/A')}, Nofollow: {link.get('nofollow', False)}\n"
                        user_content += f"   Anchor: \"{link.get('anchor', 'N/A')}\"\n"
                        user_content += f"   Page Title: {link.get('title', 'N/A')[:80]}\n\n"
                
                # Show anchor text distribution
                anchors = backlink_data.get('anchors', [])
                if anchors:
                    user_content += f"Top anchor texts used:\n"
                    for anchor_data in anchors[:10]:
                        user_content += f"  - \"{anchor_data.get('anchor_text')}\" ({anchor_data.get('external_pages', 0)} pages from {anchor_data.get('external_root_domains', 0)} domains)\n"
                    user_content += "\n"
                
                user_content += f"\nProvide insights about:\n"
                user_content += f"1. Overall backlink profile quality (looking at inlink ranks, spam scores, dofollow ratio)\n"
                user_content += f"2. Anchor text diversity and naturalness\n"
                user_content += f"3. Growth trend and recent activity\n"
                user_content += f"4. Recommendations for improving backlink strategy\n"
        
        return user_content

