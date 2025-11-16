#!/bin/bash

# Script to create GCP secrets from .env file
# Usage: ./create-secrets.sh

set -e

PROJECT_ID="keywordschat-1761904425"
ENV_FILE="backend/.env"

echo "🔐 Creating secrets in project: $PROJECT_ID"
echo ""

# Check if .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: $ENV_FILE not found"
    exit 1
fi

# Load .env file
source "$ENV_FILE"

# Function to create or update secret
create_secret() {
    local secret_name=$1
    local secret_value=$2
    
    if [ -z "$secret_value" ]; then
        echo "⚠️  Skipping $secret_name (no value set)"
        return
    fi
    
    # Check if secret already exists
    if gcloud secrets describe "$secret_name" --project="$PROJECT_ID" &>/dev/null; then
        echo "🔄 Updating $secret_name..."
        echo -n "$secret_value" | gcloud secrets versions add "$secret_name" \
            --data-file=- \
            --project="$PROJECT_ID"
    else
        echo "✨ Creating $secret_name..."
        echo -n "$secret_value" | gcloud secrets create "$secret_name" \
            --data-file=- \
            --project="$PROJECT_ID"
    fi
}

# Create all secrets
create_secret "aiprompttracker-db-url" "$DATABASE_URL"
create_secret "dataforseo-login" "$DATAFORSEO_LOGIN"
create_secret "dataforseo-password" "$DATAFORSEO_PASSWORD"
create_secret "groq-api-key" "$GROQ_API_KEY"
create_secret "jwt-secret" "$JWT_SECRET_KEY"
create_secret "google-client-id" "$GOOGLE_CLIENT_ID"
create_secret "google-client-secret" "$GOOGLE_CLIENT_SECRET"
create_secret "rapidapi-key" "$RAPIDAPI_KEY"

echo ""
echo "✅ All secrets created/updated successfully!"
echo ""
echo "📋 Listing secrets:"
gcloud secrets list --project="$PROJECT_ID"

