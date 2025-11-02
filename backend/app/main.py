from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import logging
import os
from pathlib import Path

from .config import get_settings
from .api import auth, keyword_chat, project, backlinks

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="KeywordsChat API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

settings = get_settings()

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routers
app.include_router(auth.router, prefix=settings.API_V1_PREFIX)
app.include_router(keyword_chat.router, prefix=settings.API_V1_PREFIX)
app.include_router(project.router, prefix=settings.API_V1_PREFIX)
app.include_router(backlinks.router)

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

# Serve landing page at root
landing_dir = Path(__file__).parent.parent.parent / "landing"

@app.get("/")
async def landing_page():
    """Serve SEO-optimized landing page"""
    landing_file = landing_dir / "index.html"
    if landing_file.exists():
        return FileResponse(landing_file)
    return {"status": "KeywordsChat API", "version": "1.0.0"}

@app.get("/robots.txt")
async def robots():
    """Serve robots.txt for SEO"""
    robots_file = landing_dir / "robots.txt"
    if robots_file.exists():
        return FileResponse(robots_file, media_type="text/plain")
    return FileResponse(landing_dir / "robots.txt")

@app.get("/sitemap.xml")
async def sitemap():
    """Serve sitemap.xml for SEO"""
    sitemap_file = landing_dir / "sitemap.xml"
    if sitemap_file.exists():
        return FileResponse(sitemap_file, media_type="application/xml")
    return FileResponse(landing_dir / "sitemap.xml")

# App route disabled - waitlist mode
@app.get("/app")
@app.get("/app/{full_path:path}")
async def app_coming_soon(full_path: str = ""):
    """App is in waitlist mode"""
        return {
        "status": "Coming Soon",
        "message": "Keywords.chat is currently in private beta. Join the waitlist at https://keywords.chat"
    }

# NOTE: To enable the app, uncomment the code below:
# frontend_build_dir = Path(__file__).parent.parent.parent / "frontend" / "build" / "web"
# 
# if frontend_build_dir.exists():
#     # Mount static files (for assets like JS, CSS, images)
#     app.mount("/app/assets", StaticFiles(directory=str(frontend_build_dir / "assets")), name="assets")
#     app.mount("/app/canvaskit", StaticFiles(directory=str(frontend_build_dir / "canvaskit")), name="canvaskit")
#     
#     # Serve Flutter app at /app route
#     @app.get("/app/{full_path:path}")
#     async def serve_app(full_path: str = ""):
#         # Serve static files if they exist
#         if full_path:
#             file_path = frontend_build_dir / full_path
#             if file_path.is_file():
#                 return FileResponse(file_path)
#         
#         # Otherwise serve index.html (for SPA routing)
#         return FileResponse(frontend_build_dir / "index.html")
# else:
#     logger.warning(f"Frontend build directory not found: {frontend_build_dir}")
#     logger.warning("Run 'task build' to build the Flutter web app")

