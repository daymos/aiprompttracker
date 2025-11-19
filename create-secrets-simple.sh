#!/bin/bash

# Simple script to create GCP secrets
# You'll be prompted for each value

set -e

PROJECT_ID="youwebsitellmvisibility"
CONNECTION_NAME="youwebsitellmvisibility:europe-west1:aiprompttracker-db"

echo "🔐 Creating GCP Secrets for AI Prompt Tracker"
echo ""
echo "You'll need:"
echo "  - Database password (from earlier)"
echo "  - Google OAuth Client ID"
echo "  - Google OAuth Client Secret"
echo "  - OpenAI API Key"
echo ""
read -p "Press Enter to continue..."

# Database URL
echo ""
echo "📊 Database Configuration"
read -sp "Enter the database password you created: " DB_PASSWORD
echo ""
DATABASE_URL="postgresql://postgres:${DB_PASSWORD}@/aiprompttracker?host=/cloudsql/${CONNECTION_NAME}"

echo "Creating database URL secret..."
echo -n "$DATABASE_URL" | gcloud secrets create aiprompttracker-db-url --data-file=- --project=$PROJECT_ID 2>/dev/null || \
  echo -n "$DATABASE_URL" | gcloud secrets versions add aiprompttracker-db-url --data-file=- --project=$PROJECT_ID
echo "✓ Database URL secret created"

# JWT Secret
echo ""
echo "🔑 Generating JWT secret..."
JWT_SECRET=$(openssl rand -hex 32)
echo -n "$JWT_SECRET" | gcloud secrets create jwt-secret --data-file=- --project=$PROJECT_ID 2>/dev/null || \
  echo -n "$JWT_SECRET" | gcloud secrets versions add jwt-secret --data-file=- --project=$PROJECT_ID
echo "✓ JWT secret created"

# Google OAuth
echo ""
echo "🔐 Google OAuth Configuration"
echo "Get these from: https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID"
read -p "Enter Google OAuth Client ID: " GOOGLE_CLIENT_ID
read -sp "Enter Google OAuth Client Secret: " GOOGLE_CLIENT_SECRET
echo ""

echo "Creating Google OAuth secrets..."
echo -n "$GOOGLE_CLIENT_ID" | gcloud secrets create google-client-id --data-file=- --project=$PROJECT_ID 2>/dev/null || \
  echo -n "$GOOGLE_CLIENT_ID" | gcloud secrets versions add google-client-id --data-file=- --project=$PROJECT_ID
echo -n "$GOOGLE_CLIENT_SECRET" | gcloud secrets create google-client-secret --data-file=- --project=$PROJECT_ID 2>/dev/null || \
  echo -n "$GOOGLE_CLIENT_SECRET" | gcloud secrets versions add google-client-secret --data-file=- --project=$PROJECT_ID
echo "✓ Google OAuth secrets created"

# OpenAI API Key
echo ""
echo "🤖 OpenAI Configuration"
read -sp "Enter OpenAI API Key: " OPENAI_API_KEY
echo ""

echo "Creating OpenAI secret..."
echo -n "$OPENAI_API_KEY" | gcloud secrets create openai-api-key --data-file=- --project=$PROJECT_ID 2>/dev/null || \
  echo -n "$OPENAI_API_KEY" | gcloud secrets versions add openai-api-key --data-file=- --project=$PROJECT_ID
echo "✓ OpenAI secret created"

echo ""
echo "✅ All secrets created!"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Add GCP_SA_KEY to GitHub secrets (if not done yet)"
echo "2. Push your code:"
echo "   git push origin main"
echo ""
echo "3. After deployment, update OAuth redirect URI:"
echo "   https://YOUR-APP-URL/api/v1/auth/google/callback"
echo ""

