# 🚀 Quick Guide: Import Existing Blog to WordPress

## **Why?**

You have 13 articles in `landing/blog/` that were written manually. To use SEO Agent, they need to be in WordPress so the AI can:
- ✅ Analyze your writing tone/style
- ✅ Manage all content in one place
- ✅ Generate new articles that match your style

---

## **Step 1: Get Your WordPress Credentials**

### **WordPress URL:**
Your WordPress site URL (e.g., `https://blog.keywords.chat` or `https://keywords.chat`)

### **Username:**
Your WordPress admin username

### **Application Password:**
1. Log into WordPress admin panel
2. Click **Users** → **Your Profile**  
3. Scroll down to **"Application Passwords"** section
4. Enter name: `Import Script`
5. Click **"Add New Application Password"**
6. **COPY THE GENERATED PASSWORD** (looks like: `xxxx xxxx xxxx xxxx xxxx xxxx`)
7. ⚠️ **You'll only see this once!** Save it somewhere safe

---

## **Step 2: Run the Import Script**

```bash
# 1. Go to backend directory
cd backend

# 2. Install dependencies (if needed)
pip install -r requirements.txt

# 3. Run the import script
python scripts/import_blog_to_wordpress.py \
  --blog-dir="../landing/blog" \
  --wp-url="YOUR_WORDPRESS_URL_HERE" \
  --wp-user="YOUR_USERNAME_HERE" \
  --wp-password="YOUR_APPLICATION_PASSWORD_HERE"
```

### **Example:**

```bash
python scripts/import_blog_to_wordpress.py \
  --blog-dir="../landing/blog" \
  --wp-url="https://blog.keywords.chat" \
  --wp-user="admin" \
  --wp-password="abcd 1234 efgh 5678 ijkl 9012"
```

---

## **Step 3: Verify Import**

The script will show you:
- ✅ How many articles were imported
- ⏭️ How many were skipped (already existed)
- ❌ Any errors

Example output:
```
📊 Import Summary:
   ✅ Imported: 13 articles
   ⏭️ Skipped:  0 articles (already exist)
   ❌ Failed:   0 articles
```

Then:
1. Log into WordPress admin
2. Go to **Posts → All Posts**
3. You should see all 13 articles! 🎉

---

## **What Happens After Import?**

✅ **All 13 articles are now in WordPress**
- Same titles, content, and slugs
- Set as "Published" status
- URLs preserved (e.g., `/blog/ahrefs-alternative`)

✅ **SEO Agent is ready to use:**
- Can analyze your writing tone
- Can see your existing content
- Can generate new articles matching your style

✅ **You can manage everything in WordPress:**
- Edit posts in WP admin
- Add new posts via WP or SEO Agent
- Keep `landing/blog/` for serving static files

---

## **Troubleshooting**

### "Connection failed: 401"
❌ **Wrong credentials** - Check username and application password

### "Connection failed: 404"  
❌ **WordPress REST API not enabled** - Check if `/wp-json/` works

### "Already exists"
✅ **Not an error!** - Post was already imported (safe to ignore)

### "Connection timeout"
❌ **WordPress site is slow** - Try again or check if site is up

---

## **Next Steps**

After successful import:

1. **Test SEO Agent:**
   - Switch to "SEO Agent" mode in the app
   - Click "Let's Start"
   - Connect WordPress (same credentials)
   - Ask: "Analyze my writing style"
   - It will analyze your 13 articles! 🎨

2. **Generate Your First AI Article:**
   - Ask: "Generate an article about [topic]"
   - Review the outline
   - Generate full content
   - Publish to WordPress!

---

## **Need Help?**

- 📖 Full details: `scripts/README.md`
- 🔧 Script location: `backend/scripts/import_blog_to_wordpress.py`
- 💬 WordPress setup: See `WORDPRESS_SETUP.md`

**Ready to import? Run the script above!** 🚀

