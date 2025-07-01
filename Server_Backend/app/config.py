"""
Configuration management for IoT Server
Environment-based settings using Pydantic
"""
from functools import lru_cache
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    """Application settings"""

    # Environment
    environment: str = "development"
    debug: bool = True

    # Database
    database_url: str = "postgresql+asyncpg://iot_user:iot_pass@localhost:5432/iot_server"
    database_echo: bool = False

    # JWT Authentication
    jwt_secret_key: str = "your-super-secret-jwt-key-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 7

    # MQTT Configuration
    mqtt_host: str = "localhost"
    mqtt_port: int = 1883
    mqtt_username: Optional[str] = None
    mqtt_password: Optional[str] = None
    mqtt_keepalive: int = 60
    mqtt_use_ssl: bool = False

    # Server Configuration
    server_host: str = "0.0.0.0"
    server_port: int = 8000
    server_workers: int = 1

    # Logging
    log_level: str = "INFO"
    log_format: str = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

    # MATLAB Integration
    matlab_data_batch_size: int = 1000
    matlab_request_timeout: int = 30

    # ESP32 Device Settings
    device_heartbeat_interval: int = 30  # seconds
    device_timeout: int = 300  # seconds
    max_devices: int = 100

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()
