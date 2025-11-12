# 🛠️ Available SEO Tools

**CONSOLIDATED** - Reduced from 20 to 9 core tools for better performance and clarity.

The LLM has access to these 9 essential tools during conversations:

---

## 1. **research_keywords**
Research keywords with search volume, competition, and SEO difficulty scores.

**When to use:** User wants keyword data for a topic/niche OR wants to analyze what keywords a URL ranks for

**Parameters:**
- `keyword_or_topic` (required): The keyword/topic to research (e.g., "AI chatbots") OR a URL (e.g., "example.com")
- `location` (optional): Search scope - `"global"` for worldwide data, or country code like `"US"`, `"UK"`, `"CA"`, `"AU"` (default: "US")
- `limit` (optional): Number of keywords to return (default: 50)
- `opportunity_only` (optional): If true, filters to show only LOW DIFFICULTY opportunity keywords (easy to rank). Use when user asks for "easy to rank", "low competition", "quick wins" (default: false)

**Returns:**
- List of keywords with:
  - Search volume (monthly searches - global or location-specific)
  - Competition level (LOW/MEDIUM/HIGH)
  - Competition index (0-100)
  - SEO difficulty (0-100) - organic ranking difficulty
  - CPC (cost per click) + low/high bid
  - Trend (growth/decline %)
  - Search intent (informational, commercial, transactional, navigational)

**Examples:**
```
User: "Find keywords for my SEO toolkit"
LLM: research_keywords(keyword_or_topic="SEO toolkit", location="US", limit=50)

User: "What keywords does rapidapi.com rank for globally?"
LLM: research_keywords(keyword_or_topic="rapidapi.com", location="global", limit=20)

User: "Give me easy to rank keywords for AI chatbots"
LLM: research_keywords(keyword_or_topic="AI chatbots", opportunity_only=true, limit=20)
```

---

## 2. **check_multiple_rankings**
Check where a domain ranks for one or multiple keywords (batch processing).

**When to use:** User wants to check rankings (replaces both check_ranking and check_multiple_rankings)

**Parameters:**
- `keywords` (required): List of keywords to check rankings for (can be a single keyword)
- `domain` (required): Domain to check (e.g., "example.com")
- `location` (optional): Location for search results (default: "United States")

**Returns:**
- Position data for each keyword (1-100 or None)
- URL of the ranking page
- Title and description

**Example:**
```
User: "Where do I rank for 'seo tools'?"
LLM: check_multiple_rankings(keywords=["seo tools"], domain="keywords.chat")

User: "Check my rankings for these 5 keywords"
LLM: check_multiple_rankings(keywords=[...], domain="keywords.chat", location="United States")
```

---

## 3. **analyze_website**
Analyze website for SEO with multiple modes.

**When to use:** User wants to analyze a website (content, technical, or full site audit)

**Parameters:**
- `url` (required): Full URL to analyze (e.g., "https://example.com")
- `mode` (optional): Analysis mode:
  - `"content"` (default, fast ~3-5 sec): Analyzes content, keywords, and positioning
  - `"technical"` (~5-10 sec): Comprehensive technical audit with meta tags, broken links, performance, Core Web Vitals, AI bot access
  - `"full_technical"` (~30-60 sec): Crawls sitemap and audits up to 15 pages with aggregate stats

**Mode Selection:**
- Use `"technical"` when user says: "technical", "audit", "health check", "technical issues"
- Use `"full_technical"` when user says: "full site", "entire site", "all pages", "whole website"
- Use `"content"` (default) for: "analyze", "keywords", "content strategy", "positioning"

**Returns:**
- **Content mode**: Title, meta description, headings, content, keyword suggestions
- **Technical mode**: SEO issues, performance metrics (Core Web Vitals), AI bot access, broken links
- **Full technical mode**: Aggregate stats across multiple pages, comprehensive site health

**Examples:**
```
User: "Analyze my competitor example.com"
LLM: analyze_website(url="https://example.com", mode="content")

User: "Run a technical audit on my site"
LLM: analyze_website(url="https://keywords.chat", mode="technical")

User: "Check technical issues across my entire site"
LLM: analyze_website(url="https://keywords.chat", mode="full_technical")
```

---

## 4. **analyze_backlinks**
Analyze backlink profile for a domain.

**When to use:** User wants backlink data

**Parameters:**
- `domain` (required): Domain to analyze without http:// (e.g., "example.com")

**Returns:**
- Total backlinks count
- Referring domains count
- Domain Authority (DA)
- Top backlinks with source URL, anchor text, link quality metrics, spam score

**Example:**
```
User: "Show me backlinks for keywords.chat"
LLM: analyze_backlinks(domain="keywords.chat")
```

---

## 5. **analyze_project_status**
Load complete project data and analyze SEO progress.

**When to use:** User asks about a specific project, wants to work on SEO strategy, or asks how their project is doing. **ALWAYS use this first when discussing an existing project.**

**Parameters:**
- `project_id` (required): The ID of the project to analyze

