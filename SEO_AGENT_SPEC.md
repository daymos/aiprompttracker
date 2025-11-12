# SEO Agent Feature Specification

## Overview
SEO Agent is an AI-powered content generation and automation feature that allows users to generate SEO-optimized blog posts from their tracked keywords and publish them directly to WordPress.

## Feature Goals
- Enable users to leverage their keyword research for content creation
- Automate content generation with proper SEO optimization
- Seamlessly publish to WordPress with minimal friction
- Maintain brand voice consistency through tone analysis

---

## User Experience Flow

### Phase 1: Connect & Learn (One-time Setup)

#### Step 1: Initiate Connection
```
User clicks "SEO Agent" mode in sidebar
  ↓
If no integration exists:
  Show "Connect WordPress to get started" card
  [Connect WordPress Button]
```

#### Step 2: WordPress Connection
User provides:
- WordPress Site URL (e.g., `https://wp.keywords.chat`)
- Username
- Application Password (WordPress native feature)

System validates:
- URL accessibility
- REST API availability
- Authentication credentials
- User permissions (must be able to publish)

#### Step 3: Automatic Analysis
Upon successful connection, system fetches:
- **Last 5-10 blog posts** (for tone analysis)
- **Available categories** (for content organization)
- **Site metadata** (WP version, theme info)
- **Post frequency** (publishing patterns)

#### Step 4: Tone Profile Creation
System analyzes existing content and presents:
```
┌─────────────────────────────────────────┐
│  Analysis Complete!                     │
├─────────────────────────────────────────┤
│  ✓ Detected tone: Professional & info.  │
│  ✓ Top categories: Marketing, SEO       │
│  ✓ Avg. post length: ~1,200 words       │
│  ✓ Post frequency: ~2 posts/week        │
├─────────────────────────────────────────┤
│  [Looks Good]  [Customize Tone]         │
└─────────────────────────────────────────┘
```

---

### Phase 2: Content Generation (Main Workflow)

#### SEO Agent Dashboard View
```
┌─────────────────────────────────────────┐
│  SEO Agent for [Project Name]           │
├─────────────────────────────────────────┤
│  WordPress: ✓ Connected to wp.site.com  │
│  [Reconnect] [Settings]                 │
│                                         │
│  Content Tone: Professional              │
│  [Customize]                            │
├─────────────────────────────────────────┤
│  [+ Generate New Content]               │
│                                         │
│  📝 Drafts (3)                          │
│  📤 Scheduled (5)                       │
│  ✅ Published (12)                      │
│                                         │
│  Recent Activity:                       │
│  • "Best SEO Tools" - Published 2h ago  │
│  • "Keyword Research" - Scheduled       │
└─────────────────────────────────────────┘
```

#### Content Generation Wizard

**Step 1: Select Keywords**
```
┌─────────────────────────────────────────┐
│ Select Keywords to Target               │
├─────────────────────────────────────────┤
│ From your tracked keywords:             │
│                                         │
│ ☑ best seo tools                        │
│   SV: 2.4k | Diff: Medium | CPC: $12   │
│                                         │
│ ☑ seo software comparison               │
│   SV: 1.8k | Diff: Low | CPC: $8       │
│                                         │
│ ☐ keyword research guide                │
│   SV: 3.2k | Diff: High | CPC: $15     │
│                                         │
│ [Import from tracked keywords]          │
│ [+ Add custom keywords]                 │
│                                         │
│ Selected: 2 keywords                    │
│ Estimated articles: 2                   │
│                                         │
│ [Cancel]  [Next: Review & Generate →]  │
└─────────────────────────────────────────┘
```

**Step 2: Review Settings**
```
┌─────────────────────────────────────────┐
│ Content Settings                        │
├─────────────────────────────────────────┤
│ Articles to generate: 2                 │
│                                         │
│ Article 1: "Best SEO Tools in 2024"     │
│ Article 2: "SEO Software Comparison"    │
│                                         │
│ Settings:                               │
│ • Tone: Professional & informative      │
│ • Length: ~1,500 words each             │
│ • Category: [SEO ▼]                     │
│ • Status: Draft (review before publish) │
│                                         │
│ Advanced Options ▼                      │
│ • Include FAQ section                   │
│ • Add comparison tables                 │
│ • Generate meta descriptions            │
│                                         │
│ [← Back]  [Generate Content →]         │
└─────────────────────────────────────────┘
```

