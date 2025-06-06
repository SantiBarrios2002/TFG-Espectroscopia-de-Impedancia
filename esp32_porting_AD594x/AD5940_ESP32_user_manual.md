# ESP32 AD5940 Impedance Measurement System - User Manual

**Version**: 1.0  
**Date**: December 2024  
**Author**: ESP32 AD5940 Development Team  

---

## Table of Contents
1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Getting Started](#getting-started)
4. [Configuration Parameters](#configuration-parameters)
5. [Command Line Interface (CLI)](#command-line-interface-cli)
6. [Output Formats](#output-formats)
7. [Matlab Integration](#matlab-integration)
8. [Troubleshooting](#troubleshooting)
9. [Advanced Configuration](#advanced-configuration)
10. [Appendices](#appendices)

---

## Overview

This system provides a comprehensive impedance measurement solution using the AD5940 analog front-end (AFE) chip controlled by an ESP32 microcontroller. The system supports both single-frequency and frequency sweep measurements with extensive runtime configuration capabilities.

### Key Features
- **Runtime Configuration**: Modify parameters without recompiling code
- **CLI Interface**: Command-line interface for easy parameter adjustment
- **Multiple Output Formats**: Compact, verbose, and CSV formats
- **Frequency Sweeps**: Linear and logarithmic frequency sweeps
- **Matlab Integration**: Direct communication with Matlab via serial interface
- **Real-time Monitoring**: Live measurement display and logging

### System Architecture
```
┌─────────────┐    SPI    ┌─────────────┐
│    ESP32    │◄─────────►│    AD5940   │
│             │           │    AFE      │
│ - Main MCU  │           │ - Impedance │
│ - CLI       │           │   Measurement│
│ - Config    │           │ - Signal    │
└─────────────┘           │   Processing│
      │                   └─────────────┘
      │ UART                     │
      ▼                          │
┌─────────────┐                  │
│   Matlab/   │                  │
│  Terminal   │                  ▼
│             │            ┌─────────────┐
└─────────────┘            │  Device     │
                           │  Under Test │
                           │  (DUT)      │
                           └─────────────┘
```

---

## System Requirements

### Hardware Requirements

#### Essential Components
- **ESP32-S3 Development Board**
  - Minimum 4MB Flash, 8MB PSRAM recommended
  - USB-C connector for programming and serial communication
  
- **AD5940 Evaluation Board** or custom PCB
  - EVAL-AD5940ELECZ (recommended)
  - Custom PCB with AD5940 chip

#### Connections
| ESP32 Pin | AD5940 Pin | Function |
|-----------|------------|----------|
| GPIOxx    | SCLK       | SPI Clock |
| GPIOxx    | MOSI       | SPI Data Out |
| GPIOxx    | MISO       | SPI Data In |
| GPIOxx    | CS         | Chip Select |
| GPIOxx    | RST        | Reset |
| GPIOxx    | INT        | Interrupt |
| 3.3V      | VDD        | Power Supply |
| GND       | GND        | Ground |

#### Power Requirements
- **ESP32**: 3.3V, ~240mA typical
- **AD5940**: 
  - Digital: 1.8V/3.3V, ~20mA
  - Analog: 1.8V, ~25mA (LP mode), ~50mA (HP mode)

### Software Requirements

#### Development Environment
- **ESP-IDF Framework**: v5.0 or later
- **Python**: 3.7 or later (for ESP-IDF tools)
- **Git**: For version control and ESP-IDF installation

#### Host Software Options
- **Serial Terminal**: PuTTY, Tera Term, minicom, screen
- **Matlab**: R2019b or later (for advanced integration)
- **Python**: With pyserial library for custom applications

---

## Getting Started

### Initial Setup

#### 1. Hardware Setup
```
1. Connect ESP32 to AD5940 via SPI (see pinout table above)
2. Connect calibration resistor to AD5940 measurement terminals
3. Ensure proper power supply connections
4. Connect USB cable to ESP32 for programming and serial communication
```

#### 2. Software Setup
```bash
# Install ESP-IDF (if not already installed)
git clone --recursive https://github.com/espressif/esp-idf.git
cd esp-idf
./install.sh

# Set up environment
. ./export.sh

# Clone and build the project
git clone <your-project-repo>
cd esp32_porting_AD594x
idf.py build
idf.py flash monitor
```

#### 3. Terminal Configuration
- **Baud Rate**: 115200
- **Data Bits**: 8
- **Parity**: None
- **Stop Bits**: 1
- **Flow Control**: None

### First Boot Sequence

When the system starts successfully, you should see:

```
I (XXX) AD5940_MAIN: Starting ESP32 AD5940 Impedance Measurement Application
I (XXX) AD5940_MAIN: Build Time: Dec 06 2024 10:30:15
I (XXX) AD5940_MAIN: ESP-IDF Version: v5.1.2
I (XXX) AD5940_MAIN: Initializing MCU resources...
I (XXX) AD5940_MAIN: MCU resources initialized successfully
I (XXX) AD5940_MAIN: Configuring AD5940 platform...
I (XXX) AD5940_MAIN: Validating AD5940 chip identification...
I (XXX) AD5940_MAIN: ADIID register: 0x00004144
I (XXX) AD5940_MAIN: CHIPID register: 0x00005502
I (XXX) AD5940_MAIN: AD5940 chip identification validated successfully
I (XXX) AD5940_MAIN: AD5940 platform configured successfully
I (XXX) AD5940_MAIN: Impedance measurement started successfully

=== ESP32 AD5940 CLI Interface ===
Type 'help' for available commands
Type 'show_config' to see current configuration
===================================

ad5940> 
```

### Quick Start Example

```bash
# Check current configuration
ad5940> show_config

# Set single frequency measurement
ad5940> set_freq 10000
ad5940> set_rcal 10000
ad5940> set_voltage 800
ad5940> set_output 1

# Start measurement with new settings
ad5940> restart_measurement
```

---

## Configuration Parameters

### 1. Measurement Configuration

#### Frequency (Hz)
- **Parameter**: `user_cfg.frequency`
- **Default**: 10000.0 (10 kHz)
- **Range**: 0.1 Hz to 200 kHz (hardware dependent)
- **Description**: Single frequency for impedance measurement when sweep is disabled
- **CLI Command**: `set_freq <frequency>`
- **Example**: 
  ```bash
  ad5940> set_freq 5000    # Sets to 5 kHz
  ```

#### Calibration Resistor (Ohms)
- **Parameter**: `user_cfg.rcal_value`
- **Default**: 10000.0 (10 kΩ)
- **Range**: 1 Ω to 1 MΩ
- **Description**: Known calibration resistor value for impedance calculation
- **CLI Command**: `set_rcal <resistance>`
- **Example**: 
  ```bash
  ad5940> set_rcal 1000    # Sets to 1 kΩ
  ```

#### Excitation Voltage (mV)
- **Parameter**: `user_cfg.excitation_voltage`
- **Default**: 800.0 mV
- **Range**: 1 mV to 2200 mV
- **Description**: Peak-to-peak voltage of the excitation signal
- **Impact**: Higher voltage = better SNR, but may cause nonlinear effects
- **CLI Command**: `set_voltage <voltage_mv>`
- **Example**: 
  ```bash
  ad5940> set_voltage 500  # Sets to 500 mV peak-to-peak
  ```

#### DC Bias Voltage (V)
- **Parameter**: `user_cfg.bias_voltage`
- **Default**: 0.0 V
- **Range**: -1.1 V to +1.1 V
- **Description**: DC bias applied to the measurement
- **Use Cases**: 
  - Electrochemical measurements
  - Biasing active devices
  - Offset compensation
- **CLI Command**: `set_bias <voltage_v>`
- **Example**: 
  ```bash
  ad5940> set_bias 0.5     # Sets to 0.5 V DC bias
  ```

#### Number of Measurements
- **Parameter**: `user_cfg.num_measurements`
- **Default**: -1 (continuous)
- **Range**: -1 (continuous) or positive integer
- **Description**: Number of measurements to take before stopping
- **CLI Command**: `set_measurements <count>`
- **Examples**: 
  ```bash
  ad5940> set_measurements 100  # Take 100 measurements then stop
  ad5940> set_measurements -1   # Continuous measurements
  ```

### 2. Frequency Sweep Configuration

#### Sweep Enable
- **Parameter**: `user_cfg.sweep_enabled`
- **Default**: true
- **Description**: Enable/disable frequency sweep mode
- **Note**: Automatically set by `set_sweep` (enables) or `set_freq` (disables)

#### Sweep Configuration
- **Start Frequency**: `user_cfg.sweep_start` (default: 1000.0 Hz)
- **Stop Frequency**: `user_cfg.sweep_stop` (default: 100000.0 Hz)
- **Number of Points**: `user_cfg.sweep_points` (default: 101)
- **Sweep Type**: `user_cfg.sweep_logarithmic` (default: true)

#### CLI Command
```bash
set_sweep <start_hz> <stop_hz> <points> [log]
```

**Parameters**:
- `start_hz`: Starting frequency in Hz
- `stop_hz`: Ending frequency in Hz
- `points`: Number of frequency points (2-1000)
- `log`: Optional, 1 for logarithmic, 0 for linear (default: 1)

**Examples**:
```bash
# Logarithmic sweep from 100 Hz to 10 kHz, 51 points
ad5940> set_sweep 100 10000 51 1

# Linear sweep from 1 kHz to 5 kHz, 21 points
ad5940> set_sweep 1000 5000 21 0

# Default logarithmic sweep
ad5940> set_sweep 1000 100000 101
```

### 3. Hardware Configuration

#### TIA Resistor Selection
- **Parameter**: `user_cfg.hstia_rtia_sel`
- **Default**: `HSTIARTIA_5K` (5 kΩ)

**Available Options**:
| Value | Resistance | Current Range (approx.) |
|-------|------------|-------------------------|
| `HSTIARTIA_200` | 200 Ω | 10 mA - 100 mA |
| `HSTIARTIA_1K` | 1 kΩ | 2 mA - 20 mA |
| `HSTIARTIA_5K` | 5 kΩ | 400 µA - 4 mA |
| `HSTIARTIA_10K` | 10 kΩ | 200 µA - 2 mA |
| `HSTIARTIA_20K` | 20 kΩ | 100 µA - 1 mA |
| `HSTIARTIA_40K` | 40 kΩ | 50 µA - 500 µA |
| `HSTIARTIA_80K` | 80 kΩ | 25 µA - 250 µA |
| `HSTIARTIA_160K` | 160 kΩ | 12.5 µA - 125 µA |

**Selection Guidelines**:
- **Lower resistances**: Better for high-current, low-impedance measurements
- **Higher resistances**: Better for low-current, high-impedance measurements
- **Rule of thumb**: Choose TIA resistor ≈ expected impedance magnitude

#### ADC PGA Gain
- **Parameter**: `user_cfg.adc_pga_gain`
- **Default**: `ADCPGA_4` (4x gain)
- **Options**: `ADCPGA_1`, `ADCPGA_1_5`, `ADCPGA_2`, `ADCPGA_4`, `ADCPGA_9`
- **Usage**: Higher gain for smaller signals, but watch for saturation

#### Power Mode
- **Parameter**: `user_cfg.power_mode`
- **Default**: `AFEPWR_LP` (Low Power)
- **Options**: 
  - `AFEPWR_LP`: Lower power consumption, reduced performance
  - `AFEPWR_HP`: Higher power consumption, better performance
- **CLI Command**: `set_power <mode>` (0=LP, 1=HP)

**Comparison**:
| Mode | Power | Noise | Speed | Best For |
|------|-------|-------|-------|----------|
| LP | Low | Higher | Slower | Battery applications, basic measurements |
| HP | High | Lower | Faster | Precision measurements, fast sweeps |

### 4. Switch Matrix Configuration

The switch matrix routes signals to different measurement configurations:

#### Default Configuration (EVAL-AD5940ELECZ)
- **D Switch**: `SWD_CE0` - Counter electrode
- **P Switch**: `SWP_RE0` - Reference/working electrode
- **N Switch**: `SWN_SE0` - Sense electrode  
- **T Switch**: `SWT_SE0LOAD` - Load connection

#### Custom Configurations
For custom PCB designs, modify these parameters in the code:
```c
// 4-wire measurement
.d_switch = SWD_CE0,
.p_switch = SWP_RE0, 
.n_switch = SWN_SE0,
.t_switch = SWT_TLOAD

// 2-wire measurement  
.d_switch = SWD_CE0,
.p_switch = SWP_CE0,
.n_switch = SWN_SE0, 
.t_switch = SWT_SE0LOAD
```

### 5. Filter and Processing Configuration

#### DFT (Discrete Fourier Transform) Settings

**DFT Points**
- **Parameter**: `user_cfg.dft_num`
- **Default**: `DFTNUM_16384` (16384 points)
- **Options**: `DFTNUM_2048`, `DFTNUM_4096`, `DFTNUM_8192`, `DFTNUM_16384`

**Performance Impact**:
| DFT Points | Frequency Resolution | Measurement Time | Memory Usage |
|------------|---------------------|------------------|--------------|
| 2048 | Low | Fast | Low |
| 4096 | Medium | Medium | Medium |
| 8192 | High | Slow | High |
| 16384 | Very High | Very Slow | Very High |

**DFT Source**
- **Parameter**: `user_cfg.dft_src`
- **Default**: `DFTSRC_SINC3`
- **Options**: `DFTSRC_SINC2OSR`, `DFTSRC_SINC3`, `DFTSRC_VAR`, `DFTSRC_TEMPSENSOR`

#### Windowing
- **Parameter**: `user_cfg.hanwin_enable`
- **Default**: true
- **Description**: Applies Hanning window to reduce spectral leakage
- **Recommendation**: Enable for most applications

#### ADC Configuration

**SINC2 OSR (Oversampling Ratio)**
- **Parameter**: `user_cfg.adc_sinc2_osr`
- **Default**: `ADCSINC2OSR_22`
- **Impact**: Higher OSR = better noise performance, slower conversion

**SINC3 OSR**
- **Parameter**: `user_cfg.adc_sinc3_osr`
- **Default**: `ADCSINC3OSR_2`
- **Impact**: Additional filtering stage

**ADC Averaging**
- **Parameter**: `user_cfg.adc_avg_num`
- **Default**: `ADCAVGNUM_16` (16x averaging)
- **Options**: `ADCAVGNUM_2`, `ADCAVGNUM_4`, `ADCAVGNUM_8`, `ADCAVGNUM_16`, etc.
- **Trade-off**: More averaging = better noise performance, slower measurements

### 6. System Configuration

#### Clock Settings
- **System Clock**: `user_cfg.sys_clk_freq` (default: 16 MHz)
- **ADC Clock**: `user_cfg.adc_clk_freq` (default: 16 MHz)
- **Impact**: Higher frequencies = faster operation, more power consumption

#### FIFO and Data Rate
- **FIFO Threshold**: `user_cfg.fifo_thresh` (default: 4)
- **Output Data Rate**: `user_cfg.imp_odr` (default: 20.0 Hz)
- **Measurement Interval**: `user_cfg.measurement_interval_ms` (default: 100 ms)

### 7. Output Configuration

#### Output Modes
- **Verbose**: `user_cfg.verbose_output` (default: true)
- **Raw Data**: `user_cfg.raw_data_output` (default: false)
- **CSV Format**: `user_cfg.csv_format` (default: false)

#### CLI Command
```bash
set_output <mode>
```
- `0`: Compact format
- `1`: Verbose format  
- `2`: CSV format

---

## Command Line Interface (CLI)

### Accessing the CLI

#### Terminal Setup
1. **Connect** ESP32 via USB
2. **Open** terminal software (PuTTY, Tera Term, etc.)
3. **Configure** serial port:
   - **Port**: COM port assigned to ESP32
   - **Baud Rate**: 115200
   - **Data Bits**: 8
   - **Parity**: None
   - **Stop Bits**: 1
   - **Flow Control**: None

#### CLI Prompt
Once connected, you'll see:
```
ad5940> 
```

### Available Commands

#### Configuration Commands

**Set Single Frequency**
```bash
set_freq <frequency_hz>
```
- Sets measurement to single frequency mode
- Disables frequency sweep
- Example: `set_freq 5000`

**Configure Frequency Sweep**
```bash
set_sweep <start_hz> <stop_hz> <points> [log]
```
- Enables frequency sweep mode
- `log` parameter: 1=logarithmic, 0=linear (optional, default=1)
- Example: `set_sweep 1000 100000 51 1`

**Set Calibration Resistor**
```bash
set_rcal <resistance_ohms>
```
- Sets known calibration resistor value
- Example: `set_rcal 10000`

**Set Excitation Voltage**
```bash
set_voltage <voltage_mv>
```
- Sets peak-to-peak excitation voltage
- Range: 1-2200 mV
- Example: `set_voltage 500`

**Set DC Bias**
```bash
set_bias <voltage_v>
```
- Sets DC bias voltage
- Range: -1.1 to +1.1 V
- Example: `set_bias 0.5`

**Set Number of Measurements**
```bash
set_measurements <count>
```
- Sets measurement count (-1 for continuous)
- Example: `set_measurements 100`

**Set Power Mode**
```bash
set_power <mode>
```
- Sets power mode (0=Low Power, 1=High Power)
- Example: `set_power 1`

**Set Output Format**
```bash
set_output <mode>
```
- Sets output format (0=compact, 1=verbose, 2=CSV)
- Example: `set_output 2`

#### Information Commands

**Show Configuration**
```bash
show_config
```
- Displays all current parameter values

**Get Help**
```bash
help
```
- Shows available commands and help information

**Restart Measurement**
```bash
restart_measurement
```
- Applies new configuration and restarts measurement

### Command Examples

#### Basic Single Frequency Setup
```bash
ad5940> set_freq 10000          # Set to 10 kHz
ad5940> set_rcal 10000          # 10k calibration resistor
ad5940> set_voltage 800         # 800 mV excitation
ad5940> set_output 1            # Verbose output
ad5940> restart_measurement     # Apply settings
```

#### Frequency Sweep Setup
```bash
ad5940> set_sweep 100 10000 21 1    # 100 Hz to 10 kHz, 21 points, log
ad5940> set_output 2                # CSV output for data analysis
ad5940> set_measurements 50         # Take 50 measurements
ad5940> restart_measurement         # Apply settings
```

#### Low Power Configuration
```bash
ad5940> set_power 0             # Low power mode
ad5940> set_voltage 200         # Lower excitation voltage
ad5940> set_measurements 10     # Limited measurements
ad5940> restart_measurement     # Apply settings
```

#### High Precision Setup
```bash
ad5940> set_power 1             # High power mode
ad5940> set_voltage 1000        # Higher excitation for better SNR
ad5940> set_output 1            # Verbose output
ad5940> restart_measurement     # Apply settings
```

---

## Output Formats

### 1. Compact Format
**Activated by**: `set_output 0`

**Format**:
```
Freq: 10000.00 Hz | Z: 9876.54 Ohms | Phase: -12.34°
```

**Features**:
- Single line per measurement
- Essential information only
- Good for real-time monitoring
- Minimal data transfer

**Use Cases**:
- Real-time monitoring
- Quick checks
- Limited bandwidth connections

### 2. Verbose Format  
**Activated by**: `set_output 1`

**Format**:
```
--- Measurement Results ---
Frequency: 10000.00 Hz
Timestamp: 12345678 ms
Sample 1:
  Impedance Magnitude: 9876.543210 Ohms
  Phase: -12.345 degrees
  Phase: -0.215498 radians
---------------------------
```

**Features**:
- Detailed information per measurement
- Includes timestamp
- Phase in both degrees and radians
- Good for debugging and analysis

**Use Cases**:
- Development and debugging
- Detailed analysis
- Scientific documentation
- Troubleshooting

### 3. CSV Format
**Activated by**: `set_output 2`

**Format**:
```
Frequency(Hz),Magnitude(Ohms),Phase(Degrees)
10000.00,9876.543210,-12.345
10000.00,9875.123456,-12.340
```

**Features**:
- Comma-separated values
- Header row included
- Easy import into analysis software
- Standardized format

**Use Cases**:
- Data logging and analysis
- Import into Excel, Matlab, Python
- Automated data processing
- Scientific publications

### Raw Data Output
**Activated by**: Setting `user_cfg.raw_data_output = true` in code

**Additional Output**:
```
Raw data (2 samples): 0x12345678 0x87654321
```

**Features**:
- Hexadecimal raw ADC values
- Useful for low-level debugging
- Can be processed separately

---

## Matlab Integration

### Basic Setup

#### Serial Port Configuration
```matlab
% Configure serial port
port = "COM3";  % Adjust for your system (Linux: "/dev/ttyUSB0")
baudrate = 115200;
s = serialport(port, baudrate);

% Configure terminator and timeout
configureTerminator(s, "LF");
s.Timeout = 10;

% Clear any existing data
flush(s);
```

#### Test Connection
```matlab
% Test communication
writeline(s, "help");
response = readline(s);
disp(response);
```

### Configuration Functions

#### Basic Configuration
```matlab
function configureAD5940Basic(s, freq, rcal, voltage)
    % Configure basic measurement parameters
    
    % Set single frequency
    cmd = sprintf("set_freq %.2f", freq);
    writeline(s, cmd);
    response = readline(s);
    fprintf('Frequency: %s\n', response);
    
    % Set calibration resistor
    cmd = sprintf("set_rcal %.2f", rcal);
    writeline(s, cmd);
    response = readline(s);
    fprintf('Rcal: %s\n', response);
    
    % Set excitation voltage
    cmd = sprintf("set_voltage %.2f", voltage);
    writeline(s, cmd);
    response = readline(s);
    fprintf('Voltage: %s\n', response);
    
    % Set CSV output
    writeline(s, "set_output 2");
    response = readline(s);
    fprintf('Output: %s\n', response);
    
    % Restart measurement
    writeline(s, "restart_measurement");
    response = readline(s);
    fprintf('Restart: %s\n', response);
end
```

#### Frequency Sweep Configuration
```matlab
function configureSweep(s, fstart, fstop, points, logScale)
    % Configure frequency sweep
    
    if nargin < 5
        logScale = 1; % Default to logarithmic
    end
    
    cmd = sprintf("set_sweep %.2f %.2f %d %d", fstart, fstop, points, logScale);
    writeline(s, cmd);
    response = readline(s);
    fprintf('Sweep config: %s\n', response);
    
    % Set CSV output for easy parsing
    writeline(s, "set_output 2");
    readline(s);
    
    % Restart measurement
    writeline(s, "restart_measurement");
    readline(s);
end
```

### Data Acquisition

#### Single Measurement
```matlab
function [freq, mag, phase] = readSingleMeasurement(s)
    % Read a single impedance measurement
    
    line = readline(s);
    
    % Skip header if present
    if contains(line, "Frequency")
        line = readline(s);
    end
    
    % Parse CSV data
    values = str2double(split(line, ','));
    
    if length(values) == 3
        freq = values(1);
        mag = values(2);
        phase = values(3);
    else
        error('Invalid data format');
    end
end
```

#### Multiple Measurements
```matlab
function data = readMultipleMeasurements(s, numMeasurements, timeout)
    % Read multiple measurements with timeout
    
    if nargin < 3
        timeout = 30; % Default 30 second timeout
    end
    
    data = zeros(numMeasurements, 3);
    startTime = tic;
    
    % Skip header line
    try
        header = readline(s);
        if ~contains(header, "Frequency")
            % Put line back if it's not a header
            data(1, :) = str2double(split(header, ','))';
            startIdx = 2;
        else
            startIdx = 1;
        end
    catch
        startIdx = 1;
    end
    
    % Read data
    for i = startIdx:numMeasurements
        if toc(startTime) > timeout
            warning('Timeout reached. Got %d/%d measurements', i-1, numMeasurements);
            data = data(1:i-1, :);
            break;
        end
        
        try
            line = readline(s);
            values = str2double(split(line, ','));
            
            if length(values) == 3
                data(i, :) = values';
            else
                warning('Invalid data at measurement %d', i);
            end
        catch ME
            warning('Error reading measurement %d: %s', i, ME.message);
        end
    end
    
    % Remove any unfilled rows
    data = data(1:find(data(:,1)~=0, 1, 'last'), :);
end
```

#### Frequency Sweep Data Collection
```matlab
function [frequencies, magnitudes, phases] = performFrequencySweep(s, fstart, fstop, points)
    % Perform complete frequency sweep and collect data
    
    % Configure sweep
    configureSweep(s, fstart, fstop, points, 1); % Logarithmic
    
    % Wait for sweep to start
    pause(2);
    
    % Read data
    data = readMultipleMeasurements(s, points, 60); % 60 second timeout
    
    % Extract columns
    frequencies = data(:, 1);
    magnitudes = data(:, 2);
    phases = data(:, 3);
    
    fprintf('Collected %d measurements\n', length(frequencies));
end
```

### Data Analysis and Visualization

#### Basic Plotting
```matlab
function plotImpedanceData(frequencies, magnitudes, phases)
    % Create impedance plots
    
    figure('Position', [100, 100, 800, 600]);
    
    % Magnitude plot
    subplot(2, 1, 1);
    loglog(frequencies, magnitudes, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4);
    grid on;
    xlabel('Frequency (Hz)');
    ylabel('Impedance Magnitude (Ω)');
    title('Impedance vs Frequency');
    
    % Phase plot
    subplot(2, 1, 2);
    semilogx(frequencies, phases, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 4);
    grid on;
    xlabel('Frequency (Hz)');
    ylabel('Phase (°)');
    title('Phase vs Frequency');
    
    % Improve appearance
    set(gcf, 'Color', 'white');
    set(findall(gcf, 'Type', 'axes'), 'FontSize', 10);
end
```

#### Nyquist Plot
```matlab
function plotNyquist(magnitudes, phases)
    % Create Nyquist plot (complex impedance plane)
    
    % Convert to complex impedance
    phases_rad = phases * pi / 180; % Convert to radians
    real_part = magnitudes .* cos(phases_rad);
    imag_part = magnitudes .* sin(phases_rad);
    
    figure;
    plot(real_part, -imag_part, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4);
    grid on;
    axis equal;
    xlabel('Real Part (Ω)');
    ylabel('-Imaginary Part (Ω)');
    title('Nyquist Plot');
    
    % Add frequency labels at key points
    n = length(real_part);
    step = max(1, floor(n/10)); % Label ~10 points
    for i = 1:step:n
        text(real_part(i), -imag_part(i), sprintf('  %.0f Hz', frequencies(i)), ...
             'FontSize', 8, 'Color', 'red');
    end
end
```

### Complete Matlab Example

```matlab
function impedanceAnalysisExample()
    % Complete example of ESP32 AD5940 integration
    
    try
        % Setup
        fprintf('Setting up serial connection...\n');
        s = setupSerial("COM3"); % Adjust port as needed
        
        % Configure measurement
        fprintf('Configuring measurement...\n');
        configureSweep(s, 100, 10000, 21, 1); % 100 Hz to 10 kHz, 21 points, log
        
        % Collect data
        fprintf('Collecting data...\n');
        [freq, mag, phase] = performFrequencySweep(s, 100, 10000, 21);
        
        % Analyze and plot
        fprintf('Plotting results...\n');
        plotImpedanceData(freq, mag, phase);
        plotNyquist(mag, phase);
        
        % Save data
        data_table = table(freq, mag, phase, ...
                          'VariableNames', {'Frequency_Hz', 'Magnitude_Ohms', 'Phase_Degrees'});
        writetable(data_table, 'impedance_data.csv');
        fprintf('Data saved to impedance_data.csv\n');
        
        % Cleanup
        clear s;
        fprintf('Analysis complete!\n');
        
    catch ME
        fprintf('Error: %s\n', ME.message);
        if exist('s', 'var')
            clear s;
        end
    end
end

function s = setupSerial(port)
    % Setup serial connection with error handling
    
    s = serialport(port, 115200);
    configureTerminator(s, "LF");
    s.Timeout = 10;
    flush(s);
    
    % Test connection
    writeline(s, "help");
    pause(0.1);
    if s.NumBytesAvailable == 0
        error('No response from ESP32. Check connection and port.');
    end
    
    % Clear response
    while s.NumBytesAvailable > 0
        readline(s);
    end
end
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Connection Issues

**No Response from ESP32**

*Symptoms*:
- No output in terminal
- CLI not responding
- Connection timeout

*Solutions*:
```bash
# Check basic connection
1. Verify USB cable connection
2. Check Device Manager (Windows) or dmesg (Linux) for COM port
3. Ensure correct baud rate (115200)
4. Try different USB port
5. Press ESP32 reset button

# Terminal settings verification
- Baud rate: 115200
- Data bits: 8
- Parity: None
- Stop bits: 1
- Flow control: None
```

*Advanced Diagnostics*:
```bash
# Check if ESP32 is responsive
esptool.py --port COM3 chip_id

# Monitor boot messages
idf.py monitor
```

#### 2. AD5940 Initialization Issues

**Failed to Configure AD5940 Platform**

*Symptoms*:
```
E (XXX) AD5940_MAIN: Failed to configure AD5940 platform
```

*Solutions*:
```bash
# Check SPI connections
1. Verify all SPI connections (MOSI, MISO, SCK, CS)
2. Check power supply connections
3. Measure voltages at AD5940 pins
4. Verify ground connections

# Typical voltage levels
- VDD_1V8: 1.8V ±5%
- AVDD_1V8: 1.8V ±5%  
- DVDD_1V8: 1.8V ±5%
- IOVDD: 3.3V ±5%
```

**Invalid Chip ID Errors**

*Symptoms*:
```
E (XXX) AD5940_MAIN: Invalid CHIPID: expected 0x5502, got 0xFFFFFFFF
E (XXX) AD5940_MAIN: Invalid ADIID: expected 0x4144, got 0x00000000
```

*Root Causes and Solutions*:

| Error Pattern | Likely Cause | Solution |
|---------------|--------------|----------|
| 0xFFFFFFFF | SPI MISO not connected | Check MISO connection |
| 0x00000000 | SPI communication failure | Check all SPI lines |
| Wrong value | Wrong chip or damaged | Verify chip part number |

*SPI Debugging*:
```c
// Add to code for SPI debugging
void debug_spi_connections() {
    printf("Testing SPI connections...\n");
    
    // Test basic register access
    uint32_t test_patterns[] = {0x12345678, 0xA5A5A5A5, 0x00000000, 0xFFFFFFFF};
    
    for (int i = 0; i < 4; i++) {
        AD5940_WriteReg(REG_AFE_CALDATLOCK, test_patterns[i]);
        uint32_t readback = AD5940_ReadReg(REG_AFE_CALDATLOCK);
        
        printf("Wrote: 0x%08X, Read: 0x%08X - %s\n", 
               test_patterns[i], readback, 
               (readback == test_patterns[i]) ? "PASS" : "FAIL");
    }
}
```

#### 3. Measurement Issues

**No Measurement Data**

*Symptoms*:
- System starts but no impedance readings
- Zero or invalid values
- Timeout errors

*Diagnostics*:
```bash
# Check configuration
ad5940> show_config

# Verify device connections
1. Check calibration resistor connection
2. Verify switch matrix configuration
3. Test with known impedance

# Debug steps
ad5940> set_output 1        # Verbose output
ad5940> restart_measurement # Apply settings
```

**Noisy or Inconsistent Measurements**

*Symptoms*:
- Large variations between consecutive readings
- Unstable measurements
- Poor repeatability

*Solutions*:

| Issue | Cause | Solution |
|-------|-------|----------|
| High noise | Poor grounding | Improve ground connections |
| Drift | Temperature | Allow warm-up time |
| Interference | EMI | Add shielding, move away from noise sources |
| Saturation | Signal too large | Reduce excitation voltage |
| Poor SNR | Signal too small | Increase excitation, check TIA setting |

*Configuration adjustments*:
```bash
# For noisy measurements
ad5940> set_voltage 200     # Reduce excitation
ad5940> set_power 1         # High power mode for better SNR

# For better stability
# Increase averaging in code:
user_cfg.adc_avg_num = ADCAVGNUM_64;  // More averaging
```

#### 4. CLI and Communication Issues

**Commands Not Recognized**

*Symptoms*:
```
Unrecognized command. Type 'help' for available commands.
```

*Solutions*:
```bash
# Check command syntax
ad5940> help                # List all commands
ad5940> set_freq 1000      # Correct syntax
ad5940> setfreq 1000       # Wrong syntax (underscore required)

# Common typos
set_frequency -> set_freq
show_configuration -> show_config
```

**Parameter Out of Range Errors**

*Examples and Solutions*:
```bash
# Frequency range
ad5940> set_freq 0          # Error: must be positive
ad5940> set_freq 1000       # Correct

# Voltage range  
ad5940> set_voltage 3000    # Error: max 2200 mV
ad5940> set_voltage 800     # Correct

# Bias range
ad5940> set_bias 2.0        # Error: max ±1.1 V
ad5940> set_bias 0.5        # Correct
```

#### 5. Performance Issues

**Slow Measurements**

*Causes and Solutions*:

| Cause | Impact | Solution |
|-------|--------|----------|
| High DFT points | Very slow | Reduce DFT points |
| Excessive averaging | Slow | Reduce averaging |
| Low power mode | Slower | Use high power mode |
| Low ODR | Slow updates | Increase output data rate |

*Optimization settings*:
```c
// Fast measurement configuration
user_cfg.dft_num = DFTNUM_2048;       // Minimum DFT points
user_cfg.adc_avg_num = ADCAVGNUM_2;   // Minimum averaging
user_cfg.power_mode = AFEPWR_HP;      // High power mode
user_cfg.imp_odr = 100.0f;            // Higher data rate
```

**Memory Issues**

*Symptoms*:
- System crashes
- Stack overflow errors
- Allocation failures

*Solutions*:
```c
// Increase stack sizes in app_main()
xTaskCreate(impedance_measurement_task, "impedance", 16384, ...); // Increase from 8192
xTaskCreate(cli_task, "cli_task", 8192, ...); // Increase from 4096

// Check available memory
size_t free_heap = esp_get_free_heap_size();
printf("Free heap: %zu bytes\n", free_heap);
```

### Diagnostic Tools

#### 1. Built-in Diagnostics

**Configuration Check**:
```bash
ad5940> show_config
```

**System Information**:
```c
// Add to code for system diagnostics
void print_system_info() {
    printf("=== System Information ===\n");
    printf("ESP-IDF Version: %s\n", esp_get_idf_version());
    printf("Free heap: %zu bytes\n", esp_get_free_heap_size());
    printf("Minimum free heap: %zu bytes\n", esp_get_minimum_free_heap_size());
    
    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);
    printf("Chip: %s\n", (chip_info.model == CHIP_ESP32S3) ? "ESP32-S3" : "Unknown");
    printf("Cores: %d\n", chip_info.cores);
    printf("Flash: %dMB\n", spi_flash_get_chip_size() / (1024 * 1024));
}
```

#### 2. Hardware Testing

**SPI Communication Test**:
```c
// Test SPI communication
void test_spi_communication() {
    printf("Testing SPI communication...\n");
    
    // Test with different patterns
    uint32_t patterns[] = {0x12345678, 0xA5A5A5A5, 0x5A5A5A5A, 0x00000000, 0xFFFFFFFF};
    bool all_passed = true;
    
    for (int i = 0; i < 5; i++) {
        AD5940_WriteReg(REG_AFE_CALDATLOCK, patterns[i]);
        AD5940_Delay10us(10);
        uint32_t readback = AD5940_ReadReg(REG_AFE_CALDATLOCK);
        
        bool passed = (readback == patterns[i]);
        printf("Pattern 0x%08X: %s\n", patterns[i], passed ? "PASS" : "FAIL");
        
        if (!passed) all_passed = false;
    }
    
    printf("SPI Test: %s\n", all_passed ? "PASSED" : "FAILED");
}
```

**Power Supply Check**:
```c
// Check power supply voltages (if available)
void check_power_supplies() {
    printf("Checking power supplies...\n");
    
    // This would require additional hardware monitoring
    // Implementation depends on your specific board design
    
    printf("Note: Manual voltage measurement required\n");
    printf("Check these voltages with multimeter:\n");
    printf("- VDD_1V8: Should be 1.8V ±5%%\n");
    printf("- AVDD_1V8: Should be 1.8V ±5%%\n");
    printf("- IOVDD: Should be 3.3V ±5%%\n");
}
```

### Error Codes Reference

#### CLI Error Messages
| Error Message | Cause | Solution |
|---------------|-------|----------|
| "Error: Frequency must be positive" | Invalid frequency parameter | Use positive frequency value |
| "Error: Invalid sweep parameters" | Sweep configuration error | Check start < stop, points ≥ 2 |
| "Error: Resistance must be positive" | Invalid calibration resistor | Use positive resistance value |
| "Error: Voltage must be between 0 and 2200 mV" | Excitation voltage out of range | Use 1-2200 mV range |
| "Error: Bias voltage must be between -1.1 and 1.1 V" | DC bias out of range | Use ±1.1V range |

#### System Error Messages
| Error Message | Cause | Solution |
|---------------|-------|----------|
| "Failed to initialize MCU resources" | Hardware initialization error | Check connections and power |
| "Failed to configure AD5940 platform" | AD5940 setup error | Verify SPI connections |
| "Failed to initialize impedance measurement" | Application initialization error | Check configuration parameters |
| "Failed to start impedance measurement" | Measurement start error | Review switch matrix and TIA settings |

---

## Advanced Configuration

### Performance Optimization

#### 1. Speed Optimization

**Fast Measurement Configuration**:
```c
// Optimized for speed
static user_config_t fast_config = {
    .dft_num = DFTNUM_2048,           // Minimum DFT points
    .adc_avg_num = ADCAVGNUM_2,       // Minimum averaging
    .hanwin_enable = false,           // Disable windowing
    .power_mode = AFEPWR_HP,          // High power for speed
    .adc_sinc2_osr = ADCSINC2OSR_22,  // Lower OSR
    .adc_sinc3_osr = ADCSINC3OSR_2,   // Lower OSR
    .imp_odr = 100.0f,                // Higher data rate
    .measurement_interval_ms = 10,    // Faster polling
};
```

**Performance Metrics**:
| Configuration | Measurement Time | Accuracy | Power |
|---------------|------------------|----------|-------|
| Fast | ~50ms | Medium | High |
| Balanced | ~200ms | High | Medium |
| Precision | ~800ms | Very High | High |

#### 2. Accuracy Optimization

**High Precision Configuration**:
```c
// Optimized for accuracy
static user_config_t precision_config = {
    .dft_num = DFTNUM_16384,          // Maximum DFT points
    .adc_avg_num = ADCAVGNUM_256,     // Maximum averaging
    .hanwin_enable = true,            // Enable windowing
    .power_mode = AFEPWR_HP,          // High power for low noise
    .adc_sinc2_osr = ADCSINC2OSR_1333, // Higher OSR
    .adc_sinc3_osr = ADCSINC3OSR_4,   // Higher OSR
    .excitation_voltage = 1000.0f,    // Higher excitation for SNR
    .imp_odr = 5.0f,                  // Lower data rate
};
```

#### 3. Power Optimization

**Low Power Configuration**:
```c
// Optimized for power consumption
static user_config_t low_power_config = {
    .power_mode = AFEPWR_LP,          // Low power mode
    .excitation_voltage = 200.0f,     // Lower excitation
    .sys_clk_freq = 8000000.0f,       // Lower clock frequency
    .adc_clk_freq = 8000000.0f,       // Lower ADC clock
    .measurement_interval_ms = 1000,  // Longer intervals
    .dft_num = DFTNUM_4096,          // Moderate DFT points
    .adc_avg_num = ADCAVGNUM_8,       // Moderate averaging
};
```

### Custom Parameter Addition

#### Adding New Parameters

**Step 1: Extend Configuration Structure**
```c
typedef struct {
    // Existing parameters...
    
    // New custom parameters
    float custom_gain_factor;        // Custom gain adjustment
    uint32_t custom_filter_freq;     // Custom filter frequency
    bool custom_feature_enable;     // Custom feature flag
    
} user_config_t;
```

**Step 2: Set Default Values**
```c
static user_config_t user_cfg = {
    // Existing defaults...
    
    // New parameter defaults
    .custom_gain_factor = 1.0f,
    .custom_filter_freq = 1000,
    .custom_feature_enable = false,
};
```

**Step 3: Add CLI Commands**
```c
static int cmd_set_custom_gain(int argc, char **argv)
{
    if (argc != 2) {
        printf("Usage: set_custom_gain <factor>\n");
        return 1;
    }
    
    float gain = atof(argv[1]);
    if (gain <= 0 || gain > 10) {
        printf("Error: Gain factor must be between 0 and 10\n");
        return 1;
    }
    
    user_cfg.custom_gain_factor = gain;
    printf("Custom gain factor set to %.2f\n", gain);
    return 0;
}

static int cmd_toggle_custom_feature(int argc, char **argv)
{
    user_cfg.custom_feature_enable = !user_cfg.custom_feature_enable;
    printf("Custom feature %s\n", user_cfg.custom_feature_enable ? "enabled" : "disabled");
    return 0;
}
```

**Step 4: Register Commands**
```c
static void register_custom_commands(void)
{
    esp_console_cmd_t cmd;

    cmd = (esp_console_cmd_t){
        .command = "set_custom_gain",
        .help = "Set custom gain factor",
        .hint = NULL,
        .func = &cmd_set_custom_gain,
    };
    ESP_ERROR_CHECK(esp_console_cmd_register(&cmd));

    cmd = (esp_console_cmd_t){
        .command = "toggle_custom",
        .help = "Toggle custom feature",
        .hint = NULL,
        .func = &cmd_toggle_custom_feature,
    };
    ESP_ERROR_CHECK(esp_console_cmd_register(&cmd));
}
```

**Step 5: Use in Configuration**
```c
static void configure_impedance_measurement(void)
{
    AppIMPCfg_Type *pImpedanceCfg;
    AppIMPGetCfg(&pImpedanceCfg);
    
    // Existing configuration...
    
    // Apply custom parameters
    if (user_cfg.custom_feature_enable) {
        // Custom feature implementation
        pImpedanceCfg->ExcitBufGain *= user_cfg.custom_gain_factor;
    }
    
    // Custom filter configuration
    // Implementation depends on AD5940 capabilities
}
```

### Application-Specific Configurations

#### 1. Battery Testing Configuration
```c
static user_config_t battery_test_config = {
    .frequency = 1000.0f,             // 1 kHz for battery testing
    .excitation_voltage = 10.0f,      // Very low excitation
    .bias_voltage = 0.0f,             // No DC bias
    .sweep_enabled = false,           // Single frequency
    .power_mode = AFEPWR_LP,          // Low power mode
    .dft_num = DFTNUM_8192,          // Good resolution
    .adc_avg_num = ADCAVGNUM_64,     // High averaging for stability
    .hanwin_enable = true,            // Reduce noise
    .hstia_rtia_sel = HSTIARTIA_200,  // Low resistance for high current
};
```

#### 2. Bioimpedance Configuration
```c
static user_config_t bioimpedance_config = {
    .sweep_enabled = true,
    .sweep_start = 1000.0f,           // 1 kHz start
    .sweep_stop = 100000.0f,          // 100 kHz stop
    .sweep_points = 51,               // Good resolution
    .sweep_logarithmic = true,        // Logarithmic sweep
    .excitation_voltage = 100.0f,     // Safe for biological tissue
    .bias_voltage = 0.0f,             // No DC bias for safety
    .power_mode = AFEPWR_HP,          // High power for precision
    .hstia_rtia_sel = HSTIARTIA_5K,   // Appropriate for tissue impedance
};
```

#### 3. Material Characterization Configuration
```c
static user_config_t material_test_config = {
    .sweep_enabled = true,
    .sweep_start = 100.0f,            // Wide frequency range
    .sweep_stop = 1000000.0f,         // Up to 1 MHz
    .sweep_points = 101,              // High resolution
    .sweep_logarithmic = true,        // Logarithmic for wide range
    .excitation_voltage = 1000.0f,    // High excitation for good SNR
    .power_mode = AFEPWR_HP,          // High power for precision
    .dft_num = DFTNUM_16384,         // Maximum resolution
    .adc_avg_num = ADCAVGNUM_64,     // High averaging
    .hanwin_enable = true,            // Minimize artifacts
};
```

### Calibration and Validation

#### 1. System Calibration
```c
void perform_system_calibration(void)
{
    printf("=== System Calibration ===\n");
    
    // Test with known resistors
    float test_resistors[] = {100, 1000, 10000, 100000}; // Test values in ohms
    int num_tests = sizeof(test_resistors) / sizeof(test_resistors[0]);
    
    for (int i = 0; i < num_tests; i++) {
        printf("Connect %.0f ohm resistor and press Enter...\n", test_resistors[i]);
        getchar(); // Wait for user input
        
        // Configure for single frequency measurement
        user_cfg.frequency = 1000.0f;  // 1 kHz test frequency
        user_cfg.sweep_enabled = false;
        user_cfg.rcal_value = 10000.0f; // 10k calibration resistor
        
        configure_impedance_measurement();
        // Perform measurement and compare with expected value
        // Implementation depends on measurement collection method
    }
    
    printf("Calibration complete.\n");
}
```

#### 2. Accuracy Validation
```c
void validate_measurement_accuracy(void)
{
    printf("=== Accuracy Validation ===\n");
    
    // Test with precision resistors at multiple frequencies
    float test_frequencies[] = {100, 1000, 10000, 100000};
    float precision_resistor = 10000.0f; // 1% precision resistor
    
    for (int i = 0; i < 4; i++) {
        user_cfg.frequency = test_frequencies[i];
        user_cfg.sweep_enabled = false;
        
        configure_impedance_measurement();
        
        // Take multiple measurements and calculate statistics
        // Implementation depends on measurement collection method
        
        printf("Frequency: %.0f Hz - Expected: %.0f ohms\n", 
               test_frequencies[i], precision_resistor);
    }
}
```

---

## Appendices

### Appendix A: Pin Definitions

#### ESP32-S3 SPI Pins
| Function | GPIO | Alternative GPIOs |
|----------|------|-------------------|
| SCLK | 12 | 14, 21 |
| MOSI | 11 | 13, 35 |
| MISO | 13 | 12, 37 |
| CS | 10 | Any GPIO |
| RST | 14 | Any GPIO |
| INT | 15 | Any GPIO |

#### AD5940 Pin Functions
| Pin Name | Function | Description |
|----------|----------|-------------|
| SCLK | SPI Clock | Serial clock input |
| MOSI | SPI Data In | Master out, slave in |
| MISO | SPI Data Out | Master in, slave out |
| CS | Chip Select | Active low chip select |
| RST | Reset | Active low reset |
| GP0 | GPIO/Interrupt | Configurable GPIO/interrupt output |

### Appendix B: Register Map Summary

#### Key AD5940 Registers
| Register | Address | Function |
|----------|---------|----------|
| ADIID | 0x0400 | Analog Devices ID (0x4144) |
| CHIPID | 0x0404 | Chip ID (0x5502 for AD5940) |
| CALDATLOCK | Test register | For SPI communication testing |

### Appendix C: Error Recovery Procedures

#### 1. Complete System Reset
```bash
# Software reset
ad5940> restart_measurement

# Hardware reset (if software reset fails)
# Press reset button on ESP32

# Factory reset (restore default configuration)
# Modify user_cfg back to defaults and reflash
```

#### 2. SPI Communication Recovery
```c
// Recovery procedure for SPI issues
int recover_spi_communication(void)
{
    // Reset AD5940 hardware
    AD5940_RstSet();
    AD5940_Delay10us(100);
    AD5940_RstClr();
    AD5940_Delay10us(1000);
    
    // Reinitialize
    AD5940_Initialize();
    
    // Test communication
    uint32_t chip_id = AD5940_ReadReg(0x404);
    if (chip_id == 0x5502) {
        printf("SPI communication recovered\n");
        return 0;
    } else {
        printf("SPI recovery failed\n");
        return -1;
    }
}
```

### Appendix D: Measurement Theory

#### Impedance Calculation
The AD5940 measures impedance using the following principle:

```
Z = V / I = (V_excitation * R_cal) / (V_measured * TIA_gain)
```

Where:
- `Z` = Unknown impedance
- `V_excitation` = Applied excitation voltage
- `R_cal` = Calibration resistor value
- `V_measured` = Measured voltage across unknown impedance
- `TIA_gain` = Transimpedance amplifier gain

#### Frequency Response
The system frequency response is affected by:
- **DFT resolution**: Δf = f_sample / N_points
- **Measurement bandwidth**: Limited by ADC sampling rate
- **TIA bandwidth**: Frequency-dependent gain

#### Calibration Theory
Two-point calibration uses:
1. **Open circuit**: Infinite impedance reference
2. **Short circuit**: Zero impedance reference
3. **Known resistor**: Calibration standard

### Appendix E: Compliance and Safety

#### Electrical Safety
- **Maximum voltages**: Do not exceed specified voltage ranges
- **ESD protection**: Use proper ESD precautions when handling boards
- **Power supply**: Ensure stable, clean power supplies

#### Biomedical Applications
For bioimpedance applications:
- **Current limits**: Keep excitation current below 10 µA for safety
- **Isolation**: Use medical-grade isolation for patient contact
- **Standards compliance**: Follow IEC 60601 standards

#### EMC Considerations
- **Shielding**: Use proper shielding for sensitive measurements
- **Grounding**: Implement proper grounding schemes
- **Cable routing**: Keep signal and power cables separated

---

## Document Information

**Document Version**: 1.0  
**Last Updated**: December 2024  
**Document Format**: Markdown  
**License**: [Specify your license here]  

### Revision History
| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Dec 2024 | Initial release |

### Contact Information
- **Technical Support**: [Your support email]
- **Documentation**: [Your documentation repository]
- **Issues**: [Your issue tracker]

---

*This manual is provided as-is. Please refer to the official AD5940 datasheet and ESP32 documentation for complete technical specifications.*