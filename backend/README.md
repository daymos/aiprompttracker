# KeywordsChat Backend

Simple conversational keyword research tool.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Copy `.env.example` to `.env` and fill in your credentials:
   - DataForSEO API credentials
   - Groq API key
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

## API Endpoints

- `POST /api/v1/auth/google` - Google Sign-In
- `POST /api/v1/chat/message` - Send message and get keyword advice
- `GET /api/v1/chat/conversations` - Get conversation list
- `GET /api/v1/chat/conversation/{id}` - Get conversation details

## Development

```bash
docker-compose up
```

Access API docs at: http://localhost:8000/docs



