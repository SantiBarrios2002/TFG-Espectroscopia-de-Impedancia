#ifndef BOARD_CONFIG_H
#define BOARD_CONFIG_H

#include <stdint.h>

typedef struct {
    void (*CsSet)(void);
    void (*CsClr)(void);
    void (*RstSet)(void);
    void (*RstClr)(void);
    uint32_t (*GetMCUIntFlag)(void);
    uint32_t (*ClrMCUIntFlag)(void);
    void (*Delay10us)(uint32_t time);
    void (*ReadWriteNBytes)(unsigned char *pSendBuffer, unsigned char *pRecvBuff, unsigned long length);
    uint32_t (*MCUResourceInit)(void *pCfg);
} board_interface_t;

extern board_interface_t ad5940_interface;
extern board_interface_t ad5941_interface;

typedef enum {
    BOARD_AD5940,
    BOARD_AD5941
} board_type_t;

extern board_interface_t *current_board;

void board_select(board_type_t board_type);

// Wrapper functions that the AD5940 library expects
// These call through the current_board pointer for runtime board switching
void AD5940_CsSet(void);
void AD5940_CsClr(void);
void AD5940_RstSet(void);
void AD5940_RstClr(void);
uint32_t AD5940_GetMCUIntFlag(void);
uint32_t AD5940_ClrMCUIntFlag(void);
void AD5940_Delay10us(uint32_t time);
void AD5940_ReadWriteNBytes(unsigned char *pSendBuffer, unsigned char *pRecvBuff, unsigned long length);
uint32_t AD5940_MCUResourceInit(void *pCfg);

#endif