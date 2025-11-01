# KeywordsChat Backend

Simple conversational keyword research tool.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Copy `.env.example` to `.env` and fill in your credentials:
   - RapidAPI key (for keyword data & SERP analysis)
   - Groq API key (for LLM)
   - Moz API credentials (for backlink analysis - $5/month starter plan)
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
- **Backlink Analysis** (NEW): 
  - Get backlinks for any domain (up to 50 with $5/month plan)
  - Compare your backlinks vs competitors (link gap analysis)
  - DA/PA metrics for any domain
  - 100 backlink rows/month for free beta users

## API Endpoints

- `POST /api/v1/auth/google` - Google Sign-In
- `POST /api/v1/chat/message` - Send message and get keyword advice
- `GET /api/v1/chat/conversations` - Get conversation list
- `GET /api/v1/chat/conversation/{id}` - Get conversation details

## Moz API Setup

1. Sign up at https://moz.com/products/api
2. Subscribe to $5/month Starter plan (750 rows/month)
3. Get your Access ID and Secret Key
4. Add to `.env`:
```
MOZ_ACCESS_ID=your_access_id
MOZ_SECRET_KEY=your_secret_key
```

**Usage Tracking**: 
- Free beta users: 100 backlink rows/month
- Resets monthly automatically
- Each backlink = 1 row, DA/PA lookup = 1 row

## Development

```bash
docker-compose up
```

Access API docs at: http://localhost:8000/docs



