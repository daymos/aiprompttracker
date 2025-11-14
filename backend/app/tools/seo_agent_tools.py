"""
Function calling tools for SEO Agent features
"""


# Tool definitions for LLM function calling
SEO_AGENT_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "connect_cms",
            "description": "Connect a CMS (WordPress, Webflow, etc.) to the project. Saves credentials and tests the connection. Use when user provides CMS credentials.",
            "parameters": {
                "type": "object",
                "properties": {
                    "project_id": {
                        "type": "string",
                        "description": "The project ID to connect the CMS to"
                    },
                    "cms_type": {
                        "type": "string",
                        "enum": ["wordpress", "webflow", "ghost"],
                        "description": "Type of CMS"
                    },
                    "cms_url": {
                        "type": "string",
                        "description": "Base URL of the CMS (e.g., 'https://example.com')"
                    },
                    "username": {
                        "type": "string",
                        "description": "CMS username"
                    },
                    "password": {
                        "type": "string",
                        "description": "CMS password or application password (for WordPress)"
                    }
                },
                "required": ["project_id", "cms_type", "cms_url", "username", "password"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "test_cms_connection",
            "description": "Test if the CMS connection is working. Use to verify credentials or check connection status.",
            "parameters": {
                "type": "object",
                "properties": {
                    "project_id": {
                        "type": "string",
                        "description": "The project ID"
                    }
                },
                "required": ["project_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "analyze_content_tone",
            "description": "Analyze the writing tone/style from existing CMS posts. Creates a tone profile to match in future content generation. Use when user wants AI to match their writing style.",
            "parameters": {
                "type": "object",
                "properties": {
                    "project_id": {
                        "type": "string",
                        "description": "The project ID"
                    },
                    "num_posts": {
                        "type": "integer",
                        "description": "Number of recent posts to analyze (default 5)",
                        "default": 5
                    }
                },
                "required": ["project_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "generate_content_outline",
            "description": "Generate a detailed article outline based on topic and keywords. First step of content creation. Use when user wants to create an article.",
            "parameters": {
                "type": "object",
                "properties": {
                    "project_id": {
                        "type": "string",
                        "description": "The project ID"
                    },
                    "topic": {
                        "type": "string",
                        "description": "Main topic/title for the article"
                    },
                    "target_keywords": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of keywords to target in the article"
                    },
                    "word_count_target": {
                        "type": "integer",
                        "description": "Target word count (default 1500)",
                        "default": 1500
                    }
                },
                "required": ["project_id", "topic", "target_keywords"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "generate_full_article",
            "description": "Generate complete article content from an outline. Use after outline is approved. Creates SEO-optimized HTML content ready for publishing.",
            "parameters": {
                "type": "object",
                "properties": {
                    "project_id": {
                        "type": "string",
                        "description": "The project ID"
                    },
                    "outline_id": {
                        "type": "string",
                        "description": "ID of the generated outline (from generate_content_outline)"
                    },
                    "modifications": {
                        "type": "string",
                        "description": "Optional modifications to the outline before generating (e.g., 'Add a section about pricing')"
                    }
                },
                "required": ["project_id", "outline_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "publish_content",
            "description": "Publish generated content to the CMS. Use after content is generated and approved by user.",
            "parameters": {
                "type": "object",
                "properties": {
                    "project_id": {
                        "type": "string",
                        "description": "The project ID"
                    },
                    "content_id": {
                        "type": "string",
                        "description": "ID of the generated content"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "publish", "pending"],
                        "description": "Publishing status: 'draft' (save without publishing), 'publish' (make live), 'pending' (pending review)",
                        "default": "draft"
                    },
                    "categories": {
                        "type": "array",
                        "items": {"type": "integer"},
                        "description": "Optional category IDs to assign"
                    }
                },
                "required": ["project_id", "content_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "list_content",
            "description": "List AI-generated and imported content for a project (drafts, scheduled, published articles). Use when user asks about their content, drafts, scheduled posts, or published articles.",
            "parameters": {
                "type": "object",
                "properties": {
                    "project_id": {
                        "type": "string",
                        "description": "The project ID"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "scheduled", "published"],
                        "description": "Filter by status (optional - returns all if not specified)"
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Number of articles to return (default 50)",
                        "default": 50
                    }
                },
                "required": ["project_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_content_details",
            "description": "Get full details of a specific article/content piece. Use when user wants to read, review, or edit a specific article.",
            "parameters": {
                "type": "object",
                "properties": {
                    "content_id": {
                        "type": "string",
                        "description": "The ID of the content piece"
                    }
                },
                "required": ["content_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "create_content",
            "description": "Create and save a new SEO-optimized article. Use when user wants to generate new content.",
            "parameters": {
                "type": "object",
                "properties": {
                    "project_id": {
                        "type": "string",
                        "description": "The project ID"
                    },
                    "title": {
                        "type": "string",
                        "description": "Article title"
                    },
                    "content": {
                        "type": "string",
                        "description": "Full article content (HTML or markdown)"
                    },
                    "excerpt": {
                        "type": "string",
                        "description": "Short excerpt/summary (optional)"
                    },
                    "target_keywords": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Array of target keywords (optional)"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "scheduled", "published"],
                        "description": "Content status (default 'draft')",
                        "default": "draft"
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata like tone, style, etc (optional)"
                    }
                },
                "required": ["project_id", "title", "content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "update_content",
            "description": "Update an existing article - change status, schedule publishing, or edit content. Use when user wants to publish, schedule, or update content.",
            "parameters": {
                "type": "object",
                "properties": {
                    "content_id": {
                        "type": "string",
                        "description": "The ID of the content to update"
                    },
                    "title": {
                        "type": "string",
                        "description": "Updated title (optional)"
                    },
                    "content": {
                        "type": "string",
                        "description": "Updated content body (optional)"
                    },
                    "excerpt": {
                        "type": "string",
                        "description": "Updated excerpt (optional)"
                    },
                    "target_keywords": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Updated keywords (optional)"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "scheduled", "published"],
                        "description": "New status (optional)"
                    },
                    "published_at": {
                        "type": "string",
                        "description": "Schedule date for publishing in ISO format (optional)"
                    },
                    "published_url": {
                        "type": "string",
                        "description": "URL where content is published (optional)"
                    }
                },
                "required": ["content_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_cms_categories",
            "description": "Get available categories from the connected CMS. Use when user wants to assign categories to content.",
            "parameters": {
                "type": "object",
                "properties": {
                    "project_id": {
                        "type": "string",
                        "description": "The project ID"
                    }
                },
                "required": ["project_id"]
            }
        }
    }
]


def get_seo_agent_tools():
    """Return SEO Agent tools list"""
    return SEO_AGENT_TOOLS

