"""
Data collection and sensor data management endpoints
Handles ESP32 sensor data storage and retrieval
"""
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query, Path
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc, func

from app.database import get_db_session
from app.models.sensor_data import SensorData
from app.models.device import Device
from app.schemas.sensor_data import (
    SensorDataCreate,
    SensorDataResponse,
    SensorDataBatch,
    SensorDataQuery
)
from app.utils.logger import get_logger

router = APIRouter()
logger = get_logger("api.data")

@router.post("/", response_model=SensorDataResponse)
async def create_sensor_data(
    data: SensorDataCreate,
    db: AsyncSession = Depends(get_db_session)
):
    """
    Create a new sensor data entry
    
    Args:
        data: Sensor data to create
        db: Database session
        
    Returns:
        Created sensor data
    """
    try:
        # Verify device exists
        device_query = select(Device).where(Device.id == data.device_id)
        device_result = await db.execute(device_query)
        device = device_result.scalar_one_or_none()
        
        if not device:
            raise HTTPException(status_code=404, detail="Device not found")
        
        # Create sensor data entry
        sensor_data = SensorData(
            device_id=data.device_id,
            sensor_type=data.sensor_type,
            value=data.value,
            unit=data.unit,
            metadata=data.metadata,
            timestamp=data.timestamp or datetime.utcnow()
        )
        
        db.add(sensor_data)
        await db.commit()
        await db.refresh(sensor_data)
        
        logger.info(f"Created sensor data entry for device {data.device_id}")
        return sensor_data
        
    except Exception as e:
        logger.error(f"Failed to create sensor data: {e}")
        await db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create sensor data")

@router.post("/batch", response_model=List[SensorDataResponse])
async def create_sensor_data_batch(
    batch: SensorDataBatch,
    db: AsyncSession = Depends(get_db_session)
):
    """
    Create multiple sensor data entries in batch
    
    Args:
        batch: Batch of sensor data to create
        db: Database session
        
    Returns:
        List of created sensor data entries
    """
    try:
        # Verify device exists
        device_query = select(Device).where(Device.id == batch.device_id)
        device_result = await db.execute(device_query)
        device = device_result.scalar_one_or_none()
        
        if not device:
            raise HTTPException(status_code=404, detail="Device not found")
        
        # Create sensor data entries
        sensor_data_entries = []
        for data_point in batch.data:
            sensor_data = SensorData(
                device_id=batch.device_id,
                sensor_type=data_point.sensor_type,
                value=data_point.value,
                unit=data_point.unit,
                metadata=data_point.metadata,
                timestamp=data_point.timestamp or datetime.utcnow()
            )
            sensor_data_entries.append(sensor_data)
        
        db.add_all(sensor_data_entries)
        await db.commit()
        
        # Refresh all entries to get IDs
        for entry in sensor_data_entries:
            await db.refresh(entry)
        
        logger.info(f"Created {len(sensor_data_entries)} sensor data entries for device {batch.device_id}")
        return sensor_data_entries
        
    except Exception as e:
        logger.error(f"Failed to create sensor data batch: {e}")
        await db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create sensor data batch")

@router.get("/device/{device_id}", response_model=List[SensorDataResponse])
async def get_device_data(
    device_id: str = Path(..., description="Device ID"),
    sensor_type: Optional[str] = Query(None, description="Filter by sensor type"),
    start_time: Optional[datetime] = Query(None, description="Start time filter"),
    end_time: Optional[datetime] = Query(None, description="End time filter"),
    limit: int = Query(100, ge=1, le=1000, description="Maximum number of records"),
    offset: int = Query(0, ge=0, description="Number of records to skip"),
    db: AsyncSession = Depends(get_db_session)
):
    """
    Get sensor data for a specific device
    
    Args:
        device_id: Device identifier
        sensor_type: Optional sensor type filter
        start_time: Optional start time filter
        end_time: Optional end time filter
        limit: Maximum number of records to return
        offset: Number of records to skip
        db: Database session
        
    Returns:
        List of sensor data entries
    """
    try:
        # Build query
        query = select(SensorData).where(SensorData.device_id == device_id)
        
        # Apply filters
        if sensor_type:
            query = query.where(SensorData.sensor_type == sensor_type)
        
        if start_time:
            query = query.where(SensorData.timestamp >= start_time)
        
        if end_time:
            query = query.where(SensorData.timestamp <= end_time)
        
        # Add ordering, limit, and offset
        query = query.order_by(desc(SensorData.timestamp)).limit(limit).offset(offset)
        
        # Execute query
        result = await db.execute(query)
        sensor_data = result.scalars().all()
        
        logger.info(f"Retrieved {len(sensor_data)} sensor data entries for device {device_id}")
        return sensor_data
        
    except Exception as e:
        logger.error(f"Failed to retrieve sensor data: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve sensor data")

