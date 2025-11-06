from fastapi import APIRouter, HTTPException, Depends, Header
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Optional, AsyncIterator
import uuid
import re
import logging
import httpx
import json
import asyncio

from ..database import get_db
from ..models.user import User
from ..models.conversation import Conversation, Message
from ..models.project import Project, TrackedKeyword
from ..models.pin import PinnedItem
from ..services.keyword_service import KeywordService
from ..services.llm_service import LLMService
from ..services.rank_checker import RankCheckerService
from ..services.rapidapi_backlinks_service import RapidAPIBacklinkService
from ..services.dataforseo_backlinks_service import DataForSEOBacklinksService
from ..services.web_scraper import WebScraperService
from ..services.gsc_service import GSCService
from ..models.backlink_analysis import BacklinkAnalysis
from ..models.project import KeywordRanking
from .auth import get_current_user

router = APIRouter(prefix="/chat", tags=["chat"])
logger = logging.getLogger(__name__)

keyword_service = KeywordService()
llm_service = LLMService()
rank_checker = RankCheckerService()
backlink_service = RapidAPIBacklinkService()
dataforseo_backlink_service = DataForSEOBacklinksService()
web_scraper = WebScraperService()
gsc_service = GSCService()

class ChatRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None
    mode: Optional[str] = "ask"  # "ask" or "agent"

class ChatResponse(BaseModel):
    message: str
    conversation_id: str

class ConversationListItem(BaseModel):
    id: str
    title: str
    created_at: str
    message_count: int
    project_names: List[str] = []

async def send_sse_event(event_type: str, data: dict) -> str:
    """Format data as Server-Sent Event"""
    return f"event: {event_type}\ndata: {json.dumps(data)}\n\n"

