# KeywordsChat Backend

Simple conversational keyword research tool.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Copy `.env.example` to `.env` and fill in your credentials:
   - RapidAPI key (for keyword data, SERP analysis, and backlink analysis)
   - Groq API key (for LLM)
   - Google OAuth credentials
   - JWT secret

3. Start PostgreSQL (via Docker):
```bash
docker-compose up db -d
```

4. Run migrations:
```bash
alembic upgrade head
```

5. Start the server:
```bash
uvicorn app.main:app --reload
```

## Features

- **Keyword Research**: Get search volume, CPC, competition data via RapidAPI
- **SERP Analysis**: Analyze top 10 ranking sites and identify opportunities
- **Website Analysis**: Full-site scraping with sitemap crawling
- **Rank Tracking**: Check your Google rankings for tracked keywords
- **Backlink Analysis**: Powered by RapidAPI SEO Backlinks API
  - Comprehensive backlink profiles for any domain
  - Source URLs, anchor text, link quality metrics (inlink_rank, domain_inlink_rank)
  - Spam score detection and nofollow tracking
  - Historical trends: Monthly growth data for backlinks, referring domains, and DA
  - Daily new/lost backlinks tracking
  - Anchor text distribution analysis
  - Compare backlinks: Find link gap opportunities between domains
  - Per-request pricing (transparent billing)

## API Endpoints

- `POST /api/v1/auth/google` - Google Sign-In
- `POST /api/v1/chat/message` - Send message and get keyword advice
- `GET /api/v1/chat/conversations` - Get conversation list
- `GET /api/v1/chat/conversation/{id}` - Get conversation details

## RapidAPI Setup

**Backlink Analysis** requires a subscription to the "SEO API - Get Backlinks" on RapidAPI.

1. Sign up at https://rapidapi.com
2. Subscribe to "SEO API - Get Backlinks": https://rapidapi.com/seo-api-get-backlinks/api/seo-api-get-backlinks
3. Your RapidAPI key is the same one used for keyword research

**Pricing (RapidAPI)**: 
- $9.99/month for 500 requests
- $0.10 per additional request

**Free Beta Tier**:
- 5 backlink analyses per month (resets automatically)
- Single domain analysis = 1 request
- Domain comparison = 2 requests
- Each request returns comprehensive data including:
  - Full backlink list with source URLs, anchors, quality metrics
  - Historical trends (monthly growth data)
  - Daily new/lost backlinks tracking
  - Anchor text distribution analysis

## Development

```bash
docker-compose up
```

Access API docs at: http://localhost:8000/docs






