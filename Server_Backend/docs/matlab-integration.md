# MATLAB Client Integration Guide

This guide shows how to integrate MATLAB with your IoT server for ESP32 communication and data analysis.

## MATLAB HTTP Client Setup

### 1. Authentication and Session Management

```matlab
classdef IoTServerClient < handle
    % MATLAB client for IoT server communication
    
    properties (Access = private)
        baseURL
        token
        options
    end
    
    methods
        function obj = IoTServerClient(serverURL)
            % Constructor
            obj.baseURL = serverURL;
            obj.token = '';
            obj.options = weboptions('ContentType', 'json', 'Timeout', 30);
        end
        
        function success = login(obj, username, password)
            % Authenticate with the server
            try
                loginData = struct('username', username, 'password', password);
                response = webwrite([obj.baseURL '/auth/login'], loginData, obj.options);
                
                obj.token = response.access_token;
                obj.options.HeaderFields = {'Authorization', ['Bearer ' obj.token]};
                
                fprintf('✅ Successfully authenticated with IoT server\n');
                success = true;
            catch ME
                fprintf('❌ Authentication failed: %s\n', ME.message);
                success = false;
            end
        end
        
        function devices = getDevices(obj)
            % Get list of all ESP32 devices
            try
                devices = webread([obj.baseURL '/devices/'], obj.options);
                fprintf('📱 Found %d devices\n', length(devices));
            catch ME
                fprintf('❌ Failed to get devices: %s\n', ME.message);
                devices = [];
            end
        end
        
        function data = downloadSensorData(obj, deviceId, varargin)
            % Download sensor data from specified device
            
            % Parse optional parameters
            p = inputParser;
            addParameter(p, 'startTime', '', @ischar);
            addParameter(p, 'endTime', '', @ischar);
            addParameter(p, 'measurementTypes', {}, @iscell);
            addParameter(p, 'channels', [], @isnumeric);
            parse(p, varargin{:});
            
            % Build request
            request = struct('device_id', deviceId);
            if ~isempty(p.Results.startTime)
                request.start_time = p.Results.startTime;
            end
            if ~isempty(p.Results.endTime)
                request.end_time = p.Results.endTime;
            end
            if ~isempty(p.Results.measurementTypes)
                request.measurement_types = p.Results.measurementTypes;
            end
            if ~isempty(p.Results.channels)
                request.channels = p.Results.channels;
            end
            
            try
                response = webwrite([obj.baseURL '/matlab/download'], request, obj.options);
                data = obj.parseServerData(response);
                fprintf('📊 Downloaded %d data points\n', length(data.timestamps));
            catch ME
                fprintf('❌ Failed to download data: %s\n', ME.message);
                data = [];
            end
        end
        
        function success = sendCommand(obj, deviceId, command, parameters)
            % Send command to ESP32 device
            try
                commandData = struct(...
                    'device_id', deviceId, ...
                    'command', command, ...
                    'parameters', parameters ...
                );
                
                response = webwrite([obj.baseURL '/matlab/command'], commandData, obj.options);
                fprintf('📤 Command sent: %s to device %s\n', command, deviceId);
                success = true;
            catch ME
                fprintf('❌ Failed to send command: %s\n', ME.message);
                success = false;
            end
        end
        
        function data = parseServerData(obj, serverResponse)
            % Convert server response to MATLAB-friendly format
            rawData = serverResponse.data;
            
            if isempty(rawData)
                data = [];
                return;
            end
            
            % Extract data into arrays
            timestamps = datetime({rawData.timestamp}, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSSSS');
            values = [rawData.value];
            channels = [rawData.channel];
            measurementTypes = {rawData.measurement_type};
            units = {rawData.unit};
            
            % Create structured data
            data = struct(...
                'timestamps', timestamps, ...
                'values', values, ...
                'channels', channels, ...
                'measurementTypes', {measurementTypes}, ...
                'units', {units}, ...
                'metadata', serverResponse.metadata ...
            );
        end
    end
end
```

### 2. Example MATLAB Usage Scripts

