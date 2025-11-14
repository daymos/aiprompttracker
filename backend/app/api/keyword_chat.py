from fastapi import APIRouter, HTTPException, Depends, Header
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Optional, AsyncIterator, Dict, Any
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
from ..models.technical_audit import TechnicalAudit
from ..services.keyword_service import KeywordService
from ..services.llm_service import LLMService
from ..services.rank_checker import RankCheckerService
from ..services.rapidapi_backlinks_service import RapidAPIBacklinkService
from ..services.dataforseo_backlinks_service import DataForSEOBacklinksService
from ..services.dataforseo_service import DataForSEOService
from ..services.rapidapi_seo_service import RapidAPISEOService
from ..services.web_scraper import WebScraperService
from ..services.gsc_service import GSCService
from ..models.backlink_analysis import BacklinkAnalysis
from ..models.project import KeywordRanking
from .auth import get_current_user
from ..tools import get_seo_agent_tools
from ..tools.seo_agent_handlers import (
    handle_connect_cms,
    handle_test_cms_connection,
    handle_analyze_content_tone,
    handle_generate_content_outline,
    handle_generate_full_article,
    handle_publish_content,
    handle_list_generated_content,
    handle_get_cms_categories,
)

router = APIRouter(prefix="/chat", tags=["chat"])
logger = logging.getLogger(__name__)

keyword_service = KeywordService()
llm_service = LLMService()
rank_checker = RankCheckerService()
backlink_service = RapidAPIBacklinkService()
dataforseo_backlink_service = DataForSEOBacklinksService()
dataforseo_service = DataForSEOService()
rapidapi_seo_service = RapidAPISEOService()
web_scraper = WebScraperService()
gsc_service = GSCService()


def save_technical_audit(
    db: Session,
    user_id: str,
    url: str,
    audit_data: Dict[str, Any]
) -> Optional[TechnicalAudit]:
    """
    Save technical audit results to database if a matching project exists
    
    Returns the saved TechnicalAudit or None if no matching project
    """
    try:
        # Find project by URL (match domain)
        from urllib.parse import urlparse
        parsed_url = urlparse(url)
        domain = parsed_url.netloc or parsed_url.path
        domain = domain.replace('www.', '').replace('http://', '').replace('https://', '').strip('/').lower()
        
        # Find projects where target_url contains this domain
        projects = db.query(Project).filter(
            Project.user_id == user_id
        ).all()
        
        matching_project = None
        for p in projects:
            if p.target_url:
                p_parsed = urlparse(p.target_url)
                p_domain = (p_parsed.netloc or p_parsed.path).replace('www.', '').replace('http://', '').replace('https://', '').strip('/').lower()
                if domain in p_domain or p_domain in domain:
                    matching_project = p
                    break
        
        if not matching_project:
            logger.info(f"📊 No matching project found for {url} (domain: {domain})")
            return None
        
        # Extract metrics from audit data
        raw_data = audit_data.get("raw_data", {})
        perf_data = raw_data.get("performance", {})
        seo_data = raw_data.get("seo", {})
        bot_data = raw_data.get("bots", {})
        
        metrics = perf_data.get("metrics", [])
        seo_issues = seo_data.get("issues", [])
        bots = bot_data.get("bots", [])
        
        # Parse performance metrics
        perf_metrics = {}
        for metric in metrics:
            name = metric.get("metric_name", "")
            if "Performance Score" in name:
                perf_metrics["performance_score"] = metric.get("score", 0)
            elif "FCP" in name:
                perf_metrics["fcp_value"] = metric.get("value")
                perf_metrics["fcp_score"] = metric.get("score", 0)
            elif "LCP" in name:
                perf_metrics["lcp_value"] = metric.get("value")
                perf_metrics["lcp_score"] = metric.get("score", 0)
            elif "CLS" in name:
                perf_metrics["cls_value"] = metric.get("value")
                perf_metrics["cls_score"] = metric.get("score", 0)
            elif "TBT" in name:
                perf_metrics["tbt_value"] = metric.get("value")
                perf_metrics["tbt_score"] = metric.get("score", 0)
            elif "TTI" in name:
                perf_metrics["tti_value"] = metric.get("value")
                perf_metrics["tti_score"] = metric.get("score", 0)
        
        # Count SEO issues by severity
        seo_high = sum(1 for issue in seo_issues if issue.get("severity") == "high")
        seo_medium = sum(1 for issue in seo_issues if issue.get("severity") == "medium")
        seo_low = sum(1 for issue in seo_issues if issue.get("severity") == "low")
        
        # Count bot access
        bots_allowed = sum(1 for bot in bots if bot.get("status") == "Allowed")
        bots_blocked = sum(1 for bot in bots if bot.get("status") == "Blocked")
        
        # Create audit record
        audit = TechnicalAudit(
            id=str(uuid.uuid4()),
            project_id=matching_project.id,
            url=url,
            audit_type="comprehensive",
            performance_score=perf_metrics.get("performance_score"),
            fcp_value=perf_metrics.get("fcp_value"),
            fcp_score=perf_metrics.get("fcp_score"),
            lcp_value=perf_metrics.get("lcp_value"),
            lcp_score=perf_metrics.get("lcp_score"),
            cls_value=perf_metrics.get("cls_value"),
            cls_score=perf_metrics.get("cls_score"),
            tbt_value=perf_metrics.get("tbt_value"),
            tbt_score=perf_metrics.get("tbt_score"),
            tti_value=perf_metrics.get("tti_value"),
            tti_score=perf_metrics.get("tti_score"),
            seo_issues_count=len(seo_issues),
            seo_issues_high=seo_high,
            seo_issues_medium=seo_medium,
            seo_issues_low=seo_low,
            bots_checked=len(bots),
            bots_allowed=bots_allowed,
            bots_blocked=bots_blocked,
            full_audit_data=audit_data,
            created_by=user_id
        )
        
        db.add(audit)
        db.commit()
        db.refresh(audit)
        
        logger.info(f"💾 Saved technical audit for project '{matching_project.name}' (score: {perf_metrics.get('performance_score', 0):.0f})")
        return audit
        
    except Exception as e:
        logger.error(f"Error saving technical audit: {e}", exc_info=True)
        db.rollback()
        return None


class ChatRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None
    project_id: Optional[str] = None
    agent_mode: Optional[str] = None  # "seo_agent_setup", "seo_agent", "seo_analytics"

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
                                    "description": "Number of keywords to return. Use 100 by default to provide comprehensive data for filtering and exploration (default 100)",
                                    "default": 100
                                }
                            },
                            "required": ["keyword_or_topic"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "expand_and_research_keywords",
                        "description": "🧠 INTELLIGENT keyword research using LLM expansion + multi-angle fetching. Use when: (1) User wants COMPREHENSIVE research, (2) User says 'find ALL keywords', 'explore everything', 'cast a wide net', (3) You need to discover keywords from DIFFERENT angles (competitors, problems, features). This tool is MORE POWERFUL than regular research - it generates diverse seed keywords, fetches from multiple angles in parallel, then uses AI reasoning to rank opportunities. Use this for deep research. Use regular 'research_keywords' for quick/simple lookups.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "topic": {
                                    "type": "string",
                                    "description": "The main topic/niche to research (e.g., 'seo tools', 'project management software')"
                                },
                                "expansion_strategy": {
                                    "type": "string",
                                    "enum": ["comprehensive", "competitor_focused", "problem_solution", "feature_based"],
                                    "description": "How to expand the search: 'comprehensive' (multiple angles), 'competitor_focused' (alternatives/comparisons), 'problem_solution' (problems & solutions), 'feature_based' (specific features)",
                                    "default": "comprehensive"
                                },
                                "location": {
                                    "type": "string",
                                    "description": "Search scope: 'global' or country code like 'US', 'UK', 'CA'. Default is 'US'.",
                                    "default": "US"
                                }
                            },
                            "required": ["topic"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "find_opportunity_keywords",
                        "description": "Find LOW DIFFICULTY opportunity keywords (high volume + easy to rank). Uses SEO difficulty scores (0-100) from DataForSEO to identify REAL ranking opportunities, not just ad competition. Perfect for: 'easy to rank', 'low competition', 'low KD', 'opportunity', 'quick wins', 'low hanging fruit'. Returns keywords sorted by organic ranking potential. Note: Only supports location-specific searches (not global). CRITICAL: Use the NICHE/TOPIC as seed keyword (e.g., 'seo tools', 'semrush alternative'), NEVER the domain name.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "keyword": {
                                    "type": "string",
                                    "description": "The seed keyword representing the NICHE/TOPIC to find opportunities for. IMPORTANT: Derive from tracked keywords - if project tracks 'best semrush alternative', use 'semrush alternative' or 'seo tools' as seed. NEVER use the domain name literally (e.g., 'keywords.chat' is WRONG, 'seo tools' is CORRECT)."
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
                        "name": "check_multiple_rankings",
                        "description": "Check where a domain ranks for multiple keywords at once (batch processing). Much faster than checking one at a time. Returns position data for each keyword with interactive table view. Use this when user asks to check rankings for multiple keywords or wants a ranking report.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "keywords": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "List of keywords to check rankings for"
                                },
                                "domain": {
                                    "type": "string",
                                    "description": "Domain to check (e.g., 'example.com')"
                                },
                                "location": {
                                    "type": "string",
                                    "description": "Location for search results (default: 'United States')",
                                    "default": "United States"
                                }
                            },
                            "required": ["keywords", "domain"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "analyze_website",
                        "description": "Analyze website content for keyword strategy and positioning. Scrapes pages to extract titles, headings, content and suggests keyword opportunities. Use when user asks about: keywords, content, positioning, SEO strategy. DO NOT use if user says 'technical' - use analyze_technical_seo instead. If request is ambiguous, ask which type of analysis they want.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "url": {
                                    "type": "string",
                                    "description": "Full URL of the website to analyze. If user refers to the project or their website without specifying URL, use the project's target_url from context."
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
                        "name": "analyze_technical_seo",
                        "description": "Run COMPREHENSIVE technical audit covering: 1) Technical SEO (meta tags, headings, broken links, images), 2) Performance (Core Web Vitals, LCP, FCP, CLS, TBT, Speed Index), 3) AI Bot Access (GPTBot, Claude, Perplexity, etc). Returns unified view of all issues. MODE: 'single' (default, fast ~5-7 sec) audits ONE page. MODE: 'full' (~30-60 sec) crawls sitemap and audits up to 15 pages with aggregate stats. Use 'full' when user says: 'full site', 'entire site', 'all pages', 'whole website'. Use 'single' for specific URLs or quick checks. DO NOT use for keyword/content analysis.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "url": {
                                    "type": "string",
                                    "description": "Full URL of the website to audit (e.g., 'https://example.com')"
                                },
                                "mode": {
                                    "type": "string",
                                    "enum": ["single", "full"],
                                    "description": "Audit mode: 'single' for one page (fast), 'full' for sitemap-based multi-page audit (slower)",
                                    "default": "single"
                                }
                            },
                            "required": ["url"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "check_ai_bot_access",
                        "description": "Check which AI bots can access and crawl the website (GPTBot, Claude-Web, Perplexity, etc.). Use when user asks about: AI crawlers, bot access, AI search visibility, which AI can see their site. Very fast (~1 sec).",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "url": {
                                    "type": "string",
                                    "description": "Full URL of the website to check (e.g., 'https://example.com')"
                                }
                            },
                            "required": ["url"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "analyze_performance",
                        "description": "Run full performance audit with Core Web Vitals (LCP, FCP, CLS, TBT, Speed Index). Use when user asks about: site speed, performance, load time, Core Web Vitals, Lighthouse score, page speed. Takes ~15 sec.",
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
                        "name": "get_project_keywords",
                        "description": "Get all keywords for a project, including both tracked keywords (actively monitored) and suggested keywords (auto-detected from website). Use when user asks to see/view current keywords, or wants to know what keywords are saved for a project.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "project_id": {
                                    "type": "string",
                                    "description": "The ID of the project to get keywords for"
                                }
                            },
                            "required": ["project_id"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_project_backlinks",
                        "description": "Get detailed backlink data for a project. Returns complete backlink profile including domain authority, total backlinks, referring domains, and list of all backlinks with their details (anchor text, domain rank, follow/nofollow status). Use when user asks about backlinks, link profile, or wants to see who's linking to their site.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "project_id": {
                                    "type": "string",
                                    "description": "The ID of the project to get backlinks for"
                                }
                            },
                            "required": ["project_id"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "get_project_pinboard",
                        "description": "Get all pinned items (saved insights, notes, recommendations) for a project or globally. Use when user asks to see saved/pinned information, past insights, or wants to review what they've bookmarked.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "project_id": {
                                    "type": "string",
                                    "description": "Optional project ID to filter pins. If not provided, returns all user's pins."
                                }
                            }
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "create_project",
                        "description": "Create a new project for tracking keywords and SEO metrics. Use when user wants to create/start a project for a website or when they want to track keywords for a site they don't have a project for yet. Returns the new project_id which can be used with track_keywords.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Project name (e.g., 'TinyLaunch', 'My Blog')"
                                },
                                "url": {
                                    "type": "string",
                                    "description": "Website URL (e.g., 'https://tinylaunch.com' or 'tinylaunch.com')"
                                }
                            },
                            "required": ["name", "url"]
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
            
            # Add SEO Agent tools if in SEO Agent mode
            if request.agent_mode in ["seo_agent_setup", "seo_agent"]:
                tools.extend(get_seo_agent_tools())

            # First LLM call
            response_text, reasoning, tool_calls = await llm_service.chat_with_tools(
                user_message=request.message,
                conversation_history=conversation_history,
                available_tools=tools,
                user_projects=user_projects_data if user_projects_data else None,
                agent_mode=request.agent_mode,
                project_id=request.project_id
            )
            
            # Execute tool calls with status updates
            if tool_calls:
                tool_results = []
                metadata = None  # Initialize metadata to store data panel info
                
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
                    elif tool_name == "check_multiple_rankings":
                        yield await send_sse_event("status", {"message": "Checking rankings for multiple keywords..."})
                    elif tool_name == "analyze_website":
                        yield await send_sse_event("status", {"message": "Analyzing website..."})
                    elif tool_name == "analyze_technical_seo":
                        # Check mode from args to show appropriate status
                        mode = tool_call.get("function", {}).get("arguments", {})
                        if isinstance(mode, str):
                            import json as json_lib
                            mode = json_lib.loads(mode).get("mode", "single")
                        else:
                            mode = mode.get("mode", "single")
                        
                        if mode == "full":
                            yield await send_sse_event("status", {"message": "Crawling sitemap & auditing multiple pages..."})
                        else:
                            yield await send_sse_event("status", {"message": "Running technical SEO audit..."})
                    elif tool_name == "check_ai_bot_access":
                        yield await send_sse_event("status", {"message": "Checking AI bot access..."})
                    elif tool_name == "analyze_performance":
                        yield await send_sse_event("status", {"message": "Analyzing performance & Core Web Vitals..."})
                    elif tool_name == "analyze_backlinks":
                        yield await send_sse_event("status", {"message": "Analyzing backlinks..."})
                    elif tool_name == "get_project_keywords":
                        yield await send_sse_event("status", {"message": "Getting project keywords..."})
                    elif tool_name == "get_project_backlinks":
                        yield await send_sse_event("status", {"message": "Loading backlink data..."})
                    elif tool_name == "get_project_pinboard":
                        yield await send_sse_event("status", {"message": "Loading pinned items..."})
                    elif tool_name == "create_project":
                        yield await send_sse_event("status", {"message": "Creating new project..."})
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
                    # SEO Agent status messages
                    elif tool_name == "connect_cms":
                        yield await send_sse_event("status", {"message": "🔗 Connecting to CMS..."})
                    elif tool_name == "test_cms_connection":
                        yield await send_sse_event("status", {"message": "🔍 Testing CMS connection..."})
                    elif tool_name == "analyze_content_tone":
                        yield await send_sse_event("status", {"message": "🎨 Analyzing writing style from your posts..."})
                    elif tool_name == "generate_content_outline":
                        yield await send_sse_event("status", {"message": "📝 Generating article outline..."})
                    elif tool_name == "generate_full_article":
                        yield await send_sse_event("status", {"message": "✍️ Writing full article..."})
                    elif tool_name == "publish_content":
                        yield await send_sse_event("status", {"message": "🚀 Publishing to CMS..."})
                    elif tool_name == "list_generated_content":
                        yield await send_sse_event("status", {"message": "📚 Fetching content library..."})
                    elif tool_name == "get_cms_categories":
                        yield await send_sse_event("status", {"message": "📂 Fetching CMS categories..."})
                    
                    try:
                        if tool_name == "research_keywords":
                            keyword_or_topic = args.get("keyword_or_topic")
                            location = args.get("location", "US")
                            limit = args.get("limit", 50)  # Fetch more keywords for data panel
                            
                            # Status: Fetching suggestions
                            yield await send_sse_event("status", {"message": f"📡 Fetching keyword suggestions for '{keyword_or_topic}'..."})
                            keyword_data = await keyword_service.analyze_keywords(keyword_or_topic, location=location, limit=limit)
                            
                            # Note: SERP analysis removed to reduce latency and API costs
                            # Keyword data already includes: search_volume, competition, CPC, intent, trend
                            
                            if keyword_data:
                                # Status: Enriching with SEO difficulty
                                yield await send_sse_event("status", {"message": f"📊 Enriching {len(keyword_data)} keywords with SEO difficulty..."})
                            
                            # ⚡ FILTER OUT ALREADY-TRACKED KEYWORDS (DATABASE-LEVEL)
                            # Filter against ALL user's tracked keywords across ALL projects
                            if keyword_data:
                                yield await send_sse_event("status", {"message": "🔍 Filtering out already-tracked keywords..."})
                                
                                user_projects = db.query(Project).filter(Project.user_id == user.id).all()
                                project_ids = [p.id for p in user_projects]
                                
                                tracked = db.query(TrackedKeyword).filter(
                                    TrackedKeyword.project_id.in_(project_ids),
                                    TrackedKeyword.is_active == 1
                                ).all()
                                tracked_keywords_lower = {kw.keyword.lower().strip() for kw in tracked}
                                
                                original_count = len(keyword_data)
                                keyword_data = [
                                    kw for kw in keyword_data 
                                    if kw.get("keyword", "").lower().strip() not in tracked_keywords_lower
                                ]
                                filtered_count = original_count - len(keyword_data)
                                
                                if filtered_count > 0:
                                    logger.info(f"🔍 Filtered out {filtered_count} already-tracked keywords from {len(tracked)} total tracked. {len(keyword_data)} remain.")
                                    yield await send_sse_event("status", {"message": f"✅ Found {len(keyword_data)} new keywords (filtered out {filtered_count} already tracked)"})
                            
                            response_data = {
                                "keywords": keyword_data,
                                "total_found": len(keyword_data) if keyword_data else 0
                            }
                            
                            try:
                                json_content = json.dumps(response_data)
                                logger.info(f"📤 Sending {len(keyword_data) if keyword_data else 0} keywords to LLM. Preview: {json_content[:300]}...")
                            except (TypeError, ValueError) as json_error:
                                logger.error(f"❌ Failed to serialize keyword data to JSON: {json_error}")
                                logger.error(f"   Keyword data type: {type(keyword_data)}, First item: {keyword_data[0] if keyword_data else 'None'}")
                                raise
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json_content
                            })
                        
                        elif tool_name == "expand_and_research_keywords":
                            topic = args.get("topic")
                            expansion_strategy = args.get("expansion_strategy", "comprehensive")
                            location = args.get("location", "US")
                            
                            # Import intelligent keyword service
                            from ..services.intelligent_keyword_service import IntelligentKeywordService
                            intelligent_service = IntelligentKeywordService(keyword_service, llm_service)
                            
                            # Build user context for intelligent research
                            tracked_keywords = []
                            if project:
                                tracked_keywords = db.query(TrackedKeyword).filter(
                                    TrackedKeyword.project_id == project.id
                                ).all()
                            
                            user_context = {
                                "tracked_keywords": [kw.keyword for kw in tracked_keywords],
                                "project_name": project.name if project else "",
                                "project_url": project.target_url if project else ""
                            }
                            
                            # Status: Phase 1 - Expand
                            yield await send_sse_event("status", {"message": f"🧠 Phase 1: Generating diverse seed keywords for '{topic}'..."})
                            
                            # Perform intelligent expand → fetch → contract
                            logger.info(f"🧠 Starting intelligent keyword research for: {topic}")
                            
                            # Status: Phase 2 - Fetch
                            yield await send_sse_event("status", {"message": "📥 Phase 2: Fetching keywords from multiple angles..."})
                            
                            result = await intelligent_service.expand_and_research(
                                topic=topic,
                                user_context=user_context,
                                location=location,
                                expansion_strategy=expansion_strategy
                            )
                            
                            # Status: Phase 3 - Complete
                            yield await send_sse_event("status", {"message": f"✅ Found {len(result['keywords'])} keywords from {result.get('total_fetched', 0)} analyzed"})
                            
                            # Store in metadata for side panel (auto-open)
                            metadata = {"keyword_data": result["keywords"]}
                            
                            # Return comprehensive result to LLM
                            response_data = {
                                "keywords": result["keywords"],
                                "total_found": len(result["keywords"]),
                                "total_fetched": result.get("total_fetched", 0),
                                "seeds_used": result.get("seeds_used", []),
                                "reasoning": result.get("reasoning", ""),
                                "expansion_strategy": expansion_strategy
                            }
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(response_data)
                            })
                        
                        elif tool_name == "find_opportunity_keywords":
                            keyword = args.get("keyword")
                            location = args.get("location", "US")
                            limit = args.get("limit", 10)
                            
                            opportunity_data = await keyword_service.get_opportunity_keywords(keyword, location=location, num=limit)
                            
                            if opportunity_data:
                                # Opportunity keywords are already in the correct format (includes seo_difficulty)
                                # Just need to ensure consistent field names
                                for item in opportunity_data:
                                    # Ensure all required fields exist
                                    if 'cpc' not in item and 'low_bid' in item and 'high_bid' in item:
                                        item['cpc'] = round((item.get('low_bid', 0) + item.get('high_bid', 0)) / 2, 2)
                                    if 'intent' not in item:
                                        item['intent'] = 'informational'
                                
                                # Store in metadata for side panel (auto-open)
                                metadata = {"keyword_data": opportunity_data}
                                
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": json.dumps(opportunity_data)
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
                                "content": json.dumps(ranking_data)
                            })
                        
                        elif tool_name == "check_multiple_rankings":
                            keywords = args.get("keywords", [])
                            domain = args.get("domain")
                            location = args.get("location", "United States")
                            
                            rankings_dict = await rank_checker.check_multiple_rankings(keywords, domain, location)
                            
                            # Convert to list format for table view
                            rankings_list = []
                            for keyword, data in rankings_dict.items():
                                rankings_list.append({
                                    "keyword": keyword,
                                    "position": data.get("position"),
                                    "url": data.get("page_url"),
                                    "title": data.get("title"),
                                    "description": data.get("description"),
                                })
                            
                            # Store in metadata for data panel
                            metadata = {
                                "ranking_data": rankings_list,
                                "domain": domain,
                                "location": location
                            }
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps({"rankings": rankings_list, "total_checked": len(keywords)})
                            })
                        
                        elif tool_name == "analyze_website":
                            url = args.get("url")
                            
                            website_data = await web_scraper.analyze_full_site(url)
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(website_data)
                            })
                        
                        elif tool_name == "analyze_technical_seo":
                            url = args.get("url")
                            mode = args.get("mode", "single")
                            
                            # Status updates based on mode
                            if mode == "full":
                                yield await send_sse_event("status", {"message": "📄 Fetching sitemap..."})
                            else:
                                yield await send_sse_event("status", {"message": "🔍 Analyzing SEO tags & structure..."})
                            
                            # Run comprehensive audit (SEO + Performance + AI Bots)
                            # Mode: "single" for one page, "full" for sitemap-based multi-page audit
                            audit_data = await rapidapi_seo_service.comprehensive_site_audit(url, mode=mode)
                            
                            # Status: Complete
                            if mode == "full":
                                page_count = len(audit_data.get("page_summaries", []))
                                yield await send_sse_event("status", {"message": f"✅ Audited {page_count} pages"})
                            else:
                                yield await send_sse_event("status", {"message": "✅ Audit complete"})
                            
                            # Store separate datasets in metadata for tabbed view
                            if audit_data.get("raw_data"):
                                raw = audit_data["raw_data"]
                                
                                if mode == "full":
                                    # Full site audit - include page summaries and common issues
                                    metadata = {
                                        "technical_audit_tabs": {
                                            "seo_issues": raw["seo"].get("issues", []),
                                            "performance": raw["performance"].get("metrics", []),
                                            "ai_bots": raw["bots"].get("bots", [])
                                        },
                                        "summary": audit_data.get("summary", {}),
                                        "page_summaries": audit_data.get("page_summaries", []),
                                        "common_issues": audit_data.get("common_issues", []),
                                        "url": url,
                                        "mode": "full"
                                    }
                                    logger.info(f"✅ Set metadata for FULL SITE audit: {len(audit_data.get('page_summaries', []))} pages, {len(raw['seo'].get('issues', []))} total SEO issues")
                                else:
                                    # Single page audit
                                    metadata = {
                                        "technical_audit_tabs": {
                                            "seo_issues": raw["seo"].get("issues", []),
                                            "performance": raw["performance"].get("metrics", []),
                                            "ai_bots": raw["bots"].get("bots", [])
                                        },
                                        "summary": audit_data.get("summary", {}),
                                        "url": url,
                                        "mode": "single"
                                    }
                                    logger.info(f"✅ Set metadata for single page audit: {len(raw['seo'].get('issues', []))} SEO issues, {len(raw['performance'].get('metrics', []))} performance metrics, {len(raw['bots'].get('bots', []))} bots")
                                
                                # Save audit to database if project exists
                                save_technical_audit(db, user.id, url, audit_data)
                            else:
                                logger.warning(f"⚠️ No raw_data in audit_data: {audit_data.keys()}")
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(audit_data)
                            })
                        
                        elif tool_name == "check_ai_bot_access":
                            url = args.get("url")
                            
                            bot_data = await rapidapi_seo_service.check_ai_bot_access(url)
                            
                            # Store bot access data in metadata for data panel
                            if not bot_data.get("error") and bot_data.get("bots"):
                                metadata = {
                                    "ai_bot_access": bot_data["bots"],
                                    "summary": bot_data.get("summary", {}),
                                    "url": url
                                }
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(bot_data)
                            })
                        
                        elif tool_name == "analyze_performance":
                            url = args.get("url")
                            
                            performance_data = await rapidapi_seo_service.analyze_performance(url)
                            
                            # Store performance metrics in metadata for data panel
                            if not performance_data.get("error") and performance_data.get("metrics"):
                                metadata = {
                                    "performance_data": performance_data["metrics"],
                                    "summary": performance_data.get("summary", {}),
                                    "url": url
                                }
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(performance_data)
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
                                    "content": json.dumps(backlink_data)
                                })
                        
                        elif tool_name == "get_project_keywords":
                            project_id = args.get("project_id")
                            
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
                                # Get all keywords (both tracked and suggestions)
                                keywords = db.query(TrackedKeyword).filter(
                                    TrackedKeyword.project_id == project_id
                                ).all()
                                
                                tracked_keywords = []
                                suggested_keywords = []
                                
                                for kw in keywords:
                                    kw_info = {
                                        "keyword": kw.keyword,
                                        "search_volume": kw.search_volume,
                                        "ad_competition": kw.competition,  # Frontend expects 'ad_competition'
                                        "seo_difficulty": kw.seo_difficulty,
                                        "cpc": kw.cpc if kw.cpc is not None else 0.0,
                                        "intent": kw.intent if kw.intent else "unknown",
                                        "trend": kw.trend if kw.trend is not None else 0.0,
                                        "status": "tracked" if kw.is_active else "suggestion"
                                    }
                                    
                                    if kw.is_active:
                                        tracked_keywords.append(kw_info)
                                    else:
                                        suggested_keywords.append(kw_info)
                                
                                result = {
                                    "project_name": project.name,
                                    "project_url": project.target_url,
                                    "tracked_keywords": tracked_keywords,
                                    "suggested_keywords": suggested_keywords,
                                    "total_tracked": len(tracked_keywords),
                                    "total_suggested": len(suggested_keywords)
                                }
                                
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": json.dumps(result)
                                })
                        
                        elif tool_name == "get_project_backlinks":
                            project_id = args.get("project_id")
                            
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
                                # Get backlink analysis
                                backlink_analysis = db.query(BacklinkAnalysis).filter(
                                    BacklinkAnalysis.project_id == project_id
                                ).first()
                                
                                if not backlink_analysis:
                                    tool_results.append({
                                        "tool_call_id": tool_call["id"],
                                        "role": "tool",
                                        "name": tool_name,
                                        "content": "No backlink data found. Run backlink analysis first using analyze_backlinks tool."
                                    })
                                else:
                                    # Return detailed backlink data
                                    result = {
                                        "project_name": project.name,
                                        "project_url": project.target_url,
                                        "domain_authority": backlink_analysis.domain_authority,
                                        "total_backlinks": backlink_analysis.total_backlinks,
                                        "referring_domains": backlink_analysis.referring_domains,
                                        "analyzed_at": backlink_analysis.analyzed_at.isoformat(),
                                        "backlinks": backlink_analysis.raw_data.get("backlinks", []) if backlink_analysis.raw_data else [],
                                        "anchor_texts": backlink_analysis.raw_data.get("anchor_texts", []) if backlink_analysis.raw_data else []
                                    }
                                    
                                    tool_results.append({
                                        "tool_call_id": tool_call["id"],
                                        "role": "tool",
                                        "name": tool_name,
                                        "content": json.dumps(result)
                                    })
                        
                        elif tool_name == "get_project_pinboard":
                            project_id = args.get("project_id")
                            
                            # Build query
                            query = db.query(PinnedItem).filter(
                                PinnedItem.user_id == user.id
                            )
                            
                            # Filter by project if specified
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
                                
                                query = query.filter(PinnedItem.project_id == project_id)
                            
                            # Get all pinned items
                            pinned_items = query.order_by(PinnedItem.created_at.desc()).all()
                            
                            pins = []
                            for pin in pinned_items:
                                pins.append({
                                    "title": pin.title,
                                    "content": pin.content,
                                    "content_type": pin.content_type,
                                    "created_at": pin.created_at.isoformat(),
                                    "project_id": pin.project_id
                                })
                            
                            result = {
                                "total_pins": len(pins),
                                "pins": pins
                            }
                            
                            if project_id:
                                result["filtered_by_project"] = project.name
                            
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(result)
                            })
                        
                        elif tool_name == "create_project":
                            project_name = args.get("name")
                            project_url = args.get("url")
                            
                            # Validate inputs
                            if not project_name or not project_url:
                                tool_results.append({
                                    "tool_call_id": tool_call["id"],
                                    "role": "tool",
                                    "name": tool_name,
                                    "content": "ERROR: Project name and URL are required"
                                })
                            else:
                                # Normalize URL
                                if not project_url.startswith(('http://', 'https://')):
                                    project_url = f'https://{project_url}'
                                
                                try:
                                    # Create new project
                                    new_project = Project(
                                        id=str(uuid.uuid4()),
                                        user_id=user.id,
                                        name=project_name,
                                        target_url=project_url
                                    )
                                    db.add(new_project)
                                    db.commit()
                                    db.refresh(new_project)
                                    
                                    logger.info(f"✅ Created new project '{project_name}' (ID: {new_project.id}) for URL: {project_url}")
                                    
                                    result = {
                                        "success": True,
                                        "project_id": new_project.id,
                                        "project_name": project_name,
                                        "project_url": project_url,
                                        "message": f"Successfully created project '{project_name}' for {project_url}"
                                    }
                                    
                                    tool_results.append({
                                        "tool_call_id": tool_call["id"],
                                        "role": "tool",
                                        "name": tool_name,
                                        "content": json.dumps(result)
                                    })
                                except Exception as e:
                                    logger.error(f"Failed to create project: {e}")
                                    tool_results.append({
                                        "tool_call_id": tool_call["id"],
                                        "role": "tool",
                                        "name": tool_name,
                                        "content": f"ERROR: Failed to create project - {str(e)}"
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
                                            competition=kw_data.get("competition") or kw_data.get("ad_competition"),
                                            seo_difficulty=kw_data.get("seo_difficulty"),
                                            intent=kw_data.get("intent"),
                                            cpc=kw_data.get("cpc"),
                                            trend=kw_data.get("trend")
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
                        
                        # SEO Agent Tools
                        elif tool_name == "connect_cms":
                            result = await handle_connect_cms(
                                db=db,
                                project_id=args.get("project_id"),
                                cms_type=args.get("cms_type"),
                                cms_url=args.get("cms_url"),
                                username=args.get("username"),
                                password=args.get("password")
                            )
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(result)
                            })
                        
                        elif tool_name == "test_cms_connection":
                            result = await handle_test_cms_connection(
                                db=db,
                                project_id=args.get("project_id")
                            )
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(result)
                            })
                        
                        elif tool_name == "analyze_content_tone":
                            result = await handle_analyze_content_tone(
                                db=db,
                                project_id=args.get("project_id"),
                                num_posts=args.get("num_posts", 5)
                            )
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(result)
                            })
                        
                        elif tool_name == "generate_content_outline":
                            result = await handle_generate_content_outline(
                                db=db,
                                project_id=args.get("project_id"),
                                topic=args.get("topic"),
                                target_keywords=args.get("target_keywords", []),
                                word_count_target=args.get("word_count_target", 1500)
                            )
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(result)
                            })
                        
                        elif tool_name == "generate_full_article":
                            result = await handle_generate_full_article(
                                db=db,
                                project_id=args.get("project_id"),
                                outline_id=args.get("outline_id"),
                                modifications=args.get("modifications")
                            )
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(result)
                            })
                        
                        elif tool_name == "publish_content":
                            result = await handle_publish_content(
                                db=db,
                                project_id=args.get("project_id"),
                                content_id=args.get("content_id"),
                                status=args.get("status", "draft"),
                                categories=args.get("categories")
                            )
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(result)
                            })
                        
                        elif tool_name == "list_generated_content":
                            result = await handle_list_generated_content(
                                db=db,
                                project_id=args.get("project_id"),
                                status_filter=args.get("status_filter", "all"),
                                limit=args.get("limit", 10)
                            )
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(result)
                            })
                        
                        elif tool_name == "get_cms_categories":
                            result = await handle_get_cms_categories(
                                db=db,
                                project_id=args.get("project_id")
                            )
                            tool_results.append({
                                "tool_call_id": tool_call["id"],
                                "role": "tool",
                                "name": tool_name,
                                "content": json.dumps(result)
                                })

                    except Exception as e:
                        logger.error(f"❌ Tool execution failed for {tool_name}: {str(e)}", exc_info=True)
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
                
                # Get final response with tools still available to avoid confusing the model
                # Status: Generating response
                yield await send_sse_event("status", {"message": "✍️ Writing response..."})
                
                # The LLM can decide if it needs to call more tools or provide a final response
                assistant_response, reasoning, follow_up_tools = await llm_service.chat_with_tools(
                    user_message="Based on the tool results above, provide a clear and helpful response to the user.",
                    conversation_history=conversation_history,
                    available_tools=tools,  # Keep tools available so LLM doesn't get confused
                    user_projects=user_projects_data if user_projects_data else None
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
                # Don't reset metadata if it was set during tool execution
                if 'metadata' not in locals() or metadata is None:
                    metadata = {}
                if reasoning:
                    metadata["reasoning"] = reasoning
                
                # Save keyword data in metadata if tools were used
                if tool_calls and len(tool_calls) > 0:
                    for tool_call in tool_calls:
                        if tool_call["name"] == "research_keywords":
                            # Extract keyword data from tool results
                            for result in tool_results:
                                if result.get("name") == "research_keywords":
                                    try:
                                        import json as json_module
                                        result_data = json_module.loads(result.get("content", "{}"))
                                        if "keywords" in result_data:
                                            metadata["keyword_data"] = result_data["keywords"]
                                            break
                                    except:
                                        pass
                        
                        elif tool_call["name"] == "get_project_keywords":
                            # Extract keyword data from project keywords tool
                            for result in tool_results:
                                if result.get("name") == "get_project_keywords":
                                    try:
                                        import json as json_module
                                        result_data = json_module.loads(result.get("content", "{}"))
                                        
                                        # Combine tracked and suggested keywords into flat list for the data panel
                                        keyword_data = []
                                        
                                        # Add tracked keywords
                                        for kw in result_data.get("tracked_keywords", []):
                                            keyword_data.append({
                                                "keyword": kw.get("keyword"),
                                                "search_volume": kw.get("search_volume"),
                                                "ad_competition": kw.get("ad_competition"),
                                                "seo_difficulty": kw.get("seo_difficulty"),
                                                "cpc": kw.get("cpc", 0.0),
                                                "intent": kw.get("intent", "unknown"),
                                                "trend": kw.get("trend", 0.0),
                                                "source": "tracked"
                                            })
                                        
                                        # Add suggested keywords
                                        for kw in result_data.get("suggested_keywords", []):
                                            keyword_data.append({
                                                "keyword": kw.get("keyword"),
                                                "search_volume": kw.get("search_volume"),
                                                "ad_competition": kw.get("ad_competition"),
                                                "seo_difficulty": kw.get("seo_difficulty"),
                                                "cpc": kw.get("cpc", 0.0),
                                                "intent": kw.get("intent", "unknown"),
                                                "trend": kw.get("trend", 0.0),
                                                "source": "suggested"
                                            })
                                        
                                        if keyword_data:
                                            metadata["keyword_data"] = keyword_data
                                            logger.info(f"📊 Set metadata with {len(keyword_data)} keywords from get_project_keywords")
                                            break
                                    except Exception as e:
                                        logger.error(f"Failed to extract keyword data from get_project_keywords: {e}")
                                        pass

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
            
            # Send final response with metadata (ensure message is always a string, not None)
            message_data = {
                "message": assistant_response or "",
                "conversation_id": conversation.id
            }
            
            # Debug: Print metadata state
            logger.info(f"🔍 DEBUG: About to check metadata. metadata={metadata}, type={type(metadata)}, bool={bool(metadata) if metadata else 'N/A'}")
            
            # Include metadata if available (for keyword data, etc.)
            # Check if metadata exists and is not just an empty dict
            if assistant_response and 'metadata' in locals() and metadata is not None and (isinstance(metadata, dict) and len(metadata) > 0):
                logger.info(f"📊 Including metadata in SSE response: {list(metadata.keys())}")
                message_data["metadata"] = metadata
            else:
                logger.warning(f"⚠️ No metadata to include. assistant_response={bool(assistant_response)}, metadata_in_locals={'metadata' in locals()}, metadata_value={metadata}, metadata_type={type(metadata) if 'metadata' in locals() else 'NOT IN LOCALS'}")
            
            logger.info(f"🚀 Final message_data keys: {list(message_data.keys())}")
            yield await send_sse_event("message", message_data)
            
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

# ========================================================================
# NON-STREAMING ENDPOINT REMOVED (~1600 lines)
# Frontend only uses the streaming endpoint above (/message/stream)
# Removed unused @router.post("/message") endpoint to simplify codebase
# ========================================================================

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


@router.get("/project/{project_id}/technical-audits")
async def get_project_audits(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """
    Get technical audit history for a project
    
    Returns audit results ordered by date (newest first) with performance trends
    """
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    # Verify project belongs to user
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Get all audits for this project
    audits = db.query(TechnicalAudit).filter(
        TechnicalAudit.project_id == project_id
    ).order_by(TechnicalAudit.created_at.desc()).all()
    
    # Format response with trends
    audit_history = []
    for i, audit in enumerate(audits):
        audit_dict = {
            "id": audit.id,
            "url": audit.url,
            "audit_type": audit.audit_type,
            "created_at": audit.created_at.isoformat(),
            "performance_score": audit.performance_score,
            "fcp_value": audit.fcp_value,
            "fcp_score": audit.fcp_score,
            "lcp_value": audit.lcp_value,
            "lcp_score": audit.lcp_score,
            "cls_value": audit.cls_value,
            "cls_score": audit.cls_score,
            "tbt_value": audit.tbt_value,
            "tbt_score": audit.tbt_score,
            "tti_value": audit.tti_value,
            "tti_score": audit.tti_score,
            "seo_issues_count": audit.seo_issues_count,
            "seo_issues_high": audit.seo_issues_high,
            "seo_issues_medium": audit.seo_issues_medium,
            "seo_issues_low": audit.seo_issues_low,
            "bots_checked": audit.bots_checked,
            "bots_allowed": audit.bots_allowed,
            "bots_blocked": audit.bots_blocked,
            "full_audit_data": audit.full_audit_data,  # Added this!
            "core_web_vitals": {
                "fcp": {"value": audit.fcp_value, "score": audit.fcp_score},
                "lcp": {"value": audit.lcp_value, "score": audit.lcp_score},
                "cls": {"value": audit.cls_value, "score": audit.cls_score},
                "tbt": {"value": audit.tbt_value, "score": audit.tbt_score},
                "tti": {"value": audit.tti_value, "score": audit.tti_score},
            }
        }
        
        # Calculate trend vs previous audit
        if i < len(audits) - 1:
            prev_audit = audits[i + 1]
            if audit.performance_score and prev_audit.performance_score:
                audit_dict["performance_trend"] = audit.performance_score - prev_audit.performance_score
            if audit.seo_issues_count and prev_audit.seo_issues_count:
                audit_dict["seo_issues_trend"] = prev_audit.seo_issues_count - audit.seo_issues_count  # Positive = improvement
        
        audit_history.append(audit_dict)
    
    return {
        "project_id": project_id,
        "project_name": project.name,
        "total_audits": len(audits),
        "audits": audit_history
    }


# SEO Agent - Content Management Endpoints

@router.get("/seo-agent/content/{content_id}")
async def get_generated_content(
    content_id: str,
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get a generated content article by ID"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    # Verify project belongs to user
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Get content
    from ..models.seo_agent import GeneratedContent
    content = db.query(GeneratedContent).filter(
        GeneratedContent.id == content_id,
        GeneratedContent.project_id == project_id
    ).first()
    
    if not content:
        raise HTTPException(status_code=404, detail="Content not found")
    
    return {
        "success": True,
        "content": {
            "id": content.id,
            "title": content.title,
            "content": content.content,
            "excerpt": content.excerpt,
            "target_keywords": content.target_keywords,
            "seo_score": content.seo_score,
            "word_count": content.word_count,
            "readability_score": content.readability_score,
            "status": content.status,
            "published_at": content.published_at.isoformat() if content.published_at else None,
            "published_url": content.published_url,
            "cms_post_id": content.cms_post_id,
            "created_at": content.created_at.isoformat() if content.created_at else None,
            "metadata": content.generation_metadata or {}
        }
    }


@router.post("/seo-agent/content")
async def create_generated_content(
    request: dict,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Create a new generated content article"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    project_id = request.get("project_id")
    
    # Verify project belongs to user
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Create content
    from ..models.seo_agent import GeneratedContent
    import uuid
    
    content = GeneratedContent(
        id=str(uuid.uuid4()),
        project_id=project_id,
        title=request.get("title"),
        content=request.get("content"),
        excerpt=request.get("excerpt"),
        target_keywords=request.get("target_keywords", []),
        status=request.get("status", "draft"),
        word_count=len(request.get("content", "").split()),
        generation_metadata=request.get("metadata", {})
    )
    
    db.add(content)
    db.commit()
    db.refresh(content)
    
    return {
        "success": True,
        "content_id": content.id,
        "message": "Content created successfully"
    }


@router.put("/seo-agent/content/{content_id}")
async def update_generated_content(
    content_id: str,
    request: dict,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Update an existing generated content article"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    project_id = request.get("project_id")
    
    # Verify project belongs to user
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Get content
    from ..models.seo_agent import GeneratedContent
    content = db.query(GeneratedContent).filter(
        GeneratedContent.id == content_id,
        GeneratedContent.project_id == project_id
    ).first()
    
    if not content:
        raise HTTPException(status_code=404, detail="Content not found")
    
    # Update fields
    if "title" in request:
        content.title = request["title"]
    if "content" in request:
        content.content = request["content"]
        content.word_count = len(request["content"].split())
    if "excerpt" in request:
        content.excerpt = request["excerpt"]
    if "target_keywords" in request:
        content.target_keywords = request["target_keywords"]
    if "status" in request:
        content.status = request["status"]
    if "metadata" in request:
        content.generation_metadata = request["metadata"]
    
    db.commit()
    
    # If status is published, trigger actual publishing
    if request.get("status") == "published" and not content.published_url:
        # TODO: Trigger actual CMS publishing
        pass
    
    return {
        "success": True,
        "content_id": content.id,
        "message": "Content updated successfully"
    }


@router.get("/seo-agent/cms/categories")
async def get_cms_categories(
    project_id: str,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """Get available CMS categories for a project"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    # Verify project belongs to user
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Get CMS integration
    from ..models.seo_agent import ProjectIntegration
    integration = db.query(ProjectIntegration).filter(
        ProjectIntegration.project_id == project_id,
        ProjectIntegration.is_active == True
    ).first()
    
    if not integration:
        return {"success": False, "error": "No active CMS integration"}
    
    # Get categories from CMS
    try:
        from ..tools.seo_agent_handlers import _decrypt_password
        from ..services.cms_service import create_cms_service
        
        password = _decrypt_password(integration.encrypted_password)
        cms_service = create_cms_service(
            integration.cms_type,
            cms_url=integration.cms_url,
            username=integration.username,
            password=password
        )
        
        categories_result = await cms_service.get_categories()
        
        return {
            "success": True,
            "categories": categories_result.get("categories", [])
        }
    except Exception as e:
        logger.error(f"Error getting CMS categories: {e}")
        return {"success": False, "error": str(e)}


@router.get("/seo-agent/project/{project_id}/content")
async def list_generated_content(
    project_id: str,
    status: str = None,
    limit: int = 50,
    authorization: str = Header(...),
    db: Session = Depends(get_db)
):
    """List all generated content for a project"""
    token = authorization.replace("Bearer ", "")
    user = get_current_user(token, db)
    
    # Verify project belongs to user
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user.id
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Query content
    from ..models.seo_agent import GeneratedContent
    query = db.query(GeneratedContent).filter(
        GeneratedContent.project_id == project_id
    )
    
    if status:
        query = query.filter(GeneratedContent.status == status)
    
    contents = query.order_by(GeneratedContent.created_at.desc()).limit(limit).all()
    
    # Format response
    content_list = []
    for content in contents:
        content_list.append({
            "id": content.id,
            "title": content.title,
            "excerpt": content.excerpt,
            "target_keywords": content.target_keywords or [],
            "seo_score": content.seo_score,
            "word_count": content.word_count,
            "readability_score": content.readability_score,
            "status": content.status,
            "published_at": content.published_at.isoformat() if content.published_at else None,
            "published_url": content.published_url,
            "cms_post_id": content.cms_post_id,
            "created_at": content.created_at.isoformat() if content.created_at else None,
            "metadata": content.generation_metadata or {}
        })
    
    return {
        "success": True,
        "content": content_list,
        "total": len(content_list)
    }

