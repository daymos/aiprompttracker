# 🛠️ Available SEO Tools

The LLM has access to these 5 tools during conversations:

---

## 1. **research_keywords**
Research keywords with search volume, competition, and SERP analysis. **Supports topics, URLs, and global/location-specific searches!**

**When to use:** User wants keyword data for a topic/niche OR wants to analyze what keywords a URL ranks for

**Parameters:**
- `keyword_or_topic` (required): The keyword/topic to research (e.g., "AI chatbots", "SEO software") OR a URL (e.g., "example.com", "https://example.com")
- `location` (optional): Search scope - `"global"` for worldwide data, or country code like `"US"`, `"UK"`, `"CA"`, `"AU"` for location-specific data (default: "US")
- `limit` (optional): Number of keywords to return (default: 10)

**Returns:**
- List of keywords with:
  - Search volume (monthly searches - global or location-specific)
  - Competition level (LOW/MEDIUM/HIGH)
  - Competition index (0-100)
  - CPC (cost per click) + low/high bid
  - Trend (growth/decline %)
  - Search intent (informational, commercial, transactional, navigational)
  - SERP analysis (top 5 keywords only)
  - SERP insight (difficulty assessment)

**Examples:**
```
User: "Find keywords for my SEO toolkit"
LLM: research_keywords(keyword_or_topic="SEO toolkit", location="US", limit=10)
→ Returns 10 US-specific keywords

User: "What keywords does rapidapi.com rank for globally?"
LLM: research_keywords(keyword_or_topic="rapidapi.com", location="global", limit=20)
→ Returns global keyword data for rapidapi.com

User: "Give me UK keywords for 'AI chatbots'"
LLM: research_keywords(keyword_or_topic="AI chatbots", location="UK", limit=15)
→ Returns 15 UK-specific keywords
```

---

## 2. **find_opportunity_keywords**
Find high-potential, low-competition keywords that are easier to rank for (the "quick wins"). **Location-specific only.**

**When to use:** User asks for "easy to rank", "low competition", "opportunity", "quick wins", or "low hanging fruit" keywords

**Parameters:**
- `keyword` (required): The seed keyword to find opportunities for
- `location` (optional): Country code like `"US"`, `"UK"`, `"CA"`, `"AU"` (default: "US"). Note: Global searches not supported for opportunity keywords.
- `limit` (optional): Number of opportunity keywords to return (default: 10)

**Returns:**
- List of opportunity keywords with:
  - Search volume
  - Competition level (typically LOW or MEDIUM)
  - Competition index
  - CPC data
  - Trend data
  - Search intent
  - Opportunity score (HIGH)

**Examples:**
```
User: "Give me easy to rank keywords for 'SEO software'"
LLM: find_opportunity_keywords(keyword="SEO software", location="US", limit=15)
→ Returns 15 low-competition US keywords

User: "Show me quick wins for 'AI tools' in the UK"
LLM: find_opportunity_keywords(keyword="AI tools", location="UK", limit=10)
→ Returns 10 UK-specific opportunity keywords
```

---

## 3. **check_ranking**
Check where a domain ranks in Google for a specific keyword.

**When to use:** User wants to know their ranking position

**Parameters:**
- `keyword` (required): The keyword to check
- `domain` (required): Domain to check (e.g., "example.com")

**Returns:**
- `position`: Ranking position (1-100) or None if not ranking
- `page_url`: The specific page that's ranking

**Example:**
```
User: "Where do I rank for 'seo software'?"
LLM: check_ranking(keyword="seo software", domain="keywords.chat")
→ Returns: {position: 47, page_url: "https://keywords.chat/tools"}
```

---

## 3. **analyze_website**
Crawl and analyze a website's SEO structure.

**When to use:** User provides a URL and wants SEO analysis

**Parameters:**
- `url` (required): Full URL to analyze (e.g., "https://example.com")

**Returns:**
- Title tag
- Meta description
- Meta keywords
- All H1, H2, H3 headings
- Main content preview
- Number of links and images
- Pages analyzed (if sitemap found)
- SEO recommendations

**Example:**
```
User: "Analyze my competitor example.com"
LLM: analyze_website(url="https://example.com")
→ Returns full SEO analysis of the site
```

---

## 4. **analyze_backlinks**
Analyze backlink profile for a domain.

**When to use:** User wants backlink data for a domain

