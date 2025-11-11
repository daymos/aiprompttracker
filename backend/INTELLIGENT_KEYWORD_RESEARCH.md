# 🧠 Intelligent Keyword Research

## Overview

We've implemented a revolutionary **Expand → Fetch → Contract** architecture that uses LLM generative power to dramatically improve keyword research quality and coverage.

## The Problem We Solved

### Before (Dumb API Approach)
```
User: "find keywords for seo tools"
  ↓
API: research_keywords("seo tools")
  ↓
Result: ["seo tools", "best seo tools", "seo tools free", ...]
```

**Limitations:**
- Only returns direct variations of the seed keyword
- Misses synonyms (SEO software, SEO platforms)
- Misses related problems (how to improve rankings, keyword research tools)
- Misses adjacent niches (content optimization, rank tracking)
- Misses user intents (cheap seo tools, seo tools for beginners)
- Misses competitor angles (semrush alternative, ahrefs alternative)

### After (Intelligent LLM-Powered Approach)
```
User: "find keywords for seo tools"
  ↓
Phase 1: EXPAND (LLM generates diverse seeds)
  → ["seo tools", "semrush alternative", "keyword research", 
     "rank tracker", "seo for small business", "affordable seo software"]
  ↓
Phase 2: FETCH (Parallel API calls)
  → Query API with ALL 6 seeds simultaneously
  → Collect ~150-200 keywords from different angles
  → Deduplicate
  ↓
Phase 3: CONTRACT (LLM ranks with reasoning)
  → Filter irrelevant keywords
  → Rank by opportunity (volume × difficulty factor)
  → Consider user's existing tracked keywords
  → Apply intent alignment
  → Return top 50 with chain-of-thought explanation
```

**Benefits:**
- 3-5x more keyword coverage
- Discovers keywords from MULTIPLE angles
- LLM-powered seed generation (creative)
- LLM-powered ranking (intelligent)
- Context-aware filtering
- Explains reasoning to user

---

## Architecture

### 1. IntelligentKeywordService (`backend/app/services/intelligent_keyword_service.py`)

New service class that orchestrates the expand-fetch-contract workflow.

#### Main Method: `expand_and_research()`

```python
async def expand_and_research(
    topic: str,
    user_context: Dict[str, Any],
    location: str = "US",
    expansion_strategy: str = "comprehensive"
) -> Dict[str, Any]
```

**Returns:**
```json
{
  "keywords": [...],           // Top 50 ranked keywords
  "reasoning": "...",           // LLM's chain-of-thought explanation
  "seeds_used": [...],          // Seeds that were generated
  "total_fetched": 150,         // Total keywords before filtering
  "total_after_filtering": 50,
  "expansion_strategy": "comprehensive"
}
```

### 2. Phase 1: EXPAND - LLM Seed Generation

**Method:** `_generate_seed_keywords()`

The LLM analyzes the topic and user context to generate 6-8 diverse seed keywords.

**Coverage Areas:**
1. Direct terms & synonyms
2. Competitor/Alternative terms ("X alternative", "X vs Y")
3. Problem-based queries
4. Feature-specific terms
5. Audience segments ("for beginners", "for startups")
6. Price/Value terms ("cheap", "free", "affordable")
7. Use case terms

**Example Input:**
```
Topic: "seo tools"
User tracks: ["best semrush alternative", "tools like semrush"]
```

**Example LLM Output:**
```json
{
  "seeds": [
    "seo tools",
    "semrush alternative",
    "keyword research tools",
    "rank tracker",
    "seo for small business",
    "cheap seo software",
    "backlink checker",
    "site audit tool"
  ]
}
```

**Expansion Strategies:**

- **`comprehensive`** (default): Covers all angles
- **`competitor_focused`**: Heavy on alternatives/comparisons
- **`problem_solution`**: Focus on problems users face
- **`feature_based`**: Specific capabilities/features

### 3. Phase 2: FETCH - Parallel Multi-Seed Querying

**Method:** `_fetch_multi_seed_keywords()`

Queries the keyword API with ALL seeds simultaneously using `asyncio.gather()`.

**Parameters:**
- `per_seed_limit`: 30 keywords per seed (configurable)
- Parallel execution: All seeds queried at once

**Process:**
1. Create async tasks for each seed
2. Execute in parallel with `asyncio.gather()`
3. Merge results
4. Deduplicate by keyword text (case-insensitive)

**Example:**
```
6 seeds × 30 keywords/seed = ~180 keywords
After deduplication: ~120-150 unique keywords
```

