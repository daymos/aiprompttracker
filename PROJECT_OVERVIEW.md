# AI Prompt Tracker - Project Overview

**Domain:** [aiprompttracker.io](https://aiprompttracker.io)

## What It Does

AI Prompt Tracker monitors your brand's visibility across AI platforms (ChatGPT, Gemini, Perplexity, Claude, etc.) by testing how these LLMs respond to prompts about your brand, keywords, and competitors.

## Business Model (Inspired by YourWebsiteScore.com)

### Core Features
- **Free Initial Scan:** Enter your brand/domain → instant visibility check across LLMs
- **Daily Monitoring:** $5-9/month for automated daily checks
- **Public Report Page:** Shareable certified page with dofollow backlink
- **Badge Widget:** Embeddable badge showing "Visible on ChatGPT for X keywords"
- **Leaderboard:** Public ranking of most visible brands

### Monetization
- Free tier: 3 scans per month
- Pro tier: $9/month
  - Unlimited scans
  - Daily monitoring (up to 10 projects)
  - Historical tracking
  - Email alerts
  - Public report page + badge
  - Dofollow backlink

## Target Market

### Primary: Marketing Agencies
From Reddit research, agencies desperately need:
- ✅ Automated visibility tracking across LLMs
- ✅ Prompt & keyword-based reporting
- ✅ Historical change tracking
- ✅ Exportable, client-ready reports (PDF, CSV)
- ✅ Multi-project support (dozens of clients)
- ✅ Client-facing metrics that executives understand

### Secondary: Brand Managers & SEO Professionals
- Track brand mentions in AI-generated content
- Monitor competitor visibility
- Optimize content for AI search

## How It Works

### 1. Project Setup
```
User inputs:
- Brand/domain name
- Target keywords (e.g., "best CRM software", "project management tools")
- Competitor domains (optional)
```

### 2. Daily Automated Checks
```python
# For each project, test prompts across LLMs:
prompts = [
    f"What do you know about {brand}?",
    f"Tell me about {domain}",
    f"Best {keyword}",
    f"Top {keyword} for {use_case}"
]

# Query each LLM:
for llm in [OpenAI, Gemini, Perplexity, Claude]:
    response = llm.query(prompt)
    presence = check_brand_mentioned(response, brand)
    rank = get_mention_position(response, brand)
    store_result(llm, prompt, presence, rank, snippet)
```

### 3. Scoring Algorithm
```
Visibility Score (0-100):
- Presence frequency: 40%
- Mention rank/position: 30%
- Keyword coverage: 20%
- Consistency across LLMs: 10%

Badge: "Visible on ChatGPT for 45/50 keywords"
```

### 4. Reports & Alerts
- Dashboard with trend charts
- Weekly email: "Your visibility increased 12% this week"
- Alerts: "Dropped out of top 3 for 'keyword' on ChatGPT"
- Export: PDF/CSV for client reports

## Technical Architecture

### Backend (FastAPI + Python)
```
/api/v1/
  /auth/google          # OAuth
  /projects             # CRUD projects
  /scans                # Trigger/view scans
  /reports/{id}         # Public report page
  /badges/{id}          # Badge image generation
```

### LLM Integration
```python
# services/llm_providers.py
class OpenAIProvider:
    def query(prompt) -> response
    
class GeminiProvider:
    def query(prompt) -> response
    
class PerplexityProvider:
    def query(prompt) -> response
```

### Database Schema
```sql
projects:
  - id, user_id, domain, keywords[], competitors[]
  
scans:
  - id, project_id, llm_provider, created_at
  
scan_results:
  - id, scan_id, prompt, response_text, found, rank, snippet
  
scores:
  - id, project_id, date, overall_score, per_llm_scores
```

### Worker Service
```python
# Cron job (Cloud Scheduler or Celery)
@daily
def run_daily_scans():
    for project in active_projects:
        for llm in llm_providers:
            for prompt in project.prompt_templates:
                result = llm.query(prompt)
                parse_and_store(result)
        calculate_score(project)
        send_alerts_if_changed(project)
```

## Competitive Advantages

### vs. Manual Checking
- ✅ Automated daily monitoring
- ✅ Historical tracking
- ✅ Multi-LLM coverage
- ✅ Consistent methodology

### vs. Generic SEO Tools (Ahrefs, SEMrush)
- ✅ AI-specific (they don't track LLMs yet)
- ✅ Prompt-based testing (not just rankings)
- ✅ Agency-friendly reports
- ✅ Lower price point ($9 vs $99+)

### vs. Custom Solutions
- ✅ Ready-made dashboard
- ✅ No dev work needed
- ✅ White-label reports
- ✅ Public credibility (badge + backlink)

## Launch Strategy

### Phase 1: MVP (Weeks 1-4)
- ✅ Clean scaffold (DONE)
- [ ] Add 2-3 LLM providers (OpenAI, Gemini)
- [ ] Basic scanning + results storage
- [ ] Simple dashboard showing presence/absence
- [ ] Public report page

### Phase 2: Monitoring (Weeks 5-6)
- [ ] Daily cron workers
- [ ] Historical tracking
- [ ] Score calculation
- [ ] Badge generation

### Phase 3: Polish (Weeks 7-8)
- [ ] Email alerts
- [ ] PDF/CSV exports
- [ ] Landing page
- [ ] Payment integration (Stripe)

### Phase 4: Launch (Week 9)
- [ ] Product Hunt launch
- [ ] Reddit marketing (/r/SEO, /r/marketing)
- [ ] Agency outreach

## Marketing Copy Ideas

**Headline:** "Track Your Brand Visibility Across AI Platforms"

**Subheadline:** "See how ChatGPT, Gemini, and Perplexity answer questions about your brand. Monitor daily, export reports, prove your AI presence."

**Agency Pitch:** "Stop manually checking if your clients appear in AI search. Automated daily monitoring across all major LLMs with client-ready reports."

**Badge Text:** "AI Verified - Visible on ChatGPT, Gemini, and Perplexity"

## Next Steps

1. **Build core scanning engine**
   - Integrate OpenAI API
   - Create prompt templates
   - Parse responses for brand mentions

2. **Create dashboard UI**
   - Project creation flow
   - Results visualization
   - Historical charts

3. **Set up workers**
   - Cloud Scheduler for daily scans
   - Background job processing

4. **Build public report pages**
   - SEO-optimized
   - Shareable links
   - Dofollow backlinks

---

**Status:** Clean scaffold complete ✅  
**Next:** Start building LLM integrations 🚀

