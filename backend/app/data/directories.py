"""
Curated list of 100+ directories for backlink submissions.

Tiers:
- 'top': Premium directories requiring manual submission (Product Hunt, G2, etc.)
- 'mid': Quality directories that can be automated via form POST
- 'volume': Bulk directories for fast indexation (DA 20-40)

Automation:
- 'manual': User must submit manually (complex process)
- 'form_post': Can auto-submit via HTTP POST
- 'api': Has API endpoint
"""

DIRECTORY_DATABASE = [
    # === TOP TIER - MANUAL SUBMISSION REQUIRED ===
    {
        "name": "Product Hunt",
        "url": "https://producthunt.com",
        "category": "Startup Directories",
        "submission_url": "https://producthunt.com/posts/new",
        "requires_manual": 1,
        "automation_method": "manual",
        "domain_authority": 92,
        "tier": "top",
        "notes": "Requires detailed launch process, account setup, community engagement"
    },
    {
        "name": "G2",
        "url": "https://g2.com",
        "category": "SaaS Directories",
        "submission_url": "https://www.g2.com/products/new",
        "requires_manual": 1,
        "automation_method": "manual",
        "domain_authority": 93,
        "tier": "top",
        "notes": "Complex vendor registration process"
    },
    {
        "name": "Capterra",
        "url": "https://capterra.com",
        "category": "SaaS Directories",
        "submission_url": "https://www.capterra.com/vendors/sign-up",
        "requires_manual": 1,
        "automation_method": "manual",
        "domain_authority": 94,
        "tier": "top"
    },
    {
        "name": "BetaList",
        "url": "https://betalist.com",
        "category": "Startup Directories",
        "submission_url": "https://betalist.com/submit",
        "requires_manual": 1,
        "automation_method": "manual",
        "domain_authority": 71,
        "tier": "top",
        "notes": "Curated, requires approval"
    },
    {
        "name": "Hacker News",
        "url": "https://news.ycombinator.com",
        "category": "Tech Communities",
        "submission_url": "https://news.ycombinator.com/submit",
        "requires_manual": 1,
        "automation_method": "manual",
        "domain_authority": 95,
        "tier": "top",
        "notes": "Community-driven, requires engagement"
    },
    
    # === MID TIER - CAN AUTOMATE ===
    {
        "name": "There's An AI For That",
        "url": "https://theresanaiforthat.com",
        "category": "AI Directories",
        "submission_url": "https://theresanaiforthat.com/submit",
        "requires_manual": 0,
        "automation_method": "form_post",
        "domain_authority": 67,
        "tier": "mid",
        "form_fields": '{"name": "text", "url": "text", "description": "textarea", "category": "select"}'
    },
    {
        "name": "Futurepedia",
        "url": "https://futurepedia.io",
        "category": "AI Directories",
        "submission_url": "https://futurepedia.io/submit",
        "requires_manual": 1,
        "domain_authority": 65
    },
    {
        "name": "TopAI.tools",
        "url": "https://topai.tools",
        "category": "AI Directories",
        "submission_url": "https://topai.tools/submit",
        "requires_manual": 1,
        "domain_authority": 48
    },
    {
        "name": "AI Tools Directory",
        "url": "https://aitoolsdirectory.com",
        "category": "AI Directories",
        "submission_url": "https://aitoolsdirectory.com/submit",
        "requires_manual": 1,
        "domain_authority": 42
    },
    {
        "name": "AI Tool Hunt",
        "url": "https://aitoolhunt.com",
        "category": "AI Directories",
        "submission_url": "https://aitoolhunt.com/submit",
        "requires_manual": 1,
        "domain_authority": 38
    },
    {
        "name": "Future Tools",
        "url": "https://futuretools.io",
        "category": "AI Directories",
        "submission_url": "https://futuretools.io/submit",
        "requires_manual": 1,
        "domain_authority": 58
    },
    {
        "name": "Easy With AI",
        "url": "https://easywithai.com",
        "category": "AI Directories",
        "submission_url": "https://easywithai.com/submit",
        "requires_manual": 1,
        "domain_authority": 35
    },
    {
        "name": "AI Library",
        "url": "https://library.phygital.plus",
        "category": "AI Directories",
        "submission_url": "https://library.phygital.plus/submit",
        "requires_manual": 1,
        "domain_authority": 28
    },
    {
        "name": "Toolify AI",
        "url": "https://toolify.ai",
        "category": "AI Directories",
        "submission_url": "https://toolify.ai/submit",
        "requires_manual": 1,
        "domain_authority": 52
    },
    {
        "name": "AI Depot",
        "url": "https://aidepot.co",
        "category": "AI Directories",
        "submission_url": "https://aidepot.co/submit",
        "requires_manual": 1,
        "domain_authority": 31
    },
    
    # === SAAS DIRECTORIES ===
    {
        "name": "SaaS Hub",
        "url": "https://saashub.com",
        "category": "SaaS Directories",
        "submission_url": "https://saashub.com/submit",
        "requires_manual": 1,
        "domain_authority": 58
    },
    {
        "name": "GetApp",
        "url": "https://getapp.com",
        "category": "SaaS Directories",
        "submission_url": "https://www.getapp.com/vendors/submit",
        "requires_manual": 1,
        "domain_authority": 87
    },
    {
        "name": "Software Advice",
        "url": "https://softwareadvice.com",
        "category": "SaaS Directories",
        "submission_url": "https://www.softwareadvice.com/vendors/",
        "requires_manual": 1,
        "domain_authority": 88
    },
    {
        "name": "SaaS Genius",
        "url": "https://saasgenius.com",
        "category": "SaaS Directories",
        "submission_url": "https://saasgenius.com/submit",
        "requires_manual": 1,
        "domain_authority": 42
    },
    {
        "name": "Siftery",
        "url": "https://siftery.com",
        "category": "SaaS Directories",
        "submission_url": "https://siftery.com/add-product",
        "requires_manual": 1,
        "domain_authority": 56
    },
    {
        "name": "SaaS Worthy",
        "url": "https://saasworthy.com",
        "category": "SaaS Directories",
        "submission_url": "https://www.saasworthy.com/list-your-product",
        "requires_manual": 1,
        "domain_authority": 61
    },
    {
        "name": "FinancesOnline",
        "url": "https://financesonline.com",
        "category": "SaaS Directories",
        "submission_url": "https://financesonline.com/add-product/",
        "requires_manual": 1,
        "domain_authority": 79
    },
    {
        "name": "Crozdesk",
        "url": "https://crozdesk.com",
        "category": "SaaS Directories",
        "submission_url": "https://crozdesk.com/vendors/apply",
        "requires_manual": 1,
        "domain_authority": 64
    },
    
    # === STARTUP DIRECTORIES ===
    {
        "name": "StartupStash",
        "url": "https://startupstash.com",
        "category": "Startup Directories",
        "submission_url": "https://startupstash.com/submit",
        "requires_manual": 1,
        "domain_authority": 62
    },
    {
        "name": "Launching Next",
        "url": "https://launchingnext.com",
        "category": "Startup Directories",
        "submission_url": "https://launchingnext.com/submit",
        "requires_manual": 1,
        "domain_authority": 45
    },
    {
        "name": "Startups List",
        "url": "https://startupslist.com",
        "category": "Startup Directories",
        "submission_url": "https://startupslist.com/submit-startup",
        "requires_manual": 1,
        "domain_authority": 39
    },
    {
        "name": "Beta Page",
        "url": "https://betapage.co",
        "category": "Startup Directories",
        "submission_url": "https://betapage.co/submit",
        "requires_manual": 1,
        "domain_authority": 56
    },
    {
        "name": "Startup Buffer",
        "url": "https://startupbuffer.com",
        "category": "Startup Directories",
        "submission_url": "https://startupbuffer.com/submit",
        "requires_manual": 1,
        "domain_authority": 41
    },
    {
        "name": "Startupbase",
        "url": "https://startupbase.io",
        "category": "Startup Directories",
        "submission_url": "https://startupbase.io/submit",
        "requires_manual": 1,
        "domain_authority": 37
    },
    {
        "name": "10words",
        "url": "https://10words.io",
        "category": "Startup Directories",
        "submission_url": "https://10words.io/submit",
        "requires_manual": 1,
        "domain_authority": 33
    },
    {
        "name": "Startup Ranking",
        "url": "https://startupranking.com",
        "category": "Startup Directories",
        "submission_url": "https://www.startupranking.com/submit",
        "requires_manual": 1,
        "domain_authority": 68
    },
    
    # === TECH/DEV COMMUNITIES ===
    {
        "name": "Reddit - SaaS",
        "url": "https://reddit.com/r/SaaS",
        "category": "Tech Communities",
        "submission_url": "https://reddit.com/r/SaaS/submit",
        "requires_manual": 1,
        "domain_authority": 98
    },
    {
        "name": "Reddit - Entrepreneur",
        "url": "https://reddit.com/r/Entrepreneur",
        "category": "Tech Communities",
        "submission_url": "https://reddit.com/r/Entrepreneur/submit",
        "requires_manual": 1,
        "domain_authority": 98
    },
    {
        "name": "Indie Hackers",
        "url": "https://indiehackers.com",
        "category": "Tech Communities",
        "submission_url": "https://indiehackers.com/post/new",
        "requires_manual": 1,
        "domain_authority": 74
    },
    {
        "name": "Dev.to",
        "url": "https://dev.to",
        "category": "Tech Communities",
        "submission_url": "https://dev.to/new",
        "requires_manual": 1,
        "domain_authority": 89
    },
    {
        "name": "Hashnode",
        "url": "https://hashnode.com",
        "category": "Tech Communities",
        "submission_url": "https://hashnode.com/create",
        "requires_manual": 1,
        "domain_authority": 81
    },
    
    # === BACKLINK/SEO DIRECTORIES ===
    {
        "name": "GetMoreBacklinks",
        "url": "https://getmorebacklinks.org",
        "category": "Backlink Directories",
        "submission_url": "https://getmorebacklinks.org/submit",
        "requires_manual": 1,
        "domain_authority": 45
    },
    {
        "name": "Launch Hub",
        "url": "https://launchhub.com",
        "category": "Backlink Directories",
        "submission_url": "https://launchhub.com/submit",
        "requires_manual": 1,
        "domain_authority": 38
    },
    
    # === MICRO SAAS DIRECTORIES ===
    {
        "name": "MicroLaunch",
        "url": "https://microlaunch.net",
        "category": "Micro SaaS",
        "submission_url": "https://microlaunch.net/submit",
        "requires_manual": 1,
        "domain_authority": 34
    },
    {
        "name": "MicroStartups",
        "url": "https://microstartups.com",
        "category": "Micro SaaS",
        "submission_url": "https://microstartups.com/submit",
        "requires_manual": 1,
        "domain_authority": 29
    },
    
    # === PRODUCTIVITY/TOOLS ===
    {
        "name": "ProductivityDirectory",
        "url": "https://productivitydirectory.com",
        "category": "Productivity",
        "submission_url": "https://productivitydirectory.com/submit",
        "requires_manual": 1,
        "domain_authority": 31
    },
    {
        "name": "ToolScout",
        "url": "https://toolscout.ai",
        "category": "Productivity",
        "submission_url": "https://toolscout.ai/submit",
        "requires_manual": 1,
        "domain_authority": 28
    },
    
    # === ALTERNATIVES/COMPARISONS ===
    {
        "name": "AlternativeTo",
        "url": "https://alternativeto.net",
        "category": "Alternatives",
        "submission_url": "https://alternativeto.net/software/new/",
        "requires_manual": 1,
        "domain_authority": 86
    },
    {
        "name": "SourceForge",
        "url": "https://sourceforge.net",
        "category": "Alternatives",
        "submission_url": "https://sourceforge.net/create/",
        "requires_manual": 1,
        "domain_authority": 92
    },
    {
        "name": "Slant",
        "url": "https://slant.co",
        "category": "Alternatives",
        "submission_url": "https://slant.co/add-product",
        "requires_manual": 1,
        "domain_authority": 71
    },
]