**Step 3: Generation Progress**
```
┌─────────────────────────────────────────┐
│ Generating Content...                   │
├─────────────────────────────────────────┤
│ ✓ Article 1: "Best SEO Tools"           │
│   Generated in 45s                      │
│                                         │
│ ⏳ Article 2: "SEO Software Comparison" │
│   Generating... 60%                     │
│                                         │
│ [Cancel Generation]                     │
└─────────────────────────────────────────┘
```

**Step 4: Preview & Edit**
```
┌─────────────────────────────────────────┐
│ Best SEO Tools in 2024                  │
├─────────────────────────────────────────┤
│ 📊 SEO Score: 85/100                    │
│                                         │
│ ✓ Keyword density: Good (1.8%)          │
│ ✓ Headings: Well structured (H1-H3)     │
│ ✓ Readability: Easy (Grade 8)           │
│ ⚠ Add 2-3 more internal links           │
│ ⚠ Meta description too long (trim 20c)  │
│                                         │
│ [View Details]                          │
├─────────────────────────────────────────┤
│ Content Preview:                        │
│                                         │
│ [Full WYSIWYG editor with content]      │
│                                         │
├─────────────────────────────────────────┤
│ [Save as Draft]                         │
│ [Publish Now]                           │
│ [Schedule Publishing →]                 │
└─────────────────────────────────────────┘
```

**Step 5: Publishing Options**
```
┌─────────────────────────────────────────┐
│ Publish Settings                        │
├─────────────────────────────────────────┤
│ ○ Save as Draft (review in WordPress)   │
│ ○ Publish Immediately                   │
│ ● Schedule Publishing                   │
│                                         │
│   Date: [Dec 15, 2024 ▼]               │
│   Time: [10:00 AM ▼]                    │
│                                         │
│ Category: [SEO ▼]                       │
│ Tags: seo, tools, marketing             │
│                                         │
│ [← Back]  [Confirm & Publish]          │
└─────────────────────────────────────────┘
```

---

## Technical Implementation

### Database Schema

```sql
-- Project Integrations Table
CREATE TABLE project_integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    integration_type VARCHAR(50) NOT NULL, -- 'wordpress', 'medium', etc.
    site_url VARCHAR(255) NOT NULL,
    username VARCHAR(255) NOT NULL,
    credentials_encrypted TEXT NOT NULL, -- Encrypted app password
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'error', 'disconnected'
    last_tested TIMESTAMP,
    metadata JSONB, -- Store categories, WP version, capabilities, etc.
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(project_id, integration_type)
);

-- Content Tone Profiles Table
CREATE TABLE content_tone_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    integration_id UUID REFERENCES project_integrations(id) ON DELETE CASCADE,
    tone_analysis JSONB NOT NULL, -- Detected tone characteristics
    sample_posts JSONB, -- Store sample post IDs used for analysis
    custom_instructions TEXT, -- User customizations
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(project_id)
);

-- Generated Content Table
CREATE TABLE generated_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    integration_id UUID NOT NULL REFERENCES project_integrations(id),
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    meta_description TEXT,
    keywords TEXT[], -- Array of target keywords
    seo_score INTEGER, -- 0-100
    seo_analysis JSONB, -- Detailed SEO metrics
    status VARCHAR(50) NOT NULL, -- 'draft', 'scheduled', 'published', 'failed'
    wordpress_post_id INTEGER, -- ID in WordPress after publishing
    wordpress_url TEXT, -- Published URL
    scheduled_for TIMESTAMP,
    published_at TIMESTAMP,
    error_message TEXT,
    generation_metadata JSONB, -- Model used, tokens, etc.
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Content Generation Jobs (for async processing)
CREATE TABLE content_generation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    keywords TEXT[] NOT NULL,
    settings JSONB NOT NULL, -- Generation settings
    status VARCHAR(50) NOT NULL, -- 'pending', 'processing', 'completed', 'failed'
    progress INTEGER DEFAULT 0, -- 0-100
    results JSONB, -- Array of generated content IDs
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_integrations_project ON project_integrations(project_id);
CREATE INDEX idx_content_project ON generated_content(project_id);
CREATE INDEX idx_content_status ON generated_content(status);
CREATE INDEX idx_content_scheduled ON generated_content(scheduled_for) WHERE status = 'scheduled';
CREATE INDEX idx_jobs_user ON content_generation_jobs(user_id);
CREATE INDEX idx_jobs_status ON content_generation_jobs(status);
```

