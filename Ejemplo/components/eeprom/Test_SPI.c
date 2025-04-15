#include "Test_SPI.h"
#include "ad5940.h"
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
    esp_task_wdt_deinit(); // Deshabilita el watchdog timer
    printf("Inicializando MCU...\n");

    if (AD5940_MCUResourceInit(NULL) != 0) {
        printf("Error al inicializar los recursos del MCU\n");
        return;
    }
    printf("MCU inicializado correctamente\n");
    AD5940_Delay10us(200);

    printf("Reiniciando AD5940...\n");
    AD5940_HWReset();
    printf("AD5940 reiniciado\n");
    AD5940_Delay10us(200);

    printf("Inicializando AD5940...\n");
    AD5940_Initialize();
    AD5940_Delay10us(200);
    printf("AD5940 inicializado correctamente\n");
    AD5940_Delay10us(200);
}

void validate_ad5940_id(void) {
    printf("Leyendo registros de identificación del AD5940...\n");

    unsigned long adiid = AD5940_ReadReg(0x00000400);
    if (adiid == 0xFFFFFFFF || adiid == 0x00000000) {
        printf("Error al leer el registro ADIID: 0x%08lx\n", adiid);
    } else {
        printf("Valor del registro ADIID: 0x%08lx\n", adiid);
    }
    AD5940_Delay10us(10);

    unsigned long chipid = AD5940_ReadReg(0x00000404);
    if (chipid == 0xFFFFFFFF || chipid == 0x00000000) {
        printf("Error al leer el registro CHIPID: 0x%08lx\n", chipid);
    } else {
        printf("Valor del registro CHIPID: 0x%08lx\n", chipid);
    }

    if (adiid != 0x4144 || chipid != 0x5502) {
        printf("Error: los valores de identificación del AD5940 no coinciden con los esperados\n");
    } else {
        printf("Identificación del AD5940 correcta\n");
    }
}

void validate_ad5940_write(void) {
    printf("Iniciando prueba de escritura en AD5940...\n");

    unsigned long temp, data;
    srand(0x1234); // Inicializa la semilla del generador de números aleatorios

    int num_tests = 10000; // Número de iteraciones
    for (int i = 0; i < num_tests; i++) {
        data = rand() & 0xFFFF;
        data <<= 16;
        data |= rand() & 0xFFFF;

        // Escribir en el registro de prueba
        AD5940_WriteReg(REG_AFE_CALDATLOCK, data);

        // Leer el valor escrito
        temp = AD5940_ReadReg(REG_AFE_CALDATLOCK);

        // Validar la escritura
        if (temp != data) {
            printf("Fallo en la prueba de escritura. Valor esperado: 0x%08lx, leído: 0x%08lx\n", data, temp);
        }

        // Mostrar progreso cada 1000 iteraciones
        if ((i + 1) % 1000 == 0) {
            printf("Prueba de escritura/lectura completada %d veces. Último valor: 0x%08lx\n", i + 1, data);
        }
    }

    printf("Prueba de escritura en AD5940 completada.\n");
}