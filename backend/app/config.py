from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    # LLM Provider API Keys
    OPENAI_API_KEY: str = "placeholder"  # Required for ChatGPT
    GEMINI_API_KEY: str = "placeholder"  # Optional for Gemini
    PERPLEXITY_API_KEY: str = "placeholder"  # Optional for Perplexity
    
    # Auth
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_MINUTES: int = 43200  # 30 days
    
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    
    # Database
    DATABASE_URL: str
    
    # Environment
    ENVIRONMENT: str = "development"
    API_V1_PREFIX: str = "/api/v1"
    
    # Feature Flags
    WAITLIST_MODE: bool = False
    
    class Config:
        env_file = ".env"
        case_sensitive = True

@lru_cache()
def get_settings() -> Settings:
    return Settings()

