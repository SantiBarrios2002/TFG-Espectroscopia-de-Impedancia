/*
ESP32 AD5940/AD5941 Dual Board Main Application

This main application demonstrates both impedance measurement functionalities:
- AD5940 board: Standard impedance spectroscopy (Impedance.c)  
- AD5941 board: Battery impedance measurement (BATImpedance.c)

Uses the existing board selection system for clean board switching.

Copyright (c) 2017-2019 Analog Devices, Inc. All Rights Reserved.
This software is proprietary to Analog Devices, Inc. and its licensors.
*/

#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_task_wdt.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "mqtt_client.h"

// AD5940 includes
#include "ad5940.h"
#include "board_config.h"

// Network Configuration
#define WIFI_SSID "Oneplus"
#define WIFI_PASSWORD "123456789"
#define MQTT_BROKER_URI "mqtt://172.18.22.140:1883"
#define MQTT_PUBLISH_TOPIC "/esp32/data"

static const char *TAG = "DUAL_BOARD_MAIN";

// MQTT client handle
static esp_mqtt_client_handle_t mqtt_client = NULL;

// External functions from Main files
extern void AD5940_Main(void);  // From AD5940Main.c (Impedance.c functionality)
extern void AD5941_Main(void);  // From AD5941Main.c (BATImpedance.c functionality)

// MQTT Event Handler
static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    esp_mqtt_event_handle_t event = event_data;
    
    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED:
        ESP_LOGI(TAG, "MQTT Connected to broker");
        break;
        
    case MQTT_EVENT_DISCONNECTED:
        ESP_LOGI(TAG, "MQTT Disconnected");
        break;
        
    case MQTT_EVENT_PUBLISHED:
        ESP_LOGI(TAG, "MQTT Published data, msg_id=%d", event->msg_id);
        break;
        
    case MQTT_EVENT_ERROR:
        ESP_LOGE(TAG, "MQTT Error occurred");
        break;
        
    default:
        break;
    }
}

// WiFi event handler
static void wifi_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        ESP_LOGI(TAG, "WiFi disconnected, retrying...");
        esp_wifi_connect();
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "WiFi connected, IP: " IPSTR, IP2STR(&event->ip_info.ip));
    }
}

// Initialize WiFi connection
void wifi_init(void)
{
    // Initialize networking stack
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    // Initialize WiFi
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    // Register event handlers
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL));

    // Configure WiFi
    wifi_config_t wifi_config = {
        .sta = {
            .ssid = WIFI_SSID,
            .password = WIFI_PASSWORD,
        },
    };

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(TAG, "WiFi initialization complete, connecting to %s", WIFI_SSID);
}

// Initialize MQTT client
void mqtt_init(void)
{
    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = MQTT_BROKER_URI,
    };

    mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
    if (mqtt_client == NULL) {
        ESP_LOGE(TAG, "Failed to initialize MQTT client");
        return;
    }

    ESP_ERROR_CHECK(esp_mqtt_client_register_event(mqtt_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL));
    ESP_ERROR_CHECK(esp_mqtt_client_start(mqtt_client));
    
    ESP_LOGI(TAG, "MQTT client initialized and started");
}

// Function to publish impedance data as JSON
void publish_impedance_data(double frequency, double magnitude, double phase)
{
    if (mqtt_client == NULL) {
        ESP_LOGW(TAG, "MQTT client not initialized, cannot publish data");
        return;
    }
    
    // Create JSON payload: {"frequency":freq, "magnitude":mag, "phase":phase}
    char json_buffer[256];
    int len = snprintf(json_buffer, sizeof(json_buffer), 
                      "{\"frequency\": %.2f,\"magnitude\": %.6f,\"phase\": %.6f}",
                      frequency, magnitude, phase);
    
    if (len >= sizeof(json_buffer)) {
        ESP_LOGE(TAG, "JSON buffer overflow");
        return;
    }
    
    // Publish to /esp32/data topic
    int msg_id = esp_mqtt_client_publish(mqtt_client, MQTT_PUBLISH_TOPIC, json_buffer, len, 1, 0);
    if (msg_id != -1) {
        ESP_LOGD(TAG, "Published: %s", json_buffer);
    } else {
        ESP_LOGE(TAG, "Failed to publish MQTT message");
    }
}

