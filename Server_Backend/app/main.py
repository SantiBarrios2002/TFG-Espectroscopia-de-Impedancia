"""
FastAPI IoT Server - Main Application Entry Point
Intermediary server between MATLAB frontend and ESP32 devices
"""
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from app.config import get_settings
from app.database import init_db
from app.mqtt.client import get_mqtt_client
from app.api import devices, data, matlab
from app.auth import auth_routes
from app.utils.logger import setup_logging

# Setup logging
setup_logging()
logger = logging.getLogger(__name__)

# FastAPI lifespan management
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    logger.info("Starting IoT Server...")

    # Initialize database
    await init_db()

    # Initialize MQTT client
    mqtt_client = get_mqtt_client()
    app.state.mqtt = mqtt_client
    logger.info("MQTT client initialized")

    yield

    # Cleanup
    logger.info("IoT Server shutdown complete")

# Initialize FastAPI app
app = FastAPI(
    title="IoT MATLAB-ESP32 Server",
    description="Intermediary server for MATLAB frontend and ESP32 communication",
    version="1.0.0",
    lifespan=lifespan
)

# MQTT client will be initialized in lifespan

# CORS middleware for MATLAB client access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routers
app.include_router(auth_routes.router, prefix="/auth", tags=["authentication"])
app.include_router(devices.router, prefix="/devices", tags=["devices"])
app.include_router(data.router, prefix="/data", tags=["data"])
app.include_router(matlab.router, prefix="/matlab", tags=["matlab"])

@app.get("/", tags=["root"])
async def root():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "message": "IoT MATLAB-ESP32 Server is running",
        "version": "1.0.0"
    }

@app.get("/health", tags=["health"])
async def health_check():
    """Detailed health check"""
    settings = get_settings()
    return {
        "status": "healthy",
        "database": "connected",
        "mqtt": "connected",
        "environment": settings.environment
    }
