classdef DatasetGenerator < handle
    % Utility class for generating realistic test datasets
    % for ESP32 Data Analyzer testing
    
    properties (Access = private)
        NoiseLevel = 0.02
        SampleRate = 10
        Duration = 60
    end
    
    methods (Access = public)
        
        function obj = DatasetGenerator(varargin)
            % Constructor with optional parameters
            p = inputParser;
            addParameter(p, 'NoiseLevel', 0.02, @isnumeric);
            addParameter(p, 'SampleRate', 10, @isnumeric);
            addParameter(p, 'Duration', 60, @isnumeric);
            parse(p, varargin{:});
            
            obj.NoiseLevel = p.Results.NoiseLevel;
            obj.SampleRate = p.Results.SampleRate;
            obj.Duration = p.Results.Duration;
        end
        
        function [time, voltage] = generateRCCharging(obj, R, C, V0)
            % Generate RC charging curve data
            % V(t) = V0 * (1 - exp(-t/(R*C)))
            
            if nargin < 4, V0 = 5.0; end
            if nargin < 3, C = 100e-6; end
            if nargin < 2, R = 1000; end
            
            time = (0:1/obj.SampleRate:obj.Duration)';
            tau = R * C;
            
            % Generate clean signal
            voltage_clean = V0 * (1 - exp(-time/tau));
            
            % Add realistic noise and artifacts
            voltage = obj.addRealisticNoise(voltage_clean, time);
        end
        
        function [time, voltage] = generateRCDischarging(obj, R, C, V0)
            % Generate RC discharging curve data
            % V(t) = V0 * exp(-t/(R*C))
            
            if nargin < 4, V0 = 5.0; end
            if nargin < 3, C = 100e-6; end
            if nargin < 2, R = 1000; end
            
            time = (0:1/obj.SampleRate:obj.Duration)';
            tau = R * C;
            
            % Generate clean signal
            voltage_clean = V0 * exp(-time/tau);
            
            % Add realistic noise and artifacts
            voltage = obj.addRealisticNoise(voltage_clean, time);
        end
        
        function [time, voltage] = generateRLCUnderdamped(obj, R, L, C, V0)
            % Generate underdamped RLC response
            
            if nargin < 5, V0 = 5.0; end
            if nargin < 4, C = 10e-6; end
            if nargin < 3, L = 0.1; end
            if nargin < 2, R = 100; end
            
            time = (0:1/obj.SampleRate:obj.Duration)';
            
            % Calculate damping parameters
            omega0 = 1/sqrt(L*C);
            alpha = R/(2*L);
            omega_d = sqrt(omega0^2 - alpha^2);
            
            if omega_d > 0  % Underdamped
                voltage_clean = V0 * (1 - exp(-alpha*time) .* ...
                    (cos(omega_d*time) + (alpha/omega_d)*sin(omega_d*time)));
            else  % Overdamped fallback
                voltage_clean = obj.generateRCCharging(R, C, V0);
                voltage_clean = voltage_clean(1:length(time));
            end
            
            voltage = obj.addRealisticNoise(voltage_clean, time);
        end
        
        function [time, voltage] = generateDoubleRC(obj, R1, C1, R2, C2, V0)
            % Generate double RC circuit response
            
            if nargin < 6, V0 = 5.0; end
            if nargin < 5, C2 = 10e-6; end
            if nargin < 4, R2 = 10000; end
            if nargin < 3, C1 = 100e-6; end
            if nargin < 2, R1 = 1000; end
            
            time = (0:1/obj.SampleRate:obj.Duration)';
            
            tau1 = R1 * C1;
            tau2 = R2 * C2;
            
            % Double exponential response
            A1 = 0.6;
            A2 = 0.4;
            voltage_clean = V0 * (1 - A1*exp(-time/tau1) - A2*exp(-time/tau2));
            
            voltage = obj.addRealisticNoise(voltage_clean, time);
        end
        
        function [time, voltage] = generateBatteryDischarge(obj, capacity, current, V_nominal)
            % Generate realistic battery discharge curve
            
            if nargin < 4, V_nominal = 3.7; end
            if nargin < 3, current = 0.1; end  % 100mA
            if nargin < 2, capacity = 2.0; end  % 2Ah
            
            time = (0:1/obj.SampleRate:obj.Duration)';
            
            % Simplified battery model
            discharge_time = capacity / current * 3600;  % seconds
            SOC = max(0, 1 - time/discharge_time);  % State of charge
            
            % Voltage vs SOC relationship (simplified)
            voltage_clean = V_nominal * (0.7 + 0.3*SOC);
            
            % Add battery-specific characteristics
            voltage_clean = voltage_clean - 0.1*current*SOC;  % Internal resistance effect
            
            voltage = obj.addRealisticNoise(voltage_clean, time);
        end
        
        function [time, voltage] = generateStepResponse(obj, amplitude, step_time, tau)
            % Generate step response with exponential settling
            
            if nargin < 4, tau = 5.0; end
            if nargin < 3, step_time = 10.0; end
            if nargin < 2, amplitude = 3.3; end
            
            time = (0:1/obj.SampleRate:obj.Duration)';
            
            % Step function
            step_signal = amplitude * (time >= step_time);
            
            % Exponential settling
            settling = amplitude * (1 - exp(-(time-step_time)/tau)) .* (time >= step_time);
            voltage_clean = settling;
            
            voltage = obj.addRealisticNoise(voltage_clean, time);
        end
        
        function [time, voltage] = generateSinusoidalWithDC(obj, dc_level, amplitude, frequency, phase)
            % Generate sinusoidal signal with DC offset
            
            if nargin < 5, phase = 0; end
            if nargin < 4, frequency = 0.1; end  % 0.1 Hz
            if nargin < 3, amplitude = 1.0; end
            if nargin < 2, dc_level = 2.5; end
            
            time = (0:1/obj.SampleRate:obj.Duration)';
            
            voltage_clean = dc_level + amplitude * sin(2*pi*frequency*time + phase);
            
            voltage = obj.addRealisticNoise(voltage_clean, time);
        end
        
        function [time, voltage] = generateComplexWaveform(obj)
            % Generate complex waveform combining multiple components
            
            time = (0:1/obj.SampleRate:obj.Duration)';
            
            % Multiple components
            component1 = 2.5 * (1 - exp(-time/10));  % Exponential rise
            component2 = 0.5 * sin(2*pi*0.05*time);  % Low frequency sine
            component3 = 0.2 * sin(2*pi*0.2*time);   % Higher frequency sine
            component4 = 0.1 * sawtooth(2*pi*0.02*time);  % Sawtooth
            
            voltage_clean = component1 + component2 + component3 + component4;
            
            voltage = obj.addRealisticNoise(voltage_clean, time);
        end
        
    end
    
    methods (Access = private)
        
        function voltage_noisy = addRealisticNoise(obj, voltage_clean, time)
            % Add realistic noise and measurement artifacts
            
            % Gaussian noise
            gaussian_noise = obj.NoiseLevel * randn(size(voltage_clean)) .* max(voltage_clean);
            
            % 1/f noise (pink noise approximation)
            pink_noise = obj.generatePinkNoise(length(voltage_clean)) * obj.NoiseLevel * 0.5;
            
            % Quantization noise (ADC simulation)
            adc_bits = 12;  % 12-bit ADC
            adc_levels = 2^adc_bits;
            voltage_quantized = round(voltage_clean * adc_levels / max(voltage_clean)) * max(voltage_clean) / adc_levels;
            quantization_noise = voltage_quantized - voltage_clean;
            
            % Occasional spikes (EMI simulation)
            spike_probability = 0.001;  % 0.1% chance per sample
            spikes = (rand(size(time)) < spike_probability) .* randn(size(time)) * obj.NoiseLevel * 5;
            
            % Temperature drift (very slow)
            temp_drift = 0.001 * max(voltage_clean) * sin(2*pi*time/(obj.Duration*10));
            
            % Combine all noise sources
            voltage_noisy = voltage_clean + gaussian_noise + pink_noise + ...
                           quantization_noise + spikes + temp_drift;
            
            % Ensure non-negative voltage
            voltage_noisy = max(0, voltage_noisy);
        end
        
        function pink_noise = generatePinkNoise(obj, N)
            % Generate pink noise (1/f noise)
            
            % Ensure N is an integer
            N = round(N);
            
            % Generate white noise
            white_noise = randn(N, 1);
            
            % Apply 1/f filter in frequency domain
            X = fft(white_noise);
            
            % Create frequency vector for positive frequencies
            if mod(N, 2) == 0
                % Even length
                freqs = (1:N/2+1)';
                num_pos_freqs = N/2 + 1;
            else
                % Odd length
                freqs = (1:(N+1)/2)';
                num_pos_freqs = (N+1)/2;
            end
            
            % 1/f amplitude scaling
            scaling = 1 ./ sqrt(freqs);
            scaling(1) = 1;  % Avoid division by zero at DC
            
            % Apply scaling to positive frequencies
            X(1:num_pos_freqs) = X(1:num_pos_freqs) .* scaling;
            
            % Mirror for negative frequencies
            if mod(N, 2) == 0
                % Even length: mirror frequencies 2 to N/2
                X(N/2+2:N) = conj(X(N/2:-1:2));
            else
                % Odd length: mirror frequencies 2 to (N+1)/2
                X(num_pos_freqs+1:N) = conj(X(num_pos_freqs-1:-1:2));
            end
            
            % Convert back to time domain
            pink_noise = real(ifft(X));
        end
    end
    
    methods (Static)
        
        function demonstrateDatasets()
            % Demonstrate all available dataset types
            
            generator = DatasetGenerator('Duration', 30, 'SampleRate', 20, 'NoiseLevel', 0.03);
            
            figure('Position', [100 100 1200 800]);
            
            % RC Charging
            subplot(3, 3, 1);
            [t, v] = generator.generateRCCharging(1000, 100e-6, 5);
            plot(t, v, 'b-', 'LineWidth', 1.5);
            title('RC Charging');
            xlabel('Time (s)'); ylabel('Voltage (V)');
            grid on;
            
            % RC Discharging
            subplot(3, 3, 2);
            [t, v] = generator.generateRCDischarging(1000, 100e-6, 5);
            plot(t, v, 'r-', 'LineWidth', 1.5);
            title('RC Discharging');
            xlabel('Time (s)'); ylabel('Voltage (V)');
            grid on;
            
            % RLC Underdamped
            subplot(3, 3, 3);
            [t, v] = generator.generateRLCUnderdamped(100, 0.1, 10e-6, 5);
            plot(t, v, 'g-', 'LineWidth', 1.5);
            title('RLC Underdamped');
            xlabel('Time (s)'); ylabel('Voltage (V)');
            grid on;
            
            % Double RC
            subplot(3, 3, 4);
            [t, v] = generator.generateDoubleRC(1000, 100e-6, 5000, 20e-6, 5);
            plot(t, v, 'm-', 'LineWidth', 1.5);
            title('Double RC');
            xlabel('Time (s)'); ylabel('Voltage (V)');
            grid on;
            
            % Battery Discharge
            subplot(3, 3, 5);
            [t, v] = generator.generateBatteryDischarge(2.0, 0.1, 3.7);
            plot(t, v, 'c-', 'LineWidth', 1.5);
            title('Battery Discharge');
            xlabel('Time (s)'); ylabel('Voltage (V)');
            grid on;
            
            % Step Response
            subplot(3, 3, 6);
            [t, v] = generator.generateStepResponse(3.3, 5, 3);
            plot(t, v, 'k-', 'LineWidth', 1.5);
            title('Step Response');
            xlabel('Time (s)'); ylabel('Voltage (V)');
            grid on;
            
                        % Sinusoidal with DC
            subplot(3, 3, 7);
            [t, v] = generator.generateSinusoidalWithDC(2.5, 1.0, 0.1, 0);
            plot(t, v, 'y-', 'LineWidth', 1.5);
            title('Sinusoidal with DC');
            xlabel('Time (s)'); ylabel('Voltage (V)');
            grid on;
            
            % Complex Waveform
            subplot(3, 3, 8);
            [t, v] = generator.generateComplexWaveform();
            plot(t, v, 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
            title('Complex Waveform');
            xlabel('Time (s)'); ylabel('Voltage (V)');
            grid on;
            
            % Noise Comparison
            subplot(3, 3, 9);
            [t, v_clean] = generator.generateRCCharging(1000, 100e-6, 5);
            generator.NoiseLevel = 0;
            [~, v_no_noise] = generator.generateRCCharging(1000, 100e-6, 5);
            plot(t, v_no_noise, 'b--', 'LineWidth', 2, 'DisplayName', 'Clean');
            hold on;
            plot(t, v_clean, 'r-', 'LineWidth', 1, 'DisplayName', 'With Noise');
            title('Noise Comparison');
            xlabel('Time (s)'); ylabel('Voltage (V)');
            legend('show');
            grid on;
            hold off;
            
            sgtitle('Dataset Generator - Available Waveform Types');
        end
        
        function exportTestDataset(filename, dataset_type, varargin)
            % Export a test dataset to file for external use
            
            generator = DatasetGenerator(varargin{:});
            
            switch lower(dataset_type)
                case 'rc_charging'
                    [time, voltage] = generator.generateRCCharging();
                case 'rc_discharging'
                    [time, voltage] = generator.generateRCDischarging();
                case 'rlc_underdamped'
                    [time, voltage] = generator.generateRLCUnderdamped();
                case 'double_rc'
                    [time, voltage] = generator.generateDoubleRC();
                case 'battery_discharge'
                    [time, voltage] = generator.generateBatteryDischarge();
                case 'step_response'
                    [time, voltage] = generator.generateStepResponse();
                case 'sinusoidal'
                    [time, voltage] = generator.generateSinusoidalWithDC();
                case 'complex'
                    [time, voltage] = generator.generateComplexWaveform();
                otherwise
                    error('Unknown dataset type: %s', dataset_type);
            end
            
            % Export data
            data = [time, voltage];
            writematrix(data, filename);
            fprintf('Test dataset exported to: %s\n', filename);
        end
        
    end
end

