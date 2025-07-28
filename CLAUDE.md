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
- **EISAppV2.m created**: Implemented complete path-based MATLAB interface with server integration and ESP32 status monitoring

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


## System Operating Modes

The EIS system supports three distinct operating modes to accommodate different measurement scenarios:

### Mode 1: Real-Time Interactive Measurements
- **Communication**: MATLAB ↔ MQTT ↔ ESP32 (bidirectional)
- **Data Storage**: ESP32 → MQTT → Node-RED → InfluxDB (automatic)
- **User Experience**: Live visualization with immediate parameter control
- **Use Cases**: Interactive experimentation, parameter optimization, immediate analysis
- **Data Persistence**: All measurements automatically stored for later analysis

### Mode 2: Scheduled Autonomous Measurements
- **Programming Phase**: MATLAB → MQTT → ESP32 (schedule configuration)
- **Execution Phase**: ESP32 → MQTT → Node-RED → InfluxDB (autonomous)
- **User Experience**: Program schedule, exit MATLAB, return later for results
- **Use Cases**: Long-term studies (days/weeks), unattended monitoring, battery characterization
- **ESP32 Features**: Internal scheduling, NVS persistence, power management

### Mode 3: Historical Data Analysis
- **Communication**: MATLAB ↔ HTTP ↔ Node-RED ↔ InfluxDB
- **Data Source**: Previously stored measurements from Modes 1 & 2
- **User Experience**: Browse, query, and download historical datasets
- **Use Cases**: Offline analysis, comparative studies, report generation
- **No ESP32 Required**: Pure server-side data access

## Server Architecture

### Complete System Architecture
```
MATLAB GUI ↔ [HTTP/MQTT] ↔ Node-RED ↔ MQTT Broker ↔ ESP32 (AD5940/AD5941)
                              ↓
                          InfluxDB (Time-series data)
```

### Dual Communication Strategy

**Dataset Management (HTTP/REST):**
- **Purpose**: Historical data queries, bulk dataset downloads (Mode 3)
- **Protocol**: HTTP requests to Node-RED endpoints
- **Use Cases**: 
  - Browse and select datasets from server
  - Download measurement history for analysis
  - Query data by date, device, measurement type
- **Benefits**: Efficient for large data transfers, caching capabilities

**Real-time Operations (MQTT):**
- **Purpose**: Live measurement control and data streaming (Modes 1 & 2)
- **Protocol**: MQTT publish/subscribe
- **Use Cases**:
  - Real-time board selection (AD5940/AD5941)
  - Live impedance data streaming during measurements
  - Schedule programming for autonomous operation
  - Immediate parameter configuration (frequencies, RTIA values)
- **Benefits**: Low latency, continuous streaming, multiple client support

### MATLAB Frontend Architecture: Path-Based UI Design

**Design Philosophy:**
The MATLAB frontend has been redesigned from a tab-based to a path-based interface to eliminate user errors and create a logical workflow. The new architecture prevents dataset confusion and guides users through appropriate measurement sequences.

**Path-Based Navigation Flow:**
```
Server Connection → Mode Selection → [Database Path OR Measurement Path] → Analysis/Fitting
                                    ↓                    ↓
                           Database Browser    Board Selection → Measurement Mode → [Scheduled Exit OR Real-time Measurement]
```

### EISAppV2 Implementation

**New Path-Based Interface (`EISAppV2.m`):**
- **Single Screen Navigation**: Replaces confusing tab system with guided workflow
- **ESP32 Status Integration**: Real-time device status checking to prevent mode conflicts
- **Server-First Architecture**: All communication via MQTT/HTTP server integration
- **Error Prevention**: Visual indicators and disabled controls prevent invalid operations

**Screen-by-Screen Workflow:**

**1. Server Connection Screen:**
- MQTT broker configuration (IP, port, credentials)  
- Node-RED server settings (HTTP endpoint)
- Automatic ESP32 status detection via MQTT
- Connection validation before proceeding

**2. Mode Selection Screen:**
- **ESP32 Status Display**: Visual indicators showing current device state
- **Database Analysis Path**: Access historical measurement data
- **Measurement Path**: Perform new measurements (disabled if ESP32 busy)
- **Conflict Prevention**: Real-time status updates prevent mode conflicts

**3a. Database Path:**
```
Mode Selection → Database Browser → Analysis/Fitting (Final Endpoint)
```

**3b. Measurement Path:**
```
Mode Selection → Board Selection (AD5940/AD5941) → Measurement Mode → [Scheduled Config → App Exit] OR [Real-time → Analysis/Fitting]
```

**ESP32 Status Integration:**
```matlab
% Automatic status checking via MQTT
function getESP32Status(app)
    status_msg = receive(app.MQTTClient, 'esp32/status/mode', 'Timeout', 5);
    app.ESP32Status = jsondecode(status_msg.Data);
end

% Visual status indicators
switch app.ESP32Status.mode
    case 'STANDBY'     % Green - Ready for commands
    case 'SCHEDULED'   % Yellow - Running autonomous measurements  
    case 'REALTIME'    % Red - Connected to another client
end
```

**Scheduled Mode Implementation:**
```matlab
% Complete schedule programming
schedule_config = struct();
schedule_config.board = app.SelectedBoard;           % AD5940/AD5941
schedule_config.measurements = 10;                   % Number of measurements
schedule_config.interval_hours = 24;                 % Measurement interval
schedule_config.freq_start = 0.1;                    % Frequency range
schedule_config.freq_end = 100000;
schedule_config.num_points = 50;                     % Points per measurement

% Send to ESP32 and exit MATLAB
publish(app.MQTTClient, 'esp32/cmd/schedule', jsonencode(schedule_config));
```

