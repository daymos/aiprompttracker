# 🔐 Enable Application Passwords in WordPress

Your WordPress instance has Application Passwords disabled. Here's how to enable them:

## **Option 1: Via WordPress Admin (Easiest - 2 minutes)**

### Step 1: Log into WordPress

```
URL:      http://35.187.70.20/wp-admin
Username: user
Password: +Nl9w:10p@Ao
```

### Step 2: Check if Application Passwords are Available

1. Go to: **Users → Profile**
2. Scroll down to the bottom
3. Look for **"Application Passwords"** section

**If you see it:** Great! Jump to Step 3.

**If you DON'T see it:** Application Passwords might be disabled. Try one of these:

#### Fix A: Force Enable via HTTPS (Application Passwords require HTTPS by default)

Application Passwords are disabled on HTTP sites for security. You need to either:

1. **Enable HTTPS** on your WordPress site, OR
2. **Force enable** for local/development (not recommended for production)

To force enable for testing, SSH into your server and add to `wp-config.php`:

```bash
# SSH into the server
gcloud compute ssh keywords-wordpress --zone=europe-west1-b

# Edit wp-config.php
sudo nano /opt/bitnami/wordpress/wp-config.php

# Add this line BEFORE "/* That's all, stop editing! */"
define( 'WP_ENVIRONMENT_TYPE', 'local' );

# Save (Ctrl+X, Y, Enter)

# Restart Apache
sudo /opt/bitnami/ctlscript.sh restart apache
```

#### Fix B: Use a Plugin (JWT Authentication)

If Application Passwords still don't work, install JWT authentication:

1. Download: [JWT Authentication Plugin](https://wordpress.org/plugins/jwt-authentication-for-wp-rest-api/)
2. Upload to WordPress: **Plugins → Add New → Upload Plugin**
3. Activate it
4. Follow plugin setup instructions

### Step 3: Create Application Password

Once you see the "Application Passwords" section:

1. In the **"Application Passwords"** section
2. **Enter name:** `SEO Agent Import`
3. **Click:** "Add New Application Password"
4. **COPY THE PASSWORD** (it's shown only once!)

Example: `abcd 1234 efgh 5678 ijkl 9012`

---

## **Option 2: Quick Fix - Use Basic Auth Plugin (3 minutes)**

If Application Passwords are too complicated, use the Basic Auth plugin:

### Install Basic Auth Plugin

```bash
# SSH into server
gcloud compute ssh keywords-wordpress --zone=europe-west1-b

# Download plugin
cd /opt/bitnami/wordpress/wp-content/plugins
sudo wget https://github.com/WP-API/Basic-Auth/archive/master.zip
sudo unzip master.zip
sudo mv Basic-Auth-master basic-auth
sudo rm master.zip

# Fix permissions
sudo chown -R bitnami:daemon /opt/bitnami/wordpress/wp-content/plugins/basic-auth

# Restart Apache
sudo /opt/bitnami/ctlscript.sh restart apache
```

### Activate via WordPress Admin

1. Go to: **Plugins → Installed Plugins**
2. Find: **"Basic Auth"**
3. Click: **"Activate"**

### Now you can use regular password!

```bash
python scripts/import_blog_to_wordpress.py \
  --blog-dir="../landing/blog" \
  --wp-url="http://35.187.70.20" \
  --wp-user="user" \
  --wp-password="+Nl9w:10p@Ao"
```

---

## **Option 3: Switch to HTTPS (Recommended for Production)**

Application Passwords require HTTPS by default. Set up SSL:

### Using Let's Encrypt on Bitnami

```bash
# SSH into server
gcloud compute ssh keywords-wordpress --zone=europe-west1-b

# Run Bitnami HTTPS configuration tool
sudo /opt/bitnami/bncert-tool
```

Follow the prompts to:
1. Enter your domain (e.g., `wp.keywords.chat`)
2. It will automatically get SSL certificate from Let's Encrypt
3. Configure WordPress to use HTTPS

Then Application Passwords will work automatically!

---

## **Quick Test: Which Method is Working?**

After trying any fix above, test the connection:

```bash
cd backend
python -c "
import requests
import base64

url = 'http://35.187.70.20/wp-json/wp/v2/users/me'
auth_string = 'user:+Nl9w:10p@Ao'
b64 = base64.b64encode(auth_string.encode()).decode()
headers = {'Authorization': f'Basic {b64}'}

response = requests.get(url, headers=headers)
print(f'Status: {response.status_code}')
if response.status_code == 200:
    print('✅ Authentication works!')
    print(f'User: {response.json()[\"name\"]}')
else:
    print('❌ Authentication failed')
    print(f'Response: {response.text}')
"
```

---

## **What I Recommend:**

**For immediate testing:**
→ Use Option 2 (Basic Auth Plugin) - works in 3 minutes

**For production:**
→ Use Option 3 (HTTPS with Let's Encrypt) - proper security

---

## **After Fixing:**

Run the import script:

```bash
cd backend

python scripts/import_blog_to_wordpress.py \
  --blog-dir="../landing/blog" \
  --wp-url="http://35.187.70.20" \
  --wp-user="user" \
  --wp-password="YOUR_APP_PASSWORD_OR_REGULAR_PASSWORD"
```

🚀 **All 13 articles will be imported to WordPress!**

