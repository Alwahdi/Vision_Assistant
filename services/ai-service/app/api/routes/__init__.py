"""
API routes for Vision Assistant AI Service
"""

from fastapi import APIRouter

from .health import router as health_router
from .vision import router as vision_router

# Create main API router
api_router = APIRouter()

# Include sub-routers
api_router.include_router(health_router, prefix="/health", tags=["health"])
api_router.include_router(vision_router, prefix="/vision", tags=["vision"])
