# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive Electrochemical Impedance Spectroscopy (EIS) system developed as a Bachelor's Final Project (TFG). The system consists of three main components:
- ESP32 firmware for controlling AD5940/AD5941 impedance measurement chips
- MATLAB desktop application for data acquisition and analysis
- Python FastAPI backend server for data management and cloud services

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

### Python Backend (`Server_Backend/`)
```bash
# Development server
uvicorn main:app --reload
python -m pytest      # Run tests
alembic upgrade head   # Apply database migrations
```

### MATLAB Application (`Matlab_Application/`)
- Open `.mlapp` files in MATLAB App Designer
- Run `EISApp.mlapp` to launch the main application
- Use `readAD5940Data.m` for hardware communication testing

## Architecture Overview

### Component Interaction
```
ESP32 + AD5940 ↔ [USB/WiFi] ↔ MATLAB App ↔ [HTTP/REST] ↔ Python Server ↔ PostgreSQL
```

### Key Directories
- `esp32_porting_AD594x/`: ESP32 firmware (C/C++, ESP-IDF/PlatformIO)
- `Matlab_Application/`: Desktop GUI application (MATLAB App Designer)
- `Server_Backend/`: FastAPI backend server (Python)

## Hardware Configuration

### AD5940 Measurement Parameters
- Frequency Range: 0.1 Hz to 200 kHz
- Excitation Voltage: 1-2200 mV peak-to-peak
- DC Bias: ±1.1V range
- TIA Resistor: 200Ω to 160kΩ selectable
- Target Hardware: ESP32-S3 DevKit with AD5940/AD5941 evaluation boards

## Communication Protocols

### ESP32 ↔ MATLAB
- Serial USB communication (115200 baud)
- WiFi TCP/IP connection
- JSON-based command protocol

### MATLAB ↔ Server
- RESTful HTTP API with JWT authentication
- Batch data upload/download capabilities

## Key Source Files

### ESP32 Firmware
- `src/main.c`: Main application entry point
- `lib/Impedance.c`: Core impedance measurement functions
- `lib/AD5940Main.c`: AD5940 chip initialization and control
- `lib/ESP32Port.c`: ESP32-specific hardware abstraction layer

### MATLAB Application
- `EISApp.m`: Main application class with GUI components
- `EISAppUtils.m`: Utility functions for data processing and analysis
- `readAD5940Data.m`: Hardware communication interface

### Python Backend
- FastAPI application with async/await support
- SQLAlchemy ORM for PostgreSQL database
- JWT-based authentication system
- MQTT support for IoT device communication

## Development Notes

### ESP32 Firmware
- Uses ESP-IDF framework with PlatformIO integration
- Implements CLI interface for parameter configuration
- Supports multiple output formats (compact, verbose, CSV)
- Real-time impedance measurements with frequency sweep capabilities

### MATLAB Application
- Professional GUI with modular tab-based architecture
- Integrates Zfit library for circuit model fitting
- Real-time data visualization (Nyquist, Bode plots)
- Dataset management and export capabilities

### Backend Server
- Async FastAPI with automatic API documentation
- PostgreSQL database with Alembic migrations
- RESTful API design for MATLAB integration
- Device management and sensor data storage

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
- JSON API responses for web integration