@router.post("/message/stream")
async def send_message_stream(
    request: ChatRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Send a message and get streaming status updates via SSE"""
    
    async def event_generator() -> AsyncIterator[str]:
        try:
            # Extract token from Authorization header
            token = authorization.replace("Bearer ", "")
            user = get_current_user(token, db)
            
            # Send initial status
            yield await send_sse_event("status", {"message": "Thinking..."})
            
            # Create or get conversation
            if request.conversation_id:
                conversation = db.query(Conversation).filter(
                    Conversation.id == request.conversation_id,
                    Conversation.user_id == user.id
                ).first()
                
                if not conversation:
                    yield await send_sse_event("error", {"message": "Conversation not found"})
                    return
            else:
                # Create new conversation
                conversation = Conversation(
                    id=str(uuid.uuid4()),
                    user_id=user.id,
                    title=request.message[:50]
                )
                db.add(conversation)
                db.commit()
                db.refresh(conversation)
            
            # Save user message
            user_message = Message(
                id=str(uuid.uuid4()),
                conversation_id=conversation.id,
                role="user",
                content=request.message
            )
            db.add(user_message)
            db.commit()
            
            # Get conversation history
            messages = db.query(Message).filter(
                Message.conversation_id == conversation.id
            ).order_by(Message.created_at).all()
            
            conversation_history = []
            for msg in messages[:-1]:
                content = msg.content
                if msg.role == "assistant" and msg.message_metadata and msg.message_metadata.get("reasoning"):
                    reasoning = msg.message_metadata["reasoning"]
                    content = f"<reasoning>{reasoning}</reasoning>\n\n{content}"
                conversation_history.append({"role": msg.role, "content": content})
            
            # Get user's projects for context
            user_projects = db.query(Project).filter(Project.user_id == user.id).all()
            user_projects_data = []
            for project in user_projects:
                tracked_keywords = db.query(TrackedKeyword).filter(
                    TrackedKeyword.project_id == project.id
                ).all()
                user_projects_data.append({
                    'id': project.id,
                    'name': project.name,
                    'target_url': project.target_url,
                    'tracked_keywords': [
                        {'keyword': kw.keyword, 'search_volume': kw.search_volume, 
                         'competition': kw.competition, 'target_position': kw.target_position}
                        for kw in tracked_keywords
                    ]
                })
            
            # Define available tools
            tools = [
                {
                    "type": "function",
                    "function": {
                        "name": "research_keywords",
                        "description": "Research keywords with search volume, competition level, and SERP analysis. Use when user wants keyword data for a topic/niche. Supports both topic keywords and URL analysis (automatically detects URLs). Can search globally or for specific locations.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "keyword_or_topic": {
                                    "type": "string",
                                    "description": "The keyword/topic to research (e.g., 'AI chatbots', 'SEO software') OR a URL (e.g., 'example.com', 'https://example.com')"
                                },
                                "location": {
                                    "type": "string",
                                    "description": "Search scope: 'global' for worldwide data, or country code like 'US', 'UK', 'CA', 'AU' for location-specific data. Default is 'US'.",
                                    "default": "US"
                                },
                                "limit": {
                                    "type": "integer",
                                    "description": "Number of keywords to return (default 10)",
                                    "default": 10
                                }
                            },
                            "required": ["keyword_or_topic"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "find_opportunity_keywords",
                        "description": "Find opportunity keywords (high-potential, low-competition keywords that are easier to rank for). Use when user asks for 'easy to rank', 'low competition', 'opportunity', or 'quick wins' keywords. Note: Only supports location-specific searches (not global).",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "keyword": {
                                    "type": "string",
                                    "description": "The seed keyword to find opportunities for"
                                },
                                "location": {
                                    "type": "string",
                                    "description": "Country code like 'US', 'UK', 'CA', 'AU' for location-specific data. Default is 'US'. (Global not supported for opportunity keywords)",
                                    "default": "US"
                                },
                                "limit": {
                                    "type": "integer",
                                    "description": "Number of opportunity keywords to return (default 10)",
                                    "default": 10
                                }
                            },
                            "required": ["keyword"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "check_ranking",
                        "description": "Check where a specific domain ranks in Google for a keyword. Returns position (1-100) or None if not ranking.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "keyword": {
                                    "type": "string",
                                    "description": "The keyword to check rankings for"
                                },
                                "domain": {
                                    "type": "string",
                                    "description": "Domain to check (e.g., 'example.com')"
                                }
                            },
                            "required": ["keyword", "domain"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "analyze_website",
                        "description": "Crawl and analyze a website's SEO. Extracts title, meta description, headings, content, and provides SEO recommendations.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "url": {
                                    "type": "string",
                                    "description": "Full URL of the website to analyze (e.g., 'https://example.com')"
                                }
                            },
                            "required": ["url"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "analyze_backlinks",
                        "description": "Analyze backlink profile for a domain. Returns total backlinks, referring domains, domain authority, and top backlinks.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "domain": {
                                    "type": "string",
                                    "description": "Domain to analyze without http:// (e.g., 'example.com')"
                                }
                            },
                            "required": ["domain"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "track_keywords",
                        "description": "Add keywords to a project's keyword tracker for rank tracking. Use when user wants to track/monitor keywords for their project. Requires a project_id.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "project_id": {
                                    "type": "string",
                                    "description": "The ID of the project to add keywords to"
                                },
                                "keywords": {
                                    "type": "array",
                                    "description": "Array of keywords to track. Each keyword should include the keyword text and optionally search volume and competition.",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "keyword": {
                                                "type": "string",
                                                "description": "The keyword text"
                                            },
                                            "search_volume": {
                                                "type": "integer",
                                                "description": "Monthly search volume (optional)"
                                            },
                                            "competition": {
                                                "type": "string",
                                                "description": "Competition level: LOW, MEDIUM, or HIGH (optional)"
                                            }
                                        },
                                        "required": ["keyword"]
                                    }
                                }
                            },
                            "required": ["project_id", "keywords"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "pin_important_info",
                        "description": "Pin important information, insights, or responses to the pinboard for later reference. Use this when the user wants to save something important, bookmark key findings, or keep track of valuable insights from your analysis.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "title": {
                                    "type": "string",
                                    "description": "A concise title for the pinned item (max 100 characters)"
                                },
                                "content": {
                                    "type": "string",
                                    "description": "The content to pin (can be insights, analysis, recommendations, or any important information)"
                                },
                                "content_type": {
                                    "type": "string",
                                    "enum": ["insight", "analysis", "recommendation", "note", "finding"],
                                    "description": "Type of content being pinned",
                                    "default": "insight"
                                },
                                "project_id": {
                                    "type": "string",
                                    "description": "Optional project ID to associate this pin with a specific project"
                                }
                            },
                            "required": ["title", "content"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "analyze_project_status",
                        "description": "Load complete project data and analyze SEO progress. Use this when user asks about a specific project, wants to 'work on SEO strategy', or asks 'how is my project doing'. Returns keywords with current rankings, historical progress, backlink profile, and overall assessment. ALWAYS use this first when discussing an existing project.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "project_id": {
                                    "type": "string",
                                    "description": "The ID of the project to analyze"
                                }
                            },
                            "required": ["project_id"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_gsc_performance",
                        "description": "Get real Google Search Console data for a project - actual clicks, impressions, CTR, and average position from Google. Use this to see real performance data (not estimates), check indexing status, or analyze sitemap issues. Only works if user has connected their Google Search Console and linked the project to a GSC property.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "project_id": {
                                    "type": "string",
                                    "description": "The ID of the project to get GSC data for"
                                },
                                "data_type": {
                                    "type": "string",
                                    "enum": ["overview", "queries", "pages", "sitemaps", "indexing"],
                                    "description": "Type of GSC data to retrieve: 'overview' (summary stats), 'queries' (top keywords), 'pages' (top pages), 'sitemaps' (sitemap status), 'indexing' (indexing coverage)",
                                    "default": "overview"
                                },
                                "limit": {
                                    "type": "integer",
                                    "description": "For 'queries' or 'pages', number of results to return (default 20)",
                                    "default": 20
                                }
                            },
                            "required": ["project_id"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "link_gsc_property",
                        "description": "Link a project to a Google Search Console property. Use this when user wants to connect their project to GSC or when GSC data retrieval fails because no property is linked. Lists available GSC properties and links the selected one to the project.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "project_id": {
                                    "type": "string",
                                    "description": "The ID of the project to link"
                                },
                                "property_url": {
                                    "type": "string",
                                    "description": "Optional: The GSC property URL to link (e.g., 'https://example.com/' or 'sc-domain:example.com'). If not provided, will list available properties for user to choose from."
                                }
                            },
                            "required": ["project_id"]
                        }
                    }
                }
            ]

            # First LLM call
            response_text, reasoning, tool_calls = await llm_service.chat_with_tools(
                user_message=request.message,
                conversation_history=conversation_history,
                available_tools=tools,
                user_projects=user_projects_data if user_projects_data else None,
                mode=request.mode or "ask"
            )
            
            # Execute tool calls with status updates
            if tool_calls:
                tool_results = []
                
                for tool_call in tool_calls:
                    tool_name = tool_call["name"]
                    args = tool_call["arguments"]
                    
                    # Send status based on tool being called
                    if tool_name == "research_keywords":
                        yield await send_sse_event("status", {"message": "Researching keywords..."})
                    elif tool_name == "find_opportunity_keywords":
                        yield await send_sse_event("status", {"message": "Finding opportunity keywords..."})
                    elif tool_name == "check_ranking":
                        yield await send_sse_event("status", {"message": "Checking rankings..."})
                    elif tool_name == "analyze_website":
                        yield await send_sse_event("status", {"message": "Analyzing website..."})
                    elif tool_name == "analyze_backlinks":
                        yield await send_sse_event("status", {"message": "Analyzing backlinks..."})
                    elif tool_name == "track_keywords":
                        yield await send_sse_event("status", {"message": "Adding keywords to tracker..."})
                    elif tool_name == "pin_important_info":
                        yield await send_sse_event("status", {"message": "Pinning important information..."})
                    elif tool_name == "analyze_project_status":
                        yield await send_sse_event("status", {"message": "Loading project data..."})
                    elif tool_name == "get_gsc_performance":
                        yield await send_sse_event("status", {"message": "Fetching Google Search Console data..."})
                    elif tool_name == "link_gsc_property":
                        yield await send_sse_event("status", {"message": "Linking GSC property..."})
                    
                    try:
                        if tool_name == "research_keywords":
                            keyword_or_topic = args.get("keyword_or_topic")
                            location = args.get("location", "US")
                            limit = args.get("limit", 10)
                            
                            keyword_data = await keyword_service.analyze_keywords(keyword_or_topic, location=location, limit=limit)
                            
                            # Enrich with SERP analysis
                            serp_rate_limited = False
                            serp_success_count = 0
                            if keyword_data:
                                for keyword_item in keyword_data[:5]:
                                    keyword = keyword_item.get('keyword')
                                    if keyword:
                                        try:
                                            serp_analysis = await rank_checker.get_serp_analysis(keyword)
                                            if serp_analysis:
                                                keyword_item['serp_analysis'] = serp_analysis['analysis']
                                                keyword_item['serp_insight'] = serp_analysis['insight']
                                                serp_success_count += 1
                                        except httpx.HTTPStatusError as e:
                                            if e.response.status_code == 429:
                                                serp_rate_limited = True
                            
                            response_data = {
                                "keywords": keyword_data,
                                "total_found": len(keyword_data) if keyword_data else 0,
                                "serp_analysis_available": serp_success_count > 0,
                                "serp_analysis_count": serp_success_count
                            }
                            
                            if serp_rate_limited:
                                response_data["warning"] = "SERP analysis unavailable: API rate limit reached. Keyword data is still accurate, but ranking difficulty analysis is limited. Rate limits reset daily."
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": str(response_data)
                            })
                        
                        elif tool_name == "find_opportunity_keywords":
                            keyword = args.get("keyword")
                            location = args.get("location", "US")
                            limit = args.get("limit", 10)
                            
                            opportunity_data = await keyword_service.get_opportunity_keywords(keyword, location=location, num=limit)
                            
                            if opportunity_data:
                                processed_data = []
                                for item in opportunity_data:
                                    volume = item.get("volume", 0)
                                    competition = item.get("competition_level", "UNKNOWN")
                                    avg_cpc = (item.get("low_bid", 0) + item.get("high_bid", 0)) / 2 if item.get("high_bid") else 0
                                    
                                    processed_data.append({
                                        "keyword": item.get("text", ""),
                                        "search_volume": volume,
                                        "competition": competition,
                                        "competition_index": item.get("competition_index", 0),
                                        "cpc": round(avg_cpc, 2),
                                        "trend": item.get("trend", 0),
                                        "intent": item.get("intent", "unknown"),
                                        "opportunity_score": "HIGH"
                                    })
                                
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": str(processed_data)
                                })
                            else:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": "[]"
                                })
                        
                        elif tool_name == "check_ranking":
                            keyword = args.get("keyword")
                            domain = args.get("domain")
                            
                            ranking_data = await rank_checker.check_ranking(keyword, domain)
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": str(ranking_data)
                            })
                        
                        elif tool_name == "analyze_website":
                            url = args.get("url")
                            
                            website_data = await web_scraper.analyze_full_site(url)
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": str(website_data)
                            })
                        
                        elif tool_name == "analyze_backlinks":
                            domain = args.get("domain")
                            
                            if user.backlink_rows_used >= user.backlink_rows_limit:
                                error_msg = f"Backlink limit reached ({user.backlink_rows_limit}/month)"
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": f"ERROR: {error_msg}"
                                })
                            else:
                                backlink_data = await backlink_service.get_backlinks(domain, limit=50)
                                
                                if backlink_data and not backlink_data.get("error"):
                                    user.backlink_rows_used += 1
                                    db.commit()
                                
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": str(backlink_data)
                                })
                        
                        elif tool_name == "track_keywords":
                            project_id = args.get("project_id")
                            keywords_to_track = args.get("keywords", [])
                            
                            # Verify project exists and belongs to user
                            project = db.query(Project).filter(
                                Project.id == project_id,
                                Project.user_id == user.id
                            ).first()
                            
                            if not project:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": "ERROR: Project not found"
                                })
                            else:
                                tracked_count = 0
                                skipped_count = 0
                                errors = []
                                
                                for kw_data in keywords_to_track:
                                    keyword = kw_data.get("keyword")
                                    if not keyword:
                                        continue
                                    
                                    # Check if keyword already tracked
                                    existing = db.query(TrackedKeyword).filter(
                                        TrackedKeyword.project_id == project_id,
                                        TrackedKeyword.keyword == keyword
                                    ).first()
                                    
                                    if existing:
                                        skipped_count += 1
                                        continue
                                    
                                    try:
                                        # Add keyword to tracker immediately (don't wait for ranking)
                                        tracked_keyword = TrackedKeyword(
                                            id=str(uuid.uuid4()),
                                            project_id=project_id,
                                            keyword=keyword,
                                            search_volume=kw_data.get("search_volume"),
                                            competition=kw_data.get("competition")
                                        )
                                        db.add(tracked_keyword)
                                        tracked_count += 1
                                        
                                        # Note: Initial ranking will be checked on first manual refresh
                                        # This keeps the response fast and non-blocking
                                        
                                    except Exception as e:
                                        errors.append(f"{keyword}: {str(e)}")
                                
                                db.commit()
                                
                                result_msg = f"Successfully tracked {tracked_count} keyword(s). Rankings will be checked on next refresh."
                                if skipped_count > 0:
                                    result_msg += f" Skipped {skipped_count} already tracked."
                                if errors:
                                    result_msg += f" Errors: {', '.join(errors)}"
                                
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": result_msg
                                })
                    
                        elif tool_name == "pin_important_info":
                            title = args.get("title")
                            content = args.get("content")
                            content_type = args.get("content_type", "insight")
                            project_id = args.get("project_id")

                            # Validate required fields
                            if not title or not content:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": "ERROR: Both title and content are required"
                                })
                            else:
                                # Verify project_id if provided
                                if project_id:
                                    project = db.query(Project).filter(
                                        Project.id == project_id,
                                        Project.user_id == user.id
                                    ).first()
                                    if not project:
                                        tool_results.append({
                                            "tool_call_id": tool_call["id"],
                                            "role": "tool",
                                            "name": tool_name,
                                            "content": "ERROR: Project not found"
                                        })
                                        continue

                                # Create the pinned item
                                pinned_item = PinnedItem(
                                    id=str(uuid.uuid4()),
                                    user_id=user.id,
                                    project_id=project_id,
                                    content_type=content_type,
                                    title=title[:100],  # Truncate to max length
                                    content=content,
                                    source_message_id=None,  # AI-generated pins don't have a source message
                                    source_conversation_id=conversation.id
                                )

                                db.add(pinned_item)
                                db.commit()

                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": f"Successfully pinned '{title}' to the pinboard"
                                })
                        
                        elif tool_name == "analyze_project_status":
                            project_id = args.get("project_id")
                            
                            # Get project
                            project = db.query(Project).filter(
                                Project.id == project_id,
                                Project.user_id == user.id
                            ).first()
                            
                            if not project:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": "ERROR: Project not found"
                                })
                                continue
                            
                            # Load complete project data
                            logger.info(f"📊 Loading complete data for project: {project.name}")
                            
                            # 1. Get tracked keywords with rankings
                            tracked_keywords = db.query(TrackedKeyword).filter(
                                TrackedKeyword.project_id == project_id
                            ).all()
                            
                            keywords_data = []
                            for kw in tracked_keywords:
                                # Get all rankings for this keyword
                                rankings = db.query(KeywordRanking).filter(
                                    KeywordRanking.tracked_keyword_id == kw.id
                                ).order_by(KeywordRanking.checked_at.desc()).limit(30).all()
                                
                                current_position = rankings[0].position if rankings else None
                                current_page = rankings[0].page_url if rankings else None
                                
                                # Calculate progress (compare first vs latest)
                                progress = None
                                if len(rankings) >= 2:
                                    oldest_pos = rankings[-1].position
                                    current_pos = rankings[0].position
                                    if oldest_pos and current_pos:
                                        progress = oldest_pos - current_pos  # Positive = improvement
                                
                                keywords_data.append({
                                    "keyword": kw.keyword,
                                    "search_volume": kw.search_volume,
                                    "competition": kw.competition,
                                    "target_position": kw.target_position,
                                    "target_page": kw.target_page,
                                    "current_position": current_position,
                                    "ranking_page": current_page,
                                    "is_correct_page": kw.target_page in (current_page or '') if kw.target_page else (current_page is not None),
                                    "progress": progress,
                                    "ranking_history": [{"position": r.position, "date": r.checked_at.isoformat()} for r in rankings[:10]]
                                })
                            
                            # 2. Get backlink analysis
                            backlink_analysis = db.query(BacklinkAnalysis).filter(
                                BacklinkAnalysis.project_id == project_id
                            ).first()
                            
                            backlinks_summary = None
                            if backlink_analysis:
                                backlinks_summary = {
                                    "total_backlinks": backlink_analysis.total_backlinks,
                                    "referring_domains": backlink_analysis.referring_domains,
                                    "domain_authority": backlink_analysis.domain_authority,
                                    "analyzed_at": backlink_analysis.analyzed_at.isoformat(),
                                    "recent_backlinks": backlink_analysis.raw_data.get("backlinks", [])[:10] if backlink_analysis.raw_data else []
                                }
                            
                            # 3. Format comprehensive report
                            report = {
                                "project_name": project.name,
                                "target_url": project.target_url,
                                "created_at": project.created_at.isoformat(),
                                "keywords": {
                                    "total": len(keywords_data),
                                    "ranking": sum(1 for kw in keywords_data if kw["current_position"]),
                                    "not_ranking": sum(1 for kw in keywords_data if not kw["current_position"]),
                                    "top_10": sum(1 for kw in keywords_data if kw["current_position"] and kw["current_position"] <= 10),
                                    "improved": sum(1 for kw in keywords_data if kw["progress"] and kw["progress"] > 0),
                                    "declined": sum(1 for kw in keywords_data if kw["progress"] and kw["progress"] < 0),
                                    "details": keywords_data
                                },
                                "backlinks": backlinks_summary
                            }
                            
                            # Format as readable text for LLM
                            report_text = f"""
PROJECT STATUS REPORT: {project.name}
Website: {project.target_url}
Created: {project.created_at.strftime('%Y-%m-%d')}

KEYWORD PERFORMANCE:
- Total Keywords Tracked: {report['keywords']['total']}
- Currently Ranking: {report['keywords']['ranking']} ({int(report['keywords']['ranking']/max(report['keywords']['total'],1)*100)}%)
- Not Ranking Yet: {report['keywords']['not_ranking']}
- In Top 10: {report['keywords']['top_10']}
- Improved: {report['keywords']['improved']}
- Declined: {report['keywords']['declined']}

KEYWORD DETAILS:
"""
                            for kw in keywords_data:
                                status = "✅ Ranking" if kw["current_position"] else "❌ Not ranking"
                                pos = f"#{kw['current_position']}" if kw["current_position"] else "Not in top 100"
                                progress_emoji = ""
                                if kw["progress"]:
                                    if kw["progress"] > 0:
                                        progress_emoji = f" 📈 +{kw['progress']}"
                                    elif kw["progress"] < 0:
                                        progress_emoji = f" 📉 {kw['progress']}"
                                
                                report_text += f"\n• {kw['keyword']}: {pos} {progress_emoji}"
                                if kw["target_page"] and not kw["is_correct_page"] and kw["current_position"]:
                                    report_text += f" ⚠️  Wrong page ranking"
                            
                            if backlinks_summary:
                                report_text += f"""

BACKLINK PROFILE:
- Total Backlinks: {backlinks_summary['total_backlinks']}
- Referring Domains: {backlinks_summary['referring_domains']}
- Domain Authority: {backlinks_summary['domain_authority']}
- Last Updated: {backlinks_summary['analyzed_at'][:10]}
"""
                            else:
                                report_text += "\n\nBACKLINK PROFILE: Not analyzed yet"
                            
                            report_text += "\n\nPlease analyze this data and provide insights on SEO progress, opportunities, and recommendations."
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": report_text
                            })
                        
                        elif tool_name == "get_gsc_performance":
                            project_id = args.get("project_id")
                            data_type = args.get("data_type", "overview")
                            limit = args.get("limit", 20)
                            
                            # Check if user has GSC connected
                            if not user.gsc_access_token:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": "ERROR: Google Search Console not connected. User needs to connect their GSC account first."
                                })
                                continue
                            
                            # Get project
                            project = db.query(Project).filter(
                                Project.id == project_id,
                                Project.user_id == user.id
                            ).first()
                            
                            if not project:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": "ERROR: Project not found"
                                })
                                continue
                            
                            if not project.gsc_property_url:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": f"ERROR: Project '{project.name}' is not linked to a Google Search Console property. User needs to link this project to a GSC property first."
                                })
                                continue
                            
                            # Fetch GSC data based on type
                            try:
                                if data_type == "overview":
                                    gsc_data = await gsc_service.get_search_analytics(
                                        access_token=user.gsc_access_token,
                                        site_url=project.gsc_property_url,
                                        refresh_token=user.gsc_refresh_token
                                    )
                                    
                                    result_text = f"""
GOOGLE SEARCH CONSOLE DATA - {project.name}
Property: {project.gsc_property_url}
Period: {gsc_data['start_date']} to {gsc_data['end_date']}

PERFORMANCE SUMMARY:
- Total Clicks: {gsc_data['total_clicks']:,}
- Total Impressions: {gsc_data['total_impressions']:,}
- Average CTR: {gsc_data['average_ctr']}%
- Average Position: {gsc_data['average_position']}

This is REAL data from Google Search Console (not estimates).
"""
                                    
                                elif data_type == "queries":
                                    queries = await gsc_service.get_top_queries(
                                        access_token=user.gsc_access_token,
                                        site_url=project.gsc_property_url,
                                        limit=limit,
                                        refresh_token=user.gsc_refresh_token
                                    )
                                    
                                    result_text = f"""
TOP {len(queries)} SEARCH QUERIES - {project.name}
Real data from Google Search Console:

"""
                                    for i, q in enumerate(queries[:limit], 1):
                                        result_text += f"{i}. \"{q['query']}\" - {q['clicks']} clicks, {q['impressions']:,} impressions, {q['ctr']}% CTR, avg position #{q['position']}\n"
                                
                                elif data_type == "pages":
                                    pages = await gsc_service.get_top_pages(
                                        access_token=user.gsc_access_token,
                                        site_url=project.gsc_property_url,
                                        limit=limit,
                                        refresh_token=user.gsc_refresh_token
                                    )
                                    
                                    result_text = f"""
TOP {len(pages)} PERFORMING PAGES - {project.name}
Real data from Google Search Console:

"""
                                    for i, p in enumerate(pages[:limit], 1):
                                        result_text += f"{i}. {p['page']}\n   {p['clicks']} clicks, {p['impressions']:,} impressions, {p['ctr']}% CTR\n"
                                
                                elif data_type == "sitemaps":
                                    sitemaps = await gsc_service.get_sitemaps(
                                        access_token=user.gsc_access_token,
                                        site_url=project.gsc_property_url,
                                        refresh_token=user.gsc_refresh_token
                                    )
                                    
                                    result_text = f"""
SITEMAP STATUS - {project.name}
Total Sitemaps: {len(sitemaps)}

"""
                                    if not sitemaps:
                                        result_text += "⚠️  WARNING: No sitemaps found! This could impact indexing.\n"
                                    else:
                                        for sitemap in sitemaps:
                                            status_emoji = "✅" if sitemap['errors'] == 0 else "❌"
                                            result_text += f"{status_emoji} {sitemap['path']}\n"
                                            result_text += f"   Last submitted: {sitemap['last_submitted']}\n"
                                            result_text += f"   Errors: {sitemap['errors']}, Warnings: {sitemap['warnings']}\n"
                                            if sitemap['errors'] > 0:
                                                result_text += f"   ⚠️  ATTENTION: Sitemap has errors that need fixing!\n"
                                
                                elif data_type == "indexing":
                                    coverage = await gsc_service.get_index_coverage(
                                        access_token=user.gsc_access_token,
                                        site_url=project.gsc_property_url,
                                        refresh_token=user.gsc_refresh_token
                                    )
                                    
                                    result_text = f"""
INDEXING STATUS - {project.name}

OVERVIEW:
- Pages with impressions: {coverage['pages_with_impressions']}
- Sitemaps: {coverage['sitemaps_count']}
- Sitemap errors: {coverage['sitemap_errors']}
- Sitemap warnings: {coverage['sitemap_warnings']}

"""
                                    if coverage['sitemap_errors'] > 0:
                                        result_text += "⚠️  WARNING: Sitemap errors detected! Pages may not be indexed properly.\n\n"
                                    
                                    if coverage['sitemaps']:
                                        result_text += "SITEMAPS:\n"
                                        for sitemap in coverage['sitemaps']:
                                            result_text += f"- {sitemap['path']}: {sitemap['errors']} errors, {sitemap['warnings']} warnings\n"
                                
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": result_text
                                })
                                
                            except Exception as gsc_error:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": f"ERROR fetching GSC data: {str(gsc_error)}. The user may need to reconnect their Google Search Console account."
                                })
                        
                        elif tool_name == "link_gsc_property":
                            project_id = args.get("project_id")
                            property_url = args.get("property_url")
                            
                            # Check if user has GSC connected
                            if not user.gsc_access_token:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": "ERROR: Google Search Console not connected. User needs to connect their GSC account first by logging in again."
                                })
                                continue
                            
                            # Get project
                            project = db.query(Project).filter(
                                Project.id == project_id,
                                Project.user_id == user.id
                            ).first()
                            
                            if not project:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": "ERROR: Project not found"
                                })
                                continue
                            
                            try:
                                # If property_url is provided, link directly
                                if property_url:
                                    project.gsc_property_url = property_url
                                    db.commit()
                                    
                                    tool_results.append({
                                        "tool_call_id": tool_call["id"],
                                        "role": "tool",
                                        "name": tool_name,
                                        "content": f"✅ Successfully linked project '{project.name}' to GSC property: {property_url}"
                                    })
                                else:
                                    # Fetch available properties and let user choose
                                    properties = await gsc_service.get_site_list(
                                        access_token=user.gsc_access_token,
                                        refresh_token=user.gsc_refresh_token
                                    )
                                    
                                    if not properties:
                                        tool_results.append({
                                            "tool_call_id": tool_call["id"],
                                            "role": "tool",
                                            "name": tool_name,
                                            "content": "No GSC properties found. Make sure you have verified at least one site in Google Search Console."
                                        })
                                        continue
                                    
                                    # Auto-link if there's an obvious match
                                    target_domain = project.target_url.replace('https://', '').replace('http://', '').rstrip('/')
                                    matched_property = None
                                    
                                    for prop in properties:
                                        prop_url = prop['site_url']
                                        if target_domain in prop_url or prop_url.replace('https://', '').replace('http://', '').rstrip('/') == target_domain:
                                            matched_property = prop_url
                                            break
                                    
                                    if matched_property:
                                        project.gsc_property_url = matched_property
                                        db.commit()
                                        
                                        tool_results.append({
                                            "tool_call_id": tool_call["id"],
                                            "role": "tool",
                                            "name": tool_name,
                                            "content": f"✅ Auto-linked project '{project.name}' to GSC property: {matched_property}"
                                        })
                                    else:
                                        # Show available properties
                                        props_list = "\n".join([f"- {p['site_url']} ({p['permission_level']})" for p in properties])
                                        tool_results.append({
                                            "tool_call_id": tool_call["id"],
                                            "role": "tool",
                                            "name": tool_name,
                                            "content": f"Available GSC properties:\n{props_list}\n\nTo link, please specify which property URL to use for project '{project.name}' (target: {project.target_url})"
                                        })
                                
                            except Exception as link_error:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": f"ERROR linking GSC property: {str(link_error)}"
                                })

                    except Exception as e:
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": f"ERROR: {str(e)}"
                        })
                
                # Send status for final processing
                yield await send_sse_event("status", {"message": "Analyzing results..."})
                
                # Add tool calls to history
                conversation_history.append({
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [
                        {
                            "id": tc["id"],
                            "type": "function",
                            "function": {
                                "name": tc["name"],
                                "arguments": str(tc["arguments"])
                            }
                        }
                        for tc in tool_calls
                    ]
                })
                
                for result in tool_results:
                    conversation_history.append(result)
                
                # Get final response
                # Don't pass tools again - we want a final text response, not more tool calls
                assistant_response, reasoning, follow_up_tools = await llm_service.chat_with_tools(
                    user_message="Please analyze the results and provide a clear response to the user's request.",
                    conversation_history=conversation_history,
                    available_tools=None,  # No more tools - force text response
                    user_projects=user_projects_data if user_projects_data else None,
                    mode=request.mode or "ask"
                )
                
                # Log the response for debugging
                logger.info(f"Final response after tool execution: {len(assistant_response or '')} chars, follow_up_tools: {follow_up_tools is not None}")
                
                # If no response, provide a fallback
                if not assistant_response:
                    if follow_up_tools:
                        logger.warning("LLM requested follow-up tools after initial tool execution - providing fallback")
                        assistant_response = "I've gathered the information. Let me know if you'd like me to analyze it further."
                    else:
                        logger.warning("LLM returned no content after tool execution - providing generic fallback")
                        # Extract info from tool results to provide basic feedback
                        if tool_results and len(tool_results) > 0:
                            assistant_response = "I've completed the requested action. The results are ready."
                        else:
                            assistant_response = "Task completed. Let me know if you need anything else!"
            else:
                # No tool calls - direct response
                assistant_response = response_text
                reasoning = reasoning
            
            # Save assistant message (only if we have content)
            if assistant_response:
                metadata = {}
                if reasoning:
                    metadata["reasoning"] = reasoning

                assistant_message = Message(
                    id=str(uuid.uuid4()),
                    conversation_id=conversation.id,
                    role="assistant",
                    content=assistant_response,
                    message_metadata=metadata if metadata else None
                )
                db.add(assistant_message)
                db.commit()
                
                # Update conversation title with AI summary if this is the first exchange
                try:
                    # Check if this is a new conversation (only 2 messages: user + assistant)
                    message_count = db.query(Message).filter(
                        Message.conversation_id == conversation.id
                    ).count()
                    
                    if message_count == 2:  # First exchange complete
                        # Build conversation content for summarization
                        all_messages = db.query(Message).filter(
                            Message.conversation_id == conversation.id
                        ).order_by(Message.created_at).all()
                        
                        conversation_content = []
                        for msg in all_messages:
                            role = "You" if msg.role == "user" else "Assistant"
                            conversation_content.append(f"**{role}:** {msg.content}")
                        
                        content_text = "\n\n".join(conversation_content)
                        
                        # Generate AI summary for the title (use global llm_service)
                        title = await llm_service.summarize_conversation(content_text)
                        
                        # Update conversation title
                        conversation.title = title
                        db.commit()
                        logger.info(f"✨ Updated conversation title to: {title}")
                except Exception as e:
                    logger.warning(f"Failed to generate AI title for conversation: {e}")
                    # Don't fail the request if title generation fails
            else:
                logger.warning("⚠️  Skipping assistant message save - no content to save")
            
            # Send final response (ensure message is always a string, not None)
            yield await send_sse_event("message", {
                "message": assistant_response or "",
                "conversation_id": conversation.id
            })
            
            # Send done event
            yield await send_sse_event("done", {})
            
        except Exception as e:
            logger.error(f"Error in event_generator: {e}")
            yield await send_sse_event("error", {"message": str(e)})
    
    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"
        }
    )

@router.post("/message", response_model=ChatResponse)
async def send_message(
    request: ChatRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Send a message and get keyword research advice (non-streaming version)"""
    
    # Extract token from Authorization header
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    # Check subscription status (for now, allow free tier)
    # TODO: Add subscription check via RevenueCat
    
    # Create or get conversation
    if request.conversation_id:
        conversation = db.query(Conversation).filter(
            Conversation.id == request.conversation_id,
            Conversation.user_id == user.id
        ).first()
        
        if not conversation:
            raise HTTPException(status_code=404, detail="Conversation not found")
    else:
        # Create new conversation
        conversation = Conversation(
            id=str(uuid.uuid4()),
            user_id=user.id,
            title=request.message[:50]  # Use first 50 chars as title
        )
        db.add(conversation)
        db.commit()
        db.refresh(conversation)
    
    # Save user message
    user_message = Message(
        id=str(uuid.uuid4()),
        conversation_id=conversation.id,
        role="user",
        content=request.message
    )
    db.add(user_message)
    db.commit()
    
    # Get conversation history
    messages = db.query(Message).filter(
        Message.conversation_id == conversation.id
    ).order_by(Message.created_at).all()
    
    # Build conversation history with reasoning included for assistant messages
    conversation_history = []
    for msg in messages[:-1]:  # Exclude the message we just added
        content = msg.content
        
        # For assistant messages, prepend reasoning if available
        if msg.role == "assistant" and msg.message_metadata and msg.message_metadata.get("reasoning"):
            reasoning = msg.message_metadata["reasoning"]
            # Include reasoning in context for LLM (but was hidden from user)
            content = f"<reasoning>{reasoning}</reasoning>\n\n{content}"
        
        conversation_history.append({"role": msg.role, "content": content})
    
    # Debug logging
    logger.info(f"Conversation has {len(messages)} total messages, passing {len(conversation_history)} as history")
    
    # Get user's projects for context
    user_projects = db.query(Project).filter(Project.user_id == user.id).all()
    user_projects_data = []
    for project in user_projects:
        tracked_keywords = db.query(TrackedKeyword).filter(
            TrackedKeyword.project_id == project.id
        ).all()
        user_projects_data.append({
            'id': project.id,
            'name': project.name,
            'target_url': project.target_url,
            'tracked_keywords': [
                {'keyword': kw.keyword, 'search_volume': kw.search_volume, 
                 'competition': kw.competition, 'target_position': kw.target_position}
                for kw in tracked_keywords
            ]
        })
    
    # Define available tools for the LLM
    tools = [
        {
            "type": "function",
            "function": {
                "name": "research_keywords",
                "description": "Research keywords with search volume, competition level, and SERP analysis. Use when user wants keyword data for a topic/niche. Supports both topic keywords and URL analysis (automatically detects URLs). Can search globally or for specific locations.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "keyword_or_topic": {
                            "type": "string",
                            "description": "The keyword/topic to research (e.g., 'AI chatbots', 'SEO software') OR a URL (e.g., 'example.com', 'https://example.com')"
                        },
                        "location": {
                            "type": "string",
                            "description": "Search scope: 'global' for worldwide data, or country code like 'US', 'UK', 'CA', 'AU' for location-specific data. Default is 'US'.",
                            "default": "US"
                        },
                        "limit": {
                            "type": "integer",
                            "description": "Number of keywords to return (default 10)",
                            "default": 10
                        }
                    },
                    "required": ["keyword_or_topic"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "find_opportunity_keywords",
                "description": "Find opportunity keywords (high-potential, low-competition keywords that are easier to rank for). Use when user asks for 'easy to rank', 'low competition', 'opportunity', or 'quick wins' keywords. Note: Only supports location-specific searches (not global).",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "keyword": {
                            "type": "string",
                            "description": "The seed keyword to find opportunities for"
                        },
                        "location": {
                            "type": "string",
                            "description": "Country code like 'US', 'UK', 'CA', 'AU' for location-specific data. Default is 'US'. (Global not supported for opportunity keywords)",
                            "default": "US"
                        },
                        "limit": {
                            "type": "integer",
                            "description": "Number of opportunity keywords to return (default 10)",
                            "default": 10
                        }
                    },
                    "required": ["keyword"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "check_ranking",
                "description": "Check where a specific domain ranks in Google for a keyword. Returns position (1-100) or None if not ranking.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "keyword": {
                            "type": "string",
                            "description": "The keyword to check rankings for"
                        },
                        "domain": {
                            "type": "string",
                            "description": "Domain to check (e.g., 'example.com')"
                        }
                    },
                    "required": ["keyword", "domain"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "analyze_website",
                "description": "Crawl and analyze a website's SEO. Extracts title, meta description, headings, content, and provides SEO recommendations.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "url": {
                            "type": "string",
                            "description": "Full URL of the website to analyze (e.g., 'https://example.com')"
                        }
                    },
                    "required": ["url"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "analyze_backlinks",
                "description": "Analyze backlink profile for a domain. Returns total backlinks, referring domains, domain authority, and top backlinks.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "domain": {
                            "type": "string",
                            "description": "Domain to analyze without http:// (e.g., 'example.com')"
                        }
                    },
                    "required": ["domain"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "track_keywords",
                "description": "Add keywords to a project's keyword tracker for rank tracking. Use when user wants to track/monitor keywords for their project. Requires a project_id.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "project_id": {
                            "type": "string",
                            "description": "The ID of the project to add keywords to"
                        },
                        "keywords": {
                            "type": "array",
                            "description": "Array of keywords to track. Each keyword should include the keyword text and optionally search volume and competition.",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "keyword": {
                                        "type": "string",
                                        "description": "The keyword text"
                                    },
                                    "search_volume": {
                                        "type": "integer",
                                        "description": "Monthly search volume (optional)"
                                    },
                                    "competition": {
                                        "type": "string",
                                        "description": "Competition level: LOW, MEDIUM, or HIGH (optional)"
                                    }
                                },
                                "required": ["keyword"]
                            }
                        }
                    },
                    "required": ["project_id", "keywords"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "pin_important_info",
                "description": "Pin important information, insights, or responses to the pinboard for later reference. Use this when the user wants to save something important, bookmark key findings, or keep track of valuable insights from your analysis.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "title": {
                            "type": "string",
                            "description": "A concise title for the pinned item (max 100 characters)"
                        },
                        "content": {
                            "type": "string",
                            "description": "The content to pin (can be insights, analysis, recommendations, or any important information)"
                        },
                        "content_type": {
                            "type": "string",
                            "enum": ["insight", "analysis", "recommendation", "note", "finding"],
                            "description": "Type of content being pinned",
                            "default": "insight"
                        },
                        "project_id": {
                            "type": "string",
                            "description": "Optional project ID to associate this pin with a specific project"
                        }
                    },
                    "required": ["title", "content"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "analyze_project_status",
                "description": "Load complete project data and analyze SEO progress. Use this when user asks about a specific project, wants to 'work on SEO strategy', or asks 'how is my project doing'. Returns keywords with current rankings, historical progress, backlink profile, and overall assessment. ALWAYS use this first when discussing an existing project.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "project_id": {
                            "type": "string",
                            "description": "The ID of the project to analyze"
                        }
                    },
                    "required": ["project_id"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "get_gsc_performance",
                "description": "Get real Google Search Console data for a project - actual clicks, impressions, CTR, and average position from Google. Use this to see real performance data (not estimates), check indexing status, or analyze sitemap issues. Only works if user has connected their Google Search Console and linked the project to a GSC property.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "project_id": {
                            "type": "string",
                            "description": "The ID of the project to get GSC data for"
                        },
                        "data_type": {
                            "type": "string",
                            "enum": ["overview", "queries", "pages", "sitemaps", "indexing"],
                            "description": "Type of GSC data to retrieve: 'overview' (summary stats), 'queries' (top keywords), 'pages' (top pages), 'sitemaps' (sitemap status), 'indexing' (indexing coverage)",
                            "default": "overview"
                        },
                        "limit": {
                            "type": "integer",
                            "description": "For 'queries' or 'pages', number of results to return (default 20)",
                            "default": 20
                        }
                    },
                    "required": ["project_id"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "link_gsc_property",
                "description": "Link a project to a Google Search Console property. Use this when user wants to connect their project to GSC or when GSC data retrieval fails because no property is linked. Lists available GSC properties and links the selected one to the project.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "project_id": {
                            "type": "string",
                            "description": "The ID of the project to link"
                        },
                        "property_url": {
                            "type": "string",
                            "description": "Optional: The GSC property URL to link (e.g., 'https://example.com/' or 'sc-domain:example.com'). If not provided, will list available properties for user to choose from."
                        }
                    },
                    "required": ["project_id"]
                }
            }
        }
    ]

    # First LLM call - may return tool calls
    response_text, reasoning, tool_calls = await llm_service.chat_with_tools(
        user_message=request.message,
        conversation_history=conversation_history,
        available_tools=tools,
        user_projects=user_projects_data if user_projects_data else None,
        mode=request.mode or "ask"
    )
    
    # If LLM wants to use tools, execute them
    if tool_calls:
        logger.info(f"🛠️  Executing {len(tool_calls)} tool calls")
        tool_results = []
        
        for tool_call in tool_calls:
            tool_name = tool_call["name"]
            args = tool_call["arguments"]
            
            try:
                if tool_name == "research_keywords":
                    keyword_or_topic = args.get("keyword_or_topic")
                    location = args.get("location", "US")
                    limit = args.get("limit", 10)
                    
                    scope = "🌍 global" if location.lower() == "global" else f"📍 {location.upper()}"
                    logger.info(f"  📊 Researching keywords for: {keyword_or_topic} ({scope})")
                    keyword_data = await keyword_service.analyze_keywords(keyword_or_topic, location=location, limit=limit)
                    
                    # Enrich with SERP analysis and track rate limits
                    serp_rate_limited = False
                    serp_success_count = 0
                    if keyword_data:
                        for keyword_item in keyword_data[:5]:  # Top 5 only
                            keyword = keyword_item.get('keyword')
                            if keyword:
                                try:
                                    serp_analysis = await rank_checker.get_serp_analysis(keyword)
                                    if serp_analysis:
                                        keyword_item['serp_analysis'] = serp_analysis['analysis']
                                        keyword_item['serp_insight'] = serp_analysis['insight']
                                        serp_success_count += 1
                                except httpx.HTTPStatusError as e:
                                    if e.response.status_code == 429:
                                        serp_rate_limited = True
                                        logger.warning(f"  ⚠️  SERP analysis rate limited for '{keyword}'")
                                    # Continue to next keyword
                    
                    # Build response with rate limit info
                    response_data = {
                        "keywords": keyword_data,
                        "total_found": len(keyword_data) if keyword_data else 0,
                        "serp_analysis_available": serp_success_count > 0,
                        "serp_analysis_count": serp_success_count
                    }
                    
                    if serp_rate_limited:
                        response_data["warning"] = "SERP analysis unavailable: API rate limit reached. Keyword data is still accurate, but ranking difficulty analysis is limited. Rate limits reset daily."
                    
                    tool_results.append({
                        "tool_call_id": tool_call["id"],
                        "role": "tool",
                        "name": tool_name,
                        "content": str(response_data)
                    })
                    
                    if serp_rate_limited:
                        logger.warning(f"  ⚠️  Found {len(keyword_data) if keyword_data else 0} keywords (SERP analysis rate limited)")
                    else:
                        logger.info(f"  ✅ Found {len(keyword_data) if keyword_data else 0} keywords")
                
                elif tool_name == "find_opportunity_keywords":
                    keyword = args.get("keyword")
                    location = args.get("location", "US")
                    limit = args.get("limit", 10)
                    
                    logger.info(f"  🎯 Finding opportunity keywords for: {keyword} (location: {location.upper()})")
                    opportunity_data = await keyword_service.get_opportunity_keywords(keyword, location=location, num=limit)
                    
                    # Process the data to match our format
                    if opportunity_data:
                        processed_data = []
                        for item in opportunity_data:
                            volume = item.get("volume", 0)
                            competition = item.get("competition_level", "UNKNOWN")
                            avg_cpc = (item.get("low_bid", 0) + item.get("high_bid", 0)) / 2 if item.get("high_bid") else 0
                            
                            processed_data.append({
                                "keyword": item.get("text", ""),
                                "search_volume": volume,
                                "competition": competition,
                                "competition_index": item.get("competition_index", 0),
                                "cpc": round(avg_cpc, 2),
                                "trend": item.get("trend", 0),
                                "intent": item.get("intent", "unknown"),
                                "opportunity_score": "HIGH"  # These are pre-filtered opportunity keywords
                            })
                        
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": str(processed_data)
                        })
                        logger.info(f"  ✅ Found {len(processed_data)} opportunity keywords")
                    else:
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": "[]"
                        })
                        logger.info(f"  ℹ️  No opportunity keywords found")
                    
                elif tool_name == "check_ranking":
                    keyword = args.get("keyword")
                    domain = args.get("domain")
                    
                    logger.info(f"  📍 Checking ranking for '{keyword}' on {domain}")
                    ranking_data = await rank_checker.check_ranking(keyword, domain)
                    
                    tool_results.append({
                        "tool_call_id": tool_call["id"],
                        "role": "tool",
                        "name": tool_name,
                        "content": str(ranking_data)
                    })
                    
                    if ranking_data and ranking_data.get('position'):
                        logger.info(f"  ✅ {domain} ranks at position {ranking_data['position']} for '{keyword}'")
                    else:
                        logger.info(f"  ℹ️  {domain} not ranking in top 100 for '{keyword}'")
                
                elif tool_name == "analyze_website":
                    url = args.get("url")
                    
                    logger.info(f"  🌐 Crawling and analyzing website: {url}")
                    website_data = await web_scraper.analyze_full_site(url)
                    
                    tool_results.append({
                        "tool_call_id": tool_call["id"],
                        "role": "tool",
                        "name": tool_name,
                        "content": str(website_data)
                    })
                    
                    if website_data and not website_data.get('error'):
                        pages = website_data.get('pages_analyzed', 1)
                        logger.info(f"  ✅ Analyzed {pages} page(s) from {url}")
                    else:
                        logger.warning(f"  ⚠️  Error analyzing {url}: {website_data.get('error')}")
                    
                elif tool_name == "analyze_backlinks":
                    domain = args.get("domain")
                    
                    # Check backlink quota
                    if user.backlink_rows_used >= user.backlink_rows_limit:
                        error_msg = f"Backlink limit reached ({user.backlink_rows_limit}/month)"
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": f"ERROR: {error_msg}"
                        })
                        logger.warning(f"  ❌ {error_msg}")
                    else:
                        logger.info(f"  🔗 Analyzing backlinks for: {domain}")
                        backlink_data = await backlink_service.get_backlinks(domain, limit=50)
                        
                        if backlink_data and not backlink_data.get("error"):
                            user.backlink_rows_used += 1
                            db.commit()
                            logger.info(f"  ✅ Found {backlink_data.get('total_backlinks', 0)} backlinks")
                        
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": str(backlink_data)
                        })
                
                elif tool_name == "track_keywords":
                    project_id = args.get("project_id")
                    keywords_to_track = args.get("keywords", [])
                    
                    logger.info(f"  📌 Tracking {len(keywords_to_track)} keyword(s) for project {project_id}")
                    
                    # Verify project exists and belongs to user
                    project = db.query(Project).filter(
                        Project.id == project_id,
                        Project.user_id == user.id
                    ).first()
                    
                    if not project:
                        error_msg = "Project not found"
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": f"ERROR: {error_msg}"
                        })
                        logger.warning(f"  ❌ {error_msg}")
                    else:
                        tracked_count = 0
                        skipped_count = 0
                        errors = []
                        
                        for kw_data in keywords_to_track:
                            keyword = kw_data.get("keyword")
                            if not keyword:
                                continue
                            
                            # Check if keyword already tracked
                            existing = db.query(TrackedKeyword).filter(
                                TrackedKeyword.project_id == project_id,
                                TrackedKeyword.keyword == keyword
                            ).first()
                            
                            if existing:
                                logger.info(f"    ⏭️  Skipping '{keyword}' (already tracked)")
                                skipped_count += 1
                                continue
                            
                            try:
                                # Add keyword to tracker immediately (non-blocking)
                                tracked_keyword = TrackedKeyword(
                                    id=str(uuid.uuid4()),
                                    project_id=project_id,
                                    keyword=keyword,
                                    search_volume=kw_data.get("search_volume"),
                                    competition=kw_data.get("competition")
                                )
                                db.add(tracked_keyword)
                                tracked_count += 1
                                logger.info(f"    ✅ Tracked '{keyword}' (ranking check will happen on next refresh)")
                                
                                # Note: Initial ranking will be checked on first manual refresh
                                # This keeps the response fast and non-blocking for the user
                                
                            except Exception as e:
                                error_str = f"{keyword}: {str(e)}"
                                errors.append(error_str)
                                logger.error(f"    ❌ Error tracking '{keyword}': {e}")
                        
                        db.commit()
                        
                        result_msg = f"Successfully tracked {tracked_count} keyword(s). Rankings will be checked on next refresh."
                        if skipped_count > 0:
                            result_msg += f" Skipped {skipped_count} already tracked."
                        if errors:
                            result_msg += f" Errors: {', '.join(errors)}"
                        
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": result_msg
                        })
                        logger.info(f"  ✅ {result_msg}")

                elif tool_name == "pin_important_info":
                    title = args.get("title")
                    content = args.get("content")
                    content_type = args.get("content_type", "insight")
                    project_id = args.get("project_id")

                    logger.info(f"  📌 Pinning '{title}' to pinboard")

                    # Validate required fields
                    if not title or not content:
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": "ERROR: Both title and content are required"
                        })
                        logger.warning("  ❌ Missing title or content for pin")
                    else:
                        # Verify project_id if provided
                        if project_id:
                            project = db.query(Project).filter(
                                Project.id == project_id,
                                Project.user_id == user.id
                            ).first()
                            if not project:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": "ERROR: Project not found"
                                })
                                logger.warning(f"  ❌ Project {project_id} not found")
                                continue

                        # Create the pinned item
                        pinned_item = PinnedItem(
                            id=str(uuid.uuid4()),
                            user_id=user.id,
                            project_id=project_id,
                            content_type=content_type,
                            title=title[:100],  # Truncate to max length
                            content=content,
                            source_message_id=None,  # AI-generated pins don't have a source message
                            source_conversation_id=conversation.id
                        )

                        db.add(pinned_item)
                        db.commit()

                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": f"Successfully pinned '{title}' to the pinboard"
                        })
                        logger.info(f"  ✅ Pinned '{title}' to pinboard")
                
                elif tool_name == "analyze_project_status":
                    project_id = args.get("project_id")
                    
                    # Get project
                    project = db.query(Project).filter(
                        Project.id == project_id,
                        Project.user_id == user.id
                    ).first()
                    
                    if not project:
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": "ERROR: Project not found"
                        })
                        continue
                    
                    # Load complete project data (same as streaming version)
                    logger.info(f"📊 Loading complete data for project: {project.name}")
                    
                    # Get tracked keywords with rankings
                    tracked_keywords = db.query(TrackedKeyword).filter(
                        TrackedKeyword.project_id == project_id
                    ).all()
                    
                    keywords_data = []
                    for kw in tracked_keywords:
                        rankings = db.query(KeywordRanking).filter(
                            KeywordRanking.tracked_keyword_id == kw.id
                        ).order_by(KeywordRanking.checked_at.desc()).limit(30).all()
                        
                        current_position = rankings[0].position if rankings else None
                        current_page = rankings[0].page_url if rankings else None
                        
                        progress = None
                        if len(rankings) >= 2:
                            oldest_pos = rankings[-1].position
                            current_pos = rankings[0].position
                            if oldest_pos and current_pos:
                                progress = oldest_pos - current_pos
                        
                        keywords_data.append({
                            "keyword": kw.keyword,
                            "search_volume": kw.search_volume,
                            "competition": kw.competition,
                            "target_position": kw.target_position,
                            "target_page": kw.target_page,
                            "current_position": current_position,
                            "ranking_page": current_page,
                            "is_correct_page": kw.target_page in (current_page or '') if kw.target_page else (current_page is not None),
                            "progress": progress,
                            "ranking_history": [{"position": r.position, "date": r.checked_at.isoformat()} for r in rankings[:10]]
                        })
                    
                    # Get backlink analysis
                    backlink_analysis = db.query(BacklinkAnalysis).filter(
                        BacklinkAnalysis.project_id == project_id
                    ).first()
                    
                    backlinks_summary = None
                    if backlink_analysis:
                        backlinks_summary = {
                            "total_backlinks": backlink_analysis.total_backlinks,
                            "referring_domains": backlink_analysis.referring_domains,
                            "domain_authority": backlink_analysis.domain_authority,
                            "analyzed_at": backlink_analysis.analyzed_at.isoformat(),
                            "recent_backlinks": backlink_analysis.raw_data.get("backlinks", [])[:10] if backlink_analysis.raw_data else []
                        }
                    
                    # Format comprehensive report
                    report = {
                        "project_name": project.name,
                        "target_url": project.target_url,
                        "created_at": project.created_at.isoformat(),
                        "keywords": {
                            "total": len(keywords_data),
                            "ranking": sum(1 for kw in keywords_data if kw["current_position"]),
                            "not_ranking": sum(1 for kw in keywords_data if not kw["current_position"]),
                            "top_10": sum(1 for kw in keywords_data if kw["current_position"] and kw["current_position"] <= 10),
                            "improved": sum(1 for kw in keywords_data if kw["progress"] and kw["progress"] > 0),
                            "declined": sum(1 for kw in keywords_data if kw["progress"] and kw["progress"] < 0),
                            "details": keywords_data
                        },
                        "backlinks": backlinks_summary
                    }
                    
                    # Format as readable text for LLM
                    report_text = f"""
PROJECT STATUS REPORT: {project.name}
Website: {project.target_url}
Created: {project.created_at.strftime('%Y-%m-%d')}

KEYWORD PERFORMANCE:
- Total Keywords Tracked: {report['keywords']['total']}
- Currently Ranking: {report['keywords']['ranking']} ({int(report['keywords']['ranking']/max(report['keywords']['total'],1)*100)}%)
- Not Ranking Yet: {report['keywords']['not_ranking']}
- In Top 10: {report['keywords']['top_10']}
- Improved: {report['keywords']['improved']}
- Declined: {report['keywords']['declined']}

KEYWORD DETAILS:
"""
                    for kw in keywords_data:
                        status = "✅ Ranking" if kw["current_position"] else "❌ Not ranking"
                        pos = f"#{kw['current_position']}" if kw["current_position"] else "Not in top 100"
                        progress_emoji = ""
                        if kw["progress"]:
                            if kw["progress"] > 0:
                                progress_emoji = f" 📈 +{kw['progress']}"
                            elif kw["progress"] < 0:
                                progress_emoji = f" 📉 {kw['progress']}"
                        
                        report_text += f"\n• {kw['keyword']}: {pos} {progress_emoji}"
                        if kw["target_page"] and not kw["is_correct_page"] and kw["current_position"]:
                            report_text += f" ⚠️  Wrong page ranking"
                    
                    if backlinks_summary:
                        report_text += f"""

BACKLINK PROFILE:
- Total Backlinks: {backlinks_summary['total_backlinks']}
- Referring Domains: {backlinks_summary['referring_domains']}
- Domain Authority: {backlinks_summary['domain_authority']}
- Last Updated: {backlinks_summary['analyzed_at'][:10]}
"""
                    else:
                        report_text += "\n\nBACKLINK PROFILE: Not analyzed yet"
                    
                    report_text += "\n\nPlease analyze this data and provide insights on SEO progress, opportunities, and recommendations."
                    
                    tool_results.append({
                        "tool_call_id": tool_call["id"],
                        "role": "tool",
                        "name": tool_name,
                        "content": report_text
                    })
                
                elif tool_name == "get_gsc_performance":
                    project_id = args.get("project_id")
                    data_type = args.get("data_type", "overview")
                    limit = args.get("limit", 20)
                    
                    # Same handler logic as streaming version
                    if not user.gsc_access_token:
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": "ERROR: Google Search Console not connected. User needs to connect their GSC account first."
                        })
                        continue
                    
                    project = db.query(Project).filter(
                        Project.id == project_id,
                        Project.user_id == user.id
                    ).first()
                    
                    if not project:
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": "ERROR: Project not found"
                        })
                        continue
                    
                    if not project.gsc_property_url:
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": f"ERROR: Project '{project.name}' is not linked to a Google Search Console property. User needs to link this project to a GSC property first."
                        })
                        continue
                    
                    try:
                        if data_type == "overview":
                            gsc_data = await gsc_service.get_search_analytics(
                                access_token=user.gsc_access_token,
                                site_url=project.gsc_property_url,
                                refresh_token=user.gsc_refresh_token
                            )
                            
                            result_text = f"""
GOOGLE SEARCH CONSOLE DATA - {project.name}
Property: {project.gsc_property_url}
Period: {gsc_data['start_date']} to {gsc_data['end_date']}

PERFORMANCE SUMMARY:
- Total Clicks: {gsc_data['total_clicks']:,}
- Total Impressions: {gsc_data['total_impressions']:,}
- Average CTR: {gsc_data['average_ctr']}%
- Average Position: {gsc_data['average_position']}

This is REAL data from Google Search Console (not estimates).
"""
                            
                        elif data_type == "queries":
                            queries = await gsc_service.get_top_queries(
                                access_token=user.gsc_access_token,
                                site_url=project.gsc_property_url,
                                limit=limit,
                                refresh_token=user.gsc_refresh_token
                            )
                            
                            result_text = f"""
TOP {len(queries)} SEARCH QUERIES - {project.name}
Real data from Google Search Console:

"""
                            for i, q in enumerate(queries[:limit], 1):
                                result_text += f"{i}. \"{q['query']}\" - {q['clicks']} clicks, {q['impressions']:,} impressions, {q['ctr']}% CTR, avg position #{q['position']}\n"
                        
                        elif data_type == "pages":
                            pages = await gsc_service.get_top_pages(
                                access_token=user.gsc_access_token,
                                site_url=project.gsc_property_url,
                                limit=limit,
                                refresh_token=user.gsc_refresh_token
                            )
                            
                            result_text = f"""
TOP {len(pages)} PERFORMING PAGES - {project.name}
Real data from Google Search Console:

"""
                            for i, p in enumerate(pages[:limit], 1):
                                result_text += f"{i}. {p['page']}\n   {p['clicks']} clicks, {p['impressions']:,} impressions, {p['ctr']}% CTR\n"
                        
                        elif data_type == "sitemaps":
                            sitemaps = await gsc_service.get_sitemaps(
                                access_token=user.gsc_access_token,
                                site_url=project.gsc_property_url,
                                refresh_token=user.gsc_refresh_token
                            )
                            
                            result_text = f"""
SITEMAP STATUS - {project.name}
Total Sitemaps: {len(sitemaps)}

"""
                            if not sitemaps:
                                result_text += "⚠️  WARNING: No sitemaps found! This could impact indexing.\n"
                            else:
                                for sitemap in sitemaps:
                                    status_emoji = "✅" if sitemap['errors'] == 0 else "❌"
                                    result_text += f"{status_emoji} {sitemap['path']}\n"
                                    result_text += f"   Last submitted: {sitemap['last_submitted']}\n"
                                    result_text += f"   Errors: {sitemap['errors']}, Warnings: {sitemap['warnings']}\n"
                                    if sitemap['errors'] > 0:
                                        result_text += f"   ⚠️  ATTENTION: Sitemap has errors that need fixing!\n"
                        
                        elif data_type == "indexing":
                            coverage = await gsc_service.get_index_coverage(
                                access_token=user.gsc_access_token,
                                site_url=project.gsc_property_url,
                                refresh_token=user.gsc_refresh_token
                            )
                            
                            result_text = f"""
INDEXING STATUS - {project.name}

OVERVIEW:
- Pages with impressions: {coverage['pages_with_impressions']}
- Sitemaps: {coverage['sitemaps_count']}
- Sitemap errors: {coverage['sitemap_errors']}
- Sitemap warnings: {coverage['sitemap_warnings']}

"""
                            if coverage['sitemap_errors'] > 0:
                                result_text += "⚠️  WARNING: Sitemap errors detected! Pages may not be indexed properly.\n\n"
                            
                            if coverage['sitemaps']:
                                result_text += "SITEMAPS:\n"
                                for sitemap in coverage['sitemaps']:
                                    result_text += f"- {sitemap['path']}: {sitemap['errors']} errors, {sitemap['warnings']} warnings\n"
                        
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": result_text
                        })
                        
                    except Exception as gsc_error:
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": f"ERROR fetching GSC data: {str(gsc_error)}. The user may need to reconnect their Google Search Console account."
                        })
                
                elif tool_name == "link_gsc_property":
                    project_id = args.get("project_id")
                    property_url = args.get("property_url")
                    
                    if not user.gsc_access_token:
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": "ERROR: Google Search Console not connected. User needs to connect their GSC account first by logging in again."
                        })
                        continue
                    
                    project = db.query(Project).filter(
                        Project.id == project_id,
                        Project.user_id == user.id
                    ).first()
                    
                    if not project:
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": "ERROR: Project not found"
                        })
                        continue
                    
                    try:
                        if property_url:
                            project.gsc_property_url = property_url
                            db.commit()
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": f"✅ Successfully linked project '{project.name}' to GSC property: {property_url}"
                            })
                        else:
                            properties = await gsc_service.get_site_list(
                                access_token=user.gsc_access_token,
                                refresh_token=user.gsc_refresh_token
                            )
                            
                            if not properties:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": "No GSC properties found. Make sure you have verified at least one site in Google Search Console."
                                })
                                continue
                            
                            target_domain = project.target_url.replace('https://', '').replace('http://', '').rstrip('/')
                            matched_property = None
                            
                            for prop in properties:
                                prop_url = prop['site_url']
                                if target_domain in prop_url or prop_url.replace('https://', '').replace('http://', '').rstrip('/') == target_domain:
                                    matched_property = prop_url
                                    break
                            
                            if matched_property:
                                project.gsc_property_url = matched_property
                                db.commit()
                                
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": f"✅ Auto-linked project '{project.name}' to GSC property: {matched_property}"
                                })
                            else:
                                props_list = "\n".join([f"- {p['site_url']} ({p['permission_level']})" for p in properties])
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": f"Available GSC properties:\n{props_list}\n\nTo link, please specify which property URL to use for project '{project.name}' (target: {project.target_url})"
                                })
                        
                    except Exception as link_error:
                        tool_results.append({
                            "tool_call_id": tool_call["id"],
                            "role": "tool",
                            "name": tool_name,
                            "content": f"ERROR linking GSC property: {str(link_error)}"
                        })

            except Exception as e:
                logger.error(f"  ❌ Error executing {tool_name}: {e}")
                tool_results.append({
                    "tool_call_id": tool_call["id"],
                    "role": "tool",
                    "name": tool_name,
                    "content": f"ERROR: {str(e)}"
                })
        
        # Make second LLM call with tool results to get final response
        logger.info("🤖 Sending tool results back to LLM for final response (tools still available)")
        
        # Add tool call messages to history
        conversation_history.append({
            "role": "assistant",
            "content": None,
            "tool_calls": [
                {
                    "id": tc["id"],
                    "type": "function",  # Required by OpenAI API spec
                    "function": {
                        "name": tc["name"],
                        "arguments": str(tc["arguments"])
                    }
                }
                for tc in tool_calls
            ]
        })
        
        for result in tool_results:
            conversation_history.append(result)
        
        # Get final response from LLM (allow tools in case user wants follow-up)
        assistant_response, reasoning, follow_up_tools = await llm_service.chat_with_tools(
            user_message="",  # Empty since we're providing tool results
            conversation_history=conversation_history,
            available_tools=tools,  # Keep tools available for follow-up
            user_projects=user_projects_data if user_projects_data else None,
            mode=request.mode or "ask"
        )
        
        # If LLM wants more tool calls, we should handle recursively, but for now just log
        if follow_up_tools:
            logger.warning(f"⚠️  LLM requested {len(follow_up_tools)} follow-up tool calls after getting results. This is not yet supported.")
            assistant_response = "I got the data, but I'm having trouble processing it. Please try rephrasing your request."
    else:
        # No tool calls - direct response
        assistant_response = response_text
        reasoning = reasoning
    
    # Save assistant message (only if we have content)
    if assistant_response:
        metadata = {}
        if reasoning:
            metadata["reasoning"] = reasoning

        assistant_message = Message(
            id=str(uuid.uuid4()),
            conversation_id=conversation.id,
            role="assistant",
            content=assistant_response,
            message_metadata=metadata if metadata else None
        )
        db.add(assistant_message)
        db.commit()
        
        # Update conversation title with AI summary if this is the first exchange
        try:
            # Check if this is a new conversation (only 2 messages: user + assistant)
            message_count = db.query(Message).filter(
                Message.conversation_id == conversation.id
            ).count()
            
            if message_count == 2:  # First exchange complete
                # Build conversation content for summarization
                all_messages = db.query(Message).filter(
                    Message.conversation_id == conversation.id
                ).order_by(Message.created_at).all()
                
                conversation_content = []
                for msg in all_messages:
                    role = "You" if msg.role == "user" else "Assistant"
                    conversation_content.append(f"**{role}:** {msg.content}")
                
                content_text = "\n\n".join(conversation_content)
                
                # Generate AI summary for the title (use global llm_service)
                title = await llm_service.summarize_conversation(content_text)
                
                # Update conversation title
                conversation.title = title
                db.commit()
                logger.info(f"✨ Updated conversation title to: {title}")
        except Exception as e:
            logger.warning(f"Failed to generate AI title for conversation: {e}")
            # Don't fail the request if title generation fails
    else:
        logger.warning("⚠️  Skipping assistant message save - no content to save")
    
    return ChatResponse(
        message=assistant_response,
        conversation_id=conversation.id
    )

