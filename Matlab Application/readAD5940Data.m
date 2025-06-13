% Simple MATLAB script to read ESP32 AD5940 data (Binary Protocol)
function readAD5940Data()
    % Configuration
    COM_PORT = "COM6";  % Change to your ESP32 COM port
    BAUD_RATE = 115200;
    
    % Connect to ESP32
    fprintf('Connecting to ESP32 on %s...\n', COM_PORT);
    s = serialport(COM_PORT, BAUD_RATE);
    s.Timeout = 10;  % 10 second timeout
    
    % Storage for data
    frequency = [];
    magnitude = [];
    phase = [];
    
    % Create figure for real-time plotting
    figure('Name', 'AD5940 Real-time Data', 'NumberTitle', 'off');
    
    subplot(2,1,1);
    h_mag = plot(nan, nan, 'b.-');
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (Ω)');
    title('Impedance Magnitude');
    grid on;
    set(gca, 'XScale', 'log');
    
    subplot(2,1,2);
    h_phase = plot(nan, nan, 'r.-');
    xlabel('Frequency (Hz)');
    ylabel('Phase (degrees)');
    title('Impedance Phase');
    grid on;
    set(gca, 'XScale', 'log');
    
    % Wait for system ready
    fprintf('Waiting for ESP32 to be ready...\n');
    while true
        if s.NumBytesAvailable > 0
            % Check for text-based system ready message
            try
                line = readline(s);
                if contains(line, "SYSTEM_READY")
                    fprintf('ESP32 ready! Starting data collection...\n');
                    break;
                end
            catch
                % If readline fails, might be binary data, ignore for now
            end
        end
        pause(0.1);
    end
    
    % Read data continuously
    fprintf('Press Ctrl+C to stop data collection...\n');
    fprintf('Reading binary data format...\n');
    
    try
        while true
            if s.NumBytesAvailable >= 13  % 1 sync byte + 12 data bytes
                % Look for sync byte (0xFF)
                sync_byte = read(s, 1, "uint8");
                
                if sync_byte == 255  % 0xFF sync byte found
                    try
                        % Read binary measurement data (3 floats = 12 bytes)
                        binary_data = read(s, 3, "single");
                        
                        freq = binary_data(1);
                        mag = binary_data(2);
                        ph = binary_data(3);
                        
                        % Validate data (basic sanity check)
                        if freq > 0 && mag > 0 && ~isnan(freq) && ~isnan(mag) && ~isnan(ph)
                            % Store data
                            frequency(end+1) = freq;
                            magnitude(end+1) = mag;
                            phase(end+1) = ph;
                            
                            % Update plots
                            set(h_mag, 'XData', frequency, 'YData', magnitude);
                            set(h_phase, 'XData', frequency, 'YData', phase);
                            
                            % Auto-scale axes
                            if length(frequency) > 1
                                subplot(2,1,1);
                                xlim([min(frequency), max(frequency)]);
                                ylim([min(magnitude)*0.9, max(magnitude)*1.1]);
                                
                                subplot(2,1,2);
                                xlim([min(frequency), max(frequency)]);
                                ylim([min(phase)*1.1, max(phase)*1.1]);
                            end
                            
                            drawnow;
                            
                            % Print to console
                            fprintf('Freq: %8.2f Hz, Mag: %8.2f Ω, Phase: %6.2f°\n', ...
                                    freq, mag, ph);
                        else
                            fprintf('Invalid data received, skipping...\n');
                        end
                        
                    catch readError
                        fprintf('Error reading binary data: %s\n', readError.message);
                        % Skip malformed data
                        continue;
                    end
                else
                    % Not a sync byte, might be leftover text data
                    % Try to read as text for debugging
                    if s.NumBytesAvailable > 0
                        try
                            % Put the byte back and try to read as text
                            remaining_data = read(s, min(s.NumBytesAvailable, 100), "uint8");
                            text_data = char([sync_byte, remaining_data']);
                            if contains(text_data, "DATA:")
                                fprintf('Received text data: %s\n', text_data);
                            end
                        catch
                            % Ignore text parsing errors
                        end
                    end
                end
            end
            pause(0.01);  % Small delay to prevent CPU overload
        end
        
    catch ME
        if contains(ME.message, 'interrupted')
            fprintf('\nData collection stopped by user.\n');
        else
            fprintf('Error: %s\n', ME.message);
        end
    end
    
    % Save data when done
    if ~isempty(frequency)
        timestamp = datetime('now', 'yyyy-mm-dd_HH-MM-SS');
        filename = sprintf('AD5940_data_%s.mat', timestamp);
        save(filename, 'frequency', 'magnitude', 'phase');
        fprintf('Data saved to: %s\n', filename);
        
        % Final summary plot
        figure('Name', 'Final Results', 'NumberTitle', 'off');
        
        subplot(2,1,1);
        semilogx(frequency, magnitude, 'b.-');
        xlabel('Frequency (Hz)');
        ylabel('Magnitude (Ω)');
        title('Final Impedance Magnitude');
        grid on;
        
        subplot(2,1,2);
        semilogx(frequency, phase, 'r.-');
        xlabel('Frequency (Hz)');
        ylabel('Phase (degrees)');
        title('Final Impedance Phase');
        grid on;
    end
    
    % Close serial connection
    clear s;
    fprintf('Serial connection closed.\n');
end