# 🚀 Deploy WordPress on GCP via CLI

## Quick Deploy

```bash
# Set your GCP project ID
export GCP_PROJECT_ID="keywordschat-prod"

# Deploy WordPress
./scripts/deploy-wordpress-gcp.sh

# Wait ~2 minutes for deployment
# Then get credentials:
./scripts/get-wordpress-credentials.sh
```

**That's it!** WordPress will be running on GCP.

---

## Step-by-Step Guide

### 1. Deploy WordPress (~5 minutes)

```bash
cd /Users/mattiaspinelli/code/keywordsChat

# Deploy (uses Bitnami WordPress image from GCP Marketplace)
./scripts/deploy-wordpress-gcp.sh
```

**What it does:**
- ✅ Creates Compute Engine VM (`e2-micro` ~$7/mo)
- ✅ Uses Bitnami WordPress image (same as Marketplace)
- ✅ Configures firewall rules (HTTP/HTTPS)
- ✅ Returns external IP and next steps

**Output:**
```
✅ WordPress deployed successfully!

📍 WordPress URL: http://34.77.XXX.XXX
🔑 Admin URL: http://34.77.XXX.XXX/wp-admin

To get your credentials, run:
  ./scripts/get-wordpress-credentials.sh
```

### 2. Get WordPress Credentials (~1 minute)

```bash
# Get username and password
./scripts/get-wordpress-credentials.sh
```

**Output:**
```
🔑 Getting WordPress credentials...

Welcome to the Bitnami WordPress Stack

******************************************************************************
The default username and password is 'user' and 'XXXXXXXXXXXX'.
******************************************************************************

WordPress is running at:
  Site: http://34.77.XXX.XXX
  Admin: http://34.77.XXX.XXX/wp-admin
```

**Save these credentials!**

### 3. Access WordPress (~2 minutes)

```bash
# Open in browser
open http://YOUR_EXTERNAL_IP/wp-admin

# Login with credentials from step 2
```

**Complete WordPress setup:**
1. Login with username/password
2. Update site title: "Keywords.chat Blog"
3. Update site URL (if using custom domain later)
4. Create your first post

### 4. Configure GitHub Secret (~1 minute)

```bash
# Add to GitHub secrets:
# Name: WORDPRESS_URL
# Value: http://YOUR_EXTERNAL_IP

# Or if you set up custom domain:
# Value: https://wp.keywords.chat
```

### 5. Test Connection (~1 minute)

```bash
# Set environment variable
export WORDPRESS_URL="http://YOUR_EXTERNAL_IP"

# Test
python scripts/test_wordpress.py
```

**Expected output:**
```
✅ WordPress site is accessible
✅ WordPress REST API is accessible
✅ All tests passed!
```

---

## Configuration

### Custom Machine Type

Edit `scripts/deploy-wordpress-gcp.sh`:

```bash
# Options:
MACHINE_TYPE="e2-micro"   # ~$7/mo (default)
MACHINE_TYPE="e2-small"   # ~$15/mo (more power)
MACHINE_TYPE="e2-medium"  # ~$30/mo (production)
```

### Custom Zone

```bash
# Edit script or pass environment variable
export ZONE="us-central1-a"
./scripts/deploy-wordpress-gcp.sh
```

### Static IP (Optional but Recommended)

```bash
# Reserve static IP
gcloud compute addresses create wordpress-ip --region=europe-west1

# Get the IP
STATIC_IP=$(gcloud compute addresses describe wordpress-ip \
  --region=europe-west1 \
  --format='value(address)')

# Delete and recreate instance with static IP
gcloud compute instances delete keywords-wordpress --zone=europe-west1-b --quiet

# Then in deploy script, add:
# --address=$STATIC_IP
```

---

## Custom Domain Setup

### Option 1: Point Subdomain to VM

```bash
# 1. Get VM external IP
gcloud compute instances describe keywords-wordpress \
  --zone=europe-west1-b \
  --format='value(networkInterfaces[0].accessConfigs[0].natIP)'

# 2. Add DNS A record:
# Type: A
# Name: wp
# Value: YOUR_VM_IP
# TTL: 300

# 3. Wait for DNS propagation (~5 minutes)
# 4. Update WordPress URL:
# WordPress Admin → Settings → General
# WordPress Address: https://wp.keywords.chat
# Site Address: https://wp.keywords.chat
```

### Option 2: Use Cloud Load Balancer + SSL (Advanced)

For production with HTTPS, use Cloud Load Balancer with managed SSL certificate.

