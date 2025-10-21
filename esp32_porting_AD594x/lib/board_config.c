#include "board_config.h"
#include <stddef.h>

board_interface_t *current_board = NULL;

void board_select(board_type_t board_type) {
    switch(board_type) {
        case BOARD_AD5940:
            current_board = &ad5940_interface;
            break;
        case BOARD_AD5941:
            current_board = &ad5941_interface;
            break;
        default:
            current_board = &ad5940_interface; // Default to AD5940
            break;
    }
}

// Wrapper functions that call through current_board pointer
// These are the functions that the AD5940 library expects to find

void AD5940_CsSet(void) {
    if (current_board && current_board->CsSet) {
        current_board->CsSet();
    }
}

void AD5940_CsClr(void) {
    if (current_board && current_board->CsClr) {
        current_board->CsClr();
    }
}

void AD5940_RstSet(void) {
    if (current_board && current_board->RstSet) {
        current_board->RstSet();
    }
}

void AD5940_RstClr(void) {
    if (current_board && current_board->RstClr) {
        current_board->RstClr();
    }
}

uint32_t AD5940_GetMCUIntFlag(void) {
    if (current_board && current_board->GetMCUIntFlag) {
        return current_board->GetMCUIntFlag();
    }
    return 0;
}

uint32_t AD5940_ClrMCUIntFlag(void) {
    if (current_board && current_board->ClrMCUIntFlag) {
        return current_board->ClrMCUIntFlag();
    }
    return 0;
}

void AD5940_Delay10us(uint32_t time) {
    if (current_board && current_board->Delay10us) {
        current_board->Delay10us(time);
    }
}

void AD5940_ReadWriteNBytes(unsigned char *pSendBuffer, unsigned char *pRecvBuff, unsigned long length) {
    if (current_board && current_board->ReadWriteNBytes) {
        current_board->ReadWriteNBytes(pSendBuffer, pRecvBuff, length);
    }
}

uint32_t AD5940_MCUResourceInit(void *pCfg) {
    if (current_board && current_board->MCUResourceInit) {
        return current_board->MCUResourceInit(pCfg);
    }
    return 0;
}