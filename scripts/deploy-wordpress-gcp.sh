#!/bin/bash
# Deploy WordPress on GCP Compute Engine (Bitnami)
# This replicates the GCP Marketplace "WordPress Certified by Bitnami" deployment

set -e

# Configuration
PROJECT_ID=${GCP_PROJECT_ID:-"keywordschat-prod"}
INSTANCE_NAME="keywords-wordpress"
ZONE="europe-west1-b"
REGION="europe-west1"
MACHINE_TYPE="e2-micro"  # ~$7/mo
DISK_SIZE="10GB"

# Bitnami WordPress image (use specific latest version)
IMAGE_PROJECT="bitnami-launchpad"
IMAGE_NAME="wordpress-6-8-3-r1-debian-12-amd64"

echo "🚀 Deploying WordPress to GCP..."
echo "Project: $PROJECT_ID"
echo "Instance: $INSTANCE_NAME"
echo "Zone: $ZONE"
echo "Machine: $MACHINE_TYPE"

# Set project
gcloud config set project $PROJECT_ID

# Create the instance
echo "📦 Creating Compute Engine instance..."
gcloud compute instances create $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
  --metadata=startup-script='#!/bin/bash
# Startup script for WordPress
echo "WordPress is ready!"
' \
  --maintenance-policy=MIGRATE \
  --provisioning-model=STANDARD \
  --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
  --tags=http-server,https-server \
  --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image-project=$IMAGE_PROJECT,image=$IMAGE_NAME,mode=rw,size=$DISK_SIZE,type=pd-standard \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --labels=goog-ec-src=vm_add-gcloud \
  --reservation-affinity=any

# Wait for instance to be ready
echo "⏳ Waiting for instance to start..."
sleep 30

# Create firewall rules for HTTP/HTTPS if they don't exist
echo "🔥 Creating firewall rules..."
gcloud compute firewall-rules create allow-http \
  --project=$PROJECT_ID \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:80 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=http-server \
  2>/dev/null || echo "HTTP rule already exists"

gcloud compute firewall-rules create allow-https \
  --project=$PROJECT_ID \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=https-server \
  2>/dev/null || echo "HTTPS rule already exists"

# Get external IP
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME \
  --zone=$ZONE \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo ""
echo "✅ WordPress deployed successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 WordPress URL: http://$EXTERNAL_IP"
echo "🔑 Admin URL: http://$EXTERNAL_IP/wp-admin"
echo ""
echo "To get your credentials, run:"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='sudo cat /home/bitnami/bitnami_credentials'"
echo ""
echo "Or manually SSH and run:"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo "  sudo cat /home/bitnami/bitnami_credentials"
echo ""
echo "Set this in GitHub secrets:"
echo "  WORDPRESS_URL=http://$EXTERNAL_IP"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "1. Get credentials (see above)"
echo "2. Visit http://$EXTERNAL_IP to access WordPress"
echo "3. Complete WordPress setup wizard"
echo "4. Set WORDPRESS_URL in GitHub secrets"
echo "5. Run: python scripts/test_wordpress.py"
echo ""

