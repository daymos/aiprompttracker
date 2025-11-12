# Auto Keyword Detection Feature

## Overview
When a project is created, the system now automatically analyzes the website and extracts keywords that the site is currently targeting. These keywords are saved to the database and marked as "auto_detected" to distinguish them from manually added keywords.

## Changes Made

### Backend Changes

#### 1. Database Model (`backend/app/models/project.py`)
- Added `source` field to `TrackedKeyword` model
- Values: `"manual"` or `"auto_detected"`
- Default: `"manual"`

#### 2. Database Migration (`backend/alembic/versions/7f9183758b0e_add_source_to_tracked_keywords.py`)
- Created migration to add `source` column to `tracked_keywords` table
- Sets existing keywords to `"manual"`
- Migration ID: `7f9183758b0e`

#### 3. Project API (`backend/app/api/project.py`)
- Updated `create_project` endpoint to:
  - Analyze website using `KeywordService.get_url_keyword_ideas()`
  - Extract up to 20 keywords
  - Save them with `source="auto_detected"`
  - Gracefully handle errors (project creation succeeds even if keyword analysis fails)
- Updated `TrackedKeywordResponse` model to include `source` field
- Updated keyword response endpoints to return the `source` field

### Frontend Changes

#### 1. TrackedKeyword Model (`frontend/lib/providers/project_provider.dart`)
- Added `source` field to `TrackedKeyword` class
- Default value: `"manual"` for backward compatibility
- Updated all API response parsing to include `source` field

#### 2. UI Updates (`frontend/lib/screens/chat_screen.dart`)
- Added visual badge for auto-detected keywords
- Badge displays "Currently Targeting" with an auto_awesome icon
- Badge uses blue color scheme to distinguish from manual keywords

## Usage

### Creating a Project
When a user creates a new project:
```
POST /project/create
{
  "target_url": "https://example.com",
  "name": "My Project"
}
```

The system will:
1. Create the project
2. Analyze the website using the Keyword Service API
3. Extract keywords the site is targeting
4. Save up to 20 keywords with `source="auto_detected"`
5. Return the project details

### Viewing Keywords
When fetching project keywords:
```
GET /project/{project_id}/keywords
```

Response includes the `source` field:
```json
{
  "id": "uuid",
  "keyword": "seo tools",
  "search_volume": 5000,
  "competition": "MEDIUM",
  "current_position": null,
  "target_position": 10,
  "source": "auto_detected",
  "created_at": "2025-11-04T21:00:00"
}
```

### UI Display
- **Auto-detected keywords**: Display a blue badge with "Currently Targeting"
- **Manual keywords**: No special badge (default appearance)

## Testing

To test the feature:
1. Run the migration: `cd backend && alembic upgrade head`
2. Start the backend server
3. Create a new project with a real website URL
4. Check that keywords are automatically added with `source="auto_detected"`
5. Verify the UI shows the "Currently Targeting" badge for auto-detected keywords
6. Manually add a keyword and verify it's marked as `source="manual"`

## Benefits

1. **Immediate Value**: Users get instant keyword insights when creating a project
2. **Differentiation**: Clear distinction between current targeting and future opportunities
3. **Better UX**: No need to manually add initial keywords
4. **SEO Analysis**: Helps users understand what their site is already optimized for

## Notes

- Keyword analysis is non-blocking; project creation succeeds even if analysis fails
- Limit of 20 auto-detected keywords to avoid overwhelming users
- Uses US location for keyword data by default
- Auto-detected keywords can still be deleted like manual keywords




