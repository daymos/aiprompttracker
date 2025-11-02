#!/bin/bash

# Script to create GitHub secrets from .env file
# Usage: ./create-github-secrets.sh

set -e

ENV_FILE="backend/.env"
REPO="daymos/keywordschat"

echo "🔐 Creating GitHub secrets for repository: $REPO"
echo ""

# Check if .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: $ENV_FILE not found"
    exit 1
fi

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "❌ Error: gh CLI is not installed"
    echo "Install it: brew install gh"
    exit 1
fi

# Load .env file
source "$ENV_FILE"

# Function to create secret
create_secret() {
    local secret_name=$1
    local secret_value=$2
    
    if [ -z "$secret_value" ]; then
        echo "⚠️  Skipping $secret_name (no value set)"
        return
    fi
    
    echo "✨ Setting $secret_name..."
    echo -n "$secret_value" | gh secret set "$secret_name" --repo="$REPO"
}

# Create all secrets
echo "📝 Creating application secrets..."
create_secret "DATABASE_URL" "$DATABASE_URL"
create_secret "DATAFORSEO_LOGIN" "$DATAFORSEO_LOGIN"
create_secret "DATAFORSEO_PASSWORD" "$DATAFORSEO_PASSWORD"
create_secret "GROQ_API_KEY" "$GROQ_API_KEY"
create_secret "JWT_SECRET_KEY" "$JWT_SECRET_KEY"
create_secret "GOOGLE_CLIENT_ID" "$GOOGLE_CLIENT_ID"
create_secret "GOOGLE_CLIENT_SECRET" "$GOOGLE_CLIENT_SECRET"
create_secret "RAPIDAPI_KEY" "$RAPIDAPI_KEY"

echo ""
echo "✅ All GitHub secrets created successfully!"
echo ""
echo "📋 Listing secrets:"
gh secret list --repo="$REPO"

