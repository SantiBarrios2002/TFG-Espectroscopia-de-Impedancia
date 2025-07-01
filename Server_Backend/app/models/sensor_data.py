"""
Database model for sensor data from AFEs
"""
from sqlalchemy import Column, Integer, String, DateTime, Float, JSON, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class SensorData(Base):
    """Sensor data from AFE measurements"""
    __tablename__ = "sensor_data"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String, ForeignKey("devices.device_id"), nullable=False)

    # Measurement data
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    measurement_type = Column(String, nullable=False)  # e.g., "impedance", "voltage"
    channel = Column(Integer, nullable=False)  # AFE channel number
    value = Column(Float, nullable=False)  # Primary measurement value
    unit = Column(String, nullable=False)  # e.g., "ohm", "volt"

    # Additional data
    raw_data = Column(JSON)  # Raw ADC values, metadata
    frequency = Column(Float)  # For impedance measurements
    phase = Column(Float)  # Phase information
    quality_score = Column(Float)  # Signal quality indicator

    # Metadata
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationship
    device = relationship("Device", back_populates="sensor_data")

    def __repr__(self):
        return f"<SensorData(device_id={self.device_id}, type={self.measurement_type}, value={self.value})>"

# Add back reference to Device model
from app.models.device import Device
Device.sensor_data = relationship("SensorData", back_populates="device")
