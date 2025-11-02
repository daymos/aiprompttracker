FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend application
COPY backend/ .

# Copy landing page
COPY landing/ ../landing/

# Copy Flutter web build (will be built in CI)
COPY frontend/build/web/ ../frontend/build/web/

# Expose port (Cloud Run uses PORT env var, defaults to 8080)
EXPOSE 8080

# Run the application
# Cloud Run will set PORT environment variable
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]




