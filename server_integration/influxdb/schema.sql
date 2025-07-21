-- InfluxDB Schema for EIS Dual Board System
-- This file defines the database structure for storing impedance measurement data
-- from both AD5940 and AD5941 boards

-- Note: InfluxDB 2.x uses a different data model than traditional SQL
-- This file serves as documentation and can be adapted for InfluxDB setup

-- ============================================================================
-- MEASUREMENT DATA BUCKETS
-- ============================================================================

-- Bucket: eis_measurements
-- Retention: 30 days for raw data
-- Purpose: Store all impedance measurement data from both boards
-- Organization: eis_project

-- Measurement Schema for AD5940 (Standard Impedance Spectroscopy)
-- Measurement name: ad5940_impedance
-- Tags (indexed):
--   - device_id: ESP32 device identifier (MAC address)
--   - board_type: "AD5940"
--   - measurement_id: Unique measurement session identifier
--   - measurement_type: "impedance_sweep", "single_frequency"
-- Fields (not indexed):
--   - frequency: Measurement frequency in Hz (float)
--   - magnitude: Impedance magnitude in Ohms (float)
--   - phase: Impedance phase in degrees (float)
--   - real: Real component of impedance (float)
--   - imaginary: Imaginary component of impedance (float)
--   - firmware_version: ESP32 firmware version (string)
-- Time: timestamp of measurement

-- Example InfluxDB Line Protocol for AD5940:
-- ad5940_impedance,device_id=001122334455,board_type=AD5940,measurement_id=meas_123456,measurement_type=impedance_sweep frequency=1000.0,magnitude=125.5,phase=-45.2,real=88.7,imaginary=-89.3,firmware_version="1.0.0" 1640995200000000000

-- Measurement Schema for AD5941 (Battery Impedance)
-- Measurement name: ad5941_battery
-- Tags (indexed):
--   - device_id: ESP32 device identifier (MAC address)
--   - board_type: "AD5941"
--   - measurement_id: Unique measurement session identifier
--   - measurement_type: "battery_impedance"
--   - precharge_state: "RCAL", "BATTERY", "AMP"
-- Fields (not indexed):
--   - frequency: Measurement frequency in Hz (float)
--   - real: Real component in mOhm (float)
--   - imaginary: Imaginary component in mOhm (float)
--   - magnitude: Calculated magnitude in mOhm (float)
--   - phase: Calculated phase in degrees (float)
--   - firmware_version: ESP32 firmware version (string)
-- Time: timestamp of measurement

-- Example InfluxDB Line Protocol for AD5941:
-- ad5941_battery,device_id=001122334455,board_type=AD5941,measurement_id=meas_123456,measurement_type=battery_impedance,precharge_state=BATTERY frequency=50000.0,real=15.2,imaginary=-8.7,magnitude=17.5,phase=-29.8,firmware_version="1.0.0" 1640995200000000000

-- ============================================================================
-- SYSTEM STATUS BUCKETS
-- ============================================================================

-- Bucket: eis_system
-- Retention: 7 days
-- Purpose: Store system status, health, and operational data
-- Organization: eis_project

-- System Status Schema
-- Measurement name: system_status
-- Tags (indexed):
--   - device_id: ESP32 device identifier
--   - system_state: "idle", "measuring", "error", "initializing"
-- Fields (not indexed):
--   - uptime_seconds: System uptime in seconds (integer)
--   - memory_free: Free memory in bytes (integer)
--   - wifi_rssi: WiFi signal strength in dBm (integer)
--   - firmware_version: ESP32 firmware version (string)
--   - board_type: Currently selected board type (string)

-- System Errors Schema
-- Measurement name: system_errors
-- Tags (indexed):
--   - device_id: ESP32 device identifier
--   - error_code: Error code identifier (string)
--   - severity: "info", "warning", "error", "critical"
-- Fields (not indexed):
--   - error_message: Human readable error message (string)
--   - context: Additional context about the error (string)
--   - firmware_version: ESP32 firmware version (string)

-- Board Selection Events Schema
-- Measurement name: board_selection
-- Tags (indexed):
--   - device_id: ESP32 device identifier
--   - selected_board: "AD5940", "AD5941"
--   - status: "success", "error"
-- Fields (not indexed):
--   - message: Success or error message (string)
--   - request_id: Matching request identifier (string)
--   - firmware_version: ESP32 firmware version (string)