**Parameters:**
- `domain` (required): Domain to analyze without http:// (e.g., "example.com")

**Returns:**
- Total backlinks count
- Referring domains count
- Domain Authority (DA)
- Top backlinks with:
  - Source URL
  - Target URL
  - Anchor text
  - Link quality metrics (inlink_rank, domain_inlink_rank)
  - Spam score
  - Nofollow status
- Historical trends (monthly growth)
- New/lost backlinks
- Anchor text distribution

**Example:**
```
User: "Show me backlinks for keywords.chat"
LLM: analyze_backlinks(domain="keywords.chat")
→ Returns: 42 backlinks, 18 referring domains, DA: 12, top sources...
```

**⚠️ Usage Limit:** 5 requests/month (free beta)

---

## How The LLM Uses These

The LLM has natural access to these tools during conversation:

### **Example 1: Keyword Research Flow**
```
User: "I need keywords for my AI chatbot product"
LLM: [calls research_keywords(keyword_or_topic="AI chatbot", limit=10)]
System: [executes, returns 10 keywords with data]
LLM: "Here are 10 keyword opportunities for your AI chatbot:
     | Keyword | Searches/mo | Competition |
     | AI chatbot builder | 2.4k | LOW |
     ..."
```

### **Example 2: Competitor Analysis Flow**
```
User: "Analyze my competitor example.com and check if they rank for 'SEO tools'"
LLM: [calls analyze_website(url="https://example.com") + check_ranking(keyword="SEO tools", domain="example.com")]
System: [executes both tools]
LLM: "Example.com has a well-optimized site with:
     - Title: 'Best SEO Tools...'
     - H1s focused on SEO software
     - They rank at position 12 for 'SEO tools'
     
     Recommendations: ..."
```

### **Example 3: Multi-Tool Analysis**
```
User: "I want a full SEO analysis for my site keywords.chat"
LLM: [calls analyze_website(url="https://keywords.chat") + analyze_backlinks(domain="keywords.chat")]
System: [executes both]
LLM: "Here's your complete SEO profile:
     
     **On-Page SEO:**
     - Title: ✅ Good
     - Meta description: ⚠️ Too short (80 chars, recommend 150-160)
     - H1 tags: 3 found (good keyword focus)
     
     **Off-Page SEO:**
     - 42 backlinks from 18 domains
     - DA: 12 (growing)
     - Top referring domain: example.com (DA 45)
     
     **Recommendations:**
     1. Lengthen meta description
     2. Target more high-DA backlinks
     ..."
```

---

## Tool Selection Logic

The LLM automatically decides which tool(s) to use based on user intent:

| User Says | LLM Calls |
|-----------|-----------|
| "Find keywords for X" | `research_keywords` |
| "Where do I rank for X?" | `check_ranking` |
| "Analyze my website" | `analyze_website` |
| "Show backlinks for X" | `analyze_backlinks` |
| "Full SEO audit for X" | `analyze_website` + `analyze_backlinks` |
| "Compare my site to competitor" | `analyze_website` (both) + `analyze_backlinks` (both) |

---

## API Services Behind The Tools

| Tool | Service | API Used |
|------|---------|----------|
| research_keywords | `keyword_service.py` | RapidAPI Google Keyword Research |
| check_ranking | `rank_checker.py` | RapidAPI Google Search |
| analyze_website | `web_scraper.py` | Direct HTTP crawling |
| analyze_backlinks | `rapidapi_backlinks_service.py` | RapidAPI SEO Backlinks API |

---

## Adding More Tools

To add a new tool:

1. **Create service** in `backend/app/services/`
2. **Define tool** in `keyword_chat.py` tools array:
```python
{
    "type": "function",
    "function": {
        "name": "new_tool_name",
        "description": "What it does",
        "parameters": {...}
    }
}
```
3. **Add handler** in tool execution block:
```python
elif tool_name == "new_tool_name":
    result = await new_service.do_something(args)
    tool_results.append({...})
```

---

## Current Status

✅ **Working:**
- research_keywords (needs API fix - 404)
- check_ranking ✅
- analyze_website ✅
- analyze_backlinks ✅

⚠️ **Known Issues:**
- Keyword Research API returning 404 (need to verify RapidAPI subscription)

---

**The LLM now has 4 powerful SEO tools at its disposal during natural conversations! 🎉**

