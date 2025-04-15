idf_component_register(SRCS "Test_SPI.c" "spi_eeprom.c" "ad5940.c" "ESP32Port.c" "Impedance.c" "BodyImpedance.c"
                    LDFRAGMENTS "linker.lf"
                    INCLUDE_DIRS "."
                    PRIV_REQUIRES driver)
