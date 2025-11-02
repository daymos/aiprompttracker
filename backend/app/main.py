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

# Serve Flutter web app static files
frontend_build_dir = Path(__file__).parent.parent.parent / "frontend" / "build" / "web"

if frontend_build_dir.exists():
    # Mount static files (for assets like JS, CSS, images)
    app.mount("/assets", StaticFiles(directory=str(frontend_build_dir / "assets")), name="assets")
    app.mount("/canvaskit", StaticFiles(directory=str(frontend_build_dir / "canvaskit")), name="canvaskit")
    
    # Serve index.html for all other routes (SPA routing)
    @app.get("/{full_path:path}")
    async def serve_frontend(full_path: str):
        # Don't interfere with API routes
        if full_path.startswith("api/") or full_path.startswith("docs") or full_path.startswith("redoc"):
            return {"error": "Not found"}
        
        # Serve static files if they exist
        file_path = frontend_build_dir / full_path
        if file_path.is_file():
            return FileResponse(file_path)
        
        # Otherwise serve index.html (for SPA routing)
        return FileResponse(frontend_build_dir / "index.html")
else:
    logger.warning(f"Frontend build directory not found: {frontend_build_dir}")
    logger.warning("Run 'task build-frontend' to build the Flutter web app")
    
    @app.get("/")
    async def root():
        return {
            "status": "KeywordsChat API", 
            "version": "1.0.0",
            "note": "Frontend not built. Run 'task build-frontend' to build it."
        }