@router.get("/latest/{device_id}", response_model=Dict[str, SensorDataResponse])
async def get_latest_data(
    device_id: str = Path(..., description="Device ID"),
    db: AsyncSession = Depends(get_db_session)
):
    """
    Get the latest sensor data for each sensor type of a device
    
    Args:
        device_id: Device identifier
        db: Database session
        
    Returns:
        Dictionary mapping sensor types to their latest data
    """
    try:
        # Get latest data for each sensor type
        subquery = (
            select(
                SensorData.sensor_type,
                func.max(SensorData.timestamp).label("max_timestamp")
            )
            .where(SensorData.device_id == device_id)
            .group_by(SensorData.sensor_type)
            .subquery()
        )
        
        query = (
            select(SensorData)
            .join(
                subquery,
                and_(
                    SensorData.sensor_type == subquery.c.sensor_type,
                    SensorData.timestamp == subquery.c.max_timestamp,
                    SensorData.device_id == device_id
                )
            )
        )
        
        result = await db.execute(query)
        sensor_data = result.scalars().all()
        
        # Convert to dictionary
        latest_data = {data.sensor_type: data for data in sensor_data}
        
        logger.info(f"Retrieved latest data for {len(latest_data)} sensor types for device {device_id}")
        return latest_data
        
    except Exception as e:
        logger.error(f"Failed to retrieve latest sensor data: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve latest sensor data")

@router.delete("/device/{device_id}")
async def delete_device_data(
    device_id: str = Path(..., description="Device ID"),
    older_than: Optional[datetime] = Query(None, description="Delete data older than this timestamp"),
    sensor_type: Optional[str] = Query(None, description="Delete only specific sensor type"),
    db: AsyncSession = Depends(get_db_session)
):
    """
    Delete sensor data for a device
    
    Args:
        device_id: Device identifier
        older_than: Optional timestamp to delete only old data
        sensor_type: Optional sensor type filter
        db: Database session
        
    Returns:
        Number of deleted records
    """
    try:
        # Build delete query
        query = select(SensorData).where(SensorData.device_id == device_id)
        
        if older_than:
            query = query.where(SensorData.timestamp < older_than)
        
        if sensor_type:
            query = query.where(SensorData.sensor_type == sensor_type)
        
        # Get records to delete (for counting)
        result = await db.execute(query)
        records_to_delete = result.scalars().all()
        
        # Delete records
        for record in records_to_delete:
            await db.delete(record)
        
        await db.commit()
        
        count = len(records_to_delete)
        logger.info(f"Deleted {count} sensor data records for device {device_id}")
        
        return {"deleted_count": count}
        
    except Exception as e:
        logger.error(f"Failed to delete sensor data: {e}")
        await db.rollback()
        raise HTTPException(status_code=500, detail="Failed to delete sensor data")

@router.get("/summary/{device_id}")
async def get_data_summary(
    device_id: str = Path(..., description="Device ID"),
    db: AsyncSession = Depends(get_db_session)
):
    """
    Get summary statistics for device sensor data
    
    Args:
        device_id: Device identifier
        db: Database session
        
    Returns:
        Summary statistics
    """
    try:
        # Get total count
        count_query = select(func.count(SensorData.id)).where(SensorData.device_id == device_id)
        count_result = await db.execute(count_query)
        total_count = count_result.scalar()
        
        # Get sensor type counts
        type_query = (
            select(SensorData.sensor_type, func.count(SensorData.id))
            .where(SensorData.device_id == device_id)
            .group_by(SensorData.sensor_type)
        )
        type_result = await db.execute(type_query)
        sensor_type_counts = dict(type_result.all())
        
        # Get time range
        time_query = (
            select(
                func.min(SensorData.timestamp),
                func.max(SensorData.timestamp)
            )
            .where(SensorData.device_id == device_id)
        )
        time_result = await db.execute(time_query)
        min_time, max_time = time_result.one_or_none() or (None, None)
        
        summary = {
            "device_id": device_id,
            "total_records": total_count,
            "sensor_types": sensor_type_counts,
            "earliest_record": min_time,
            "latest_record": max_time
        }
        
        logger.info(f"Generated data summary for device {device_id}")
        return summary
        
    except Exception as e:
        logger.error(f"Failed to generate data summary: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate data summary")