**Mode 1: Real-time Operation:**
```matlab
% Send measurement parameters via MQTT
publish(mqtt_client, 'esp32/cmd/config', '{"board":"AD5941","freq_start":1,"freq_end":100000}');

% Subscribe to live impedance data (also stored automatically)
subscribe(mqtt_client, 'sensors/eis/data', @onRealtimeData);
```

**Mode 2: Schedule Programming:**
```matlab
% Program autonomous measurement schedule
schedule = struct('measurements', 10, 'interval_hours', 24, 'board', 'AD5940');
publish(mqtt_client, 'esp32/cmd/schedule', jsonencode(schedule));

% Exit MATLAB - ESP32 runs independently
```

**Mode 3: Dataset Management:**
```matlab
% Query available datasets via HTTP
datasets = webread('http://node-red:1880/api/datasets', 'device_id', 'esp32_001');

% Download specific dataset
data = webread('http://node-red:1880/api/dataset/12345');
```

### ESP32 State Management Architecture

**Operating States:**
```c
typedef enum {
    MODE_STANDBY,       // Waiting for commands
    MODE_REALTIME,      // Interactive measurements (Mode 1)
    MODE_SCHEDULED      // Autonomous scheduled measurements (Mode 2)
} system_mode_t;
```

**State Management Features:**
- **NVS Persistence**: Schedules survive reboots and power cycles
- **FreeRTOS Timers**: Precise timing for scheduled measurements
- **Task Management**: Clean transitions between operating modes
- **Power Efficiency**: Deep sleep support during long intervals
- **Error Recovery**: Robust handling of network/measurement failures

**Implementation Capabilities:**
- **Mode Transitions**: Runtime switching based on MQTT commands
- **Schedule Storage**: Complex measurement schedules in non-volatile storage
- **Autonomous Operation**: Independent execution without MATLAB connection
- **Status Reporting**: Battery level, measurement progress, error states

### Node-RED Integration Benefits
- **Unified Data Storage**: All modes store data identically in InfluxDB
- **Scalability**: Multiple ESP32 devices and MATLAB clients
- **Real-time monitoring**: Live dashboards for measurement data
- **Data persistence**: Guaranteed storage regardless of client connections
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
- `EISApp.m`: Original tab-based application class with GUI components (legacy)
- `EISAppV2.m`: **New path-based application with server integration and ESP32 status monitoring**
- `EISAppUtils.m`: Utility functions for data processing and analysis

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
- **Multi-Mode Operation**: Supports real-time, scheduled, and standby operating modes
- **State Management**: FreeRTOS-based state machine with NVS persistence
- **Autonomous Scheduling**: Independent measurement execution with configurable intervals
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
- **Path-Based Interface Design**: New EISAppV2.m with guided workflow replacing confusing tab system
- **ESP32 Status Integration**: Real-time device status monitoring to prevent mode conflicts
- **Multi-Mode Interface**: Supports all three operating modes (real-time, scheduled, historical)
- **Error Prevention**: Visual indicators and disabled controls prevent invalid operations
- **Single Screen Navigation**: Clean screen-by-screen workflow with Back/Next/Cancel controls
- **Real-time Data**: MQTT client for live measurement streaming from ESP32 via server
- **Schedule Programming**: Complete interface for configuring autonomous measurement schedules
- **Dataset Management**: Node-RED integration for downloading stored datasets from InfluxDB
- **Analysis Tools**: Integrates Zfit library for circuit model fitting (endpoint for all paths)
- **Visualization**: Real-time data visualization (Nyquist, Bode plots)
- **Export Capabilities**: Multiple format support for data export
- **Dual Architecture**: Legacy EISApp.m (tab-based) and new EISAppV2.m (path-based)


## Development Environment

### Current Development Status (Updated)
- **ESP32 Firmware**: Dual board support implemented and functional
  - Production firmware ready for server integration (src/main.c)
  - MQTT test implementation complete (test/main.c) with WiFi, JSON processing, and device management
  - Text protocol restored for compatibility with both server and debug interfaces
  - **Multi-mode architecture designed**: State management framework ready for implementation
- **MATLAB Application**: Path-based interface implemented and functional
  - **EISAppV2.m completed**: Path-based workflow with server integration and ESP32 status monitoring
  - **Error Prevention**: Visual status indicators and conflict prevention implemented
  - **Server Integration**: MQTT client and HTTP communication ready for deployment
  - **Legacy Support**: Original EISApp.m maintained for reference
- **Server Backend Phase 1**: Foundation components complete (MQTT schemas, Node-RED flows, InfluxDB schema, MATLAB config)
- **Server Backend Phase 2**: Ready for Raspberry Pi deployment and end-to-end testing

### Development Workflow
- **MQTT Testing**: Use test/main.c for complete MQTT integration testing with server
- **Production Deployment**: Use src/main.c with server integration (dual board tasks ready)
- **Multi-Mode Implementation**: Add state management and scheduling to ESP32 firmware
- **MATLAB Frontend**: EISAppV2.m path-based interface ready for server deployment
- **Testing Workflow**: Use EISAppV2.m for complete path-based user experience testing
- **Server Integration**: All Phase 1 components ready for Raspberry Pi deployment
- **Next Steps**: Deploy Node-RED flows, setup InfluxDB, test end-to-end multi-mode pipeline with EISAppV2

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