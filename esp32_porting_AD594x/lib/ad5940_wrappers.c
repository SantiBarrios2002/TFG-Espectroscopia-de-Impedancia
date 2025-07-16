#include "board_config.h"
#include "ad5940.h"

// Wrapper functions that delegate to the selected board implementation
void AD5940_CsSet(void) {
    if (current_board) {
        current_board->CsSet();
    }
}

void AD5940_CsClr(void) {
    if (current_board) {
        current_board->CsClr();
    }
}

void AD5940_RstSet(void) {
    if (current_board) {
        current_board->RstSet();
    }
}

void AD5940_RstClr(void) {
    if (current_board) {
        current_board->RstClr();
    }
}

uint32_t AD5940_GetMCUIntFlag(void) {
    if (current_board) {
        return current_board->GetMCUIntFlag();
    }
    return 0;
}

uint32_t AD5940_ClrMCUIntFlag(void) {
    if (current_board) {
        return current_board->ClrMCUIntFlag();
    }
    return 0;
}

void AD5940_Delay10us(uint32_t time) {
    if (current_board) {
        current_board->Delay10us(time);
    }
}

void AD5940_ReadWriteNBytes(unsigned char *pSendBuffer, unsigned char *pRecvBuff, unsigned long length) {
    if (current_board) {
        current_board->ReadWriteNBytes(pSendBuffer, pRecvBuff, length);
    }
}

uint32_t AD5940_MCUResourceInit(void *pCfg) {
    if (current_board) {
        return current_board->MCUResourceInit(pCfg);
    }
    return 1; // Error
}