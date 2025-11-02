# API Call Flow - Where & When APIs Are Called

## 🔄 Complete Request Flow

### 1. **Frontend (Flutter) → Backend**
```
User types message in chat
   ↓
Flutter app calls: POST http://localhost:8000/api/v1/chat/message
   ↓
Request reaches: backend/app/api/keyword_chat.py
```

### 2. **Backend Processing (keyword_chat.py)**

```python
# File: backend/app/api/keyword_chat.py

async def send_message(...):
    # Step 1: Save user message to database
    
    # Step 2: Ask LLM: "Does user want keyword research?"
    keyword_to_research = await llm_service.extract_keyword_intent(
        user_message=request.message,
        conversation_history=conversation_history
    )
    
    # Step 3: If YES → Call Keyword API
    if keyword_to_research:
        keyword_data = await keyword_service.analyze_keywords(keyword_to_research)
        # ↑ This calls RapidAPI Keyword Research API
    
    # Step 4: Ask LLM: "Does user want backlink analysis?"
    backlink_intent = await llm_service.extract_backlink_intent(...)
    
    # Step 5: If YES → Call Backlink API
    if backlink_intent:
        backlink_data = await backlink_service.get_backlinks(domain)
        # ↑ This calls RapidAPI Backlinks API
    
    # Step 6: Generate final response with LLM
    assistant_response = await llm_service.generate_keyword_advice(...)
    
    # Step 7: Save & return response
```

### 3. **API Services Call External APIs**

```python
# File: backend/app/services/keyword_service.py
async def analyze_keywords(seed_keyword: str):
    # Makes HTTP request to:
    # https://google-keyword-research1.p.rapidapi.com/keyword-research
    # Returns keyword data OR raises exception

# File: backend/app/services/rapidapi_backlinks_service.py  
async def get_backlinks(domain: str):
    # Makes HTTP request to:
    # https://seo-api-get-backlinks.p.rapidapi.com/backlinks.php
    # Returns backlink data OR raises exception
```

## 🚨 Current Problem

**The LLM intent detector is too conservative!**

Looking at your logs:
```
Line 513: INFO:app.api.keyword_chat:LLM determined no specific keyword research needed
```

This means `extract_keyword_intent()` returned `None`, so the keyword API was **never called**.

## 🔍 What You'll See Now (With New Logging)

### When Intent Detection Works:
```
INFO: 🔍 Asking LLM: Does user want keyword research?
INFO: 📋 LLM intent response: 'SEO tools'
INFO: ✅ LLM detected keyword research intent for: 'SEO tools'
INFO: 🔍 Starting keyword analysis for: 'SEO tools' (limit: 10)
INFO: 🔍 Fetching keyword data for: 'SEO tools'
INFO: 📡 API Endpoint: https://google-keyword-research1.p.rapidapi.com/...
INFO: 📥 Response status: 200
INFO: ✅ Successfully received data
```

### When Intent Detection Fails:
```
INFO: 🔍 Asking LLM: Does user want keyword research?
INFO: 📋 LLM intent response: 'NULL'
INFO: ❌ LLM says: No keyword research needed
```

## 🧪 How to Test

### Test 1: Direct Keyword Request
User types: **"find keywords for AI chatbots"**

Expected logs:
```
INFO: 🔍 Asking LLM: Does user want keyword research?
INFO: ✅ LLM detected keyword research intent for: 'AI chatbots'
INFO: 🔍 Fetching keyword data for: 'AI chatbots'
```

### Test 2: Conversational Request
User: **"I want to research keywords"**
Bot: **"Sure! What topic?"**
User: **"it's a chat based SEO tool"**

Expected logs:
```
INFO: 🔍 Asking LLM: Does user want keyword research?
INFO: ✅ LLM detected keyword research intent for: 'chat based SEO tool'
INFO: 🔍 Fetching keyword data for: 'chat based SEO tool'
```

## 📝 Summary

**APIs are called from**: Backend Python services
**When they're called**: When LLM intent detection returns a keyword/domain
**Why they're not called**: LLM is returning "NULL" (no intent detected)

**With new logging**, you'll now see:
1. What the user asked
2. What the LLM understood
3. Whether APIs were triggered
4. Full API request/response details

