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

// AD5940 includes
#include "ad5940.h"
#include "board_config.h"

static const char *TAG = "DUAL_BOARD_MAIN";

// External functions from Main files
extern void AD5940_Main(void);  // From AD5940Main.c (Impedance.c functionality)
extern void AD5941_Main(void);  // From AD5941Main.c (BATImpedance.c functionality)

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
    printf("AD5940_SYSTEM_READY\n");
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
    printf("AD5941_SYSTEM_READY\n");
    fflush(stdout);

    // Call AD5941 main function (BATImpedance.c functionality)
    AD5941_Main();
    
    // This should never be reached
    ESP_LOGE(TAG, "AD5941_Main returned unexpectedly");
    vTaskDelete(NULL);
}

// Production-ready measurement task that can switch between boards
void measurement_task(void *pvParameters)
{
    ESP_LOGI(TAG, "=== Production Measurement Task Ready ===");
    ESP_LOGI(TAG, "Waiting for board selection and start commands from server/MATLAB...");
    
    // In production, this task would:
    // 1. Wait for MQTT/server commands to select board
    // 2. Call board_select(BOARD_AD5940) or board_select(BOARD_AD5941) 
    // 3. Initialize and run the appropriate measurement function
    // 4. Stream data back via MQTT/server
    
    // For now, just keep the task alive and ready
    while (1) {
        ESP_LOGI(TAG, "Measurement system ready - awaiting server integration");
        vTaskDelay(pdMS_TO_TICKS(10000)); // 10 second heartbeat
    }
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
    
    // Print available functionality
    ESP_LOGI(TAG, "=== Dual Board Functionality Compiled ===");
    ESP_LOGI(TAG, "✓ AD5940: Standard impedance spectroscopy ready");
    ESP_LOGI(TAG, "✓ AD5941: Battery impedance measurement ready");
    ESP_LOGI(TAG, "========================================");
    
    // Create production measurement task (ready for server integration)
    BaseType_t task_created = xTaskCreate(
        measurement_task,         // Task function
        "measurement_task",       // Task name
        8192,                     // Stack size (8KB)
        NULL,                     // Parameters
        5,                        // Priority
        NULL                      // Task handle
    );
    
    if (task_created != pdPASS) {
        ESP_LOGE(TAG, "Failed to create measurement task");
        return;
    }
    
    ESP_LOGI(TAG, "Production measurement task created - both AD5940 and AD5941 functionality available");
    
    // For individual board testing during development, uncomment one of these:
    xTaskCreate(ad5940_impedance_task, "ad5940_task", 8192, NULL, 5, NULL);  // AD5940 only
    // xTaskCreate(ad5941_battery_task, "ad5941_task", 8192, NULL, 5, NULL);    // AD5941 only
}