// ESP32 specific initialization
uint32_t MCUPlatformInit(void *pCfg)
{
    ESP_LOGI(TAG, "MCU Platform Init");
    /* Clock Configure - handled by ESP-IDF */
    /* UART Configure - handled by ESP-IDF */  
    /* GPIO Configure - handled by ESP-IDF */
    return 0;
}

// Task for AD5940 board (Impedance.c functionality)
void ad5940_impedance_task(void *pvParameters)
{
    ESP_LOGI(TAG, "=== Starting AD5940 Impedance Measurement ===");
    
    // Select AD5940 board using existing board selection system
    board_select(BOARD_AD5940);
    ESP_LOGI(TAG, "AD5940 board selected");
    
    // Initialize MCU platform
    MCUPlatformInit(NULL);
    
    // Initialize AD5940 MCU resources  
    AD5940_MCUResourceInit(NULL);
    
    ESP_LOGI(TAG, "AD5940 initialized, starting impedance measurements");
    
    // Signal system is ready for this board
    ESP_LOGI(TAG, "AD5940_SYSTEM_READY");
    fflush(stdout);
    
    // Call AD5940 main function (Impedance.c functionality)
    AD5940_Main();
    
    // This should never be reached
    ESP_LOGE(TAG, "AD5940_Main returned unexpectedly");
    vTaskDelete(NULL);
}

// Task for AD5941 board (BATImpedance.c functionality)  
void ad5941_battery_task(void *pvParameters)
{
    ESP_LOGI(TAG, "=== Starting AD5941 Battery Impedance Measurement ===");
    
    // Select AD5941 board using existing board selection system
    board_select(BOARD_AD5941);
    ESP_LOGI(TAG, "AD5941 board selected");
    
    // Initialize MCU platform
    MCUPlatformInit(NULL);
    
    // Initialize AD5940 MCU resources (note: still AD5940_MCUResourceInit for AD5941)
    AD5940_MCUResourceInit(NULL);
    
    ESP_LOGI(TAG, "AD5941 initialized, starting battery impedance measurements");
    
    // Signal system is ready for this board
    ESP_LOGI(TAG, "AD5941_SYSTEM_READY");
    fflush(stdout);

    // Call AD5941 main function (BATImpedance.c functionality)
    AD5941_Main();
    
    // This should never be reached
    ESP_LOGE(TAG, "AD5941_Main returned unexpectedly");
    vTaskDelete(NULL);
}


// Main ESP-IDF application entry point
void app_main(void)
{
    ESP_LOGI(TAG, "Starting ESP32 Dual Board Application");
    ESP_LOGI(TAG, "Build Time: %s %s", __DATE__, __TIME__);
    
    // Disable the task watchdog timer
    ESP_ERROR_CHECK(esp_task_wdt_deinit());
    ESP_LOGI(TAG, "Task watchdog timer disabled");
    
    // Initialize NVS (required for ESP32)
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    
    // Initialize WiFi connection
    wifi_init();
    
    // Give WiFi time to connect before initializing MQTT
    vTaskDelay(pdMS_TO_TICKS(5000)); // 5 second delay
    
    // Initialize MQTT client
    mqtt_init();
    
    // Print available functionality
    ESP_LOGI(TAG, "=== Dual Board Functionality Compiled ===");
    ESP_LOGI(TAG, "✓ AD5940: Standard impedance spectroscopy ready");
    // ESP_LOGI(TAG, "✓ AD5941: Battery impedance measurement ready");
    ESP_LOGI(TAG, "========================================");
    
    // For individual board selection, uncomment one of these:
    xTaskCreate(ad5940_impedance_task, "ad5940_task", 8192, NULL, 5, NULL);  // AD5940 only
    // xTaskCreate(ad5941_battery_task, "ad5941_task", 8192, NULL, 5, NULL);    // AD5941 only
}