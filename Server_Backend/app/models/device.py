"""
Database model for ESP32 devices
"""
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Float, JSON
from sqlalchemy.sql import func
from app.database import Base

class Device(Base):
    """ESP32 Device model"""
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    device_type = Column(String, default="ESP32")
    firmware_version = Column(String)
    ip_address = Column(String)
    mac_address = Column(String)

    # Status and health
    is_active = Column(Boolean, default=True)
    is_online = Column(Boolean, default=False)
    last_heartbeat = Column(DateTime(timezone=True))

    # Configuration
    sampling_rate = Column(Integer, default=1000)  # Hz
    channels_config = Column(JSON)  # AFE channel configuration

    # Metadata
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"<Device(device_id={self.device_id}, name={self.name})>"
