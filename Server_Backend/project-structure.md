# IoT Server Project Structure

```
iot-matlab-esp32-server/
├── app/
│   ├── __init__.py
│   ├── main.py                    # FastAPI application entry point
│   ├── config.py                  # Configuration and settings
│   ├── database.py                # Database connection and setup
│   ├── auth/
│   │   ├── __init__.py
│   │   ├── jwt_handler.py         # JWT token handling
│   │   └── auth_routes.py         # Authentication endpoints
│   ├── api/
│   │   ├── __init__.py
│   │   ├── devices.py             # ESP32 device management
│   │   ├── data.py                # Data collection endpoints
│   │   └── matlab.py              # MATLAB-specific endpoints
│   ├── mqtt/
│   │   ├── __init__.py
│   │   ├── client.py              # MQTT client setup
│   │   └── handlers.py            # MQTT message handlers
│   ├── models/
│   │   ├── __init__.py
│   │   ├── device.py              # Device database models
│   │   ├── sensor_data.py         # Sensor data models
│   │   └── user.py                # User models
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── device.py              # Pydantic schemas for devices
│   │   ├── sensor_data.py         # Pydantic schemas for sensor data
│   │   └── user.py                # User schemas
│   └── utils/
│       ├── __init__.py
│       ├── logger.py              # Logging configuration
│       └── helpers.py             # Utility functions
├── tests/
│   ├── __init__.py
│   ├── conftest.py                # Pytest configuration
│   ├── test_auth.py               # Authentication tests
│   ├── test_devices.py            # Device API tests
│   ├── test_data.py               # Data API tests
│   └── test_mqtt.py               # MQTT functionality tests
├── docker/
│   ├── Dockerfile                 # Production Docker image
│   ├── Dockerfile.dev             # Development Docker image
│   └── mosquitto.conf             # MQTT broker configuration
├── scripts/
│   ├── run_dev.py                 # Development server script
│   └── init_db.py                 # Database initialization
├── docs/
│   ├── api_documentation.md       # API documentation
│   ├── deployment_guide.md        # Deployment instructions
│   └── matlab_integration.md      # MATLAB usage guide
├── .env.example                   # Environment variables template
├── .gitignore                     # Git ignore file
├── docker-compose.yml             # Development environment
├── docker-compose.prod.yml        # Production environment
├── requirements.txt               # Python dependencies
├── requirements-dev.txt           # Development dependencies
├── pytest.ini                    # Pytest configuration
├── alembic.ini                    # Database migration config
└── README.md                      # Project documentation
```

## Key Components Explanation

### `/app` - Core Application
- **main.py**: FastAPI application instance and route registration
- **config.py**: Environment-based configuration management
- **database.py**: SQLAlchemy async engine and session management

### `/app/auth` - Authentication System
- **jwt_handler.py**: JWT token creation, validation, and refresh
- **auth_routes.py**: Login, logout, and token refresh endpoints

### `/app/api` - API Endpoints
- **devices.py**: ESP32 device registration, status, and management
- **data.py**: Sensor data collection, storage, and retrieval
- **matlab.py**: MATLAB-specific endpoints for data download and commands

### `/app/mqtt` - MQTT Integration
- **client.py**: MQTT client initialization and connection management
- **handlers.py**: MQTT message processing and database integration

### `/app/models` - Database Models
- SQLAlchemy models for devices, sensor data, and users
- Relationships and constraints for data integrity

### `/app/schemas` - API Validation
- Pydantic models for request/response validation
- Data serialization and type checking

### `/tests` - Testing Framework
- Comprehensive test coverage for all components
- Pytest fixtures and configuration
- Integration and unit tests

### `/docker` - Containerization
- Multi-stage Docker builds for development and production
- MQTT broker configuration
- Container optimization for IoT workloads

This structure follows FastAPI best practices and provides clear separation of concerns for maintainable, scalable IoT server development.