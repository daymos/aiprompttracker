#!/bin/bash
# Delete WordPress instance from GCP

INSTANCE_NAME=${1:-"keywords-wordpress"}
ZONE=${2:-"europe-west1-b"}
PROJECT_ID=${GCP_PROJECT_ID:-"keywordschat-prod"}

echo "🗑️  Deleting WordPress instance..."
echo "Instance: $INSTANCE_NAME"
echo "Zone: $ZONE"
echo ""

read -p "Are you sure you want to delete this instance? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Cancelled."
  exit 0
fi

gcloud compute instances delete $INSTANCE_NAME \
  --zone=$ZONE \
  --project=$PROJECT_ID \
  --quiet

echo "✅ WordPress instance deleted"

