"""
MQTT client configuration and setup for ESP32 device communication
"""
import asyncio
from typing import Optional, Dict, Any
from fastapi_mqtt import FastMQTT, MQTTConfig
import logging

from app.config import get_settings

logger = logging.getLogger(__name__)

# MQTT Configuration
settings = get_settings()

mqtt_config = MQTTConfig(
    host=settings.mqtt_host,
    port=settings.mqtt_port,
    username=settings.mqtt_username,
    password=settings.mqtt_password,
    keepalive=settings.mqtt_keepalive,
    ssl=settings.mqtt_use_ssl
)

# Global MQTT client instance
mqtt_client: Optional[FastMQTT] = None

def get_mqtt_client() -> FastMQTT:
    """Get the global MQTT client instance"""
    global mqtt_client
    if mqtt_client is None:
        mqtt_client = FastMQTT(config=mqtt_config)
    return mqtt_client

async def publish_to_device(device_id: str, topic: str, payload: Dict[str, Any]) -> bool:
    """
    Publish a message to a specific ESP32 device
    
    Args:
        device_id: ESP32 device identifier
        topic: MQTT topic suffix (will be prefixed with device_id)
        payload: Message payload
        
    Returns:
        bool: True if message was published successfully
    """
    try:
        client = get_mqtt_client()
        full_topic = f"esp32/{device_id}/{topic}"
        
        await client.publish(full_topic, payload)
        logger.info(f"Published message to {full_topic}: {payload}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to publish to {device_id}/{topic}: {e}")
        return False

async def subscribe_to_device(device_id: str, topic: str) -> bool:
    """
    Subscribe to messages from a specific ESP32 device
    
    Args:
        device_id: ESP32 device identifier  
        topic: MQTT topic suffix
        
    Returns:
        bool: True if subscription was successful
    """
    try:
        client = get_mqtt_client()
        full_topic = f"esp32/{device_id}/{topic}"
        
        await client.subscribe(full_topic)
        logger.info(f"Subscribed to {full_topic}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to subscribe to {device_id}/{topic}: {e}")
        return False