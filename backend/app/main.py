from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging

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

# Include routers
app.include_router(auth.router, prefix=settings.API_V1_PREFIX)
app.include_router(keyword_chat.router, prefix=settings.API_V1_PREFIX)
app.include_router(project.router, prefix=settings.API_V1_PREFIX)
app.include_router(backlinks.router)

@app.get("/")
async def root():
    return {"status": "KeywordsChat API", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

