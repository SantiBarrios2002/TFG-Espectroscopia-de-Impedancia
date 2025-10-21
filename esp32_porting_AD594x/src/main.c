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
#include <stdlib.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_task_wdt.h"
#include "driver/uart.h"

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

// Helper function to parse board selection from string commands
// Useful for MQTT/Serial command integration
board_type_t parse_board_selection(const char *command)
{
    if (command == NULL) {
        return BOARD_AD5940;  // Default
    }

    // Check for "AD5941" or "BOARD_AD5941" in command string
    if (strstr(command, "AD5941") != NULL || strstr(command, "5941") != NULL) {
        return BOARD_AD5941;
    }

    // Check for "AD5940" or "BOARD_AD5940" in command string
    if (strstr(command, "AD5940") != NULL || strstr(command, "5940") != NULL) {
        return BOARD_AD5940;
    }

    ESP_LOGW(TAG, "Unknown board in command '%s', defaulting to AD5940", command);
    return BOARD_AD5940;
}

// Generic measurement task that works with any selected board
// The board_config system allows runtime switching via board_select()
void measurement_task(void *pvParameters)
{
    board_type_t board = (board_type_t)(uintptr_t)pvParameters;

    // Runtime board selection - this is the key feature!
    board_select(board);

    if (board == BOARD_AD5940) {
        ESP_LOGI(TAG, "=== Starting AD5940 Impedance Measurement ===");
        ESP_LOGI(TAG, "AD5940 board selected via board_config system");

        // Initialize MCU platform
        MCUPlatformInit(NULL);

        // Initialize using wrapper function - calls ad5940_interface.MCUResourceInit
        AD5940_MCUResourceInit(NULL);

        ESP_LOGI(TAG, "AD5940 initialized, starting impedance measurements");
        ESP_LOGI(TAG, "AD5940_SYSTEM_READY");

        // All AD5940_* function calls now route through current_board pointer
        AD5940_Main();

    } else if (board == BOARD_AD5941) {
        ESP_LOGI(TAG, "=== Starting AD5941 Battery Impedance Measurement ===");
        ESP_LOGI(TAG, "AD5941 board selected via board_config system");

        // Initialize MCU platform
        MCUPlatformInit(NULL);

        // Initialize using wrapper function - calls ad5941_interface.MCUResourceInit
        AD5940_MCUResourceInit(NULL);

        ESP_LOGI(TAG, "AD5941 initialized, starting battery impedance measurements");
        ESP_LOGI(TAG, "AD5941_SYSTEM_READY");

        // All AD5940_* function calls now route through current_board pointer
        AD5941_Main();
    }

    fflush(stdout);
    ESP_LOGE(TAG, "Measurement function returned unexpectedly");
    vTaskDelete(NULL);
}

// Legacy task wrappers for backwards compatibility
void ad5940_impedance_task(void *pvParameters)
{
    measurement_task((void *)(uintptr_t)BOARD_AD5940);
}

void ad5941_battery_task(void *pvParameters)
{
    measurement_task((void *)(uintptr_t)BOARD_AD5941);
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
    ESP_LOGI(TAG, "=== Board Config System Enabled ===");
    ESP_LOGI(TAG, "Runtime board switching via board_select()");
    ESP_LOGI(TAG, "AD5940: Standard impedance spectroscopy");
    ESP_LOGI(TAG, "AD5941: Battery impedance measurement");
    ESP_LOGI(TAG, "====================================");

    /*
     * RUNTIME BOARD SWITCHING EXAMPLES:
     *
     * Example 1: Simple static selection
     * board_type_t selected_board = BOARD_AD5940;  // or BOARD_AD5941
     * xTaskCreate(measurement_task, "measure", 8192, (void*)(uintptr_t)selected_board, 5, NULL);
     *
     * Example 2: Dynamic selection from MQTT/Serial command
     * char* command = "SELECT_BOARD:AD5941";
     * board_type_t board = parse_board_command(command);
     * board_select(board);  // Switch at runtime!
     *
     * Example 3: Sequential measurements on both boards
     * // Run AD5940 first
     * board_select(BOARD_AD5940);
     * AD5940_MCUResourceInit(NULL);
     * perform_measurement();
     *
     * // Switch to AD5941
     * board_select(BOARD_AD5941);
     * AD5940_MCUResourceInit(NULL);
     * perform_measurement();
     */

    // Default: Start with AD5941 battery measurements
    // Change BOARD_AD5941 to BOARD_AD5940 to switch boards
    // xTaskCreate(measurement_task, "measure", 8192, (void*)(uintptr_t)BOARD_AD5941, 5, NULL);
    xTaskCreate(ad5941_battery_task, "AD5941_BAT_Task", 8192, NULL, 5, NULL);
}
