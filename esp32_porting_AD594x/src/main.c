/*
ESP32 AD5940 Impedance Measurement - Simple Main

Copyright (c) 2017-2019 Analog Devices, Inc. All Rights Reserved.
This software is proprietary to Analog Devices, Inc. and its licensors.
*/

#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_task_wdt.h"  // Add this include

// AD5940 includes
#include "ad5940.h"

static const char *TAG = "AD5940_MAIN";

// External function from AD5940Main.c
extern void AD5940_Main(void);

// ESP32 specific initialization
uint32_t MCUPlatformInit(void *pCfg)
{
    ESP_LOGI(TAG, "MCU Platform Init");
    /* Clock Configure - handled by ESP-IDF */
    /* UART Configure - handled by ESP-IDF */  
    /* GPIO Configure - handled by ESP-IDF */
    return 0;
}

// Task wrapper for AD5940_Main
void ad5940_task(void *pvParameters)
{
    ESP_LOGI(TAG, "Starting AD5940 task");
    
    // Initialize MCU platform
    MCUPlatformInit(NULL);
    
    // Initialize AD5940 MCU resources  
    AD5940_MCUResourceInit(NULL);
    
    ESP_LOGI(TAG, "AD5940 initialized, starting main loop");
    
    // Call the main AD5940 function (this will run forever)
    AD5940_Main();
    
    // This should never be reached, but just in case
    vTaskDelete(NULL);
}

// Main ESP-IDF application entry point
void app_main(void)
{
    ESP_LOGI(TAG, "Starting ESP32 AD5940 Application");
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
    
    // Create the AD5940 task
    BaseType_t task_created = xTaskCreate(
        ad5940_task,           // Task function
        "ad5940_task",         // Task name
        8192,                  // Stack size (8KB)
        NULL,                  // Parameters
        5,                     // Priority
        NULL                   // Task handle
    );
    
    if (task_created != pdPASS) {
        ESP_LOGE(TAG, "Failed to create AD5940 task");
        return;
    }
    
    ESP_LOGI(TAG, "AD5940 task created successfully");
    
    // The main task can now exit - the AD5940 task will continue running
}