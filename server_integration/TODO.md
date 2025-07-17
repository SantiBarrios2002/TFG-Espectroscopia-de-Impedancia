# Server Integration TODO List

## Remaining Components to Implement

### 1. MQTT Message Schemas
- **File**: `mqtt/message_schemas.json`
- **Purpose**: Define JSON schema validation for all MQTT messages
- **Contains**: JSON Schema definitions for payload validation, error handling schemas

### 2. Node-RED Integration
- **File**: `node-red/flows.json`
- **Purpose**: Node-RED flow definitions for data processing
- **Contains**: 
  - MQTT subscriber flows
  - Data transformation flows
  - InfluxDB insertion flows
  - Dashboard creation flows
  - Alert/notification flows

- **File**: `node-red/dashboard_config.json`
- **Purpose**: Node-RED dashboard configuration
- **Contains**: Dashboard layout, widgets, charts for real-time monitoring

### 3. InfluxDB Configuration
- **File**: `influxdb/schema.sql`
- **Purpose**: Database schema for EIS measurements
- **Contains**: 
  - Measurement tables structure
  - Index definitions
  - Data types for impedance data

- **File**: `influxdb/retention_policy.json`
- **Purpose**: Data retention and downsampling policies
- **Contains**: Retention rules, aggregation policies, storage optimization

- **File**: `influxdb/queries.sql`
- **Purpose**: Common queries for MATLAB integration
- **Contains**: Prepared queries for data retrieval, aggregation queries

### 4. Configuration Files
- **File**: `config/mqtt_config.h`
- **Purpose**: ESP32 MQTT client configuration
- **Contains**: Connection parameters, topic definitions, SSL/TLS settings

- **File**: `config/matlab_config.json`
- **Purpose**: MATLAB server connection configuration
- **Contains**: Server endpoints, authentication, connection timeouts

- **File**: `config/docker-compose.override.yml`
- **Purpose**: IoTStack customizations for EIS system
- **Contains**: Custom service configurations, port mappings, volume mounts

### 5. Automation Scripts
- **File**: `scripts/setup_server.sh`
- **Purpose**: Automated server setup script
- **Contains**: IoTStack setup, service configuration, initial data setup

- **File**: `scripts/test_connection.py`
- **Purpose**: Connection testing and validation
- **Contains**: MQTT connection tests, InfluxDB connectivity tests, end-to-end testing

### 6. Documentation
- **File**: `docs/architecture.md`
- **Purpose**: System architecture documentation
- **Contains**: Component diagrams, data flow, integration patterns

- **File**: `docs/api_reference.md`
- **Purpose**: API documentation for integrations
- **Contains**: MQTT API, HTTP API, message formats

- **File**: `docs/troubleshooting.md`
- **Purpose**: Common issues and solutions
- **Contains**: Connection problems, performance tuning, debugging guides

- **File**: `README.md`
- **Purpose**: Integration setup guide
- **Contains**: Step-by-step setup instructions, prerequisites, configuration examples

## Implementation Priority

### High Priority (Core Functionality)
1. `mqtt/message_schemas.json` - Required for message validation
2. `config/mqtt_config.h` - ESP32 MQTT implementation
3. `config/matlab_config.json` - MATLAB server integration
4. `influxdb/schema.sql` - Database structure

### Medium Priority (Automation & Monitoring)
1. `node-red/flows.json` - Data processing automation
2. `scripts/setup_server.sh` - Deployment automation
3. `scripts/test_connection.py` - Testing and validation

### Low Priority (Documentation & Enhancement)
1. `docs/architecture.md` - System documentation
2. `docs/api_reference.md` - API documentation
3. `docs/troubleshooting.md` - Support documentation
4. `node-red/dashboard_config.json` - Monitoring dashboard

## Notes
- All configurations should support dual board system (AD5940/AD5941)
- Security considerations for MQTT authentication and SSL/TLS
- Performance optimization for high-frequency data streaming
- Integration with existing MATLAB codebase patterns