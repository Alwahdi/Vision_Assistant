#!/usr/bin/env python3

"""
Vision Assistant - AI Service
Main entry point for the AI processing service
"""

import asyncio
import os
import time
from contextlib import asynccontextmanager
from typing import AsyncGenerator

import uvicorn
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import structlog
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

from app.api.routes import api_router
from app.core.config import settings
from app.core.logging import setup_logging
from app.db.session import engine
from app.db.base import Base

# Setup structured logging
setup_logging()
logger = structlog.get_logger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter(
    'ai_service_requests_total',
    'Total number of requests to AI service',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'ai_service_request_duration_seconds',
    'Request latency in seconds',
    ['method', 'endpoint']
)

AI_PROCESSING_TIME = Histogram(
    'ai_processing_duration_seconds',
    'AI processing time in seconds',
    ['operation']
)

# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """
    Lifespan context manager for FastAPI application.
    Handles startup and shutdown events.
    """
    logger.info("Starting Vision Assistant AI Service")

    # Create database tables
    Base.metadata.create_all(bind=engine)

    logger.info("Database tables created/verified")

    yield

    logger.info("Shutting down Vision Assistant AI Service")

# Create FastAPI application
app = FastAPI(
    title="Vision Assistant AI Service",
    description="AI-powered processing service for Vision Assistant platform",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

# Set up CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Metrics middleware
@app.middleware("http")
async def add_metrics_middleware(request: Request, call_next):
    start_time = time.time()

    response = await call_next(request)

    # Record metrics
    process_time = time.time() - start_time
    REQUEST_LATENCY.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(process_time)

    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=str(response.status_code)
    ).inc()

    return response

# Metrics endpoint
@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint."""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )

# Include API routes
app.include_router(api_router, prefix="/api/v1")

# Health check endpoint
@app.get("/health")
async def health_check():
    """Basic health check endpoint."""
    return {
        "status": "healthy",
        "service": "vision-assistant-ai-service",
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT,
    }

# Readiness probe
@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint."""
    return {
        "status": "ready",
        "service": "vision-assistant-ai-service",
    }

# Liveness probe
@app.get("/live")
async def liveness_check():
    """Liveness check endpoint."""
    return {
        "status": "alive",
        "service": "vision-assistant-ai-service",
    }

# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler for unhandled exceptions."""
    logger.error("Unhandled exception", exc_info=exc)
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal Server Error",
            "message": "An unexpected error occurred",
            "timestamp": None,  # Will be set by middleware
        },
    )

if __name__ == "__main__":
    # Development server
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8000)),
        reload=settings.ENVIRONMENT == "development",
        log_level="info",
    )