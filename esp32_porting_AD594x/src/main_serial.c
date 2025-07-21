/*
ESP32 AD5940/AD5941 Dual Board Serial Debug Main

This file is for debugging purposes via PlatformIO Serial Monitor.
It provides direct serial communication with both AD5940 and AD5941 boards
for development and testing purposes.

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

static const char *TAG = "SERIAL_DEBUG";

// External functions from Main files
extern void AD5940_Main(void);  // From AD5940Main.c (Impedance.c functionality)
extern void AD5941_Main(void);  // From AD5941Main.c (BATImpedance.c functionality)

// Current selected board
static board_type_t current_board = BOARD_AD5940;  // Default to AD5940
static bool board_selected = false;
static bool system_running = false;

// ESP32 specific initialization
uint32_t MCUPlatformInit(void *pCfg)
{
    ESP_LOGI(TAG, "MCU Platform Init for Board: %s", 
             current_board == BOARD_AD5940 ? "AD5940" : "AD5941");
    /* Clock Configure - handled by ESP-IDF */
    /* UART Configure - handled by ESP-IDF */  
    /* GPIO Configure - handled by ESP-IDF */
    return 0;
}

// Command processing function
void process_serial_command(const char* command) 
{
    ESP_LOGI(TAG, "Received command: %s", command);
    
    // Board selection commands
    if (strstr(command, "SELECT_BOARD:AD5940")) {
        if (system_running) {
            printf("ERROR: Cannot change board while system is running. Restart ESP32.\n");
            return;
        }
        current_board = BOARD_AD5940;
        board_select(BOARD_AD5940);
        board_selected = true;
        printf("BOARD_SELECTED:AD5940\n");
        printf("AD5940 board selected (Impedance.c functionality)\n");
        ESP_LOGI(TAG, "Board selected: AD5940");
    }
    else if (strstr(command, "SELECT_BOARD:AD5941")) {
        if (system_running) {
            printf("ERROR: Cannot change board while system is running. Restart ESP32.\n");
            return;
        }
        current_board = BOARD_AD5941;
        board_select(BOARD_AD5941);
        board_selected = true;
        printf("BOARD_SELECTED:AD5941\n");
        printf("AD5941 board selected (BATImpedance.c functionality)\n");
        ESP_LOGI(TAG, "Board selected: AD5941");
    }
    // Start measurement command
    else if (strstr(command, "START")) {
        if (!board_selected) {
            printf("ERROR: Please select a board first (SELECT_BOARD:AD5940 or SELECT_BOARD:AD5941)\n");
            return;
        }
        if (system_running) {
            printf("ERROR: System is already running\n");
            return;
        }
        system_running = true;
        printf("SYSTEM_STARTING\n");
        ESP_LOGI(TAG, "Starting measurement system");
    }
    // Help command
    else if (strstr(command, "HELP")) {
        printf("=== ESP32 Serial Debug Commands ===\n");
        printf("SELECT_BOARD:AD5940  - Select AD5940 board (Impedance.c)\n");
        printf("SELECT_BOARD:AD5941  - Select AD5941 board (BATImpedance.c)\n");
        printf("START                - Start measurement system\n");
        printf("HELP                 - Show this help\n");
        printf("===================================\n");
    }
    // Ping command for connection testing
    else if (strstr(command, "ping")) {
        printf("pong\n");
    }
    else {
        printf("ERROR: Unknown command. Type HELP for available commands.\n");
    }
    
    fflush(stdout);
}

// Command processing task for serial input
void command_processing_task(void *pvParameters)
{
    char command_buffer[256];
    int buffer_index = 0;
    
    ESP_LOGI(TAG, "Command processing task started");
    printf("=== ESP32 Serial Debug Interface ===\n");
    printf("Type HELP for available commands\n");
    printf("=====================================\n");
    
    while (1) {
        int c = getchar();
        if (c != EOF) {
            if (c == '\n' || c == '\r') {
                if (buffer_index > 0) {
                    command_buffer[buffer_index] = '\0';
                    process_serial_command(command_buffer);
                    buffer_index = 0;
                }
            } else if (buffer_index < sizeof(command_buffer) - 1) {
                command_buffer[buffer_index++] = c;
            }
        }
        vTaskDelay(pdMS_TO_TICKS(10)); // Small delay to prevent busy waiting
    }
}

// Measurement task for AD5940/AD5941
void measurement_task(void *pvParameters)
{
    ESP_LOGI(TAG, "Measurement task created, waiting for START command");
    
    while (1) {
        if (system_running && board_selected) {
            ESP_LOGI(TAG, "Starting measurement for board: %s", 
                     current_board == BOARD_AD5940 ? "AD5940" : "AD5941");
            
            // Initialize MCU platform
            MCUPlatformInit(NULL);
            
            // Initialize AD5940 MCU resources  
            AD5940_MCUResourceInit(NULL);
            
            ESP_LOGI(TAG, "Board initialized, starting main loop");
            
            // Signal system is ready
            printf("SYSTEM_READY:BOARD_%s\n", current_board == BOARD_AD5940 ? "AD5940" : "AD5941");
            fflush(stdout);

            // Call the appropriate main function based on selected board
            if (current_board == BOARD_AD5940) {
                ESP_LOGI(TAG, "Starting AD5940_Main (Impedance.c)");
                AD5940_Main();  // From AD5940Main.c
            } else {
                ESP_LOGI(TAG, "Starting AD5941_Main (BATImpedance.c)");
                AD5941_Main();  // From AD5941Main.c
            }
            
            // This should never be reached as Main functions run forever
            ESP_LOGE(TAG, "Main function returned unexpectedly");
            system_running = false;
        }
        
        vTaskDelay(pdMS_TO_TICKS(1000)); // Check every second
    }
}

// Main ESP-IDF application entry point
void app_main(void)
{
    ESP_LOGI(TAG, "Starting ESP32 Dual Board Serial Debug Application");
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
    
    // Create command processing task
    BaseType_t cmd_task_created = xTaskCreate(
        command_processing_task,   // Task function
        "cmd_task",               // Task name
        4096,                     // Stack size (4KB)
        NULL,                     // Parameters
        4,                        // Priority (lower than measurement)
        NULL                      // Task handle
    );
    
    if (cmd_task_created != pdPASS) {
        ESP_LOGE(TAG, "Failed to create command processing task");
        return;
    }
    
    // Create measurement task
    BaseType_t meas_task_created = xTaskCreate(
        measurement_task,         // Task function
        "measurement_task",       // Task name
        8192,                     // Stack size (8KB)
        NULL,                     // Parameters
        5,                        // Priority (higher than command)
        NULL                      // Task handle
    );
    
    if (meas_task_created != pdPASS) {
        ESP_LOGE(TAG, "Failed to create measurement task");
        return;
    }
    
    ESP_LOGI(TAG, "All tasks created successfully");
    ESP_LOGI(TAG, "Serial debug interface ready");
    
    // The main task can now exit - other tasks will continue running
}