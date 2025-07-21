# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive Electrochemical Impedance Spectroscopy (EIS) system developed as a Bachelor's Final Project (TFG). The system currently consists of two main components:
- ESP32 firmware for controlling AD5940/AD5941 impedance measurement chips
- MATLAB desktop application acting as a frontend for data acquisition and analysis

The MATLAB application serves as the primary frontend interface with two main server connections:
1. **Real-time measurements**: MQTT connection to server for live ESP32/board data acquisition
2. **Dataset management**: Node-RED connection to server for downloading datasets from InfluxDB databases

Note: A backend server for data management and cloud services will be developed separately for Raspberry Pi deployment using IoTStack containers. Additionally, wired USB connections will be maintained for debugging purposes.

## Development Memories

- Every time we create new files we update the CLAUDE.md file

## Build and Development Commands

### ESP32 Firmware (`esp32_porting_AD594x/`)
```bash
# ESP-IDF workflow
idf.py build           # Compile firmware
idf.py flash          # Flash to ESP32
idf.py monitor        # Serial monitoring

# PlatformIO workflow
pio build             # Build project
pio upload            # Upload firmware
pio device monitor    # Monitor serial output
```


### MATLAB Application (`Matlab_Application/`)
- Open `.mlapp` files in MATLAB App Designer
- Run `EISApp.mlapp` to launch the main application
- Use `readAD5940Data.m` for hardware communication testing

## Architecture Overview

### Component Interaction
```
ESP32 + AD5940/AD5941 ↔ [MQTT via Server] ↔ MATLAB Frontend App ↔ [Node-RED] ↔ InfluxDB
                     ↔ [USB - Debug only] ↔
```

### Key Directories
- `esp32_porting_AD594x/`: ESP32 firmware (C/C++, ESP-IDF/PlatformIO)
- `Matlab_Application/`: Desktop GUI application (MATLAB App Designer)
- `server_integration/`: IoTStack server integration configurations and specifications

## Hardware Configuration

### AD5940/AD5941 Measurement Parameters
- Frequency Range: 0.1 Hz to 200 kHz
- Excitation Voltage: 1-2200 mV peak-to-peak
- DC Bias: ±1.1V range
- TIA Resistor: 200Ω to 160kΩ selectable
- Target Hardware: ESP32-S3 DevKit with AD5940/AD5941 evaluation boards

### Dual Board Pin Configuration
**AD5940 Board:**
- SPI: SCLK=13, MISO=12, MOSI=14
- Control: CS=9, INT=10, RST=11

**AD5941 Board:**
- SPI: SCLK=18, MISO=19, MOSI=23
- Control: CS=4, INT=3, RST=15

### Board Selection System
- **Function Pointer Interface**: `board_interface_t` structure with board-specific implementations
- **Runtime Switching**: `board_select(BOARD_AD5940)` or `board_select(BOARD_AD5941)`
- **MATLAB Integration**: Board selection commands sent via serial/WiFi communication
- **Hardware Isolation**: Separate pin assignments prevent SPI bus conflicts

## Communication Protocols

### Production Architecture
**ESP32 ↔ Server ↔ MATLAB Frontend:**
- **MQTT**: Real-time data streaming from ESP32 to server, consumed by MATLAB
- **Node-RED**: Dataset download from InfluxDB database to MATLAB
- **InfluxDB**: Time-series database for measurement storage
- **JSON Protocol**: Standardized data format across all components

### Development/Debug Architecture
**ESP32 ↔ MATLAB (Direct):**
- Serial USB communication (115200 baud) - **Debug only**
- WiFi TCP/IP connection - **Debug only**
- JSON-based command protocol
- **Board Selection Commands**: Runtime switching between AD5940/AD5941 boards
- **Example Commands**: `"SELECT_BOARD:AD5940"`, `"SELECT_BOARD:AD5941"`


## Future Architecture: Node-RED Integration

