# 🔐 Create Application Password (2 minutes)

Application Passwords are now ENABLED! ✅

## Step 1: Log into WordPress Admin

**Open in browser:**
```
http://35.187.70.20/wp-admin
```

**Credentials:**
- Username: `user`
- Password: `+Nl9w:10p@Ao`

## Step 2: Go to Your Profile

1. Click your username in the top right
2. Select **"Profile"** or **"Edit My Profile"**
3. Or go directly to: `http://35.187.70.20/wp-admin/profile.php`

## Step 3: Create Application Password

1. Scroll down to **"Application Passwords"** section (near the bottom)
2. In the **"New Application Password Name"** field, enter:
   ```
   SEO Agent Import
   ```
3. Click **"Add New Application Password"**
4. **COPY THE PASSWORD** immediately! It looks like:
   ```
   abcd 1234 efgh 5678 ijkl 9012
   ```
   ⚠️ **You'll only see it once!**

## Step 4: Run the Import Script

Replace `YOUR_APP_PASSWORD_HERE` with the password you just copied:

```bash
cd /Users/mattiaspinelli/code/keywordsChat/backend

python scripts/import_blog_to_wordpress.py \
  --blog-dir="../landing/blog" \
  --wp-url="http://35.187.70.20" \
  --wp-user="user" \
  --wp-password="YOUR_APP_PASSWORD_HERE"
```

### Example:
```bash
python scripts/import_blog_to_wordpress.py \
  --blog-dir="../landing/blog" \
  --wp-url="http://35.187.70.20" \
  --wp-user="user" \
  --wp-password="abcd 1234 efgh 5678 ijkl 9012"
```

## Expected Output:

```
============================================================
🚀 WordPress Blog Import Tool
============================================================

🔍 Testing WordPress connection...
✅ Connected to WordPress as: user

📚 Found 13 articles to import

📄 Processing: ahrefs-alternative.html
   ✅ Imported: Best Ahrefs Alternative: 10 Cheaper Tools Compared (2025)
      URL: http://35.187.70.20/ahrefs-alternative

...

📊 Import Summary:
   ✅ Imported: 13 articles
   ⏭️  Skipped:  0 articles (already exist)
   ❌ Failed:   0 articles
============================================================
```

## That's it! 🎉

All your articles will be in WordPress and ready for SEO Agent to use!

---

**Need help?** Check `ENABLE_APP_PASSWORDS.md` for troubleshooting.

