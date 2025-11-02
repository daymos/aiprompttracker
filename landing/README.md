# Keywords.chat Landing Page

SEO-optimized landing page for Keywords.chat

## 🎨 Design
- **Theme**: Ayu Mirage (dark theme)
- **Primary Color**: Orange (#ffd580)
- **Accent Colors**: Cyan (#5ccfe6), Purple (#d4bfff)
- **Fully responsive** mobile-first design

## 🚀 Deployment Options

### Option 1: Serve via Backend (Recommended)
The FastAPI backend can serve this as the root page:

```python
# In backend/app/main.py
from fastapi.responses import FileResponse

@app.get("/")
async def landing_page():
    return FileResponse("../landing/index.html")
```

### Option 2: Deploy to Vercel
```bash
cd landing
vercel --prod
```

### Option 3: Deploy to Netlify
```bash
cd landing
netlify deploy --prod
```

### Option 4: Deploy to GitHub Pages
1. Push to GitHub repository
2. Go to Settings → Pages
3. Select branch and `/landing` folder
4. Done!

### Option 5: Deploy to S3 + CloudFront
```bash
aws s3 sync landing/ s3://keywords-chat-landing
aws cloudfront create-invalidation --distribution-id YOUR_ID --paths "/*"
```

## 🔍 SEO Features

✅ **Meta Tags**: Comprehensive title, description, keywords
✅ **Open Graph**: Optimized for social sharing
✅ **Twitter Cards**: Enhanced Twitter sharing
✅ **Semantic HTML**: Proper heading hierarchy
✅ **Fast Loading**: No external dependencies
✅ **Mobile Friendly**: Responsive design
✅ **Canonical URL**: Proper URL structure

## 📝 Customization

To update content:
1. Open `index.html`
2. Edit text in sections (hero, features, etc.)
3. Update meta tags at the top
4. Redeploy

## 🎯 Call-to-Actions

- Primary CTA: "Get Started Free" → `/app`
- Secondary CTA: "See Features" → `#features`
- Footer CTAs: Privacy, Terms links

## 📊 Analytics (Recommended)

Add Google Analytics or Plausible:

```html
<!-- Add before </head> -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

## 🔗 URLs to Update

Before deploying, update these placeholders:
- `https://keywords.chat` → Your actual domain
- `/app` → Your app URL
- Add actual social media image URLs for og:image

## 🎨 Brand Assets Needed

Create these for better SEO:
- `favicon.ico` (32x32)
- `logo-512.png` (512x512 for PWA)
- `og-image.png` (1200x630 for social sharing)

