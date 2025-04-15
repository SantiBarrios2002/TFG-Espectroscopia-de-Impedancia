#ifndef TEST_SPI_H
#define TEST_SPI_H

void initialize_ad5940(void);
void validate_ad5940_id(void);
void validate_ad5940_write(); // Llamada a la prueba de escritura

#endif // TEST_SPI_H
