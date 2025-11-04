# SEO Knowledge Base - "Poor Man's RAG" System

## Overview

The SEO Knowledge Base is a lightweight retrieval-augmented generation (RAG) system that enhances Agent Mode with advanced SEO knowledge from **"Strategic SEO 2025" by Shaun Anderson**.

Instead of including the entire 464KB book in prompts, we split it into topic-based chunks and dynamically load only the relevant sections based on the user's query context.

---

## Architecture

```
┌─────────────────┐
│  User Query     │
│  "How does      │
│  Google rank?"  │
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│ Topic Detection     │
│ - Analyze query     │
│ - Match keywords    │
│ - Identify topics   │
└────────┬────────────┘
         │
         ▼
┌─────────────────────────┐
│ Chunk Retrieval         │
│ - Load relevant chunks  │
│ - Combine (max 15KB)    │
│ - Skip large chunks     │
└────────┬────────────────┘
         │
         ▼
┌───────────────────────────┐
│ LLM Context Injection     │
│ - Add to system messages  │
│ - Used in Agent Mode only │
└────────┬──────────────────┘
         │
         ▼
┌───────────────────────────┐
│ Enhanced SEO Response     │
│ - Strategic guidance      │
│ - Backed by book insights │
│ - References concepts     │
└───────────────────────────┘
```

---

## Components

### 1. Book Splitter (`app/data/split_seo_book.py`)

**Purpose:** Splits the Strategic SEO 2025 book into topic-based chunks

**Process:**
- Identifies major sections using regex patterns
- Categorizes each section by topic keywords
- Creates individual chunk files (chunk_000.txt, chunk_001.txt, etc.)
- Generates an index.json with metadata

**Output:**
- 21 topic-based chunks
- Index with topic mappings
- Summary document

**Usage:**
```bash
python app/data/split_seo_book.py
```

---

### 2. Knowledge Service (`app/services/seo_knowledge_service.py`)

**Purpose:** Retrieves relevant knowledge chunks based on query context

**Key Methods:**

#### `get_relevant_knowledge(query_context, max_chars=15000)`
Fetches relevant SEO knowledge for a query

```python
knowledge = service.get_relevant_knowledge(
    "How does Google's algorithm work?",
    max_chars=15000
)
# Returns: Relevant chunks about google_algorithm, trust_eeat, user_signals
```

**Process:**
1. Detect topics from query keywords
2. Find chunks mapped to those topics
3. Load chunks (max 3 per topic)
4. Combine chunks up to max_chars limit
5. Skip chunks > 100KB (too large for context)
6. Return formatted knowledge text

#### `_detect_topics(query_lower)`
Identifies relevant SEO topics from query

**Topic Categories:**
- `google_algorithm`: Algorithm, ranking, Q*, P*, Navboost, PageRank
- `entity_seo`: Entities, knowledge graph, schema markup
- `trust_eeat`: Trust, E-E-A-T, authority, credibility
- `user_signals`: Clicks, engagement, dwell time, UX
- `content_strategy`: Content quality, helpful content, writing
- `technical_seo`: Crawling, indexing, site speed, Core Web Vitals
- `link_building`: Backlinks, link signals, link building
- `zero_click`: SERP features, featured snippets, AI overviews
- `local_seo`: Local pack, Google Business Profile, citations
- `competitive`: Competitor analysis, competitive intelligence

---

### 3. LLM Service Integration (`app/services/llm_service.py`)

**Automatic Knowledge Injection in Agent Mode:**

When `mode="agent"`, the system:
1. Builds context from user message + recent conversation
2. Calls knowledge service to get relevant chunks
3. Injects knowledge as additional system message
4. LLM uses this knowledge to enhance recommendations

**Code Flow:**
```python
if mode == "agent":
    knowledge_service = get_seo_knowledge_service()
    seo_knowledge = knowledge_service.get_relevant_knowledge(
        context, max_chars=15000
    )
    if seo_knowledge:
        messages.append({
            "role": "system",
            "content": f"{seo_knowledge}\n\nUse this advanced SEO knowledge..."
        })
```

**Key Feature:** Knowledge injection is transparent to the user. The LLM references the book's concepts naturally in its strategic guidance.

---

## Knowledge Base Structure

### Directory: `/backend/app/data/seo_knowledge_base/`

