function simple_eis_capture()
% Simple EIS Data Capture Script
% Connects to AD5940 board via serial and plots frequency, magnitude, phase
% Parameters are controlled via firmware

clc; close all;
fprintf('=== Simple EIS Data Capture ===\n');

% Configuration
BAUD_RATE = 115200;
TIMEOUT_SEC = 10;

% Data storage
frequencies = [];
magnitudes = [];
phases = [];
measurement_count = 0;

try
    % Find and connect to serial port
    ports = serialportlist("available");
    if isempty(ports)
        error('No serial ports found');
    end
    
    if isscalar(ports)
        selected_port = ports(1);
        fprintf('Using port: %s\n', selected_port);
    else
        fprintf('Available ports:\n');
        for i = 1:length(ports)
            fprintf('  %d: %s\n', i, ports(i));
        end
        port_idx = input('Select port: ');
        selected_port = ports(port_idx);
    end

    % Ask for board selection before connecting
    fprintf('\nBoard Selection:\n');
    fprintf('1: AD5940 Impedance Measurement\n');
    fprintf('2: AD5941 Battery Impedance Measurement\n');
    board_choice = input('Select board (1 or 2): ');

    if board_choice ~= 1 && board_choice ~= 2
        error('Invalid board choice. Must be 1 or 2.');
    end
    
    % Connect to ESP32
    fprintf('Connecting to %s...\n', selected_port);
    serial_conn = serialport(selected_port, BAUD_RATE);
    serial_conn.Timeout = TIMEOUT_SEC;
    flush(serial_conn);
    pause(1);

    fprintf('Connected! Waiting for board selection prompt...\n');

    % Wait for board selection prompt and send pre-selected choice
    board_sent = false;
    timeout_time = tic;

    while toc(timeout_time) < 10 && ~board_sent
        if serial_conn.NumBytesAvailable > 0
            line = readline(serial_conn);
            fprintf('ESP32: %s\n', line);

            % Check for board selection prompt
            if contains(line, 'Enter choice (1 or 2):')
                % Send pre-selected board choice
                writeline(serial_conn, num2str(board_choice));
                fprintf('Sent board choice: %d\n', board_choice);
                board_sent = true;
            end
        end
        pause(0.1);
    end

    if ~board_sent
        error('Board selection timeout - no prompt received');
    end

    fprintf('Board choice sent! Waiting for measurement data...\n');
    fprintf('Press Ctrl+C to stop\n\n');
    
    % Setup plots
    figure('Name', 'EIS Real-time Data', 'Position', [100 100 1200 400]);
    
    % Magnitude plot
    subplot(1,3,1);
    h_mag = semilogx(NaN, NaN, 'b-o', 'LineWidth', 2, 'MarkerSize', 4);
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (Ohm)');
    title('Impedance Magnitude');
    grid on;
    
    % Phase plot  
    subplot(1,3,2);
    h_phase = semilogx(NaN, NaN, 'r-o', 'LineWidth', 2, 'MarkerSize', 4);
    xlabel('Frequency (Hz)');
    ylabel('Phase (degrees)');
    title('Impedance Phase');
    grid on;
    
    % Nyquist plot
    subplot(1,3,3);
    h_nyquist = plot(NaN, NaN, 'g-o', 'LineWidth', 2, 'MarkerSize', 4);
    xlabel('Real Impedance (Ohm)');
    ylabel('Imaginary Impedance (Ohm)');
    title('Nyquist Plot');
    grid on;
    axis equal;
    
    drawnow;
    
    % Data capture loop
    start_time = datetime('now');
    
    while true
        if serial_conn.NumBytesAvailable > 0
            try
                line = readline(serial_conn);
                fprintf('%s\n', line);
                
                % Parse EIS data (text format: "Freq:1.44 RzMag: 958066432.000000 Ohm , RzPhase: 0.425207")
                if contains(line, 'Freq:') && contains(line, 'RzMag:') && contains(line, 'RzPhase:')
                    try
                        % Extract frequency
                        freq_match = regexp(line, 'Freq:([\d.]+)', 'tokens');
                        % Extract magnitude
                        mag_match = regexp(line, 'RzMag:\s*([\d.]+)', 'tokens');
                        % Extract phase
                        phase_match = regexp(line, 'RzPhase:\s*([\d.-]+)', 'tokens');
                        
                        if ~isempty(freq_match) && ~isempty(mag_match) && ~isempty(phase_match)
                            measurement_count = measurement_count + 1;
                            
                            % Store data
                            frequencies(end+1) = str2double(freq_match{1}{1});
                            magnitudes(end+1) = str2double(mag_match{1}{1});
                            phases(end+1) = str2double(phase_match{1}{1});
                            
                            % Calculate real and imaginary parts for Nyquist
                            real_z = magnitudes(end) * cos(deg2rad(phases(end)));
                            imag_z = magnitudes(end) * sin(deg2rad(phases(end)));
                            
                            % Update plots
                            set(h_mag, 'XData', frequencies, 'YData', magnitudes);
                            set(h_phase, 'XData', frequencies, 'YData', phases);
                            
                            % Update Nyquist plot
                            real_parts = magnitudes .* cos(deg2rad(phases));
                            imag_parts = magnitudes .* sin(deg2rad(phases));
                            set(h_nyquist, 'XData', real_parts, 'YData', -imag_parts);
                            
                            % Auto-scale axes
                            subplot(1,3,1); axis tight;
                            subplot(1,3,2); axis tight;
                            subplot(1,3,3); axis tight; axis equal;
                            
                            drawnow;
                            
                            fprintf('Point %d: f=%.2f Hz, |Z|=%.2f Ohm, φ=%.2f°\n', ...
                                measurement_count, frequencies(end), magnitudes(end), phases(end));
                        end
                        
                    catch ME
                        fprintf('Parse error: %s\n', ME.message);
                    end
                end
                
            catch ME
                if contains(ME.message, 'Timeout')
                    continue;
                else
                    fprintf('Read error: %s\n', ME.message);
                end
            end
        end
        
        pause(0.01);
    end
    
