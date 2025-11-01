#!/bin/bash

echo "🚀 Starting KeywordsChat..."

# Check if backend .env exists
if [ ! -f backend/.env ]; then
    echo "❌ backend/.env not found!"
    echo "📝 Copy backend/.env.example to backend/.env and fill in your credentials"
    exit 1
fi

# Start PostgreSQL
echo "🐘 Starting PostgreSQL..."
cd backend
docker-compose up db -d

# Wait for database
echo "⏳ Waiting for database..."
sleep 3

# Run migrations
echo "🔄 Running database migrations..."
alembic upgrade head

# Start backend
echo "🔧 Starting backend..."
uvicorn app.main:app --reload &
BACKEND_PID=$!

cd ..

# Start frontend
echo "🎨 Starting frontend..."
cd frontend
flutter run -d chrome &
FRONTEND_PID=$!

echo ""
echo "✅ KeywordsChat is running!"
echo "📍 Backend: http://localhost:8000"
echo "📍 Frontend: (Flutter will open in Chrome)"
echo "📚 API Docs: http://localhost:8000/docs"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait for Ctrl+C
trap "echo '🛑 Stopping services...'; kill $BACKEND_PID $FRONTEND_PID; docker-compose -f backend/docker-compose.yml stop; exit" INT
wait



