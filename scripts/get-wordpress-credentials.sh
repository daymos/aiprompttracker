#!/bin/bash
# Get WordPress credentials from Bitnami instance

INSTANCE_NAME=${1:-"keywords-wordpress"}
ZONE=${2:-"europe-west1-b"}

echo "🔑 Getting WordPress credentials..."
echo "Instance: $INSTANCE_NAME"
echo "Zone: $ZONE"
echo ""

# Get credentials
gcloud compute ssh $INSTANCE_NAME \
  --zone=$ZONE \
  --command='sudo cat /home/bitnami/bitnami_credentials'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get external IP
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME \
  --zone=$ZONE \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo ""
echo "WordPress is running at:"
echo "  Site: http://$EXTERNAL_IP"
echo "  Admin: http://$EXTERNAL_IP/wp-admin"
echo ""
echo "Set in GitHub secrets:"
echo "  WORDPRESS_URL=http://$EXTERNAL_IP"
echo ""