### Planned Server Architecture
```
MATLAB GUI ↔ [HTTP/MQTT] ↔ Node-RED ↔ MQTT Broker ↔ ESP32 (AD5940/AD5941)
                              ↓
                          InfluxDB (Time-series data)
```

### Dual Communication Strategy

**Dataset Management (HTTP/REST):**
- **Purpose**: Historical data queries, bulk dataset downloads
- **Protocol**: HTTP requests to Node-RED endpoints
- **Use Cases**: 
  - Browse and select datasets from server
  - Download measurement history for analysis
  - Query data by date, device, measurement type
- **Benefits**: Efficient for large data transfers, caching capabilities

**Real-time Operations (MQTT):**
- **Purpose**: Live measurement control and data streaming
- **Protocol**: MQTT publish/subscribe
- **Use Cases**:
  - Real-time board selection (AD5940/AD5941)
  - Live impedance data streaming during measurements
  - Immediate parameter configuration (frequencies, RTIA values)
- **Benefits**: Low latency, continuous streaming, multiple client support

### MATLAB Frontend Features

**1. Real-time Operation Mode:**
```matlab
% Send measurement parameters via MQTT
publish(mqtt_client, 'esp32/cmd/config', '{"board":"AD5941","freq_start":1,"freq_end":100000}');

% Subscribe to live impedance data
subscribe(mqtt_client, 'sensors/eis/data', @onRealtimeData);
```

**2. Dataset Management Mode:**
```matlab
% Query available datasets via HTTP
datasets = webread('http://node-red:1880/api/datasets', 'device_id', 'esp32_001');

% Download specific dataset
data = webread('http://node-red:1880/api/dataset/12345');
```

### Node-RED Integration Benefits
- **Scalability**: Multiple ESP32 devices and MATLAB clients
- **Real-time monitoring**: Live dashboards for measurement data
- **Data persistence**: InfluxDB for time-series storage
- **Flexibility**: Easy integration of additional data sources
- **Protocol bridging**: Seamless conversion between HTTP, MQTT, and database protocols

## Key Source Files

### ESP32 Firmware
- `src/main.c`: Production main application with dual board support (ready for server)
- `test/main.c`: Complete MQTT test implementation with WiFi and JSON processing
- `src/test_spi.c`: SPI testing application for board validation
- `lib/Impedance.c`: Core impedance measurement functions (AD5940)
- `lib/BATImpedance.c`: Battery impedance measurement functions (AD5941)
- `lib/AD5940Main.c`: AD5940 chip initialization and control
- `lib/AD5941Main.c`: AD5941 chip initialization and control
- `lib/ESP32Port_AD5940.c`: Hardware abstraction layer for AD5940 board
- `lib/ESP32Port_AD5941.c`: Hardware abstraction layer for AD5941 board with precharge GPIO
- `lib/board_config.c`: Dual board selection and interface management
- `include/board_config.h`: Board interface definitions and function pointers
- `include/mqtt_config.h`: MQTT client configuration and topic structures

### MATLAB Application
- `EISApp.m`: Main application class with GUI components
- `EISAppUtils.m`: Utility functions for data processing and analysis
- `readAD5940Data.m`: Hardware communication interface

### Server Integration
- `server_integration/mqtt/message_schemas.json`: Complete JSON schemas for MQTT message validation
- `server_integration/node-red/flows.json`: Complete Node-RED flows for MQTT processing and REST API endpoints
- `server_integration/influxdb/schema.sql`: InfluxDB database schema and setup documentation
- `server_integration/config/matlab_config.json`: MATLAB server integration configuration
- `server_integration/include/mqtt_config.h`: ESP32 MQTT client configuration header
- `server_integration/TODO.md`: Remaining integration components to implement


## Development Notes

