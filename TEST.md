# Quick Test

1. **Start backend:**
```bash
cd backend
uvicorn app.main:app --reload
```

2. **Check it works:**
- http://localhost:8000/health
- http://localhost:8000/docs

3. **Create test user in DB:**
```bash
docker exec -it backend-db-1 psql -U aiprompttracker -d aiprompttracker -c "INSERT INTO users (id, email, name, provider) VALUES ('test123', 'test@test.com', 'Test', 'google');"
```

4. **Test API in Swagger UI:**
- Go to http://localhost:8000/docs
- Click on endpoints and "Try it out"

Done.