```
seo_knowledge_base/
├── chunk_000.txt       # Introduction
├── chunk_001.txt       # Section 1: The New Reality
├── chunk_002.txt       # How Google Works
├── chunk_003.txt       # Section 2: Strategic Playbook
├── chunk_004.txt       # Entity SEO
├── chunk_005.txt       # Building Trust
├── chunk_006.txt       # Helpful Content Update
├── chunk_007.txt       # Zero-Click Marketing
├── chunk_008.txt       # Section 3: Practical Framework
├── chunk_009.txt       # SEO Evidence Brief
├── chunk_010.txt       # Section 1 (detailed)
├── chunk_011.txt       # How Google Works (detailed) [LARGE]
├── chunk_012.txt       # Building Trust (detailed)
├── chunk_013.txt       # Section 2 (detailed)
├── chunk_014.txt       # Entity SEO (detailed)
├── chunk_015.txt       # Trust Recovery (detailed)
├── chunk_016.txt       # Helpful Content (detailed)
├── chunk_017.txt       # HCU Deep Dive
├── chunk_018.txt       # Zero-Click Deep Dive
├── chunk_019.txt       # Practical Framework (detailed)
├── chunk_020.txt       # Evidence Brief (detailed)
├── index.json          # Chunk metadata and topic mappings
└── SUMMARY.md          # Book overview
```

### Index Structure (`index.json`)

```json
{
  "chunks": [
    {
      "id": "chunk_002",
      "file": "chunk_002.txt",
      "title": "How Google Works",
      "start_line": 19,
      "end_line": 134,
      "categories": ["google_algorithm", "trust_eeat", "user_signals"],
      "char_count": 5206,
      "line_count": 115
    }
  ],
  "topics": {
    "google_algorithm": ["chunk_002", "chunk_008", ...],
    "entity_seo": ["chunk_004", "chunk_014", ...],
    "trust_eeat": ["chunk_002", "chunk_004", ...]
  }
}
```

---

## How It Works in Practice

### Example 1: Algorithm Question

**User Query:** "How does Google's ranking algorithm work?"

**What Happens:**
1. **Topic Detection:** Detects `google_algorithm` topic
2. **Chunk Selection:** Loads chunks 002, 008, 009 (algorithm-related)
3. **Knowledge Injection:** ~5KB of relevant content added to context
4. **Agent Response:** References Q* (Quality Signal), P* (Popularity Signal), Navboost, etc.

**Result:** Agent provides strategic guidance grounded in the book's framework

---

### Example 2: Trust & Authority

**User Query:** "My site needs better trust and authority"

**What Happens:**
1. **Topic Detection:** Detects `trust_eeat` topic
2. **Chunk Selection:** Loads chunks about E-E-A-T, trust signals, quality raters
3. **Knowledge Injection:** ~15KB of E-E-A-T content
4. **Agent Response:** Explains Experience, Expertise, Authority, Trustworthiness with actionable steps

**Result:** Agent provides E-E-A-T framework with specific implementation guidance

---

### Example 3: Entity SEO

**User Query:** "What is entity SEO and how do I implement it?"

**What Happens:**
1. **Topic Detection:** Detects `entity_seo` topic
2. **Chunk Selection:** Loads chunks 004, 014, 015 (entity-focused)
3. **Knowledge Injection:** ~10KB about entities, knowledge graph, schema
4. **Agent Response:** Explains entity recognition, schema markup, entity home concepts

**Result:** Agent provides entity SEO framework with practical implementation steps

---

## Benefits

### 1. Context Efficiency
- **Without RAG:** Can't include 464KB book → generic advice
- **With RAG:** Only relevant 5-15KB → specific, book-backed advice
- **Token Savings:** 95-97% reduction in knowledge base tokens

### 2. Strategic Depth
- Agent can reference specific SEO concepts (Q*, P*, Navboost, E-E-A-T)
- Recommendations backed by Google DOJ trial disclosures
- Advanced concepts explained naturally in context

### 3. Dynamic Knowledge
- Different queries trigger different knowledge chunks
- Algorithm questions get algorithm chunks
- Local SEO questions get local SEO chunks
- Efficient use of context window

### 4. Maintainability
- Easy to update: Replace book → re-run splitter
- Easy to extend: Add more books/sources → expand index
- Easy to test: Test suite validates topic detection

---

## Performance Characteristics

### Chunk Sizes
- **Small chunks:** 200-5,000 chars (headers, summaries)
- **Medium chunks:** 5,000-25,000 chars (detailed sections)
- **Large chunks:** 25,000-180,000 chars (comprehensive chapters)
- **Note:** Chunks > 100KB are skipped (too large for context)

### Retrieval Limits
- **Max chars per query:** 15,000 (configurable)
- **Max chunks per topic:** 3
- **Max topics detected:** 3
- **Total possible retrieval:** ~5-15KB per query

### Topic Coverage
- **Google Algorithm:** 10 chunks
- **Trust & E-E-A-T:** 16 chunks
- **User Signals:** 8 chunks
- **Content Strategy:** 7 chunks
- **Entity SEO:** 3 chunks
- **Zero-Click:** 1 chunk
- **Local SEO:** 2 chunks

---

## Testing

### Running Tests

```bash
cd backend
python test_seo_knowledge.py
```

### Test Coverage
1. **Topic Detection:** Validates pattern matching for each category
2. **Knowledge Retrieval:** Tests chunk loading and combination
3. **Available Topics:** Lists all indexed topics