### Backend API Endpoints

#### Integration Management

```python
# POST /api/projects/{project_id}/integrations/wordpress
# Connect WordPress integration
Request:
{
    "site_url": "https://wp.keywords.chat",
    "username": "admin",
    "app_password": "xxxx xxxx xxxx xxxx xxxx xxxx"
}
Response:
{
    "id": "uuid",
    "status": "active",
    "site_info": {
        "name": "My Blog",
        "url": "https://wp.keywords.chat",
        "wp_version": "6.4.2",
        "categories": [...],
        "user_capabilities": [...]
    }
}

# GET /api/projects/{project_id}/integrations
# List all integrations
Response:
{
    "integrations": [
        {
            "id": "uuid",
            "type": "wordpress",
            "site_url": "https://wp.keywords.chat",
            "status": "active",
            "last_tested": "2024-12-01T10:30:00Z"
        }
    ]
}

# DELETE /api/projects/{project_id}/integrations/{integration_id}
# Remove integration
Response: 204 No Content

# POST /api/projects/{project_id}/integrations/{integration_id}/test
# Test connection
Response:
{
    "success": true,
    "message": "Connection successful",
    "tested_at": "2024-12-01T10:30:00Z"
}
```

#### Tone Analysis

```python
# POST /api/projects/{project_id}/integrations/{integration_id}/analyze-tone
# Analyze WordPress content for tone
Response:
{
    "tone_profile": {
        "formality": "professional",
        "style": "informative",
        "avg_word_count": 1200,
        "reading_level": 8,
        "common_phrases": [...],
        "post_frequency": "2_per_week"
    },
    "sample_posts": [
        {"id": 123, "title": "...", "excerpt": "..."}
    ]
}

# PUT /api/projects/{project_id}/tone-profile
# Update tone profile with custom settings
Request:
{
    "custom_instructions": "Write in a casual, friendly tone",
    "formality_level": "casual",
    "target_word_count": 1500
}
```

#### Content Generation

```python
# POST /api/projects/{project_id}/content/generate
# Generate content from keywords
Request:
{
    "keywords": ["best seo tools", "seo software comparison"],
    "settings": {
        "tone_profile_id": "uuid",
        "word_count": 1500,
        "include_faq": true,
        "include_tables": true,
        "category": "SEO",
        "status": "draft"  # or "publish" or "schedule"
    }
}
Response:
{
    "job_id": "uuid",
    "status": "processing",
    "estimated_time": 120  // seconds
}

# GET /api/projects/{project_id}/content/jobs/{job_id}
# Check generation job status
Response:
{
    "id": "uuid",
    "status": "completed",
    "progress": 100,
    "results": [
        {
            "content_id": "uuid",
            "title": "Best SEO Tools in 2024",
            "seo_score": 85
        }
    ]
}

# GET /api/projects/{project_id}/content
# List generated content
Query params: ?status=draft&limit=10&offset=0
Response:
{
    "content": [
        {
            "id": "uuid",
            "title": "Best SEO Tools in 2024",
            "status": "draft",
            "seo_score": 85,
            "created_at": "2024-12-01T10:30:00Z"
        }
    ],
    "total": 42,
    "limit": 10,
    "offset": 0
}

# GET /api/projects/{project_id}/content/{content_id}
# Get full content details
Response:
{
    "id": "uuid",
    "title": "Best SEO Tools in 2024",
    "content": "<full html content>",
    "meta_description": "...",
    "keywords": ["best seo tools", "seo tools"],
    "seo_score": 85,
    "seo_analysis": {
        "keyword_density": 1.8,
        "readability_score": 65,
        "heading_structure": "good",
        "issues": [
            {"type": "warning", "message": "Add more internal links"}
        ]
    },
    "status": "draft"
}

# PUT /api/projects/{project_id}/content/{content_id}
# Update content
Request:
{
    "title": "Updated Title",
    "content": "<updated html>",
    "meta_description": "..."
}

# DELETE /api/projects/{project_id}/content/{content_id}
# Delete content
Response: 204 No Content
```

#### Publishing