### 4. Phase 3: CONTRACT - LLM Ranking with Chain-of-Thought

**Method:** `_contract_and_rank()`

The LLM analyzes ALL keywords and applies sophisticated filtering and ranking.

**Chain-of-Thought Process:**

```xml
<reasoning>
1. Relevance Filter: Which keywords are actually relevant to the topic?
   - Remove: Too tangential or off-topic
   - Keep: Align with user's niche

2. Opportunity Assessment:
   - High opportunity: Volume > 100/mo + KD < 40 (quick wins)
   - Medium opportunity: Decent volume + KD 40-60
   - Low opportunity: Volume < 50/mo OR KD > 60 (skip)

3. Strategic Fit:
   - What niches/angles is user already covering?
   - What gaps exist that we should fill?
   - Prioritize keywords that complement their strategy

4. Intent Alignment:
   - Commercial ("best", "vs", "alternative"): High conversion
   - Informational ("how to", "what is"): Build authority
   - Transactional ("buy", "price"): Direct ROI

5. Final Ranking:
   - Formula: (volume * difficulty_factor) + intent_multiplier
   - difficulty_factor: 1 - (kd/100)
   - intent_multiplier: +50 for commercial, +25 for transactional
</reasoning>
```

**Fallback:**
If LLM fails, uses formula-based ranking:
```python
score = volume * (1 - kd/100)
```

---

## New Tool: `expand_and_research_keywords`

### Tool Definition

```json
{
  "name": "expand_and_research_keywords",
  "description": "🧠 INTELLIGENT keyword research using LLM expansion + multi-angle fetching. Use when user wants COMPREHENSIVE research.",
  "parameters": {
    "topic": "Main topic/niche (e.g., 'seo tools')",
    "expansion_strategy": "comprehensive | competitor_focused | problem_solution | feature_based",
    "location": "US | UK | CA | etc."
  }
}
```

### When LLM Should Use This Tool

**Use `expand_and_research_keywords` when:**
- ✅ User says "find ALL keywords"
- ✅ User wants "comprehensive research"
- ✅ User says "cast a wide net", "explore everything"
- ✅ You need keywords from DIFFERENT angles

**Use regular `research_keywords` when:**
- ✅ User wants quick results for a specific term
- ✅ Simple lookup ("find keywords for X")
- ✅ User wants results RIGHT NOW (fast)

### LLM Prompt Guidance

Added to `backend/app/services/llm_service.py`:

```
**INTELLIGENT KEYWORD RESEARCH TOOLS:**

You have TWO keyword research approaches - choose wisely:

1. **`research_keywords`** - Quick & Direct
   - Fast (single API call)
   - Returns ~50-100 variations

2. **`expand_and_research_keywords`** - 🧠 INTELLIGENT & COMPREHENSIVE
   - Slower (~10-15 seconds) but MUCH more comprehensive
   - Generates 6-8 diverse seeds → Fetches ~150-200 keywords → AI ranks top 50
```

### Handler Implementation

In `backend/app/api/keyword_chat.py`:

```python
elif tool_name == "expand_and_research_keywords":
    # Import service
    from ..services.intelligent_keyword_service import IntelligentKeywordService
    intelligent_service = IntelligentKeywordService(keyword_service, llm_service)
    
    # Build user context
    user_context = {
        "tracked_keywords": [kw.keyword for kw in project.keywords] if project else [],
        "project_name": project.name if project else "",
        "project_url": project.url if project else ""
    }
    
    # Perform intelligent research
    result = await intelligent_service.expand_and_research(...)
    
    # Store in metadata for side panel
    metadata = {"keyword_data": result["keywords"]}
```

---

## User Experience

### Example: Standard Research

**User:** "find keywords for task management"

**Assistant:**
```
Here are 5 keywords for task management:

| Keyword | Searches/mo | Ad Comp | SEO Diff |
|---------|-------------|---------|----------|
| task management software | 18,000 | HIGH | 78 |
| best task management | 5,400 | MEDIUM | 65 |
| task management tools | 8,100 | HIGH | 72 |
...

📊 View all 47 keywords in side panel →
```

### Example: Intelligent Research

**User:** "find me EVERYTHING related to seo tools, cast a wide net"

