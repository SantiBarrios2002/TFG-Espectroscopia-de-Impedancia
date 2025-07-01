"""
Logging configuration for the IoT Server
"""
import logging
import logging.config
import sys
from typing import Dict, Any

from app.config import get_settings

def setup_logging() -> None:
    """
    Configure logging for the application
    """
    settings = get_settings()
    
    log_config: Dict[str, Any] = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "default": {
                "format": settings.log_format,
                "datefmt": "%Y-%m-%d %H:%M:%S",
            },
            "detailed": {
                "format": "%(asctime)s | %(name)s | %(levelname)s | %(filename)s:%(lineno)d | %(message)s",
                "datefmt": "%Y-%m-%d %H:%M:%S",
            },
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "level": settings.log_level,
                "formatter": "default",
                "stream": sys.stdout,
            },
            "file": {
                "class": "logging.FileHandler",
                "level": "INFO",
                "formatter": "detailed",
                "filename": "iot_server.log",
                "mode": "a",
            },
        },
        "loggers": {
            "app": {
                "level": settings.log_level,
                "handlers": ["console", "file"],
                "propagate": False,
            },
            "uvicorn": {
                "level": "INFO",
                "handlers": ["console"],
                "propagate": False,
            },
            "uvicorn.access": {
                "level": "INFO" if settings.debug else "WARNING",
                "handlers": ["console"],
                "propagate": False,
            },
            "sqlalchemy.engine": {
                "level": "INFO" if settings.database_echo else "WARNING",
                "handlers": ["console"],
                "propagate": False,
            },
        },
        "root": {
            "level": settings.log_level,
            "handlers": ["console"],
        },
    }
    
    # Apply logging configuration
    logging.config.dictConfig(log_config)
    
    # Log startup message
    logger = logging.getLogger("app.startup")
    logger.info(f"Logging configured - Level: {settings.log_level}, Environment: {settings.environment}")

def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance with the specified name
    
    Args:
        name: Logger name
        
    Returns:
        Logger instance
    """
    return logging.getLogger(f"app.{name}")