```python
# POST /api/projects/{project_id}/content/{content_id}/publish
# Publish to WordPress
Request:
{
    "integration_id": "uuid",
    "publish_immediately": false,
    "scheduled_for": "2024-12-15T10:00:00Z",
    "category_id": 5,
    "tags": ["seo", "tools", "marketing"],
    "status": "draft"  # or "publish"
}
Response:
{
    "success": true,
    "wordpress_post_id": 123,
    "wordpress_url": "https://wp.keywords.chat/blog/best-seo-tools",
    "status": "scheduled"
}

# POST /api/projects/{project_id}/content/batch-publish
# Publish multiple articles with scheduling
Request:
{
    "content_ids": ["uuid1", "uuid2", "uuid3"],
    "integration_id": "uuid",
    "schedule": {
        "start_date": "2024-12-15",
        "frequency": "every_2_days",
        "time": "10:00"
    }
}
```

### WordPress Service Implementation

```python
# backend/services/wordpress_service.py

import requests
from requests.auth import HTTPBasicAuth
from typing import Dict, List, Optional
import logging

logger = logging.getLogger(__name__)

class WordPressService:
    def __init__(self, site_url: str, username: str, app_password: str):
        self.base_url = site_url.rstrip('/')
        self.auth = HTTPBasicAuth(username, app_password)
        self.api_url = f"{self.base_url}/wp-json/wp/v2"
    
    def test_connection(self) -> Dict:
        """Test WordPress REST API connection"""
        try:
            response = requests.get(
                f"{self.api_url}/users/me",
                auth=self.auth,
                timeout=10
            )
            
            if response.status_code == 200:
                user_data = response.json()
                return {
                    "success": True,
                    "user": user_data,
                    "capabilities": user_data.get("capabilities", {})
                }
            else:
                return {
                    "success": False,
                    "error": f"Authentication failed: {response.status_code}"
                }
        except Exception as e:
            logger.error(f"WordPress connection test failed: {e}")
            return {"success": False, "error": str(e)}
    
    def get_site_info(self) -> Dict:
        """Get WordPress site information"""
        response = requests.get(
            f"{self.base_url}/wp-json",
            auth=self.auth,
            timeout=10
        )
        return response.json()
    
    def get_posts(self, limit: int = 10) -> List[Dict]:
        """Fetch recent posts for tone analysis"""
        response = requests.get(
            f"{self.api_url}/posts",
            auth=self.auth,
            params={"per_page": limit, "status": "publish"},
            timeout=10
        )
        return response.json()
    
    def get_categories(self) -> List[Dict]:
        """Get available categories"""
        response = requests.get(
            f"{self.api_url}/categories",
            auth=self.auth,
            params={"per_page": 100},
            timeout=10
        )
        return response.json()
    
    def create_post(
        self,
        title: str,
        content: str,
        status: str = "draft",
        category_ids: Optional[List[int]] = None,
        tags: Optional[List[str]] = None,
        meta_description: Optional[str] = None,
        scheduled_date: Optional[str] = None
    ) -> Dict:
        """Create a new WordPress post"""
        data = {
            "title": title,
            "content": content,
            "status": status,
            "categories": category_ids or [],
        }
        
        # Add tags if provided
        if tags:
            # Convert tag names to IDs (or create new tags)
            tag_ids = self._get_or_create_tags(tags)
            data["tags"] = tag_ids
        
        # Add scheduled date if provided
        if scheduled_date and status == "future":
            data["date"] = scheduled_date
        
        # Add meta description (requires Yoast or similar plugin)
        if meta_description:
            data["meta"] = {"_yoast_wpseo_metadesc": meta_description}
        
        response = requests.post(
            f"{self.api_url}/posts",
            auth=self.auth,
            json=data,
            timeout=30
        )
        
        return response.json()
    
    def _get_or_create_tags(self, tag_names: List[str]) -> List[int]:
        """Get tag IDs or create new tags if they don't exist"""
        tag_ids = []
        
        for tag_name in tag_names:
            # Try to find existing tag
            response = requests.get(
                f"{self.api_url}/tags",
                auth=self.auth,
                params={"search": tag_name},
                timeout=10
            )
            
            tags = response.json()
            if tags:
                tag_ids.append(tags[0]["id"])
            else:
                # Create new tag
                response = requests.post(
                    f"{self.api_url}/tags",
                    auth=self.auth,
                    json={"name": tag_name},
                    timeout=10
                )
                tag_ids.append(response.json()["id"])
        
        return tag_ids
```