#### Basic Device Communication
```matlab
%% IoT Server Communication Example
% This script demonstrates basic communication with the IoT server

% Initialize client
client = IoTServerClient('http://localhost:8000');

% Authenticate
if client.login('your_username', 'your_password')
    
    % Get available devices
    devices = client.getDevices();
    
    if ~isempty(devices)
        deviceId = devices(1).device_id;
        fprintf('Using device: %s\n', deviceId);
        
        % Send measurement command
        success = client.sendCommand(deviceId, 'start_measurement', struct(...
            'sampling_rate', 1000, ...
            'channels', [1, 2, 3], ...
            'measurement_type', 'impedance' ...
        ));
        
        if success
            % Wait for measurement
            pause(5);
            
            % Download data
            data = client.downloadSensorData(deviceId, ...
                'measurementTypes', {'impedance'}, ...
                'channels', [1, 2, 3] ...
            );
            
            if ~isempty(data)
                % Plot results
                figure;
                plot(data.timestamps, data.values);
                title('ESP32 Sensor Data');
                xlabel('Time');
                ylabel('Impedance (Ohm)');
                grid on;
            end
        end
    end
end
```

#### Advanced Data Analysis
```matlab
%% Advanced IoT Data Analysis
% Comprehensive analysis of multi-channel sensor data

function analyzeIoTData()
    % Initialize client
    client = IoTServerClient('http://localhost:8000');
    
    if ~client.login('your_username', 'your_password')
        error('Authentication failed');
    end
    
    deviceId = 'ESP32_001';
    
    % Download historical data (last 24 hours)
    endTime = datetime('now');
    startTime = endTime - hours(24);
    
    data = client.downloadSensorData(deviceId, ...
        'startTime', char(startTime, 'yyyy-MM-dd''T''HH:mm:ss'), ...
        'endTime', char(endTime, 'yyyy-MM-dd''T''HH:mm:ss'), ...
        'measurementTypes', {'impedance', 'voltage'} ...
    );
    
    if isempty(data)
        warning('No data available for analysis');
        return;
    end
    
    % Organize data by measurement type and channel
    impedanceData = filterData(data, 'impedance');
    voltageData = filterData(data, 'voltage');
    
    % Create analysis dashboard
    createAnalysisDashboard(impedanceData, voltageData);
    
    % Perform statistical analysis
    stats = performStatisticalAnalysis(impedanceData);
    displayStatistics(stats);
    
    % Export results
    exportResults(data, stats, 'iot_analysis_results.mat');
end

function filteredData = filterData(data, measurementType)
    % Filter data by measurement type
    mask = strcmp(data.measurementTypes, measurementType);
    
    filteredData = struct(...
        'timestamps', data.timestamps(mask), ...
        'values', data.values(mask), ...
        'channels', data.channels(mask) ...
    );
end

function createAnalysisDashboard(impedanceData, voltageData)
    % Create comprehensive analysis dashboard
    figure('Position', [100, 100, 1200, 800]);
    
    % Impedance time series
    subplot(2, 3, 1);
    plot(impedanceData.timestamps, impedanceData.values, 'b-');
    title('Impedance vs Time');
    xlabel('Time');
    ylabel('Impedance (Ω)');
    grid on;
    
    % Voltage time series
    subplot(2, 3, 2);
    plot(voltageData.timestamps, voltageData.values, 'r-');
    title('Voltage vs Time');
    xlabel('Time');
    ylabel('Voltage (V)');
    grid on;
    
    % Impedance histogram
    subplot(2, 3, 3);
    histogram(impedanceData.values, 30);
    title('Impedance Distribution');
    xlabel('Impedance (Ω)');
    ylabel('Frequency');
    
    % Channel comparison
    subplot(2, 3, 4);
    uniqueChannels = unique(impedanceData.channels);
    channelMeans = arrayfun(@(ch) mean(impedanceData.values(impedanceData.channels == ch)), uniqueChannels);
    bar(uniqueChannels, channelMeans);
    title('Mean Impedance by Channel');
    xlabel('Channel');
    ylabel('Mean Impedance (Ω)');
    
    % Correlation analysis
    subplot(2, 3, 5);
    if length(uniqueChannels) >= 2
        ch1_data = impedanceData.values(impedanceData.channels == uniqueChannels(1));
        ch2_data = impedanceData.values(impedanceData.channels == uniqueChannels(2));
        minLen = min(length(ch1_data), length(ch2_data));
        scatter(ch1_data(1:minLen), ch2_data(1:minLen));
        title(sprintf('Channel %d vs Channel %d', uniqueChannels(1), uniqueChannels(2)));
        xlabel(sprintf('Channel %d (Ω)', uniqueChannels(1)));
        ylabel(sprintf('Channel %d (Ω)', uniqueChannels(2)));
    end
    
    % FFT Analysis
    subplot(2, 3, 6);
    if length(impedanceData.values) > 100
        [pxx, f] = periodogram(impedanceData.values);
        semilogy(f, pxx);
        title('Power Spectral Density');
        xlabel('Normalized Frequency');
        ylabel('Power/Frequency');
    end
end

function stats = performStatisticalAnalysis(data)
    % Comprehensive statistical analysis
    stats = struct();
    stats.mean = mean(data.values);
    stats.std = std(data.values);
    stats.min = min(data.values);
    stats.max = max(data.values);
    stats.median = median(data.values);
    stats.dataPoints = length(data.values);
    stats.timeSpan = hours(data.timestamps(end) - data.timestamps(1));
end

function displayStatistics(stats)
    % Display statistical summary
    fprintf('\n📊 Statistical Analysis Summary\n');
    fprintf('================================\n');
    fprintf('Data Points: %d\n', stats.dataPoints);
    fprintf('Time Span: %.1f hours\n', stats.timeSpan);
    fprintf('Mean: %.3f\n', stats.mean);
    fprintf('Std Dev: %.3f\n', stats.std);
    fprintf('Min: %.3f\n', stats.min);
    fprintf('Max: %.3f\n', stats.max);
    fprintf('Median: %.3f\n', stats.median);
end

function exportResults(data, stats, filename)
    % Export analysis results
    save(filename, 'data', 'stats');
    fprintf('✅ Results exported to %s\n', filename);
end
```