**Returns:**
- All tracked keywords with current rankings
- Historical progress
- Backlink profile
- Overall SEO assessment
- Suggested keywords (auto-detected)

**Example:**
```
User: "How is my keywords.chat project doing?"
LLM: analyze_project_status(project_id="abc-123-xyz")
```

---

## 6. **create_project**
Create a new project for tracking keywords and SEO metrics.

**When to use:** User wants to create/start a project for a website or when they want to track keywords for a site they don't have a project for yet

**Parameters:**
- `name` (required): Project name (e.g., "TinyLaunch", "My Blog")
- `url` (required): Website URL (e.g., "https://tinylaunch.com" or "tinylaunch.com")

**Returns:**
- `success`: Boolean indicating if project was created
- `project_id`: The ID of the newly created project (use this for track_keywords)
- `project_name`: Name of the project
- `project_url`: URL of the project
- `message`: Success message

**Example:**
```
User: "Create a project for tinylaunch.com and start tracking"
LLM: create_project(name="TinyLaunch", url="https://tinylaunch.com")
```

---

## 7. **track_keywords**
Add keywords to a project's keyword tracker for rank tracking.

**When to use:** User wants to track/monitor keywords for their project

**Parameters:**
- `project_id` (required): The ID of the project
- `keywords` (required): Array of keywords with:
  - `keyword` (required): The keyword text
  - `search_volume` (optional): Monthly search volume
  - `competition` (optional): Competition level (LOW/MEDIUM/HIGH)

**Example:**
```
User: "Track these top 5 keywords for my project"
LLM: track_keywords(project_id="abc-123", keywords=[...])
```

---

## 8. **get_gsc_performance**
Get real Google Search Console data for a project.

**When to use:** User wants actual GSC data (not estimates) - clicks, impressions, CTR, average position, indexing status

**Parameters:**
- `project_id` (required): The ID of the project
- `data_type` (optional): Type of GSC data:
  - `"overview"` (default): Summary stats (clicks, impressions, CTR, position)
  - `"queries"`: Top keywords with click data
  - `"pages"`: Top pages with click data
  - `"sitemaps"`: Sitemap status
  - `"indexing"`: Indexing coverage
- `limit` (optional): For queries/pages, number of results to return (default: 20)

**Example:**
```
User: "Show me my Google Search Console data"
LLM: get_gsc_performance(project_id="abc-123", data_type="overview")

User: "What queries are getting clicks in GSC?"
LLM: get_gsc_performance(project_id="abc-123", data_type="queries", limit=50)
```

---

## 9. **pin_important_info**
Pin important information, insights, or responses to the pinboard for later reference.

**When to use:** User wants to save something important, bookmark key findings, or keep track of valuable insights

**Parameters:**
- `title` (required): A concise title (max 100 characters)
- `content` (required): The content to pin (insights, analysis, recommendations)
- `content_type` (optional): Type of content - "insight", "analysis", "recommendation", "note", "finding" (default: "insight")
- `project_id` (optional): Associate with a specific project

**Example:**
```
User: "Save this for later"
LLM: pin_important_info(title="SEO Strategy", content="...", content_type="recommendation")
```

---

## Tool Consolidation Notes

**Removed/Merged Tools:**
- ❌ `expand_and_research_keywords` - Too complex, functionality merged into `research_keywords`
- ❌ `find_opportunity_keywords` - Merged into `research_keywords` via `opportunity_only` parameter
- ❌ `check_ranking` - Use `check_multiple_rankings` for all ranking checks
- ❌ `analyze_technical_seo` - Merged into `analyze_website` via `mode` parameter
- ❌ `check_ai_bot_access` - Merged into `analyze_website` technical mode
- ❌ `analyze_performance` - Merged into `analyze_website` technical mode
- ❌ `get_project_keywords` - Use `analyze_project_status` which returns all project data
- ❌ `get_project_backlinks` - Use `analyze_project_status` which returns backlink data
- ❌ `get_project_pinboard` - Less critical, removed for simplicity
- ❌ `link_gsc_property` - Handle in UI, not chat

**Benefits:**
- ✅ Faster LLM response times (fewer tools to process)
- ✅ Clearer tool selection logic
- ✅ Reduced token usage
- ✅ Easier to maintain and extend
- ✅ Less confusion for the LLM

---

## API Services Behind The Tools

| Tool | Service | API Used |
|------|---------|----------|
| research_keywords | `keyword_service.py` | RapidAPI Google Keyword Research + DataForSEO |
| check_multiple_rankings | `rank_checker.py` | DataForSEO SERP API |
| analyze_website | `web_scraper.py` + `rapidapi_seo_service.py` | Direct HTTP + RapidAPI Technical SEO |
| analyze_backlinks | `rapidapi_backlinks_service.py` | RapidAPI SEO Backlinks API |
| analyze_project_status | Database + multiple services | Internal |
| track_keywords | Database | Internal |
| get_gsc_performance | `gsc_service.py` | Google Search Console API |
| pin_important_info | Database | Internal |

---

**The LLM now has 8 powerful, focused SEO tools at its disposal! 🎉**
