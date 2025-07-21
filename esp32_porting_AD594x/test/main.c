/*
ESP32 AD5940/AD5941 Dual Board MQTT Integration Test

This test implementation integrates MQTT client with dual board functionality
for validation before production deployment.

Copyright (c) 2017-2019 Analog Devices, Inc. All Rights Reserved.
This software is proprietary to Analog Devices, Inc. and its licensors.
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "nvs_flash.h"
#include "esp_task_wdt.h"

// MQTT includes
#include "mqtt_client.h"

// Project includes
#include "ad5940.h"
#include "board_config.h"
#include "mqtt_config.h"

// JSON library for message formatting
#include "cJSON.h"

static const char *TAG = "MQTT_TEST";

// External functions from Main files
extern void AD5940_Main(void);  // From AD5940Main.c (Impedance.c functionality)
extern void AD5941_Main(void);  // From AD5941Main.c (BATImpedance.c functionality)

// Global MQTT configuration
static mqtt_config_t g_mqtt_config;
static esp_mqtt_client_handle_t g_mqtt_client = NULL;

// WiFi event group
static EventGroupHandle_t s_wifi_event_group;
#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1

// Current board state
static board_type_t g_current_board = BOARD_AD5940;
static bool g_board_selected = false;
static bool g_measurement_active = false;
static char g_measurement_id[32] = {0};

// ESP32 specific initialization
uint32_t MCUPlatformInit(void *pCfg)
{
    ESP_LOGI(TAG, "MCU Platform Init");
    return 0;
}

// WiFi event handler
static void wifi_event_handler(void* arg, esp_event_base_t event_base,
                              int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        ESP_LOGI(TAG, "WiFi disconnected, retrying...");
        esp_wifi_connect();
        xEventGroupClearBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "WiFi connected, IP:" IPSTR, IP2STR(&event->ip_info.ip));
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    }
}

// Initialize WiFi
static void wifi_init(void)
{
    s_wifi_event_group = xEventGroupCreate();

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    esp_event_handler_instance_t instance_any_id;
    esp_event_handler_instance_t instance_got_ip;
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT,
                                                        ESP_EVENT_ANY_ID,
                                                        &wifi_event_handler,
                                                        NULL,
                                                        &instance_any_id));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT,
                                                        IP_EVENT_STA_GOT_IP,
                                                        &wifi_event_handler,
                                                        NULL,
                                                        &instance_got_ip));

    wifi_config_t wifi_config = {
        .sta = {
            .ssid = WIFI_SSID,
            .password = WIFI_PASSWORD,
            .threshold.authmode = WIFI_AUTH_WPA2_PSK,
        },
    };
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(TAG, "WiFi init finished");
}

// Create JSON message for board selection response
static char* create_board_selection_response(const char* status, const char* board, const char* message, const char* request_id)
{
    cJSON *json = cJSON_CreateObject();
    cJSON *device_info = cJSON_CreateObject();
    
    cJSON_AddStringToObject(json, "status", status);
    cJSON_AddStringToObject(json, "selected_board", board);
    cJSON_AddStringToObject(json, "message", message);
    cJSON_AddStringToObject(json, "timestamp", "2024-01-01T00:00:00Z"); // TODO: Add real timestamp
    
    if (request_id) {
        cJSON_AddStringToObject(json, "request_id", request_id);
    }
    
    cJSON_AddStringToObject(device_info, "device_id", g_mqtt_config.device_info.device_id);
    cJSON_AddStringToObject(device_info, "board_type", board);
    cJSON_AddStringToObject(device_info, "firmware_version", g_mqtt_config.device_info.firmware_version);
    cJSON_AddItemToObject(json, "device_info", device_info);
    
    char *json_string = cJSON_Print(json);
    cJSON_Delete(json);
    
    return json_string;
}

// Process board selection command
static void process_board_selection_command(cJSON *json)
{
    cJSON *board_type = cJSON_GetObjectItem(json, "board_type");
    cJSON *request_id = cJSON_GetObjectItem(json, "request_id");
    
    if (!cJSON_IsString(board_type)) {
        ESP_LOGE(TAG, "Invalid board selection command - missing board_type");
        return;
    }
    
    const char* board_str = board_type->valuestring;
    const char* req_id = request_id ? request_id->valuestring : NULL;
    
    ESP_LOGI(TAG, "Processing board selection: %s", board_str);
    
    // Select the board
    if (strcmp(board_str, "AD5940") == 0) {
        board_select(BOARD_AD5940);
        g_current_board = BOARD_AD5940;
        g_board_selected = true;
        
        char* response = create_board_selection_response("success", "AD5940", "AD5940 board selected", req_id);
        esp_mqtt_client_publish(g_mqtt_client, g_mqtt_config.topics.resp_board_select, response, 0, MQTT_QOS_LEVEL, false);
        free(response);
        
    } else if (strcmp(board_str, "AD5941") == 0) {
        board_select(BOARD_AD5941);
        g_current_board = BOARD_AD5941;
        g_board_selected = true;
        
        char* response = create_board_selection_response("success", "AD5941", "AD5941 board selected", req_id);
        esp_mqtt_client_publish(g_mqtt_client, g_mqtt_config.topics.resp_board_select, response, 0, MQTT_QOS_LEVEL, false);
        free(response);
        
    } else {
        char error_msg[128];
        snprintf(error_msg, sizeof(error_msg), "Unknown board type: %s", board_str);
        
        char* response = create_board_selection_response("error", "UNKNOWN", error_msg, req_id);
        esp_mqtt_client_publish(g_mqtt_client, g_mqtt_config.topics.resp_board_select, response, 0, MQTT_QOS_LEVEL, false);
        free(response);
    }
}

// Process measurement start command
static void process_measurement_command(cJSON *json)
{
    if (!g_board_selected) {
        ESP_LOGE(TAG, "Cannot start measurement - no board selected");
        return;
    }
    
    cJSON *measurement_type = cJSON_GetObjectItem(json, "measurement_type");
    cJSON *request_id = cJSON_GetObjectItem(json, "request_id");
    
    if (!cJSON_IsString(measurement_type)) {
        ESP_LOGE(TAG, "Invalid measurement command - missing measurement_type");
        return;
    }
    
    // Generate measurement ID
    snprintf(g_measurement_id, sizeof(g_measurement_id), "meas_%ld", esp_timer_get_time() / 1000);
    g_measurement_active = true;
    
    ESP_LOGI(TAG, "Starting measurement: %s on board %s", 
             measurement_type->valuestring, 
             g_current_board == BOARD_AD5940 ? "AD5940" : "AD5941");
    
    // TODO: Start actual measurement task based on selected board
    // For now, just acknowledge the command
    cJSON *response = cJSON_CreateObject();
    cJSON_AddStringToObject(response, "status", "started");
    cJSON_AddStringToObject(response, "measurement_id", g_measurement_id);
    cJSON_AddStringToObject(response, "board_type", g_current_board == BOARD_AD5940 ? "AD5940" : "AD5941");
    
    char *response_str = cJSON_Print(response);
    esp_mqtt_client_publish(g_mqtt_client, g_mqtt_config.topics.resp_measurement, response_str, 0, MQTT_QOS_LEVEL, false);
    
    free(response_str);
    cJSON_Delete(response);
}

// MQTT event handler
static void mqtt_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    esp_mqtt_event_handle_t event = event_data;
    esp_mqtt_client_handle_t client = event->client;
    
    switch ((esp_mqtt_event_id_t)event_id) {
        case MQTT_EVENT_CONNECTED:
            ESP_LOGI(TAG, "MQTT Connected");
            g_mqtt_config.state = MQTT_STATE_CONNECTED;
            
            // Subscribe to command topics
            esp_mqtt_client_subscribe(client, g_mqtt_config.topics.cmd_board_select, MQTT_QOS_LEVEL);
            esp_mqtt_client_subscribe(client, g_mqtt_config.topics.cmd_measurement, MQTT_QOS_LEVEL);
            esp_mqtt_client_subscribe(client, g_mqtt_config.topics.cmd_stop, MQTT_QOS_LEVEL);
            
            g_mqtt_config.state = MQTT_STATE_SUBSCRIBED;
            ESP_LOGI(TAG, "Subscribed to command topics");
            break;
            
        case MQTT_EVENT_DISCONNECTED:
            ESP_LOGI(TAG, "MQTT Disconnected");
            g_mqtt_config.state = MQTT_STATE_DISCONNECTED;
            break;
            
        case MQTT_EVENT_SUBSCRIBED:
            ESP_LOGI(TAG, "MQTT Subscribed to topic, msg_id=%d", event->msg_id);
            break;
            
        case MQTT_EVENT_DATA:
            ESP_LOGI(TAG, "MQTT Data received: topic=%.*s", event->topic_len, event->topic);
            
            // Parse incoming JSON command
            cJSON *json = cJSON_ParseWithLength(event->data, event->data_len);
            if (json == NULL) {
                ESP_LOGE(TAG, "Failed to parse JSON command");
                break;
            }
            
            // Route command based on topic
            if (strstr(event->topic, "/cmd/board_select")) {
                process_board_selection_command(json);
            } else if (strstr(event->topic, "/cmd/measurement_start")) {
                process_measurement_command(json);
            }
            
            cJSON_Delete(json);
            break;
            
        case MQTT_EVENT_ERROR:
            ESP_LOGE(TAG, "MQTT Error occurred");
            g_mqtt_config.state = MQTT_STATE_ERROR;
            break;
            
        default:
            break;
    }
}

// Initialize MQTT client
static void mqtt_init(void)
{
    // Initialize device info
    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);
    snprintf(g_mqtt_config.device_info.device_id, sizeof(g_mqtt_config.device_info.device_id), 
             "%02x%02x%02x%02x%02x%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    
    snprintf(g_mqtt_config.device_info.client_id, sizeof(g_mqtt_config.device_info.client_id), 
             "%s%s", MQTT_CLIENT_ID_PREFIX, g_mqtt_config.device_info.device_id);
    
    strcpy(g_mqtt_config.device_info.firmware_version, "1.0.0");
    
    // Initialize topics
    mqtt_init_topics(&g_mqtt_config.topics, g_mqtt_config.device_info.device_id);
    
    // MQTT client configuration
    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = "mqtt://192.168.1.100:1883", // Change to your broker
        .credentials.client_id = g_mqtt_config.device_info.client_id,
        .session.keepalive = MQTT_KEEPALIVE_INTERVAL,
        .session.disable_clean_session = !MQTT_CLEAN_SESSION,
    };
    
    g_mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
    esp_mqtt_client_register_event(g_mqtt_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(g_mqtt_client);
    
    ESP_LOGI(TAG, "MQTT client initialized with ID: %s", g_mqtt_config.device_info.client_id);
}

// Initialize MQTT topics
void mqtt_init_topics(mqtt_topics_t *topics, const char *device_id)
{
    snprintf(topics->cmd_board_select, MQTT_MAX_TOPIC_LENGTH, MQTT_TOPIC_CMD_BOARD_SELECT, device_id);
    snprintf(topics->cmd_measurement, MQTT_MAX_TOPIC_LENGTH, MQTT_TOPIC_CMD_MEASUREMENT, device_id);
    snprintf(topics->cmd_stop, MQTT_MAX_TOPIC_LENGTH, MQTT_TOPIC_CMD_STOP, device_id);
    snprintf(topics->resp_board_select, MQTT_MAX_TOPIC_LENGTH, MQTT_TOPIC_RESP_BOARD_SELECT, device_id);
    snprintf(topics->resp_measurement, MQTT_MAX_TOPIC_LENGTH, MQTT_TOPIC_RESP_MEASUREMENT, device_id);
    snprintf(topics->data_ad5940, MQTT_MAX_TOPIC_LENGTH, MQTT_TOPIC_DATA_AD5940, device_id);
    snprintf(topics->data_ad5941, MQTT_MAX_TOPIC_LENGTH, MQTT_TOPIC_DATA_AD5941, device_id);
    snprintf(topics->system_status, MQTT_MAX_TOPIC_LENGTH, MQTT_TOPIC_SYSTEM_STATUS, device_id);
    snprintf(topics->system_errors, MQTT_MAX_TOPIC_LENGTH, MQTT_TOPIC_SYSTEM_ERRORS, device_id);
    snprintf(topics->system_heartbeat, MQTT_MAX_TOPIC_LENGTH, MQTT_TOPIC_SYSTEM_HEARTBEAT, device_id);
}

// Heartbeat task
void heartbeat_task(void *pvParameters)
{
    while (1) {
        if (g_mqtt_config.state == MQTT_STATE_SUBSCRIBED) {
            cJSON *heartbeat = cJSON_CreateObject();
            cJSON_AddStringToObject(heartbeat, "status", "alive");
            cJSON_AddStringToObject(heartbeat, "device_id", g_mqtt_config.device_info.device_id);
            cJSON_AddNumberToObject(heartbeat, "uptime", esp_timer_get_time() / 1000000);
            cJSON_AddNumberToObject(heartbeat, "free_heap", esp_get_free_heap_size());
            
            char *heartbeat_str = cJSON_Print(heartbeat);
            esp_mqtt_client_publish(g_mqtt_client, g_mqtt_config.topics.system_heartbeat, heartbeat_str, 0, 0, false);
            
            free(heartbeat_str);
            cJSON_Delete(heartbeat);
        }
        
        vTaskDelay(pdMS_TO_TICKS(MQTT_HEARTBEAT_INTERVAL_MS));
    }
}

// Main ESP-IDF application entry point
void app_main(void)
{
    ESP_LOGI(TAG, "Starting ESP32 Dual Board MQTT Test Application");
    ESP_LOGI(TAG, "Build Time: %s %s", __DATE__, __TIME__);
    
    // Initialize NVS
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    
    // Initialize WiFi
    wifi_init();
    
    // Wait for WiFi connection
    EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
                                          WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
                                          pdFALSE,
                                          pdFALSE,
                                          portMAX_DELAY);
                                          
    if (bits & WIFI_CONNECTED_BIT) {
        ESP_LOGI(TAG, "Connected to WiFi");
        
        // Initialize MQTT
        mqtt_init();
        
        // Create heartbeat task
        xTaskCreate(heartbeat_task, "heartbeat", 4096, NULL, 3, NULL);
        
        ESP_LOGI(TAG, "=== MQTT Test System Ready ===");
        ESP_LOGI(TAG, "Device ID: %s", g_mqtt_config.device_info.device_id);
        ESP_LOGI(TAG, "Listening for board selection and measurement commands...");
        
    } else {
        ESP_LOGE(TAG, "Failed to connect to WiFi");
    }
}