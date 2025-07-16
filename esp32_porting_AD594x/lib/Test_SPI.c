#include "Test_SPI.h"
#include "ad5940.h"
#include "board_config.h"
#include <stdio.h>
#include "esp_task_wdt.h"

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

void initialize_ad5940(void) {
    esp_task_wdt_deinit(); // Disable watchdog timer
    printf("Initializing MCU...\n");

    if (current_board == NULL) {
        printf("Error: No board selected. Call board_select() first.\n");
        return;
    }

    if (current_board->MCUResourceInit(NULL) != 0) {
        printf("Error initializing MCU resources\n");
        return;
    }
    printf("MCU initialized successfully\n");
    current_board->Delay10us(200);

    printf("Resetting AD5940...\n");
    AD5940_HWReset();
    printf("AD5940 reset complete\n");
    current_board->Delay10us(200);

    printf("Initializing AD5940...\n");
    AD5940_Initialize();
    current_board->Delay10us(200);
    printf("AD5940 initialized successfully\n");
    current_board->Delay10us(200);
}

void validate_ad5940_id(void) {
    printf("Reading AD5940 identification registers...\n");

    unsigned long adiid = AD5940_ReadReg(0x00000400);
    if (adiid == 0xFFFFFFFF || adiid == 0x00000000) {
        printf("Error reading ADIID register: 0x%08lx\n", adiid);
    } else {
        printf("ADIID register value: 0x%08lx\n", adiid);
    }
    current_board->Delay10us(10);

    unsigned long chipid = AD5940_ReadReg(0x00000404);
    if (chipid == 0xFFFFFFFF || chipid == 0x00000000) {
        printf("Error reading CHIPID register: 0x%08lx\n", chipid);
    } else {
        printf("CHIPID register value: 0x%08lx\n", chipid);
    }

    if (adiid != 0x4144 || chipid != 0x5502) {
        printf("Error: AD5940 identification values do not match expected values\n");
    } else {
        printf("AD5940 identification correct\n");
    }
}

void validate_ad5940_write(void) {
    printf("Starting AD5940 write test...\n");

    unsigned long temp, data;
    srand(0x1234); // Initialize random number generator seed

    int num_tests = 10000; // Number of iterations
    for (int i = 0; i < num_tests; i++) {
        data = rand() & 0xFFFF;
        data <<= 16;
        data |= rand() & 0xFFFF;

        // Write to test register
        AD5940_WriteReg(REG_AFE_CALDATLOCK, data);

        // Read written value
        temp = AD5940_ReadReg(REG_AFE_CALDATLOCK);

        // Validate write operation
        if (temp != data) {
            printf("Write test failed. Expected: 0x%08lx, Read: 0x%08lx\n", data, temp);
        }

        // Show progress every 1000 iterations
        if ((i + 1) % 1000 == 0) {
            printf("Write/read test completed %d times. Last value: 0x%08lx\n", i + 1, data);
        }
    }

    printf("AD5940 write test completed.\n");
}