@router.get("/conversations", response_model=List[ConversationListItem])
async def get_conversations(
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get list of user's conversations"""
    
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    conversations = db.query(Conversation).filter(
        Conversation.user_id == user.id
    ).order_by(Conversation.updated_at.desc()).all()
    
    result = []
    for conv in conversations:
        message_count = db.query(Message).filter(
            Message.conversation_id == conv.id
        ).count()
        
        # Extract project IDs from messages in this conversation
        messages = db.query(Message).filter(
            Message.conversation_id == conv.id
        ).all()
        
        project_ids = set()
        
        # 1. Check message metadata for explicit project_id
        for msg in messages:
            if msg.message_metadata and isinstance(msg.message_metadata, dict):
                if 'project_id' in msg.message_metadata:
                    project_ids.add(msg.message_metadata['project_id'])
        
        # 2. If no explicit project_id, try to match by project name/URL in title and messages
        if not project_ids:
            # Get all user's projects
            user_projects = db.query(Project).filter(
                Project.user_id == user.id
            ).all()
            
            # Build search text from title and messages
            search_text = (conv.title or "").lower()
            for msg in messages[:5]:  # Check first 5 messages only for performance
                search_text += " " + msg.content.lower()
            
            # Check if any project name or URL appears in the text
            for project in user_projects:
                # Check project name
                if project.name and project.name.lower() in search_text:
                    project_ids.add(project.id)
                # Check project URL (extract domain)
                elif project.target_url:
                    from urllib.parse import urlparse
                    parsed = urlparse(project.target_url)
                    domain = parsed.netloc or parsed.path
                    domain = domain.replace('www.', '').replace('https://', '').replace('http://', '')
                    if domain and domain in search_text:
                        project_ids.add(project.id)
        
        # Get project names
        project_names = []
        if project_ids:
            projects = db.query(Project).filter(
                Project.id.in_(project_ids)
            ).all()
            project_names = [p.name for p in projects if p.name]
        
        result.append(ConversationListItem(
            id=conv.id,
            title=conv.title or "Untitled Conversation",
            created_at=conv.created_at.isoformat(),
            message_count=message_count,
            project_names=project_names
        ))
    
    return result

@router.get("/conversation/{conversation_id}")
async def get_conversation(
    conversation_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get a specific conversation with all messages"""
    
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == user.id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    messages = db.query(Message).filter(
        Message.conversation_id == conversation_id
    ).order_by(Message.created_at).all()
    
    return {
        "id": conversation.id,
        "title": conversation.title,
        "created_at": conversation.created_at.isoformat(),
        "messages": [
            {
                "id": msg.id,
                "role": msg.role,
                "content": msg.content,
                "created_at": msg.created_at.isoformat(),
                "message_metadata": msg.message_metadata
            }
            for msg in messages
        ]
    }

@router.delete("/conversation/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Delete a conversation and all its messages"""
    
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == user.id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    # Delete all messages first
    db.query(Message).filter(
        Message.conversation_id == conversation_id
    ).delete()
    
    # Delete conversation
    db.delete(conversation)
    db.commit()
    
    return {"message": "Conversation deleted successfully"}

class RenameConversationRequest(BaseModel):
    title: str

@router.put("/conversation/{conversation_id}/rename")
async def rename_conversation(
    conversation_id: str,
    request: RenameConversationRequest,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Rename a conversation"""
    
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == user.id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    # Update the title
    conversation.title = request.title
    db.commit()
    
    return {"message": "Conversation renamed successfully", "title": conversation.title}

@router.delete("/conversations/all")
async def delete_all_conversations(
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Delete all conversations for the current user"""
    
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    # Get all user's conversations
    conversations = db.query(Conversation).filter(
        Conversation.user_id == user.id
    ).all()
    
    conversation_ids = [conv.id for conv in conversations]
    
    if not conversation_ids:
        return {"message": "No conversations to delete", "count": 0}
    
    # Delete all messages for these conversations
    deleted_messages = db.query(Message).filter(
        Message.conversation_id.in_(conversation_ids)
    ).delete(synchronize_session=False)
    
    # Delete all conversations
    deleted_conversations = db.query(Conversation).filter(
        Conversation.user_id == user.id
    ).delete(synchronize_session=False)
    
    db.commit()
    
    return {
        "message": f"Deleted {deleted_conversations} conversations and {deleted_messages} messages",
        "count": deleted_conversations
    }

def should_fetch_keyword_data(message: str) -> bool:
    """Determine if we should fetch keyword data based on the message"""
    keywords_triggers = [
        "keyword", "keywords", "search volume", "rank", "ranking",
        "target", "should i", "what about", "traffic", "seo"
    ]
    message_lower = message.lower()
    return any(trigger in message_lower for trigger in keywords_triggers)

def extract_keywords_from_message(message: str) -> List[str]:
    """Extract potential keywords from user message"""
    # Look for quoted phrases first
    quoted = re.findall(r'"([^"]+)"', message)
    if quoted:
        return quoted
    
    # Look for phrases after "for", "about", "targeting"
    patterns = [
        r'(?:for|about|targeting)\s+([a-zA-Z\s]+?)(?:\.|$|\?)',
        r'keyword[s]?\s+like\s+([a-zA-Z\s]+?)(?:\.|$|\?)'
    ]
    
    for pattern in patterns:
        matches = re.findall(pattern, message, re.IGNORECASE)
        if matches:
            return [m.strip() for m in matches]
    
    # Fallback: just return meaningful words
    words = message.split()
    if len(words) > 2:
        return [' '.join(words[:3])]
    
    return []

