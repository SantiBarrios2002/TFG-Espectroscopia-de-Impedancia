"""
MATLAB-specific API endpoints for data retrieval and commands
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc
from typing import List, Optional
from datetime import datetime, timedelta
import logging

from app.database import get_db
from app.models.sensor_data import SensorData
from app.models.device import Device
from app.schemas.matlab import MatlabDataRequest, MatlabCommandRequest
from app.auth.jwt_handler import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/datasets")
async def list_datasets(
    device_id: Optional[str] = None,
    measurement_type: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    skip: int = 0,
    limit: int = 1000,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """List available datasets for MATLAB download"""

    # Build query filters
    filters = []

    if device_id:
        filters.append(SensorData.device_id == device_id)

    if measurement_type:
        filters.append(SensorData.measurement_type == measurement_type)

    if start_date:
        filters.append(SensorData.timestamp >= start_date)

    if end_date:
        filters.append(SensorData.timestamp <= end_date)

    # Execute query
    query = select(SensorData).where(and_(*filters)) if filters else select(SensorData)
    query = query.order_by(desc(SensorData.timestamp)).offset(skip).limit(limit)

    result = await db.execute(query)
    datasets = result.scalars().all()

    # Format for MATLAB consumption
    matlab_data = []
    for data in datasets:
        matlab_data.append({
            "id": data.id,
            "device_id": data.device_id,
            "timestamp": data.timestamp.isoformat(),
            "measurement_type": data.measurement_type,
            "channel": data.channel,
            "value": data.value,
            "unit": data.unit,
            "frequency": data.frequency,
            "phase": data.phase,
            "quality_score": data.quality_score,
            "raw_data": data.raw_data
        })

    return {
        "datasets": matlab_data,
        "total_count": len(matlab_data),
        "filters_applied": {
            "device_id": device_id,
            "measurement_type": measurement_type,
            "start_date": start_date,
            "end_date": end_date
        }
    }

@router.post("/download")
async def download_data(
    request: MatlabDataRequest,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Download sensor data in MATLAB-compatible format"""

    # Build comprehensive query
    filters = [SensorData.device_id == request.device_id]

    if request.measurement_types:
        filters.append(SensorData.measurement_type.in_(request.measurement_types))

    if request.channels:
        filters.append(SensorData.channel.in_(request.channels))

    if request.start_time:
        filters.append(SensorData.timestamp >= request.start_time)

    if request.end_time:
        filters.append(SensorData.timestamp <= request.end_time)

    # Execute query
    query = select(SensorData).where(and_(*filters)).order_by(SensorData.timestamp)
    result = await db.execute(query)
    data_points = result.scalars().all()

    if not data_points:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No data found for the specified criteria"
        )

    # Format data for MATLAB
    matlab_dataset = {
        "metadata": {
            "device_id": request.device_id,
            "download_time": datetime.utcnow().isoformat(),
            "total_points": len(data_points),
            "time_range": {
                "start": data_points[0].timestamp.isoformat(),
                "end": data_points[-1].timestamp.isoformat()
            }
        },
        "data": []
    }

    for point in data_points:
        matlab_dataset["data"].append({
            "timestamp": point.timestamp.isoformat(),
            "measurement_type": point.measurement_type,
            "channel": point.channel,
            "value": point.value,
            "unit": point.unit,
            "frequency": point.frequency,
            "phase": point.phase,
            "quality_score": point.quality_score,
            "raw_data": point.raw_data
        })

    logger.info(f"Data download: {len(data_points)} points for device {request.device_id}")
    return matlab_dataset

@router.post("/command")
async def send_command(
    command: MatlabCommandRequest,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Send command from MATLAB to ESP32 device via MQTT"""
    from app.mqtt.client import mqtt_client

    # Verify device exists
    result = await db.execute(
        select(Device).where(Device.device_id == command.device_id)
    )
    device = result.scalar_one_or_none()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device {command.device_id} not found"
        )

    if not device.is_online:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Device {command.device_id} is offline"
        )

    # Send command via MQTT
    topic = f"devices/{command.device_id}/commands"
    message = {
        "command": command.command,
        "parameters": command.parameters,
        "timestamp": datetime.utcnow().isoformat(),
        "source": "matlab"
    }

    try:
        # Publish MQTT message
        await mqtt_client.publish(topic, message)

        logger.info(f"Command sent to {command.device_id}: {command.command}")
        return {
            "status": "command_sent",
            "device_id": command.device_id,
            "command": command.command,
            "topic": topic
        }

    except Exception as e:
        logger.error(f"Failed to send command: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send command to device"
        )
