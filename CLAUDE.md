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
# Development server (standalone)
cd Server_Backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Docker development environment
docker-compose up --build     # Start all services (PostgreSQL, Redis, MQTT, FastAPI)
docker-compose down           # Stop all services
docker-compose logs app       # View application logs

# Testing and database
python -m pytest             # Run tests with coverage
alembic upgrade head          # Apply database migrations
alembic revision --autogenerate -m "description"  # Create new migration

# Production deployment
docker-compose -f docker-compose.prod.yml up -d
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
  - `app/`: Main application code (FastAPI, models, schemas, API endpoints)
  - `docker/`: Docker configuration files (Dockerfile, docker-compose)
  - `tests/`: Comprehensive test suite with pytest
  - `docs/`: API documentation and deployment guides

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

### Python Backend (`Server_Backend/app/`)
- `main.py`: FastAPI application with async lifespan management
- `database.py`: Async SQLAlchemy setup with PostgreSQL
- `config.py`: Environment-based configuration management
- `auth/`: JWT authentication system (login, register, password management)
- `api/`: REST API endpoints (devices, data collection, MATLAB integration)
- `models/`: SQLAlchemy database models (Device, User, SensorData)
- `schemas/`: Pydantic validation schemas for API requests/responses
- `mqtt/`: MQTT client for ESP32 device communication
- `utils/`: Logging configuration and utility functions

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
- **FastAPI Framework**: Async/await support with automatic OpenAPI documentation
- **Database**: PostgreSQL with async SQLAlchemy ORM and Alembic migrations
- **Authentication**: JWT-based auth with access/refresh tokens
- **API Design**: RESTful endpoints for device management, data collection, MATLAB integration
- **MQTT Integration**: Real-time communication with ESP32 devices
- **Docker Support**: Complete containerized development and production environments
- **Testing**: Comprehensive test suite with pytest, coverage, and CI/CD ready
- **Configuration**: Environment-based settings with validation

## Development Environment

### Server Backend Docker Services
- **PostgreSQL**: Primary database (port 5432)
- **Redis**: Session storage and caching (port 6379)
- **MQTT Broker (Mosquitto)**: Device communication (ports 1883, 9001)
- **FastAPI Application**: Main server (port 8000)
- **Adminer**: Database management UI (port 8080)

### Configuration Files
- `.env.example`: Environment variables template
- `pytest.ini`: Test configuration with coverage and async support
- `alembic.ini`: Database migration configuration
- `docker-compose.yml`: Development environment
- `docker-compose.prod.yml`: Production deployment with Nginx, monitoring

### API Documentation
- **Interactive Docs**: Available at `http://localhost:8000/docs` (Swagger UI)
- **ReDoc**: Available at `http://localhost:8000/redoc`
- **Health Check**: `GET /health` endpoint for monitoring

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

### Server Testing
- **Unit Tests**: Individual component testing
- **Integration Tests**: API endpoint testing
- **Database Tests**: Model and migration testing
- **Authentication Tests**: JWT token and user management testing
- **Coverage Reports**: HTML and XML coverage reports generated