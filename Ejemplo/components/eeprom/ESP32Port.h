#ifndef _ESP32PORT_H_
#define _ESP32PORT_H_

#include "ad5940.h"
#include <stdint.h>

// Function prototypes
void AD5940_CsPinCtrl(uint8_t level);
void AD5940_RstPinCtrl(uint8_t level);
uint32_t AD5940_ReadWrite(uint32_t data);
void AD5940_Delay10us(uint32_t time);
uint32_t AD5940_GetMCUIntFlag(void);
void AD5940_ClrMCUIntFlag(void);
void AD5940_MCUResourceInit(void);

#endif // _ESP32PORT_H_