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