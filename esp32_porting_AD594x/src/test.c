#include "ad5940.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#include "string.h"

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
  AD5940_MCUResourceInit(NULL);

	printf("MCU Initialised\n");

	// reset AD5940
	printf("Attempting to reset AD5940...\n");
	AD5940_HWReset();
	printf("AD5940 reset!\n");

	// initialise AD5940 by writing the startup sequence
	printf("Attempting to initialise AD5940...\n");
	AD5940_Initialize();
	printf("AD5940 initialised!\n");

	unsigned long temp;

  temp = AD5940_ReadReg(REG_AFECON_CHIPID);
  printf("Read ADIID register, got: 0x%04lx\n", temp);
  if(temp != 0x5502)
      printf("Read register test failed.\n" );
  else
      printf("Read register test passed\n");

	// write register test
  srand(0x1234);
  int i = 10;
	while(i--)
	{
		static unsigned long count;
		static unsigned long data;
		/* Generate a 32bit random data */
		data = rand()&0xffff;
		data <<= 16;
		data |= rand()&0xffff;
		count ++;	/* Read write count */
		/**
		 * Register CALDATLOCK is 32-bit width, it's readable and writable.
		 * We use it to test SPI register access.
		*/
		AD5940_WriteReg(REG_AFE_CALDATLOCK, data);
		temp = AD5940_ReadReg(REG_AFE_CALDATLOCK);
		if(temp != data)
		    printf("Write register test failed @0x%08lx\n", data);
		if(!(count%1000))
		    printf("Read/Write has been done %ld times, latest data is 0x%08lx\n", count, data);
	}
  printf("SPI read/write test completed");

	printf("Testing both ID registers:\n");

	uint32_t adiid = AD5940_ReadReg(REG_AFECON_ADIID);
	printf("ADIID:  0x%08lx (expected ~0x4144)\n", adiid);

	vTaskDelay(pdMS_TO_TICKS(10)); // Small delay between reads

	uint32_t chipid = AD5940_ReadReg(REG_AFECON_CHIPID);
	printf("CHIPID: 0x%08lx (expected 0x5500/5501/5502)\n", chipid);

	printf("\n=== Manual Register Test ===\n");

	// Try reading register 0x0000 (should be different from 0x0404)
	uint32_t reg0 = AD5940_ReadReg(0x0000);
	printf("Register 0x0000: 0x%08lx\n", reg0);

	uint32_t reg4 = AD5940_ReadReg(0x0004);  
	printf("Register 0x0004: 0x%08lx\n", reg4);

	uint32_t reg8 = AD5940_ReadReg(0x0008);
	printf("Register 0x0008: 0x%08lx\n", reg8);
}

