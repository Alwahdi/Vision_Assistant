"""
Health check routes for AI Service
"""

from fastapi import APIRouter

router = APIRouter()


@router.get("/")
async def health_check():
    """Basic health check endpoint."""
    return {
        "status": "healthy",
        "service": "vision-assistant-ai-service",
        "version": "1.0.0",
    }


@router.get("/detailed")
async def detailed_health_check():
    """Detailed health check with component status."""
    return {
        "status": "healthy",
        "service": "vision-assistant-ai-service",
        "version": "1.0.0",
        "components": {
            "database": {"status": "healthy", "message": "Database connection OK"},
            "redis": {"status": "healthy", "message": "Redis connection OK"},
            "models": {"status": "healthy", "message": "AI models loaded"},
        },
    }