### Content Generation Service

```python
# backend/services/content_generator.py

import openai
from typing import Dict, List
import logging

logger = logging.getLogger(__name__)

class ContentGenerator:
    def __init__(self, api_key: str):
        self.client = openai.OpenAI(api_key=api_key)
    
    def generate_article(
        self,
        keyword: str,
        tone_profile: Dict,
        word_count: int = 1500,
        include_faq: bool = True
    ) -> Dict:
        """Generate SEO-optimized article"""
        
        # Build prompt based on tone profile
        tone_instructions = self._build_tone_instructions(tone_profile)
        
        prompt = f"""Write a comprehensive, SEO-optimized blog post about "{keyword}".

Target word count: {word_count} words

Tone and Style:
{tone_instructions}

Requirements:
- Use proper HTML formatting with headings (h2, h3)
- Include keyword naturally throughout (target 1-2% density)
- Create compelling introduction and conclusion
- Use bullet points and numbered lists where appropriate
- Include relevant examples and data
{'- Add an FAQ section at the end' if include_faq else ''}

Format the output as JSON:
{{
    "title": "Engaging title with keyword",
    "meta_description": "150-160 character description",
    "content": "Full HTML content",
    "keywords": ["primary", "related", "keywords"],
    "outline": ["H2 heading 1", "H2 heading 2", ...]
}}
"""
        
        response = self.client.chat.completions.create(
            model="gpt-4-turbo-preview",
            messages=[
                {"role": "system", "content": "You are an expert SEO content writer."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            response_format={"type": "json_object"}
        )
        
        import json
        result = json.loads(response.choices[0].message.content)
        
        # Calculate SEO score
        seo_analysis = self._analyze_seo(result, keyword)
        result["seo_score"] = seo_analysis["score"]
        result["seo_analysis"] = seo_analysis
        
        return result
    
    def _build_tone_instructions(self, tone_profile: Dict) -> str:
        """Build tone instructions from profile"""
        instructions = []
        
        formality = tone_profile.get("formality", "professional")
        style = tone_profile.get("style", "informative")
        
        instructions.append(f"- Formality level: {formality}")
        instructions.append(f"- Writing style: {style}")
        
        if custom := tone_profile.get("custom_instructions"):
            instructions.append(f"- Custom guidance: {custom}")
        
        return "\n".join(instructions)
    
    def _analyze_seo(self, content: Dict, keyword: str) -> Dict:
        """Analyze SEO quality of generated content"""
        text = content.get("content", "")
        title = content.get("title", "")
        
        # Calculate keyword density
        keyword_count = text.lower().count(keyword.lower())
        word_count = len(text.split())
        keyword_density = (keyword_count / word_count) * 100 if word_count > 0 else 0
        
        # Check title
        title_has_keyword = keyword.lower() in title.lower()
        
        # Check headings
        h2_count = text.count("<h2>")
        h3_count = text.count("<h3>")
        
        # Calculate score (0-100)
        score = 0
        issues = []
        
        # Keyword in title (25 points)
        if title_has_keyword:
            score += 25
        else:
            issues.append({"type": "error", "message": "Keyword not in title"})
        
        # Keyword density (25 points)
        if 1.0 <= keyword_density <= 2.5:
            score += 25
        elif keyword_density < 1.0:
            score += 10
            issues.append({"type": "warning", "message": "Keyword density too low"})
        else:
            score += 10
            issues.append({"type": "warning", "message": "Keyword density too high"})
        
        # Heading structure (25 points)
        if h2_count >= 3:
            score += 25
        else:
            score += 10
            issues.append({"type": "warning", "message": "Add more H2 headings"})
        
        # Content length (25 points)
        if word_count >= 1000:
            score += 25
        else:
            score += 10
            issues.append({"type": "warning", "message": "Content too short"})
        
        return {
            "score": score,
            "keyword_density": round(keyword_density, 2),
            "word_count": word_count,
            "heading_count": {"h2": h2_count, "h3": h3_count},
            "title_has_keyword": title_has_keyword,
            "issues": issues
        }
```

---

## Frontend Implementation

### Directory Structure

