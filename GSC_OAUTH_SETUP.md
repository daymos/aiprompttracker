# Google Search Console OAuth Setup

## Backend Changes ✅ COMPLETE

The backend is now ready to accept and store GSC tokens!

### What Changed:
- ✅ Auth endpoint updated to accept GSC tokens
- ✅ Tokens automatically stored when user signs in with GSC scope

## Required Steps

### 1. Update Google Cloud Console (5 minutes)

**Add GSC Scope:**

1. Go to: https://console.cloud.google.com
2. Select your project: `keywordschat` (or whatever your project is named)
3. Navigate to: **APIs & Services → OAuth consent screen**
4. Click **"EDIT APP"**
5. Click **"ADD OR REMOVE SCOPES"**
6. Search for **"Search Console"** or manually add:
   ```
   https://www.googleapis.com/auth/webmasters.readonly
   ```
7. Check the box next to it
8. Click **"UPDATE"** at the bottom
9. Click **"SAVE AND CONTINUE"** through the rest

**That's it for GCP!** ✅

### 2. Update Flutter Google Sign-In

Find where you configure Google Sign-In (likely in `lib/services/auth_service.dart` or similar):

**Current code probably looks like:**
```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'profile',
  ],
);
```

**Update to:**
```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'profile',
    'https://www.googleapis.com/auth/webmasters.readonly',  // ADD THIS
  ],
);
```

**Then when sending tokens to backend, include GSC tokens:**
```dart
// After Google Sign-In succeeds:
final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;

// Send to backend
final response = await http.post(
  Uri.parse('$baseUrl/api/v1/auth/google'),
  body: jsonEncode({
    'id_token': googleAuth.idToken,
    'access_token': googleAuth.accessToken,
    'gsc_access_token': googleAuth.accessToken,  // ADD THIS
    'gsc_refresh_token': googleAuth.serverAuthCode,  // ADD THIS if available
  }),
);
```

**Note:** The GSC token is the same as the regular access_token when the scope is included. Flutter's GoogleSignIn will request all scopes together.

### 3. Test the Flow

**After making these changes:**

1. **Clear app state** (logout if logged in)
2. **Sign in again**
3. User will see consent screen asking for Search Console access
4. Accept it
5. Tokens automatically saved to backend! ✅

**Verify it worked:**
```bash
# Check database
psql your_database
SELECT email, gsc_access_token IS NOT NULL as has_gsc_token FROM users;
```

### 4. Link Project to GSC Property

**Option A: Manually (for testing)**
```sql
UPDATE projects 
SET gsc_property_url = 'https://yoursite.com/' 
WHERE id = 'your_project_id';
```

**Option B: Via API** (what frontend should do)
```bash
curl -X GET "http://localhost:8000/api/v1/gsc/properties" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
# Returns list of GSC properties

curl -X POST "http://localhost:8000/api/v1/gsc/project/link" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"project_id": "xxx", "property_url": "https://yoursite.com/"}'
```

### 5. Test in Chat!

```
You: "Show me my GSC data"
Agent: [calls get_gsc_performance] "Here's your real Google data..."

You: "Check my sitemap status"  
Agent: [calls get_gsc_performance with sitemaps] "Your sitemap has..."
```

## Troubleshooting

**"Access Not Configured"**
- Make sure API is enabled: `gcloud services list --enabled | grep searchconsole`
- Should see: `searchconsole.googleapis.com`

**"Invalid Scope"**
- Check OAuth consent screen in GCP Console
- Scope should be: `https://www.googleapis.com/auth/webmasters.readonly`
- Make sure you clicked "SAVE"

**"Insufficient Permission"**
- User needs to have verified their site in GSC first
- GSC API only returns properties the user owns/manages

**Tokens not saving**
- Check Flutter is sending `gsc_access_token` in auth request
- Check backend logs for errors
- Verify database migration ran: `alembic current`

## Summary

✅ **Backend:** Ready to accept GSC tokens
📝 **GCP Console:** Add scope (1 minute)
📱 **Flutter:** Add scope to GoogleSignIn (2 lines of code)
🧪 **Test:** Sign in again, tokens save automatically

Then you can chat with the agent and it has real GSC data!