### ESP32 Firmware
- Uses ESP-IDF framework with PlatformIO integration
- **Dual Board Support**: Supports both AD5940 and AD5941 impedance measurement chips
- **Runtime Board Selection**: Switch between boards without recompilation via commands
- **Function Pointer Interface**: Clean abstraction layer for board-specific implementations
- **Hardware Isolation**: Separate pin configurations for each board to avoid conflicts
- **Text Protocol**: Reverted from binary to text protocol for easier debugging and server integration
- **Serial Debug Interface**: Interactive command system via PlatformIO Serial Monitor
- **Dual Main Files**: Separate main.c (for server) and main_serial.c (for debugging)
- **Naming Conflict Resolution**: Fixed function and variable naming conflicts between AD5940/AD5941 libraries
- Real-time impedance measurements with frequency sweep capabilities

#### Key Implementation Files:
- `src/main.c`: Production main file for server integration with dual board task functions
- `src/main_serial.c`: Debug main file with interactive serial interface
- `lib/AD5940Main.c`: AD5940 board implementation (Impedance.c functionality)
- `lib/AD5941Main.c`: AD5941 board implementation (BATImpedance.c functionality) 
- `lib/BATImpedance.c`: Battery impedance measurement library (fixed compiler warnings)
- `lib/ESP32Port_AD5940.c`: ESP32 hardware abstraction for AD5940 board
- `lib/ESP32Port_AD5941.c`: ESP32 hardware abstraction for AD5941 board with precharge control

#### Recent Implementation Updates:
- **Arduino_WriteDn Function**: Implemented ESP32 version of ADI's precharge control function
  - Maps ADI digital pins D3/D4 to ESP32 GPIO 17/18
  - Enables BATImpedance.c precharge functionality for battery measurements
  - Resolves linking errors between ADI library and ESP32 platform
- **Dual Board Compilation**: Both AD5940 and AD5941 functionality compiles simultaneously
  - Fixed naming conflicts (AppBuff → AppBATBuff in AD5941Main.c)
  - Fixed compiler warnings in BATImpedance.c (indentation, format specifiers)
- **Production-Ready Main**: Clean main.c with both board functionalities ready for server integration

### MATLAB Application (Frontend)
- **Frontend Architecture**: Acts as primary user interface for the EIS system
- **Server-Only Communication**: MATLAB connects exclusively via server (MQTT/HTTP), no direct serial connection
- **Real-time Data**: MQTT client for live measurement streaming from ESP32 via server
- **Dataset Management**: Node-RED integration for downloading stored datasets from InfluxDB
- **GUI Features**: Professional interface with modular tab-based architecture
- **Analysis Tools**: Integrates Zfit library for circuit model fitting
- **Visualization**: Real-time data visualization (Nyquist, Bode plots)
- **Export Capabilities**: Multiple format support for data export
- **Clean Architecture**: Removed direct serial communication code (readAD5940Data.m deleted)


## Development Environment

### Current Development Status (Updated)
- **ESP32 Firmware**: Dual board support implemented and functional
  - Production firmware ready for server integration (src/main.c)
  - MQTT test implementation complete (test/main.c) with WiFi, JSON processing, and device management
  - Text protocol restored for compatibility with both server and debug interfaces
- **MATLAB Application**: Prepared for server-only communication
- **Server Backend Phase 1**: Foundation components complete (MQTT schemas, Node-RED flows, InfluxDB schema, MATLAB config)
- **Server Backend Phase 2**: Ready for Raspberry Pi deployment and end-to-end testing

### Development Workflow
- **MQTT Testing**: Use test/main.c for complete MQTT integration testing with server
- **Production Deployment**: Use src/main.c with server integration (dual board tasks ready)
- **Server Integration**: All Phase 1 components ready for Raspberry Pi deployment
- **Next Steps**: Deploy Node-RED flows, setup InfluxDB, test end-to-end pipeline

## Testing and Validation

### Measurement Capabilities
- Single frequency measurements
- Frequency sweeps (linear/logarithmic)
- Bioimpedance spectroscopy applications
- Battery characterization and material testing

### Data Formats
- Real-time streaming data
- CSV export for analysis
- MATLAB .mat file format
- JSON API responses for future web integration