#include "ad5940.h"
#include "Test_SPI.h"
#include "board_config.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

// freeRTOS related includes
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

// driver related includes
#include "driver/uart.h"
#include "driver/spi_master.h"
#include "driver/gpio.h"
#include "esp_timer.h"

void app_main() 
{
    printf("=== Dual Board Test Using Test_SPI Functions ===\n");
    
    // Hardcoded board selection for testing - change this line to test different boards
    board_select(BOARD_AD5940); // Change to BOARD_AD5941 to test the other board
    
    // Test 1: Initialize selected device
    printf("\n=== Test 1: Device Initialization ===\n");
    initialize_ad5940();
    printf("Initialization test completed\n");

    // Test 2: Validate AD5940 ID
    printf("\n=== Test 2: AD5940 ID Validation ===\n");
    validate_ad5940_id();
    printf("ID validation test completed\n");

    // Test 3: Validate AD5940 Write/Read Operations
    printf("\n=== Test 3: AD5940 Write/Read Test ===\n");
    validate_ad5940_write();
    printf("Write/read test completed\n");

    // Summary
    printf("\n=== Test Summary ===\n");
    printf("All AD5940 board tests have been executed.\n");
    printf("Check the output above for any errors or failures.\n");
    printf("If no errors were reported, the board is working correctly.\n");
    
    // Keep running for continuous monitoring
    printf("\nBoard test completed. System will continue running...\n");
    while(1) {
        vTaskDelay(pdMS_TO_TICKS(10000)); // 10 second heartbeat
        printf("System heartbeat - Board operational\n");
    }
}