---

## Management Commands

### SSH into WordPress

```bash
gcloud compute ssh keywords-wordpress --zone=europe-west1-b
```

### View Logs

```bash
# SSH first, then:
sudo tail -f /opt/bitnami/apache/logs/error_log
sudo tail -f /opt/bitnami/apache/logs/access_log
```

### Restart Services

```bash
# SSH first, then:
sudo /opt/bitnami/ctlscript.sh restart
sudo /opt/bitnami/ctlscript.sh restart apache
sudo /opt/bitnami/ctlscript.sh restart mysql
```

### Update WordPress

```bash
# SSH first, then:
sudo /opt/bitnami/bnconfig --machine_hostname YOUR_DOMAIN
cd /opt/bitnami/wordpress
sudo /opt/bitnami/wp-cli/bin/wp core update
sudo /opt/bitnami/wp-cli/bin/wp plugin update --all
```

### Backup WordPress

```bash
# Create snapshot of disk
gcloud compute disks snapshot keywords-wordpress \
  --zone=europe-west1-b \
  --snapshot-names=wordpress-backup-$(date +%Y%m%d)
```

### Stop/Start Instance (Save Money)

```bash
# Stop (saves $$ when not using)
gcloud compute instances stop keywords-wordpress --zone=europe-west1-b

# Start
gcloud compute instances start keywords-wordpress --zone=europe-west1-b
```

### Delete Instance

```bash
./scripts/delete-wordpress-gcp.sh

# Or manually:
gcloud compute instances delete keywords-wordpress --zone=europe-west1-b
```

---

## Cost Optimization

### Current Setup: ~$7/mo
- VM: e2-micro (~$7/mo)
- Disk: 10GB SSD (~$1.70/mo, included in VM cost)
- Network: Egress free tier (first 1GB/month)

### To Reduce Cost:

**Option 1: Use Preemptible VM** (~70% cheaper)
- Risk: VM can be terminated anytime
- Good for: Development/testing
- Add `--preemptible` flag to create command

**Option 2: Stop When Not Using**
```bash
# Stop at night, start in morning
gcloud compute instances stop keywords-wordpress --zone=europe-west1-b
# Saves ~70% of VM cost
```

**Option 3: Smaller Disk**
```bash
# 10GB is plenty for WordPress
# But you could use 5GB for even less
DISK_SIZE="5GB"  # in deploy script
```

---

## Troubleshooting

### Can't Access WordPress

**Check firewall:**
```bash
gcloud compute firewall-rules list --filter="name~'(http|https)'"
```

**Check VM is running:**
```bash
gcloud compute instances list
```

**Check external IP:**
```bash
gcloud compute instances describe keywords-wordpress \
  --zone=europe-west1-b \
  --format='value(networkInterfaces[0].accessConfigs[0].natIP)'
```

### WordPress Shows "Error Establishing Database Connection"

**SSH and check MySQL:**
```bash
gcloud compute ssh keywords-wordpress --zone=europe-west1-b
sudo /opt/bitnami/ctlscript.sh status
sudo /opt/bitnami/ctlscript.sh restart mysql
```

### Can't SSH

**Check project ID:**
```bash
gcloud config get-value project
# Should be: keywordschat-prod
```

**Try with project flag:**
```bash
gcloud compute ssh keywords-wordpress \
  --zone=europe-west1-b \
  --project=keywordschat-prod
```

---

## Comparison with Railway

| Aspect | GCP Compute Engine | Railway |
|--------|-------------------|---------|
| **Cost** | ~$7/mo | ~$5/mo |
| **Setup** | CLI script (5 min) | Web UI (2 min) |
| **Control** | Full SSH access | Limited |
| **Billing** | Same as Cloud Run | Separate |
| **Performance** | Guaranteed | Shared |
| **Backups** | Snapshots (manual) | Included |
| **SSL** | Manual setup | Automatic |

**Recommendation:** 
- **Development:** Railway (easier)
- **Production:** GCP (more control, same billing)

---

## Next Steps

1. ✅ Deploy WordPress: `./scripts/deploy-wordpress-gcp.sh`
2. ✅ Get credentials: `./scripts/get-wordpress-credentials.sh`
3. ✅ Login and create test post
4. ✅ Set GitHub secret: `WORDPRESS_URL`
5. ✅ Test: `python scripts/test_wordpress.py`
6. ✅ Generate blog: `python scripts/generate_blog.py`
7. ✅ Deploy: `git push`

**Your WordPress is ready!** 🎉

