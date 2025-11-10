# Technical SEO Audit Feature

## Overview
New AI-powered technical SEO audit feature using DataForSEO OnPage API to identify and report technical issues on websites.

## How It Works

### Backend
1. **DataForSEO OnPage API Integration** (`dataforseo_service.py`)
   - Crawls up to 50 pages of a website
   - Analyzes technical issues (meta tags, titles, H1s, broken links, page size, etc.)
   - Returns structured list of issues with severity levels

2. **LLM Tool** (`keyword_chat.py`)
   - Tool name: `analyze_technical_seo`
   - Takes a URL as input
   - Returns issues with metadata for the data panel
   - Automatically invoked when user asks about technical SEO or site health

### Frontend
1. **Data Table View** (`chat_screen.dart`)
   - New column configuration: `_buildTechnicalSEOColumns()`
   - Color-coded severity (Red=High, Orange=Medium, Blue=Low)
   - Shows: Severity, Issue Type, Page, Description, How to Fix

2. **Message Actions** (`message_bubble.dart`)
   - "View Data Table" button (opens side panel)
   - "Download CSV" button (exports to CSV)
   - Auto-detects technical SEO data in message metadata

## Issue Types Detected

### High Severity
- Missing Meta Description
- Missing Title Tag
- Missing H1
- HTTP 4xx/5xx Errors

### Medium Severity
- Title Too Long (>60 chars)
- Multiple H1 Tags
- Broken Links

### Low Severity
- Large Page Size (>1MB)

## Usage Example

**User:** "Run a technical SEO audit on example.com"

**AI:**
1. Calls `analyze_technical_seo` tool
2. DataForSEO crawls the site (takes ~10-30 seconds)
3. Returns structured issues list
4. AI provides conversational summary
5. User can click "View Data Table" to see full report
6. User can download CSV for offline analysis

## Data Structure

```json
{
  "issues": [
    {
      "type": "Missing Meta Description",
      "severity": "high",
      "page": "/about",
      "element": "<meta name='description'>",
      "description": "Page lacks meta description for search results",
      "recommendation": "Add unique 150-160 character meta description"
    }
  ],
  "summary": {
    "total_issues": 42,
    "high": 5,
    "medium": 15,
    "low": 22,
    "pages_crawled": 10
  }
}
```

## Future Enhancements
- Add more issue types (redirects, canonicals, robots.txt, sitemap)
- Filter by severity level in data panel
- Export to PDF report
- Schedule recurring audits
- Compare audits over time
- Priority score for issues