### Example Test Output

```
✅ Query: "How does Google's algorithm work?"
   Expected: ['google_algorithm']
   Detected: ['google_algorithm']

✅ Retrieved 5276 chars, 138 lines
   First chunk: Section 3 - A Practical Framework...
```

---

## Configuration

### Adjusting Retrieval Limits

**In `seo_knowledge_service.py`:**

```python
# Default: 15KB max per query
knowledge = service.get_relevant_knowledge(context, max_chars=15000)

# Increase for more detail:
knowledge = service.get_relevant_knowledge(context, max_chars=25000)

# Decrease for token efficiency:
knowledge = service.get_relevant_knowledge(context, max_chars=10000)
```

### Skipping Large Chunks

**In `seo_knowledge_service.py`:**

```python
# Skip chunks > 100KB (default)
if chunk_meta["char_count"] > 100000:
    logger.info(f"Skipping large chunk {chunk_id}")
    return None

# Adjust threshold:
if chunk_meta["char_count"] > 50000:  # Stricter limit
```

### Adding New Topics

**In `seo_knowledge_service.py`:**

```python
topic_patterns = {
    # ... existing topics ...
    'new_topic': [
        'keyword1', 'keyword2', 'phrase to detect'
    ]
}
```

Then re-run the splitter to categorize chunks with the new topic.

---

## Extending the System

### Adding More Books/Sources

1. **Add new book:** `/backend/new-seo-book.txt`
2. **Create splitter:** Copy `split_seo_book.py`, adjust for new structure
3. **Generate chunks:** Run splitter → `/data/seo_kb_2/`
4. **Update service:** Load from multiple knowledge bases
5. **Merge indices:** Combine topic mappings

### Creating Specialized Knowledge Bases

Example: Separate KB for technical SEO vs. content strategy

```python
class TechnicalSEOKnowledge(SEOKnowledgeService):
    def __init__(self):
        self.knowledge_base_dir = Path(...) / "technical_seo_kb"
        ...

class ContentStrategyKnowledge(SEOKnowledgeService):
    def __init__(self):
        self.knowledge_base_dir = Path(...) / "content_strategy_kb"
        ...
```

---

## Future Enhancements

### 1. Semantic Search
Replace keyword matching with embeddings:
- Generate embeddings for each chunk
- Store in vector DB (e.g., ChromaDB, FAISS)
- Semantic similarity search instead of keyword matching

### 2. Query-Specific Chunks
Create smaller, query-optimized chunks:
- Q&A format chunks
- Checklist chunks
- Example chunks

### 3. Hybrid Retrieval
Combine keyword + semantic search:
- Keyword match for topic categories
- Semantic match within category for best chunks

### 4. Caching
Cache frequently retrieved chunks:
- Redis cache for hot chunks
- Reduces file I/O
- Faster response times

### 5. Multi-Source Knowledge
Combine multiple authoritative sources:
- Multiple SEO books
- Google documentation
- Case studies
- Research papers

---

## Troubleshooting

### No Knowledge Returned

**Issue:** `get_relevant_knowledge()` returns `None`

**Causes:**
1. No topics detected → Add more pattern keywords
2. All chunks too large → Adjust size threshold
3. Index not loaded → Check file path

**Fix:**
```bash
# Regenerate knowledge base
cd backend
python app/data/split_seo_book.py

# Test detection
python test_seo_knowledge.py
```

### Topics Not Detected

**Issue:** Queries don't match expected topics

**Fix:** Add more pattern keywords in `topic_patterns`:

```python
'google_algorithm': [
    'algorithm', 'ranking', 'how google', 
    'google works',  # Add more variations
    'search engine ranking',
    'serp algorithm'
]
```

### Chunks Too Large

**Issue:** Context window exceeded

**Fix:** Reduce `max_chars` or skip larger chunks:

```python
# Stricter chunk size filtering
if chunk_meta["char_count"] > 50000:  # From 100000
    return None
```

---

## Summary

The SEO Knowledge Base is a **lightweight RAG system** that enhances Agent Mode with expert SEO knowledge without bloating the context window.

**Key Benefits:**
- ✅ **Efficient:** Only loads relevant 5-15KB per query (vs. 464KB full book)
- ✅ **Strategic:** References advanced concepts (Q*, P*, E-E-A-T, Navboost)
- ✅ **Dynamic:** Different queries trigger different knowledge
- ✅ **Maintainable:** Easy to update and extend
- ✅ **Transparent:** Users see enhanced guidance, not raw knowledge chunks

**Impact on Agent Mode:**
- More authoritative SEO guidance
- References proven frameworks and concepts
- Backed by Google DOJ trial evidence
- Provides deeper strategic insights

The system transforms Agent Mode from a helpful SEO assistant into a **strategic SEO partner backed by industry-leading expertise**.