```
frontend/lib/
├── screens/
│   └── chat_screen.dart (existing, updated)
├── widgets/
│   ├── integrations/
│   │   ├── wordpress_connection_card.dart
│   │   ├── wordpress_connection_dialog.dart
│   │   ├── integration_status_badge.dart
│   │   └── integration_settings_dialog.dart
│   └── seo_agent/
│       ├── seo_agent_dashboard.dart
│       ├── content_generator_wizard.dart
│       ├── keyword_selector.dart
│       ├── content_preview.dart
│       ├── seo_score_widget.dart
│       ├── publish_dialog.dart
│       └── content_library.dart
├── models/
│   ├── integration.dart
│   ├── tone_profile.dart
│   ├── generated_content.dart
│   └── generation_job.dart
├── providers/
│   ├── integration_provider.dart
│   └── content_provider.dart
└── services/
    ├── wordpress_service.dart
    └── content_generation_service.dart
```

### Key Models

```dart
// lib/models/integration.dart
class Integration {
  final String id;
  final String projectId;
  final String type; // 'wordpress'
  final String siteUrl;
  final String username;
  final IntegrationStatus status;
  final DateTime? lastTested;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  
  const Integration({
    required this.id,
    required this.projectId,
    required this.type,
    required this.siteUrl,
    required this.username,
    required this.status,
    this.lastTested,
    this.metadata,
    required this.createdAt,
  });
  
  factory Integration.fromJson(Map<String, dynamic> json) {
    return Integration(
      id: json['id'],
      projectId: json['project_id'],
      type: json['integration_type'],
      siteUrl: json['site_url'],
      username: json['username'],
      status: IntegrationStatus.values.byName(json['status']),
      lastTested: json['last_tested'] != null 
          ? DateTime.parse(json['last_tested']) 
          : null,
      metadata: json['metadata'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

enum IntegrationStatus { active, error, disconnected }

// lib/models/generated_content.dart
class GeneratedContent {
  final String id;
  final String projectId;
  final String integrationId;
  final String title;
  final String content;
  final String? metaDescription;
  final List<String> keywords;
  final int? seoScore;
  final Map<String, dynamic>? seoAnalysis;
  final ContentStatus status;
  final int? wordpressPostId;
  final String? wordpressUrl;
  final DateTime? scheduledFor;
  final DateTime? publishedAt;
  final DateTime createdAt;
  
  const GeneratedContent({
    required this.id,
    required this.projectId,
    required this.integrationId,
    required this.title,
    required this.content,
    this.metaDescription,
    required this.keywords,
    this.seoScore,
    this.seoAnalysis,
    required this.status,
    this.wordpressPostId,
    this.wordpressUrl,
    this.scheduledFor,
    this.publishedAt,
    required this.createdAt,
  });
  
  factory GeneratedContent.fromJson(Map<String, dynamic> json) {
    return GeneratedContent(
      id: json['id'],
      projectId: json['project_id'],
      integrationId: json['integration_id'],
      title: json['title'],
      content: json['content'],
      metaDescription: json['meta_description'],
      keywords: List<String>.from(json['keywords'] ?? []),
      seoScore: json['seo_score'],
      seoAnalysis: json['seo_analysis'],
      status: ContentStatus.values.byName(json['status']),
      wordpressPostId: json['wordpress_post_id'],
      wordpressUrl: json['wordpress_url'],
      scheduledFor: json['scheduled_for'] != null
          ? DateTime.parse(json['scheduled_for'])
          : null,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

enum ContentStatus { draft, scheduled, published, failed }
```

---

## MVP Feature Scope (Phase 1)

### ✅ Must Have
1. WordPress connection with Application Password
2. Automatic tone analysis from existing posts
3. Keyword selection from tracked keywords
4. Content generation (single article)
5. Basic content preview with SEO score
6. Publish to WordPress (draft or immediate)
7. Content library (view drafts/published)

### 🔄 Should Have (Phase 2)
1. Content editing interface
2. Scheduling functionality
3. Batch generation (multiple articles)
4. Advanced tone customization
5. Internal linking suggestions
6. Content performance tracking

### 💡 Nice to Have (Phase 3)
1. Content templates
2. Multi-platform publishing (Medium, Ghost, etc.)
3. Content campaigns with auto-scheduling
4. A/B testing different titles/descriptions
5. AI-powered content optimization suggestions
6. Content calendar view

