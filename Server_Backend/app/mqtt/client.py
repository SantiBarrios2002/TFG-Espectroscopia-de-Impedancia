"""
MQTT client configuration and setup for ESP32 device communication
"""
import asyncio
from typing import Optional, Dict, Any
import logging
import json

from app.config import get_settings

logger = logging.getLogger(__name__)

# Global MQTT client instance
mqtt_client: Optional['SimpleMQTTClient'] = None

class SimpleMQTTClient:
    """Simple MQTT client wrapper for development"""
    
    def __init__(self, config):
        self.config = config
        self.connected = False
        logger.info(f"MQTT client initialized for {config.get('host', 'localhost')}:{config.get('port', 1883)}")
    
    async def connect(self):
        """Connect to MQTT broker"""
        self.connected = True
        logger.info("MQTT client connected (mock)")
    
    async def disconnect(self):
        """Disconnect from MQTT broker"""
        self.connected = False
        logger.info("MQTT client disconnected")
    
    async def publish(self, topic: str, payload: Dict[str, Any]) -> bool:
        """Publish message to MQTT topic"""
        if not self.connected:
            logger.warning("MQTT client not connected")
            return False
        
        logger.info(f"Publishing to {topic}: {json.dumps(payload)}")
        return True
    
    async def subscribe(self, topic: str) -> bool:
        """Subscribe to MQTT topic"""
        if not self.connected:
            logger.warning("MQTT client not connected")
            return False
        
        logger.info(f"Subscribed to {topic}")
        return True

def get_mqtt_client() -> SimpleMQTTClient:
    """Get the global MQTT client instance"""
    global mqtt_client
    if mqtt_client is None:
        settings = get_settings()
        config = {
            'host': settings.mqtt_host,
            'port': settings.mqtt_port,
            'username': settings.mqtt_username,
            'password': settings.mqtt_password,
            'keepalive': settings.mqtt_keepalive,
            'ssl': settings.mqtt_use_ssl
        }
        mqtt_client = SimpleMQTTClient(config)
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