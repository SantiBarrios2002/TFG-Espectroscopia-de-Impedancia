/*
ESP32 MQTT Client Configuration for EIS Dual Board System

This header defines MQTT connection parameters, topic structures,
and configuration for dual board (AD5940/AD5941) communication.

Copyright (c) 2017-2019 Analog Devices, Inc. All Rights Reserved.
This software is proprietary to Analog Devices, Inc. and its licensors.
*/

#ifndef MQTT_CONFIG_H
#define MQTT_CONFIG_H

#include <stdint.h>
#include <stdbool.h>

// MQTT Broker Configuration
#define MQTT_BROKER_HOST        "192.168.1.100"    // Change to your server IP
#define MQTT_BROKER_PORT        1883                // Standard MQTT port
#define MQTT_BROKER_PORT_SSL    8883                // SSL/TLS MQTT port

// Device Configuration
#define MQTT_CLIENT_ID_PREFIX   "eis_device_"       // Will append device MAC
#define MQTT_DEVICE_ID_LENGTH   12                  // MAC address length
#define MQTT_MAX_TOPIC_LENGTH   128                 // Maximum topic string length
#define MQTT_MAX_PAYLOAD_SIZE   1024                // Maximum message payload size

// Connection Settings
#define MQTT_KEEPALIVE_INTERVAL 60                  // Keepalive in seconds
#define MQTT_CLEAN_SESSION      true                // Clean session flag
#define MQTT_QOS_LEVEL         1                    // Quality of Service (0, 1, or 2)
#define MQTT_RETAIN_MESSAGES   false                // Retain flag for published messages

// Reconnection Settings
#define MQTT_RECONNECT_TIMEOUT  5000                // Reconnect timeout in ms
#define MQTT_MAX_RECONNECT_ATTEMPTS 10              // Maximum reconnection attempts
#define MQTT_RECONNECT_BACKOFF  2                   // Exponential backoff multiplier

// Authentication (optional - set to NULL if not used)
#define MQTT_USERNAME          NULL                 // MQTT username
#define MQTT_PASSWORD          NULL                 // MQTT password

// SSL/TLS Configuration (set to true for secure connection)
#define MQTT_USE_SSL           false                // Enable SSL/TLS
#define MQTT_VERIFY_PEER       true                 // Verify server certificate
#define MQTT_CA_CERT_PATH      NULL                 // Path to CA certificate

// Topic Templates (use sprintf to fill {device_id})
#define MQTT_TOPIC_BASE                "eis/device/%s"

// Command Topics (Server → ESP32)
#define MQTT_TOPIC_CMD_BOARD_SELECT    "eis/device/%s/cmd/board_select"
#define MQTT_TOPIC_CMD_MEASUREMENT     "eis/device/%s/cmd/measurement_start"
#define MQTT_TOPIC_CMD_STOP            "eis/device/%s/cmd/measurement_stop"

// Response Topics (ESP32 → Server) 
#define MQTT_TOPIC_RESP_BOARD_SELECT   "eis/device/%s/status/board_selection"
#define MQTT_TOPIC_RESP_MEASUREMENT    "eis/device/%s/status/measurement"

// Data Topics (ESP32 → Server)
#define MQTT_TOPIC_DATA_AD5940         "eis/device/%s/data/ad5940"
#define MQTT_TOPIC_DATA_AD5941         "eis/device/%s/data/ad5941"

// System Topics (ESP32 → Server)
#define MQTT_TOPIC_SYSTEM_STATUS       "eis/device/%s/system/status"
#define MQTT_TOPIC_SYSTEM_ERRORS       "eis/device/%s/system/errors"
#define MQTT_TOPIC_SYSTEM_HEARTBEAT    "eis/device/%s/system/heartbeat"

// Message Publishing Intervals
#define MQTT_HEARTBEAT_INTERVAL_MS     30000        // 30 seconds
#define MQTT_STATUS_UPDATE_INTERVAL_MS 60000        // 60 seconds
#define MQTT_DATA_PUBLISH_IMMEDIATE    true         // Publish measurement data immediately

// Buffer Sizes
#define MQTT_TOPIC_BUFFER_SIZE         128          // Topic string buffer
#define MQTT_JSON_BUFFER_SIZE          512          // JSON message buffer
#define MQTT_ERROR_MSG_SIZE            256          // Error message buffer

// WiFi Configuration for MQTT
#define WIFI_SSID                      "YourWiFiNetwork"    // Change this
#define WIFI_PASSWORD                  "YourWiFiPassword"   // Change this
#define WIFI_RECONNECT_TIMEOUT_MS      10000                // WiFi reconnect timeout
#define WIFI_MAX_RECONNECT_ATTEMPTS    5                    // Max WiFi reconnection attempts

// Device Identification
typedef struct {
    char device_id[MQTT_DEVICE_ID_LENGTH + 1];     // Device MAC address string
    char client_id[32];                             // MQTT client ID
    char firmware_version[16];                      // Firmware version string
} mqtt_device_info_t;

// MQTT Topic Structure
typedef struct {
    char cmd_board_select[MQTT_MAX_TOPIC_LENGTH];
    char cmd_measurement[MQTT_MAX_TOPIC_LENGTH]; 
    char cmd_stop[MQTT_MAX_TOPIC_LENGTH];
    char resp_board_select[MQTT_MAX_TOPIC_LENGTH];
    char resp_measurement[MQTT_MAX_TOPIC_LENGTH];
    char data_ad5940[MQTT_MAX_TOPIC_LENGTH];
    char data_ad5941[MQTT_MAX_TOPIC_LENGTH];
    char system_status[MQTT_MAX_TOPIC_LENGTH];
    char system_errors[MQTT_MAX_TOPIC_LENGTH];
    char system_heartbeat[MQTT_MAX_TOPIC_LENGTH];
} mqtt_topics_t;

// MQTT Connection Status
typedef enum {
    MQTT_STATE_DISCONNECTED = 0,
    MQTT_STATE_CONNECTING,
    MQTT_STATE_CONNECTED,
    MQTT_STATE_SUBSCRIBED,
    MQTT_STATE_ERROR
} mqtt_connection_state_t;

// MQTT Configuration Structure
typedef struct {
    mqtt_device_info_t device_info;
    mqtt_topics_t topics;
    mqtt_connection_state_t state;
    uint32_t last_heartbeat_ms;
    uint32_t reconnect_attempts;
    bool auto_reconnect;
} mqtt_config_t;

// Function Declarations
void mqtt_init_device_info(mqtt_device_info_t *device_info);
void mqtt_init_topics(mqtt_topics_t *topics, const char *device_id);
const char* mqtt_get_state_string(mqtt_connection_state_t state);

// Utility Macros
#define MQTT_TOPIC_SPRINTF(buffer, template, device_id) \
    snprintf(buffer, sizeof(buffer), template, device_id)

#define MQTT_IS_CONNECTED(config) \
    ((config)->state == MQTT_STATE_CONNECTED || (config)->state == MQTT_STATE_SUBSCRIBED)

// Debug Configuration
#define MQTT_DEBUG_ENABLED             true          // Enable MQTT debug logging
#define MQTT_DEBUG_TAG                "MQTT_EIS"     // ESP_LOG tag for MQTT

#endif // MQTT_CONFIG_H