---

## Security Considerations

### Data Protection
- ✅ Encrypt WordPress credentials at rest using Fernet or AES-256
- ✅ Use HTTPS for all WordPress API calls
- ✅ Never log passwords or application passwords
- ✅ Store credentials in environment variables, not code
- ✅ Implement credential rotation mechanism

### API Security
- ✅ Validate WordPress URLs to prevent SSRF attacks
- ✅ Rate limit content generation requests (max 10/hour per user)
- ✅ Validate user permissions before publishing
- ✅ Sanitize all user inputs before generating content
- ✅ Implement request timeouts (30s max)

### WordPress Security
- ✅ Verify SSL certificates for WordPress sites
- ✅ Test permissions before attempting operations
- ✅ Handle failed authentications gracefully
- ✅ Provide clear error messages without exposing sensitive data

---

## Error Handling

### Connection Errors
```
❌ Cannot connect to WordPress site
   • Verify the site URL is correct
   • Check that REST API is enabled
   • Ensure Application Passwords are enabled
   [Test Connection] [Help Article]
```

### Authentication Errors
```
❌ Authentication failed
   • Verify your username is correct
   • Check your Application Password
   • Ensure user has publishing permissions
   [Reconnect] [View Credentials]
```

### Generation Errors
```
❌ Content generation failed
   • AI service temporarily unavailable
   • Try again in a few moments
   [Retry] [Save Draft] [Contact Support]
```

### Publishing Errors
```
❌ Failed to publish to WordPress
   • Connection lost to WordPress site
   • Verify integration is still active
   • Check WordPress site status
   [Retry] [Save Locally] [View Details]
```

---

## Success Metrics

### User Engagement
- % of users who connect WordPress
- Average articles generated per user per month
- % of generated content that gets published
- Time saved vs manual content creation

### Content Quality
- Average SEO score of generated content
- User edit rate (how much they modify AI content)
- Published vs draft ratio
- User satisfaction ratings

### Business Metrics
- Feature adoption rate
- Retention impact (do users stay longer?)
- Upgrade conversion (does this drive paid plans?)
- Support ticket volume

---

## Next Steps

### Week 1: Backend Foundation
- [ ] Create database tables and migrations
- [ ] Implement WordPress connection service
- [ ] Build integration API endpoints
- [ ] Add encryption for credentials
- [ ] Write tests for WordPress service

### Week 2: Tone Analysis & Generation
- [ ] Implement tone analysis from WP posts
- [ ] Build content generation service
- [ ] Create SEO scoring algorithm
- [ ] Implement generation job queue
- [ ] Add generation API endpoints

### Week 3: Frontend - Connection Flow
- [ ] Create integration models and providers
- [ ] Build WordPress connection dialog
- [ ] Implement tone analysis UI
- [ ] Add integration settings
- [ ] Create status indicators

### Week 4: Frontend - Content Generation
- [ ] Build keyword selector widget
- [ ] Create generation wizard
- [ ] Implement content preview
- [ ] Add SEO score visualization
- [ ] Build content library

### Week 5: Publishing & Polish
- [ ] Implement publishing dialog
- [ ] Add scheduling functionality
- [ ] Create error handling UI
- [ ] Write documentation
- [ ] User testing and refinement

---

## Questions & Decisions Needed

1. **Pricing**: Will SEO Agent be part of existing plans or premium add-on?
2. **Rate Limits**: How many articles can users generate per month?
3. **AI Model**: GPT-4 Turbo vs Claude vs custom fine-tuned model?
4. **WordPress Hosting**: Should we offer managed WordPress hosting?
5. **Content Approval**: Require manual review before publishing by default?
6. **Multi-language**: Support content generation in languages other than English?

---

## Resources

### WordPress REST API Documentation
- https://developer.wordpress.org/rest-api/
- https://developer.wordpress.org/rest-api/using-the-rest-api/authentication/

### Application Passwords Guide
- https://make.wordpress.org/core/2020/11/05/application-passwords-integration-guide/

### SEO Best Practices
- Keyword density: 1-2%
- Readability: Grade 7-8
- Content length: 1000+ words for blog posts
- Heading structure: H1 (title), multiple H2s, H3s for subsections

---

## Changelog

- 2024-12-01: Initial specification created
- [Add updates as feature evolves]

