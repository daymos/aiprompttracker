# Keyword Context Understanding & Filtering Fix

## Problem Summary

The LLM had THREE major issues with keyword suggestions:

### Issue 1: Misunderstanding Project Context (FIXED)

### Example from Conversation:
```
User: "lets work on the keywords for keywords.chat. we need more long tails oportunities with low kd"

LLM Response:
- omegle keyword (90 searches/mo)
- best keyword for omegle (70 searches/mo)
- keyword omegle (10 searches/mo)
- keywords chat (10 searches/mo)
```

**Why this was wrong:**
- User's project tracks: "best semrush alternative", "tools like semrush", "ahrefs alternative"
- → Project is an **SEO tool** competing with Semrush/Ahrefs
- ❌ LLM interpreted "keywords.chat" literally as a **chat platform**
- ❌ Suggested keywords about **Omegle** (random chat site)

### Additional Issues:
1. **Ignored tracked keywords** - Didn't analyze existing keywords to understand niche
2. **Repeated suggestions** - When user asked for "different keywords", returned 4/5 same ones
3. **No deduplication** - Kept suggesting same keywords across multiple requests

---

## Root Causes

### 1. Missing Niche Analysis
- LLM didn't analyze tracked keywords to understand the domain's actual niche
- No guidance on deriving proper seed keywords from project context

### 2. Poor Tool Description
- `find_opportunity_keywords` didn't warn against using domain names literally
- Description: "The seed keyword to find opportunities for" (too vague)

### 3. No Deduplication Logic
- LLM had no instruction to avoid repeating previous suggestions
- No guidance on showing different results from same dataset

---

## Fixes Implemented

### 1. **Enhanced LLM Prompt** (`llm_service.py`)

Added new section: **"CRITICAL: UNDERSTANDING PROJECT NICHE & SEED KEYWORDS"**

```markdown
🚨 BEFORE calling find_opportunity_keywords or research_keywords:

1. **ANALYZE TRACKED KEYWORDS** to understand the niche
   - If user asks about "keywords for keywords.chat" or "my project"
   - Look at their tracked keywords (in USER'S EXISTING PROJECTS section)
   - Example: Project tracks "best semrush alternative", "tools like semrush", "ahrefs alternative"
   - → Niche is: "SEO tools / Semrush alternatives / Ahrefs alternatives"
   - → Correct seed keywords: "semrush alternative", "ahrefs alternative", "seo tools"
   - ❌ WRONG: Using domain name literally ("keywords chat", "keywords.chat")

2. **DERIVE PROPER SEED KEYWORD** from niche understanding
   - Use the TOPIC/CATEGORY the user competes in, NOT their domain name
   - If they track "best X tool" → search for "X tool", "X alternative", "best X"
   - If they track "how to Y" → search for "Y guide", "Y tips", "Y tutorial"

3. **AVOID DUPLICATE SUGGESTIONS**
   - Before calling tools, check conversation history for previous tool_results
   - If you already suggested keywords in this conversation, DON'T repeat them
   - Filter to show DIFFERENT keywords from the same data set
   - Tell user: "Here are 5 MORE keywords from the same research (showing X-Y total)"
```

### 2. **Updated Tool Descriptions** (`keyword_chat.py`)

**Before:**
```json
{
  "name": "find_opportunity_keywords",
  "description": "Find LOW DIFFICULTY opportunity keywords...",
  "parameters": {
    "keyword": {
      "description": "The seed keyword to find opportunities for"
    }
  }
}
```

**After:**
```json
{
  "name": "find_opportunity_keywords",
  "description": "Find LOW DIFFICULTY opportunity keywords... CRITICAL: Use the NICHE/TOPIC as seed keyword (e.g., 'seo tools', 'semrush alternative'), NEVER the domain name.",
  "parameters": {
    "keyword": {
      "description": "The seed keyword representing the NICHE/TOPIC to find opportunities for. IMPORTANT: Derive from tracked keywords - if project tracks 'best semrush alternative', use 'semrush alternative' or 'seo tools' as seed. NEVER use the domain name literally (e.g., 'keywords.chat' is WRONG, 'seo tools' is CORRECT)."
    }
  }
}
```

---

## Expected Behavior After Fix

### Correct Flow:

1. **User asks:** "lets work on the keywords for keywords.chat. we need more long tails oportunities with low kd"

2. **LLM analyzes tracked keywords:**
   - Sees: "best semrush alternative", "tools like semrush", "ahrefs alternative"
   - Understands: This is an SEO tool competing with Semrush/Ahrefs
   - Derives niche: "SEO tools", "Semrush alternatives", "Ahrefs alternatives"

3. **LLM calls tool with correct seed:**
   ```python
   find_opportunity_keywords(keyword="seo tools", location="US", limit=10)
   # or
   find_opportunity_keywords(keyword="semrush alternative", location="US", limit=10)
   ```

4. **LLM returns relevant keywords:**
   ```
   - cheap seo tools (1,200 searches/mo, KD: 15)
   - best seo tools for small business (800 searches/mo, KD: 22)
   - affordable keyword research tool (500 searches/mo, KD: 18)
   - semrush alternatives free (900 searches/mo, KD: 12)
   - low cost seo software (400 searches/mo, KD: 25)
   ```

5. **If user asks for more:**
   - LLM filters existing data to show DIFFERENT keywords
   - Doesn't call API again
   - Tells user: "Here are 5 MORE keywords from the same research (showing 6-10 of 50 total)"

---

## Testing

### Test Case 1: Project Context Understanding
```
User: "find keywords for my project"
Expected: LLM analyzes tracked keywords, derives niche, calls tool with proper seed
```

