from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from .config import get_settings
import logging

logger = logging.getLogger(__name__)
settings = get_settings()

# Lazy initialization - don't create engine on import
_engine = None
_SessionLocal = None
Base = declarative_base()

def get_engine():
    """Get or create database engine (lazy initialization)"""
    global _engine
    if _engine is None:
        logger.info(f"Creating database engine for: {settings.DATABASE_URL[:20]}...")
        _engine = create_engine(settings.DATABASE_URL)
    return _engine

def get_session_local():
    """Get or create SessionLocal (lazy initialization)"""
    global _SessionLocal
    if _SessionLocal is None:
        _SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=get_engine())
    return _SessionLocal

def get_db():
    """Dependency for FastAPI endpoints that need database access"""
    SessionLocal = get_session_local()
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()