catch ME
    if ~contains(ME.message, 'interrupted')
        fprintf('Error: %s\n', ME.message);
    end
end

% Cleanup and save data
fprintf('\n=== Saving Data ===\n');

try
    if exist('serial_conn', 'var')
        delete(serial_conn);
        fprintf('Serial connection closed.\n');
    end
catch
end

% Save data if we have measurements
if measurement_count > 0
    % Create data structure
    eis_data = struct();
    eis_data.frequencies = frequencies';
    eis_data.magnitudes = magnitudes';
    eis_data.phases = phases';
    eis_data.real_impedance = magnitudes' .* cos(deg2rad(phases'));
    eis_data.imag_impedance = magnitudes' .* sin(deg2rad(phases'));
    eis_data.measurement_time = start_time;
    eis_data.num_points = measurement_count;
    eis_data.port_used = selected_port;
    
    % Generate filename
    timestamp_str = datetime(start_time, 'yyyy-mm-dd_HH-MM-SS');
    filename = sprintf('eis_data_%s.mat', timestamp_str);
    
    % Save data
    save(filename, 'eis_data');
    fprintf('Data saved to: %s\n', filename);
    fprintf('Total measurements: %d\n', measurement_count);
    
    % Also save as CSV for external analysis
    csv_filename = sprintf('eis_data_%s.csv', timestamp_str);
    data_table = table(eis_data.frequencies, eis_data.magnitudes, eis_data.phases, ...
        eis_data.real_impedance, eis_data.imag_impedance, ...
        'VariableNames', {'Frequency_Hz', 'Magnitude_Ohm', 'Phase_deg', 'Real_Ohm', 'Imag_Ohm'});
    
    writetable(data_table, csv_filename);
    fprintf('CSV saved to: %s\n', csv_filename);
else
    fprintf('No measurement data captured.\n');
end

fprintf('\nCapture session completed.\n');

end