### Test Case 2: Deduplication
```
User: "find keywords for seo tools"
LLM: [shows 5 keywords]
User: "give me more"
Expected: LLM shows DIFFERENT keywords from same dataset, doesn't repeat
```

### Test Case 3: Domain Name Handling
```
User: "find keywords for example.com"
Tracked keywords: "project management software", "task management tools"
Expected: LLM uses "project management" or "task management" as seed, NOT "example.com"
```

---

---

### Issue 2: Not Filtering Already-Tracked Keywords (FIXED)

**From conversation_1762896378861.csv:**
```
User: "remove the ones we already track from the list"

LLM Response:
- semrush alternative ✅
- semrush free alternative ✅
- best semrush alternative ❌ (USER ALREADY TRACKS THIS!)
- sites like semrush ✅
- tools like semrush ❌ (USER ALREADY TRACKS THIS!)
```

**Why this was wrong:**
- User explicitly asked to remove tracked keywords
- LLM knows what keywords are tracked (in project context)
- But didn't cross-reference and filter them out
- Suggested keywords the user already tracks

---

### Issue 3: Repeating Keywords When Asked for "Different Ones" (FIXED)

**From same conversation:**
```
User: "I want different ones"

LLM Response (2nd time):
- semrush alternative (REPEATED!)
- semrush free alternative (REPEATED!)
- sites like semrush (REPEATED!)
- websites like semrush (new)
- websites similar to semrush (new)
```

**Why this was wrong:**
- User asked for "different ones"
- LLM had 10 keywords in side panel
- But repeated 3 out of 5 keywords from previous suggestion
- Should have shown keywords 6-10, not repeated 1-3

---

## Impact

### Before Fixes:
- ❌ Nonsensical keyword suggestions (Omegle keywords for SEO tool)
- ❌ Suggested keywords user already tracks
- ❌ Repeated same keywords when user asked for "more" or "different"
- ❌ Poor user experience, wasted time
- ❌ User had to manually correct the LLM multiple times

### After Fixes:
- ✅ Contextually relevant keyword suggestions
- ✅ Automatically filters out already-tracked keywords
- ✅ No duplicate suggestions across requests
- ✅ Proper pagination (shows keywords 6-10 when asked for "more")
- ✅ Proper niche understanding from tracked keywords
- ✅ Better API usage (filter existing data instead of new calls)
- ✅ Improved user experience and trust

---

## Additional Fixes for Issues 2 & 3

### Fix #4: Mandatory Filtering of Tracked Keywords

Added explicit **CRITICAL FILTERING STEPS** section:

```markdown
1. **REMOVE ALREADY-TRACKED KEYWORDS FIRST** ⚠️ MANDATORY
   - Look at USER'S EXISTING PROJECTS section in your context
   - Find the list of keywords they're tracking
   - **EXACT MATCH**: Remove ANY keyword from results that EXACTLY matches
   - Example: User tracks ["best semrush alternative", "tools like semrush"]
   - → API returns ["semrush alternative", "best semrush alternative", "tools like semrush"]
   - → You MUST show: ["semrush alternative"] (removed the 2 duplicates)
   - ⚠️ CRITICAL: Do this filtering IN YOUR REASONING before presenting to user
```

### Fix #5: Mandatory Deduplication Across Conversation

```markdown
2. **HANDLE "DIFFERENT" / "MORE" REQUESTS** ⚠️ MANDATORY
   - When user says "different", "more", "other", "I want different ones"
   - Look back at your PREVIOUS assistant messages in this conversation
   - Find which keywords you ALREADY showed in tables
   - **NEVER REPEAT** those keywords again
   - Show the NEXT batch from the full dataset
   - Example: Already showed keywords 1-5 → now show 6-10
   - ⚠️ CRITICAL: List previously-shown keywords IN YOUR REASONING to avoid repeating
```

### Fix #6: Enhanced Reasoning Template

Updated reasoning template to force explicit tracking:

```markdown
<reasoning>
- What is the user asking for?
- What data/context do I have available?
- What keywords does the user ALREADY TRACK? (list them)
- What keywords have I ALREADY SUGGESTED in this conversation? (list them)
- After filtering duplicates, what NEW keywords should I show?
- What action should I take?
- How should I present the information?
</reasoning>
```

### Fix #7: Step-by-Step Example

Added complete example showing correct filtering workflow:

```markdown
User tracked keywords: ["best semrush alternative", "tools like semrush", "sites like semrush"]
API returned: ["semrush alternative", "best semrush alternative", "tools like semrush", "semrush free alternative", "websites like semrush"]

Step 1: Filter out tracked keywords
→ Remove: "best semrush alternative", "tools like semrush"
→ Remaining: ["semrush alternative", "semrush free alternative", "websites like semrush"]

Step 2: Show first 5 (or all if less)
→ Show these 3 keywords

User: "I want different ones"

Step 3: Check what I already showed
→ I showed: ["semrush alternative", "semrush free alternative", "websites like semrush"]
→ API has 10 total keywords in side panel

Step 4: Show NEXT batch (keywords 4-8 from filtered list)
→ Find keywords I haven't shown yet
→ Show 5 NEW keywords from the remaining 7
```

---

## Related Files Modified

1. **`backend/app/services/llm_service.py`**
   - Added "CRITICAL: UNDERSTANDING PROJECT NICHE & SEED KEYWORDS" section
   - Added "CRITICAL FILTERING STEPS" with 3-step mandatory process
   - Enhanced reasoning template to track duplicates explicitly
   - Added complete step-by-step filtering example
   - Enhanced deduplication guidance with ⚠️ MANDATORY flags

2. **`backend/app/api/keyword_chat.py`**
   - Updated `find_opportunity_keywords` tool description (2 instances)
   - Added explicit warning about domain names vs. niche topics

