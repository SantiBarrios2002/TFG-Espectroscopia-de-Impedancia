/*

Copyright (c) 2017-2019 Analog Devices, Inc. All Rights Reserved.

This software is proprietary to Analog Devices, Inc. and its licensors.
By using this software you agree to the terms of the associated
Analog Devices Software License Agreement.

*/

#include "stdio.h"
#include "ad5940.h"

/* Functions that used to initialize MCU platform */
uint32_t MCUPlatformInit(void *pCfg);

int main(void)
{
  void AD5940_Main(void);
  MCUPlatformInit(0);
  AD5940_MCUResourceInit(0);
  printf("Hello AD5940-Build Time:%s\n",__TIME__);
  AD5940_Main();
}

/* Below functions are used to initialize MCU Platform */
uint32_t MCUPlatformInit(void *pCfg)
{
  /* Clock Configure */
  /* Configure system clock */
  
  /* UART Configure */
  /* Configure UART for debug output */
  
  /* GPIO Configure */
  /* Configure GPIO pins */
  
  return 0;
}