### 3. Real-time Data Streaming (WebSocket)

```matlab
%% Real-time Data Streaming
% Monitor ESP32 data in real-time using WebSocket connection

function realtimeMonitor()
    % Real-time monitoring setup
    client = IoTServerClient('http://localhost:8000');
    
    if ~client.login('your_username', 'your_password')
        error('Authentication failed');
    end
    
    % Setup real-time plot
    figure('Position', [100, 100, 800, 600]);
    h = animatedline('Color', 'blue', 'LineWidth', 2);
    xlim([0, 100]);
    ylim([0, 1000]);
    xlabel('Sample Number');
    ylabel('Sensor Value');
    title('Real-time ESP32 Data');
    grid on;
    
    % Polling loop (in production, use WebSocket)
    sampleCount = 0;
    while sampleCount < 1000
        try
            % Get latest data point
            data = client.downloadSensorData('ESP32_001', ...
                'measurementTypes', {'impedance'}, ...
                'channels', 1 ...
            );
            
            if ~isempty(data) && length(data.values) > sampleCount
                newValue = data.values(end);
                sampleCount = sampleCount + 1;
                
                addpoints(h, sampleCount, newValue);
                drawnow;
                
                % Auto-scale y-axis
                if mod(sampleCount, 10) == 0
                    ylim([min(h.YData) * 0.9, max(h.YData) * 1.1]);
                end
            end
            
            pause(0.1); % 10 Hz update rate
            
        catch ME
            fprintf('⚠️ Connection error: %s\n', ME.message);
            pause(1);
        end
    end
end
```

## Integration Workflow

### 1. Initial Setup
1. Start your IoT server: `docker-compose up -d`
2. Create MATLAB client: `client = IoTServerClient('http://localhost:8000')`
3. Authenticate: `client.login('username', 'password')`

### 2. Device Management
1. List devices: `devices = client.getDevices()`
2. Send commands: `client.sendCommand(deviceId, 'command', parameters)`
3. Monitor status via heartbeat endpoints

### 3. Data Analysis
1. Download historical data with filters
2. Perform statistical analysis
3. Create visualizations and reports
4. Export results for further processing

### 4. Production Considerations
- Implement proper error handling and retry logic
- Use connection pooling for high-frequency requests
- Consider WebSocket for real-time data streaming
- Implement data caching for improved performance
- Add logging and monitoring for debugging