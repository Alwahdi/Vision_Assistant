"""
Core configuration for Vision Assistant AI Service
"""

import os
from typing import List, Optional

from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Application settings
    APP_NAME: str = Field(default="Vision Assistant AI Service")
    VERSION: str = Field(default="1.0.0")
    ENVIRONMENT: str = Field(default="development")
    DEBUG: bool = Field(default=False)

    # Server settings
    HOST: str = Field(default="0.0.0.0")
    PORT: int = Field(default=8000)

    # Database settings
    POSTGRES_HOST: str = Field(default="localhost")
    POSTGRES_PORT: int = Field(default=5432)
    POSTGRES_USER: str = Field(default="vision_user")
    POSTGRES_PASSWORD: str = Field(default="vision_password")
    POSTGRES_DB: str = Field(default="vision_assistant")

    @property
    def DATABASE_URL(self) -> str:
        """Database connection URL."""
        return (
            f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}"
            f"@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )

    # Redis settings
    REDIS_HOST: str = Field(default="localhost")
    REDIS_PORT: int = Field(default=6379)
    REDIS_PASSWORD: Optional[str] = Field(default=None)
    REDIS_DB: int = Field(default=0)

    @property
    def REDIS_URL(self) -> str:
        """Redis connection URL."""
        auth = f":{self.REDIS_PASSWORD}@" if self.REDIS_PASSWORD else ""
        return f"redis://{auth}{self.REDIS_HOST}:{self.REDIS_PORT}/{self.REDIS_DB}"

    # AI/ML settings
    AI_MODEL_CACHE_SIZE: str = Field(default="2gb")
    AI_PROCESSING_TIMEOUT: int = Field(default=300)
    AI_MAX_CONCURRENT_REQUESTS: int = Field(default=10)
    AI_MODEL_PATH: str = Field(default="./models")

    # External services
    API_GATEWAY_URL: str = Field(default="http://localhost:3000")

    # Logging
    LOG_LEVEL: str = Field(default="INFO")

    # Security
    SECRET_KEY: str = Field(default="development-secret-key-change-in-production")
    ALGORITHM: str = Field(default="HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=30)

    # CORS
    CORS_ORIGINS: List[str] = Field(default_factory=lambda: ["http://localhost:3000"])

    class Config:
        """Pydantic configuration."""
        env_file = ".env"
        case_sensitive = True


# Create global settings instance
settings = Settings()