-- ============================================================================
-- INFLUXDB 2.x SETUP COMMANDS
-- ============================================================================

-- Create Organization (run once)
-- influx org create -n eis_project

-- Create Buckets (run once)
-- influx bucket create -n eis_measurements -r 30d -o eis_project
-- influx bucket create -n eis_system -r 7d -o eis_project

-- Create API Token for Write Access
-- influx auth create -o eis_project --read-bucket eis_measurements --read-bucket eis_system --write-bucket eis_measurements --write-bucket eis_system

-- ============================================================================
-- COMMON QUERIES FOR MATLAB INTEGRATION
-- ============================================================================

-- Query 1: Get latest measurements for a specific device and board
-- from(bucket: "eis_measurements")
--   |> range(start: -1h)
--   |> filter(fn: (r) => r._measurement == "ad5940_impedance" and r.device_id == "001122334455")
--   |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")

-- Query 2: Get frequency sweep data for analysis
-- from(bucket: "eis_measurements")
--   |> range(start: -24h)
--   |> filter(fn: (r) => r._measurement == "ad5940_impedance" and r.measurement_type == "impedance_sweep")
--   |> filter(fn: (r) => r.measurement_id == "meas_123456")
--   |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
--   |> sort(columns: ["frequency"])

-- Query 3: Get system health for monitoring
-- from(bucket: "eis_system")
--   |> range(start: -1h)
--   |> filter(fn: (r) => r._measurement == "system_status")
--   |> filter(fn: (r) => r.device_id == "001122334455")
--   |> last()

-- Query 4: Get battery impedance data with precharge states
-- from(bucket: "eis_measurements")
--   |> range(start: -1h)
--   |> filter(fn: (r) => r._measurement == "ad5941_battery")
--   |> filter(fn: (r) => r.device_id == "001122334455")
--   |> filter(fn: (r) => r.precharge_state == "BATTERY")
--   |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")

-- Query 5: Aggregate data by time windows for dashboard
-- from(bucket: "eis_measurements")
--   |> range(start: -24h)
--   |> filter(fn: (r) => r._measurement == "ad5940_impedance")
--   |> filter(fn: (r) => r._field == "magnitude")
--   |> aggregateWindow(every: 10m, fn: mean, createEmpty: false)

-- ============================================================================
-- DATA RETENTION POLICIES
-- ============================================================================

-- Raw measurement data: 30 days
-- Downsampled 1-minute averages: 6 months (created via tasks)
-- Downsampled 1-hour averages: 2 years (created via tasks)
-- System logs: 7 days

-- Task for 1-minute downsampling (example)
-- option task = {name: "downsample-1min", every: 1m}
-- 
-- from(bucket: "eis_measurements")
--   |> range(start: -2m)
--   |> filter(fn: (r) => r._measurement == "ad5940_impedance" or r._measurement == "ad5941_battery")
--   |> aggregateWindow(every: 1m, fn: mean, createEmpty: false)
--   |> to(bucket: "eis_measurements_1min")

-- ============================================================================
-- INDEXING CONSIDERATIONS
-- ============================================================================

-- Tags are automatically indexed in InfluxDB
-- Key tags for optimal query performance:
-- - device_id: Essential for device-specific queries
-- - board_type: Allows efficient filtering by measurement type
-- - measurement_id: Enables session-based data retrieval
-- - measurement_type: Supports different measurement workflow queries
-- - precharge_state: Important for battery impedance analysis

-- Field keys to consider for series cardinality:
-- - Avoid high-cardinality fields as tags
-- - firmware_version could become a tag if versions are limited
-- - Numerical values (frequency, magnitude, phase) should remain as fields

-- ============================================================================
-- SECURITY CONSIDERATIONS
-- ============================================================================

-- Create separate tokens for different access levels:
-- 1. ESP32 devices: Write-only access to measurement buckets
-- 2. MATLAB application: Read-only access for data retrieval
-- 3. Node-RED: Read/write access for data processing
-- 4. Dashboard: Read-only access for visualization
-- 5. Admin: Full access for maintenance and management

-- Example token creation:
-- influx auth create -o eis_project --write-bucket eis_measurements --description "ESP32 Write Token"
-- influx auth create -o eis_project --read-bucket eis_measurements --description "MATLAB Read Token"