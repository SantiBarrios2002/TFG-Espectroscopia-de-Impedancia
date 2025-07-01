"""
ESP32 Device management API endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
import logging

from app.database import get_db
from app.models.device import Device
from app.schemas.device import DeviceCreate, DeviceResponse, DeviceUpdate
from app.auth.jwt_handler import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/register", response_model=DeviceResponse)
async def register_device(
    device: DeviceCreate,
    db: AsyncSession = Depends(get_db)
):
    """Register a new ESP32 device"""
    try:
        # Check if device already exists
        result = await db.execute(
            select(Device).where(Device.device_id == device.device_id)
        )
        existing_device = result.scalar_one_or_none()

        if existing_device:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Device {device.device_id} already registered"
            )

        # Create new device
        db_device = Device(**device.dict())
        db.add(db_device)
        await db.commit()
        await db.refresh(db_device)

        logger.info(f"Device registered: {device.device_id}")
        return db_device

    except Exception as e:
        await db.rollback()
        logger.error(f"Error registering device: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to register device"
        )

@router.get("/", response_model=List[DeviceResponse])
async def list_devices(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """List all registered devices"""
    result = await db.execute(
        select(Device).offset(skip).limit(limit)
    )
    devices = result.scalars().all()
    return devices

@router.get("/{device_id}", response_model=DeviceResponse)
async def get_device(
    device_id: str,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Get device by ID"""
    result = await db.execute(
        select(Device).where(Device.device_id == device_id)
    )
    device = result.scalar_one_or_none()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device {device_id} not found"
        )

    return device

@router.put("/{device_id}", response_model=DeviceResponse)
async def update_device(
    device_id: str,
    device_update: DeviceUpdate,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """Update device configuration"""
    result = await db.execute(
        select(Device).where(Device.device_id == device_id)
    )
    device = result.scalar_one_or_none()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device {device_id} not found"
        )

    # Update device fields
    for field, value in device_update.dict(exclude_unset=True).items():
        setattr(device, field, value)

    await db.commit()
    await db.refresh(device)

    logger.info(f"Device updated: {device_id}")
    return device

@router.post("/{device_id}/heartbeat")
async def device_heartbeat(
    device_id: str,
    db: AsyncSession = Depends(get_db)
):
    """ESP32 device heartbeat endpoint"""
    from datetime import datetime

    result = await db.execute(
        select(Device).where(Device.device_id == device_id)
    )
    device = result.scalar_one_or_none()

    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device {device_id} not found"
        )

    # Update heartbeat and online status
    device.last_heartbeat = datetime.utcnow()
    device.is_online = True

    await db.commit()

    return {"status": "heartbeat_received", "device_id": device_id}
