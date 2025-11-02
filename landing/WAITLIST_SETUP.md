# Waitlist Email Collection Setup

## 📧 Email Collection Options

### Option 1: Formspree (Recommended - Easiest)

**Free tier**: 50 submissions/month

1. Go to [formspree.io](https://formspree.io)
2. Sign up for free account
3. Create a new form
4. Copy your form endpoint (e.g., `https://formspree.io/f/xwkgjpqr`)
5. Update `landing/index.html`:
   ```html
   <form class="waitlist-form" action="https://formspree.io/f/YOUR_FORM_ID" method="POST">
   ```
6. Done! Emails will be sent to your inbox

### Option 2: Google Forms

1. Create a Google Form
2. Add email field
3. Get the form action URL
4. Update the form action in `landing/index.html`

### Option 3: Custom Backend Endpoint

Add to `backend/app/main.py`:

```python
from pydantic import BaseModel, EmailStr
from datetime import datetime

class WaitlistSignup(BaseModel):
    email: EmailStr

waitlist_emails = []

@app.post("/api/v1/waitlist")
async def join_waitlist(signup: WaitlistSignup):
    """Collect waitlist emails"""
    
    # Add to list
    waitlist_emails.append({
        "email": signup.email,
        "timestamp": datetime.now().isoformat()
    })
    
    # TODO: Save to database
    # TODO: Send confirmation email
    # TODO: Add to email marketing tool (Mailchimp, ConvertKit, etc.)
    
    logger.info(f"New waitlist signup: {signup.email}")
    
    return {"message": "Thanks for joining! We'll be in touch soon."}
```

Then update the form:
```html
<form class="waitlist-form" id="waitlist-form">
    <div class="form-group">
        <input 
            type="email" 
            name="email" 
            id="email"
            placeholder="Enter your email" 
            required
            class="email-input"
        >
        <button type="submit" class="submit-button">
            Get Early Access →
        </button>
    </div>
    <p class="form-note">🚀 Launching soon! No spam, ever.</p>
</form>

<script>
document.getElementById('waitlist-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('email').value;
    
    try {
        const response = await fetch('/api/v1/waitlist', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email })
        });
        
        if (response.ok) {
            alert('🎉 Thanks for joining! Check your email for updates.');
            document.getElementById('email').value = '';
        }
    } catch (error) {
        alert('Oops! Something went wrong. Please try again.');
    }
});
</script>
```

### Option 4: Email Marketing Tools

**Mailchimp**:
- Embed Mailchimp signup form
- Free tier: 500 contacts

**ConvertKit**:
- Create a form
- Embed the code

**Substack**:
- Use Substack's built-in subscribe widget

## 📊 Tracking Signups

### Google Analytics
Add before `</head>`:
```html
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

### Track form submissions:
```javascript
// Add to form submit
gtag('event', 'waitlist_signup', {
  'event_category': 'engagement',
  'event_label': 'landing_page'
});
```

## 🎯 Launch Checklist

When ready to launch the app:

1. **Update landing page**:
   - Change "Join Waitlist" to "Get Started Free"
   - Update href from `#waitlist` to `/app`

2. **Enable app in backend**:
   ```python
   # In backend/app/main.py
   # Uncomment the Flutter app serving code (lines 81-101)
   ```

3. **Test**:
   - Visit http://localhost:8000 (landing)
   - Visit http://localhost:8000/app (should work)
   - Test signup flow

4. **Deploy**:
   - Push to production
   - Monitor signups
   - Send launch emails to waitlist!

## 💌 Email Template for Launch

Subject: Keywords.chat is LIVE! 🚀

Body:
```
Hey there!

You joined the Keywords.chat waitlist, and we're excited to tell you:
We're LIVE! 🎉

Start using your AI-powered SEO assistant now:
👉 https://keywords.chat/app

What you can do:
✅ Research keywords with real data
✅ Analyze SERP competition
✅ Check your rankings
✅ Audit websites
✅ Analyze backlinks

No credit card required to get started.

Happy optimizing!
- The Keywords.chat Team
```