**Assistant:**
```
🧠 I used intelligent multi-angle research to explore this topic comprehensively.

I generated 7 seed keywords and analyzed 163 keywords from different angles:
- Direct terms (seo tools, seo software)
- Competitor alternatives (semrush alternative, ahrefs alternative)
- Feature-specific (keyword research, rank tracker)
- Audience segments (seo for startups, seo for bloggers)
- Value terms (cheap seo, free seo tools)

After analyzing the landscape, I found the best opportunities are in the 
"affordable alternative" space. Keywords like "cheap seo tools" and 
"semrush free alternative" have strong volume (1K-2K/mo) with very 
manageable difficulty (KD 8-15).

Top 5 opportunities:

| Keyword | Searches/mo | Ad Comp | SEO Diff |
|---------|-------------|---------|----------|
| cheap seo tools | 1,200 | MEDIUM | 12 |
| seo tools for startups | 800 | LOW | 8 |
| semrush alternative free | 900 | LOW | 15 |
| affordable rank tracker | 400 | LOW | 10 |
| best free seo software | 1,500 | MEDIUM | 18 |

Seeds explored: seo tools, semrush alternative, keyword research tools, 
rank tracker, seo for small business, cheap seo software, backlink checker

📊 View all 50 ranked keywords in side panel → Want me to track the top ones?
```

---

## Performance & Cost

### Speed

| Method | Seeds | Keywords Fetched | API Calls | Time |
|--------|-------|------------------|-----------|------|
| Standard `research_keywords` | 1 | 50 | 1 | ~2-3s |
| Intelligent `expand_and_research_keywords` | 6-8 | 150-200 | 6-8 | ~10-15s |

**Why the intelligent method is worth it:**
- 3x more coverage
- Keywords from DIFFERENT angles (not just variations)
- LLM reasoning and ranking
- Better opportunity discovery

### Cost

**Standard Research:**
- Google Keyword Insight: $0.001 per keyword
- DataForSEO KD enrichment: $0.01 + ($0.0001 × 50) = $0.015
- **Total: ~$0.065 per query**

**Intelligent Research:**
- Google Keyword Insight: 6 seeds × $0.001 × 30 = $0.18
- DataForSEO KD enrichment: 6 calls × $0.015 = $0.09
- LLM (seed generation): $0.0001 (GPT-OSS 120B via Groq)
- LLM (ranking): $0.0003
- **Total: ~$0.27 per query**

**Trade-off:**
- 4x more expensive
- But 3x more coverage
- Much higher quality (multi-angle + AI ranking)
- Use strategically for comprehensive research

---

## Testing

### Test 1: Basic Intelligent Research

```
User: "find me ALL keywords related to project management software"
Expected: LLM calls expand_and_research_keywords with topic="project management software"
```

### Test 2: Competitor-Focused Strategy

```
User: "explore all competitor alternatives for notion"
Expected: LLM calls expand_and_research_keywords with 
         topic="notion" and expansion_strategy="competitor_focused"
```

### Test 3: Standard vs Intelligent

```
User: "quick keyword research for email marketing"
Expected: LLM calls research_keywords (quick)

User: "comprehensive keyword analysis for email marketing, cast a wide net"
Expected: LLM calls expand_and_research_keywords (comprehensive)
```

### Test 4: Presentation

Expected output should include:
- ✅ "🧠 I used intelligent multi-angle research..."
- ✅ Number of seeds generated
- ✅ Total keywords analyzed
- ✅ Summary of AI reasoning
- ✅ Top 5 opportunities in table
- ✅ List of seeds explored
- ✅ Side panel indicator

---

## Future Enhancements

1. **Adaptive Strategy Selection**
   - LLM automatically chooses expansion strategy based on user context
   - Example: If user tracks many competitor keywords → use "competitor_focused"

2. **Multi-Region Expansion**
   - Generate seeds and fetch from multiple regions simultaneously
   - Discover geo-specific opportunities

3. **Historical Trend Analysis**
   - Incorporate trend data into ranking
   - Prioritize growing keywords

4. **Iterative Refinement**
   - Allow user to refine: "explore more in the [angle] direction"
   - Re-run with adjusted strategy

5. **Seed Suggestion Transparency**
   - Show user the generated seeds BEFORE fetching
   - Allow user to add/remove seeds: "add 'project management pricing' to the seeds"

---

## Related Files

- `backend/app/services/intelligent_keyword_service.py` - Core service
- `backend/app/api/keyword_chat.py` - Tool definition and handler
- `backend/app/services/llm_service.py` - LLM prompt guidance
- `backend/INTELLIGENT_KEYWORD_RESEARCH.md` - This documentation

