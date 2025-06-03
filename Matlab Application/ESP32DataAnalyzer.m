classdef ESP32DataAnalyzer < matlab.apps.AppBase
    % Enhanced ESP32 Data Analyzer Application
    % Features: Improved error handling, data export, multiple circuit models,
    % simulation mode for testing, and enhanced visualization
    
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        
        % Connection Panel
        ConnectionPanel         matlab.ui.container.Panel
        SerialPortDropDown      matlab.ui.control.DropDown
        RefreshPortsButton      matlab.ui.control.Button
        ConnectButton          matlab.ui.control.Button
        DisconnectButton       matlab.ui.control.Button
        SimulationModeCheckBox  matlab.ui.control.CheckBox
        StatusLabel            matlab.ui.control.Label
        
        % Acquisition Panel
        AcquisitionPanel       matlab.ui.container.Panel
        StartAcquisitionButton matlab.ui.control.Button
        StopAcquisitionButton  matlab.ui.control.Button
        ClearDataButton        matlab.ui.control.Button
        SampleRateSpinner      matlab.ui.control.Spinner
        DurationSpinner        matlab.ui.control.Spinner
        
        % Visualization Panel
        VisualizationPanel     matlab.ui.container.Panel
        DataAxes               matlab.ui.control.UIAxes
        ResidualsAxes          matlab.ui.control.UIAxes
        
        % Analysis Panel
        AnalysisPanel          matlab.ui.container.Panel
        CircuitModelDropDown   matlab.ui.control.DropDown
        FitModelButton         matlab.ui.control.Button
        ParameterTable         matlab.ui.control.Table
        GoodnessTable          matlab.ui.control.Table
        
        % Data Export Panel
        ExportPanel            matlab.ui.container.Panel
        ExportDataButton       matlab.ui.control.Button
        ExportModelButton      matlab.ui.control.Button
        SaveSessionButton      matlab.ui.control.Button
        LoadSessionButton      matlab.ui.control.Button
        
        % Properties
        SerialConnection       % Serial port object
        DataBuffer            % Data storage buffer
        TimeBuffer            % Time data buffer
        IsAcquiring           % Acquisition status flag
        Timer                 % Data acquisition timer
        CircuitModel          % Equivalent circuit model
        FittedParameters      % Model parameters
        SimulationData        % For testing mode
        SessionData           % Complete session data
    end
    
    methods (Access = private)
        
        function startupFcn(app)
            % Initialize application components
            app.IsAcquiring = false;
            app.DataBuffer = [];
            app.TimeBuffer = [];
            app.SessionData = struct();
            
            % Initialize simulation data generator
            app.initializeSimulation();
            
            % Populate serial port dropdown
            app.updateSerialPorts();
            
            % Initialize UI state
            app.updateUIState('disconnected');
            
            % Configure axes
            app.setupAxes();
            
            % Initialize tables
            app.initializeTables();
            
            % Setup circuit model options
            app.setupCircuitModels();
            
            % Create acquisition timer
            app.Timer = timer('ExecutionMode', 'fixedRate', ...
                             'Period', 1/app.SampleRateSpinner.Value, ...
                             'TimerFcn', @(~,~) app.acquireData());
        end
        
        function initializeSimulation(app)
            % Initialize simulation parameters for testing
            app.SimulationData = struct();
            app.SimulationData.noiseLevel = 0.02;
            app.SimulationData.R = 1000; % 1kΩ
            app.SimulationData.C = 100e-6; % 100μF
            app.SimulationData.V0 = 5.0; % 5V
            app.SimulationData.tau = app.SimulationData.R * app.SimulationData.C;
            app.SimulationData.startTime = 0;
        end
        
        function setupAxes(app)
            % Configure visualization axes
            xlabel(app.DataAxes, 'Time (s)');
            ylabel(app.DataAxes, 'Voltage (V)');
            title(app.DataAxes, 'Real-time Data Acquisition');
            app.DataAxes.XGrid = 'on';
            app.DataAxes.YGrid = 'on';
            
            xlabel(app.ResidualsAxes, 'Time (s)');
            ylabel(app.ResidualsAxes, 'Residuals (V)');
            title(app.ResidualsAxes, 'Fitting Residuals');
            app.ResidualsAxes.XGrid = 'on';
            app.ResidualsAxes.YGrid = 'on';
        end

        
        function setupCircuitModels(app)
            % Setup available circuit models
            models = {'RC Series', 'RC Parallel', 'RLC Series', 'RLC Parallel', ...
                     'Double RC', 'Warburg Element'};
            app.CircuitModelDropDown.Items = models;
            app.CircuitModelDropDown.Value = 'RC Series';
        end
        
        function initializeTables(app)
            % Initialize parameter and goodness-of-fit tables
            app.ParameterTable.Data = {};
            app.ParameterTable.ColumnName = {'Parameter', 'Value', 'Unit', 'Std Error'};
            app.ParameterTable.ColumnEditable = [false false false false];
            app.ParameterTable.ColumnWidth = {80, 80, 50, 80};
            
            app.GoodnessTable.Data = {};
            app.GoodnessTable.ColumnName = {'Metric', 'Value'};
            app.GoodnessTable.ColumnEditable = [false false];
            app.GoodnessTable.ColumnWidth = {120, 80};
        end
        
        function updateUIState(app, state)
            % Update UI state based on connection and acquisition status
            switch state
                case 'disconnected'
                    app.ConnectButton.Enable = 'on';
                    app.DisconnectButton.Enable = 'off';
                    app.StartAcquisitionButton.Enable = 'off';
                    app.StopAcquisitionButton.Enable = 'off';
                    app.StatusLabel.Text = 'Ready - Select connection mode';
                    
                case 'connected'
                    app.ConnectButton.Enable = 'off';
                    app.DisconnectButton.Enable = 'on';
                    app.StartAcquisitionButton.Enable = 'on';
                    app.StopAcquisitionButton.Enable = 'off';
                    
                case 'acquiring'
                    app.StartAcquisitionButton.Enable = 'off';
                    app.StopAcquisitionButton.Enable = 'on';
                    app.ConnectButton.Enable = 'off';
                    app.DisconnectButton.Enable = 'off';
                    
                case 'stopped'
                    app.StartAcquisitionButton.Enable = 'on';
                    app.StopAcquisitionButton.Enable = 'off';
                    if app.SimulationModeCheckBox.Value
                        app.DisconnectButton.Enable = 'on';
                    else
                        app.DisconnectButton.Enable = 'on';
                    end
            end
        end
        
        function updateSerialPorts(app)
            % Update available serial ports
            try
                ports = serialportlist("available");
                if isempty(ports)
                    app.SerialPortDropDown.Items = {'No ports available'};
                else
                    app.SerialPortDropDown.Items = ports;
                end
            catch ME
                app.StatusLabel.Text = ['Error detecting ports: ' ME.message];
                app.SerialPortDropDown.Items = {'Error detecting ports'};
            end
        end
        
        function refreshPortsButtonPushed(app, ~)
            % Refresh serial port list
            app.updateSerialPorts();
            app.StatusLabel.Text = 'Serial ports refreshed';
        end
        
        function simulationModeChanged(app, ~)
            % Handle simulation mode toggle
            if app.SimulationModeCheckBox.Value
                app.SerialPortDropDown.Enable = 'off';
                app.RefreshPortsButton.Enable = 'off';
                app.StatusLabel.Text = 'Simulation mode enabled';
            else
                app.SerialPortDropDown.Enable = 'on';
                app.RefreshPortsButton.Enable = 'on';
                app.StatusLabel.Text = 'Hardware mode enabled';
            end
        end
        
        function connectButtonPushed(app, ~)
            % Establish connection (real or simulated)
            try
                if app.SimulationModeCheckBox.Value
                    % Simulation mode
                    app.StatusLabel.Text = 'Connected to simulation';
                    app.updateUIState('connected');
                else
                    % Real hardware connection
                    selectedPort = app.SerialPortDropDown.Value;
                    if strcmp(selectedPort, 'No ports available') || strcmp(selectedPort, 'Error detecting ports')
                        app.StatusLabel.Text = 'No valid port selected';
                        return;
                    end
                    
                    % Create serial connection
                    app.SerialConnection = serialport(selectedPort, 115200, ...
                        'DataBits', 8, 'StopBits', 1, 'Parity', 'none', ...
                        'Timeout', 5);
                    
                    configureTerminator(app.SerialConnection, "LF");
                    
                    app.StatusLabel.Text = ['Connected to ' selectedPort];
                    app.updateUIState('connected');
                    
                    % Test connection
                    app.testConnection();
                end
                
            catch ME
                app.StatusLabel.Text = ['Connection failed: ' ME.message];
                app.cleanupConnection();
            end
        end
        
        function disconnectButtonPushed(app, ~)
            % Disconnect from ESP32 or simulation
            try
                if app.IsAcquiring
                    app.stopAcquisition();
                end
                
                app.cleanupConnection();
                app.updateUIState('disconnected');
                app.StatusLabel.Text = 'Disconnected';
                
            catch ME
                app.StatusLabel.Text = ['Disconnect error: ' ME.message];
            end
        end
        
        function cleanupConnection(app)
            % Clean up connection resources
            if ~isempty(app.SerialConnection)
                try
                    delete(app.SerialConnection);
                catch
                end
                app.SerialConnection = [];
            end
        end
        
        function testConnection(app)
            % Test ESP32 communication
            if app.SimulationModeCheckBox.Value
                app.StatusLabel.Text = 'Simulation ready';
                return;
            end
            
            try
                if ~isempty(app.SerialConnection)
                    writeline(app.SerialConnection, "TEST");
                    pause(0.1);
                    
                    if app.SerialConnection.NumBytesAvailable > 0
                        response = readline(app.SerialConnection);
                        app.StatusLabel.Text = ['Connection OK - ' char(response)];
                    else
                        app.StatusLabel.Text = 'Connected - No device response';
                    end
                end
            catch ME
                app.StatusLabel.Text = ['Test failed: ' ME.message];
            end
        end
        
        function sampleRateChanged(app, ~)
            % Update timer period when sample rate changes
            if ~isempty(app.Timer) && isvalid(app.Timer)
                stop(app.Timer);
                app.Timer.Period = 1/app.SampleRateSpinner.Value;
                if app.IsAcquiring
                    start(app.Timer);
                end
            end
        end
        
        function startAcquisitionButtonPushed(app, ~)
            % Start data acquisition
            try
                app.IsAcquiring = true;
                app.DataBuffer = [];
                app.TimeBuffer = [];
                
                % Clear axes
                cla(app.DataAxes);
                cla(app.ResidualsAxes);
                
                % Reset simulation time
                if app.SimulationModeCheckBox.Value
                    app.SimulationData.startTime = datetime("now");
                end
                
                app.updateUIState('acquiring');
                app.StatusLabel.Text = 'Acquiring data...';
                
                % Update timer period
                app.Timer.Period = 1/app.SampleRateSpinner.Value;
                start(app.Timer);
                
                % Send start command to ESP32 (if not in simulation mode)
                if ~app.SimulationModeCheckBox.Value && ~isempty(app.SerialConnection)
                    writeline(app.SerialConnection, "START_ACQ");
                end
                
            catch ME
                app.StatusLabel.Text = ['Start error: ' ME.message];
                app.updateUIState('connected');
            end
        end
        
        function stopAcquisitionButtonPushed(app, ~)
            % Stop data acquisition
            app.stopAcquisition();
        end
        
        function stopAcquisition(app)
            % Stop data acquisition process
            if app.IsAcquiring
                app.IsAcquiring = false;
                
                % Stop timer
                if ~isempty(app.Timer) && isvalid(app.Timer)
                    stop(app.Timer);
                end
                
                % Send stop command to ESP32 (if not in simulation mode)
                if ~app.SimulationModeCheckBox.Value && ~isempty(app.SerialConnection)
                    try
                        writeline(app.SerialConnection, "STOP_ACQ");
                    catch
                    end
                end
                
                app.updateUIState('stopped');
                app.StatusLabel.Text = sprintf('Data acquisition stopped - %d samples collected', ...
                    length(app.DataBuffer));
            end
        end
        
        function clearDataButtonPushed(app, ~)
            % Clear all collected data
            app.DataBuffer = [];
            app.TimeBuffer = [];
            app.FittedParameters = [];
            
            cla(app.DataAxes);
            cla(app.ResidualsAxes);
            
            app.ParameterTable.Data = {};
            app.GoodnessTable.Data = {};
            
            app.StatusLabel.Text = 'Data cleared';
        end
        
        function acquireData(app)
            % Acquire data from ESP32 or simulation
            try
                if ~app.IsAcquiring
                    return;
                end
                
                if app.SimulationModeCheckBox.Value
                    % Generate simulated data
                    [time, voltage] = app.generateSimulatedData();
                else
                    % Read from ESP32
                    [time, voltage] = app.readHardwareData();
                end
                
                if ~isnan(time) && ~isnan(voltage)
                    % Add to buffers
                    app.TimeBuffer = [app.TimeBuffer; time];
                    app.DataBuffer = [app.DataBuffer; voltage];
                    
                    % Update plot
                    app.updatePlot();
                    
                    % Check duration limit
                    if ~isempty(app.TimeBuffer) && (max(app.TimeBuffer) - min(app.TimeBuffer)) >= app.DurationSpinner.Value
                        app.stopAcquisition();
                    end
                    
                    % Limit buffer size for memory management
                    if length(app.DataBuffer) > 10000
                        app.TimeBuffer = app.TimeBuffer(end-9999:end);
                        app.DataBuffer = app.DataBuffer(end-9999:end);
                    end
                end
                
            catch ME
                app.StatusLabel.Text = ['Acquisition error: ' ME.message];
                app.stopAcquisition();
            end
        end
        
        function [time, voltage] = generateSimulatedData(app)
            % Generate realistic simulated data for testing
            persistent sampleCount;
            if isempty(sampleCount)
                sampleCount = 0;
            end
            
            % Calculate time
            time = sampleCount / app.SampleRateSpinner.Value;
            sampleCount = sampleCount + 1;
            
            % Generate RC charging curve with noise
            tau = app.SimulationData.tau;
            V0 = app.SimulationData.V0;
            
            % Basic RC charging: V(t) = V0 * (1 - exp(-t/tau))
            voltage = V0 * (1 - exp(-time/tau));
            
            % Add realistic noise
            noise = app.SimulationData.noiseLevel * randn() * V0;
            voltage = voltage + noise;
            
            % Add some measurement artifacts
            if mod(sampleCount, 50) == 0
                voltage = voltage + 0.05 * randn(); % Occasional spikes
            end
            
            % Ensure positive voltage
            voltage = max(0, voltage);
        end
        
        function [time, voltage] = readHardwareData(app)
            % Read data from ESP32 hardware
            time = NaN;
            voltage = NaN;
            
            if ~isempty(app.SerialConnection) && app.SerialConnection.NumBytesAvailable > 0
                try
                    dataLine = readline(app.SerialConnection);
                    values = str2double(split(dataLine, ','));
                    
                    if length(values) == 2 && ~any(isnan(values))
                        time = values(1);
                        voltage = values(2);
                    end
                catch
                    % Handle parsing errors gracefully
                end
            end
        end
        
        function updatePlot(app)
            % Update real-time data plot
            if ~isempty(app.DataBuffer) && ~isempty(app.TimeBuffer)
                plot(app.DataAxes, app.TimeBuffer, app.DataBuffer, 'b-', 'LineWidth', 1.5);
                
                % Auto-scale axes
                if length(app.TimeBuffer) > 1
                    app.DataAxes.XLim = [min(app.TimeBuffer), max(app.TimeBuffer) + 0.1];
                    app.DataAxes.YLim = [min(0, min(app.DataBuffer)*0.9), max(app.DataBuffer)*1.1];
                end
                
                drawnow limitrate;
            end
        end
        
        function fitModelButtonPushed(app, ~)
            % Perform equivalent circuit model fitting
            if length(app.DataBuffer) < 10
                app.StatusLabel.Text = 'Insufficient data for fitting';
                return;
            end
            
            try
                selectedModel = app.CircuitModelDropDown.Value;
                
                switch selectedModel
                    case 'RC Series'
                        app.fitRCSeriesModel();
                    case 'RC Parallel'
                        app.fitRCParallelModel();
                    case 'RLC Series'
                        app.fitRLCSeriesModel();
                    case 'Double RC'
                        app.fitDoubleRCModel();
                    otherwise
                        app.StatusLabel.Text = 'Model not implemented yet';
                        return;
                end
                
                app.StatusLabel.Text = ['Model fitted: ' selectedModel];
                
            catch ME
                app.StatusLabel.Text = ['Fitting error: ' ME.message];
            end
        end
        
        function fitRCSeriesModel(app)
            % Fit RC series circuit model
            time = app.TimeBuffer - min(app.TimeBuffer); % Normalize time
            voltage = app.DataBuffer;
            
            % RC charging: V(t) = V0 * (1 - exp(-t/(R*C)))
            fitFunc = @(params, t) params(1) * (1 - exp(-t/params(2)));
            
            % Initial estimates
            V0_est = max(voltage);
            tau_est = time(find(voltage >= 0.63*V0_est, 1));
            if isempty(tau_est)
                tau_est = max(time)/3;
            end
            
            % Perform fitting with bounds
            lb = [0, 0];
            ub = [2*V0_est, 10*max(time)];
            
            options = optimoptions('lsqcurvefit', 'Display', 'off', 'MaxIterations', 1000);
            [params, resnorm, residual, ~, ~, ~, jacobian] = ...
                lsqcurvefit(fitFunc, [V0_est, tau_est], time, voltage, lb, ub, options);
            
            % Extract parameters
            V0_fitted = params(1);
            tau_fitted = params(2);
            
            % Calculate R and C (assuming known current)
            I_assumed = 0.001; % 1mA
            R_fitted = V0_fitted / I_assumed;
            C_fitted = tau_fitted / R_fitted;
            
            % Calculate parameter uncertainties
            ci = nlparci(params, residual, 'jacobian', jacobian);
            V0_std = (ci(1,2) - ci(1,1))/2;
            tau_std = (ci(2,2) - ci(2,1))/2;
            R_std = V0_std / I_assumed;
            C_std = sqrt((tau_std/R_fitted)^2 + (tau_fitted*R_std/R_fitted^2)^2);
            
            % Store fitted parameters
            app.FittedParameters = struct('V0', V0_fitted, 'tau', tau_fitted, ...
                'R', R_fitted, 'C', C_fitted, 'model', 'RC Series');
            
            % Update parameter table
            app.ParameterTable.Data = {
                'V₀', sprintf('%.3f', V0_fitted), 'V', sprintf('±%.3f', V0_std);
                'τ', sprintf('%.3f', tau_fitted), 's', sprintf('±%.3f', tau_std);
                'R', sprintf('%.1f', R_fitted), 'Ω', sprintf('±%.1f', R_std);
                'C', sprintf('%.1f', C_fitted*1e6), 'μF', sprintf('±%.1f', C_std*1e6)
            };
            
            % Calculate goodness of fit
            fitted_voltage = fitFunc(params, time);
            app.calculateGoodnessOfFit(voltage, fitted_voltage, residual);
            
            % Plot fitted curve and residuals
            app.plotFittedModel(time, voltage, fitted_voltage, residual);
        end
        
        function fitRCParallelModel(app)
            % Fit RC parallel circuit model (discharge)
            time = app.TimeBuffer - min(app.TimeBuffer);
            voltage = app.DataBuffer;
            
            % RC discharge: V(t) = V0 * exp(-t/(R*C))
            fitFunc = @(params, t) params(1) * exp(-t/params(2));
            
            V0_est = max(voltage);
            tau_est = -time(find(voltage <= 0.37*V0_est, 1));
            if isempty(tau_est)
                tau_est = max(time)/3;
            end
            
            options = optimoptions('lsqcurvefit', 'Display', 'off');
            [params, resnorm, residual, ~, ~, ~, jacobian] = ...
                lsqcurvefit(fitFunc, [V0_est, tau_est], time, voltage, [0, 0], [], options);
            
            V0_fitted = params(1);
            tau_fitted = params(2);
            
            % Calculate uncertainties
            ci = nlparci(params, residual, 'jacobian', jacobian);
            V0_std = (ci(1,2) - ci(1,1))/2;
            tau_std = (ci(2,2) - ci(2,1))/2;
            
            app.FittedParameters = struct('V0', V0_fitted, 'tau', tau_fitted, 'model', 'RC Parallel');
            
            app.ParameterTable.Data = {
                'V₀', sprintf('%.3f', V0_fitted), 'V', sprintf('±%.3f', V0_std);
                'τ', sprintf('%.3f', tau_fitted), 's', sprintf('±%.3f', tau_std)
            };
            
            fitted_voltage = fitFunc(params, time);
            app.calculateGoodnessOfFit(voltage, fitted_voltage, residual);
            app.plotFittedModel(time, voltage, fitted_voltage, residual);
        end
        
        function fitRLCSeriesModel(app)
            % Fit RLC series circuit model (underdamped response)
            time = app.TimeBuffer - min(app.TimeBuffer);
            voltage = app.DataBuffer;
            
            % RLC underdamped: V(t) = V0 * (1 - exp(-αt) * (cos(ωt) + (α/ω)sin(ωt)))
            % Simplified to: V(t) = A + B*exp(-αt)*cos(ωt + φ)
            fitFunc = @(params, t) params(1) + params(2) * exp(-params(3)*t) .* cos(params(4)*t + params(5));
            
            % Initial estimates
            A_est = mean(voltage(end-10:end)); % Final value
            B_est = max(voltage) - A_est;
            alpha_est = 1;
            omega_est = 2*pi;
            phi_est = 0;
            
            options = optimoptions('lsqcurvefit', 'Display', 'off', 'MaxIterations', 2000);
            [params, resnorm, residual] = lsqcurvefit(fitFunc, ...
                [A_est, B_est, alpha_est, omega_est, phi_est], time, voltage, [], [], options);
            
            app.FittedParameters = struct('A', params(1), 'B', params(2), 'alpha', params(3), ...
                'omega', params(4), 'phi', params(5), 'model', 'RLC Series');
            
            app.ParameterTable.Data = {
                'A', sprintf('%.3f', params(1)), 'V', 'N/A';
                'B', sprintf('%.3f', params(2)), 'V', 'N/A';
                'α', sprintf('%.3f', params(3)), '1/s', 'N/A';
                'ω', sprintf('%.3f', params(4)), 'rad/s', 'N/A';
                'φ', sprintf('%.3f', params(5)), 'rad', 'N/A'
            };
            
            fitted_voltage = fitFunc(params, time);
            app.calculateGoodnessOfFit(voltage, fitted_voltage, residual);
            app.plotFittedModel(time, voltage, fitted_voltage, residual);
        end
        
        function fitDoubleRCModel(app)
            % Fit double RC circuit model (two time constants)
            time = app.TimeBuffer - min(app.TimeBuffer);
            voltage = app.DataBuffer;
            
            % Double RC: V(t) = V0 * (1 - A1*exp(-t/τ1) - A2*exp(-t/τ2))
            fitFunc = @(params, t) params(1) * (1 - params(2)*exp(-t/params(3)) - params(4)*exp(-t/params(5)));
            
            % Initial estimates
            V0_est = max(voltage);
            A1_est = 0.5;
            tau1_est = max(time)/10;
            A2_est = 0.5;
            tau2_est = max(time)/2;
            
            options = optimoptions('lsqcurvefit', 'Display', 'off', 'MaxIterations', 2000);
            [params, resnorm, residual] = lsqcurvefit(fitFunc, ...
                [V0_est, A1_est, tau1_est, A2_est, tau2_est], time, voltage, ...
                [0, 0, 0, 0, 0], [2*V0_est, 1, 10*max(time), 1, 10*max(time)], options);
            
            app.FittedParameters = struct('V0', params(1), 'A1', params(2), 'tau1', params(3), ...
                'A2', params(4), 'tau2', params(5), 'model', 'Double RC');
            
            app.ParameterTable.Data = {
                'V₀', sprintf('%.3f', params(1)), 'V', 'N/A';
                'A₁', sprintf('%.3f', params(2)), '-', 'N/A';
                'τ₁', sprintf('%.3f', params(3)), 's', 'N/A';
                'A₂', sprintf('%.3f', params(4)), '-', 'N/A';
                'τ₂', sprintf('%.3f', params(5)), 's', 'N/A'
            };
            
            fitted_voltage = fitFunc(params, time);
            app.calculateGoodnessOfFit(voltage, fitted_voltage, residual);
            app.plotFittedModel(time, voltage, fitted_voltage, residual);
        end
        
        function calculateGoodnessOfFit(app, measured, fitted, residual)
            % Calculate goodness of fit metrics
            
            % R-squared
            SS_res = sum(residual.^2);
            SS_tot = sum((measured - mean(measured)).^2);
            R_squared = 1 - SS_res/SS_tot;
            
            % Root Mean Square Error
            RMSE = sqrt(mean(residual.^2));
            
            % Mean Absolute Error
            MAE = mean(abs(residual));
            
            % Adjusted R-squared (assuming 2 parameters)
            n = length(measured);
            p = 2; % number of parameters
            R_squared_adj = 1 - (1-R_squared)*(n-1)/(n-p-1);
            
            % Akaike Information Criterion
            AIC = n*log(SS_res/n) + 2*p;
            
            app.GoodnessTable.Data = {
                'R²', sprintf('%.4f', R_squared);
                'Adj R²', sprintf('%.4f', R_squared_adj);
                'RMSE', sprintf('%.4f', RMSE);
                'MAE', sprintf('%.4f', MAE);
                'AIC', sprintf('%.2f', AIC)
            };
        end
        
        function plotFittedModel(app, time, measured, fitted, residual)
            % Plot fitted model and residuals
            
            % Main plot with data and fit
            plot(app.DataAxes, time, measured, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Measured');
            hold(app.DataAxes, 'on');
            plot(app.DataAxes, time, fitted, 'r--', 'LineWidth', 2, 'DisplayName', 'Fitted');
            hold(app.DataAxes, 'off');
            legend(app.DataAxes, 'show', 'Location', 'best');
            
            % Residuals plot
            plot(app.ResidualsAxes, time, residual, 'g-', 'LineWidth', 1);
            hold(app.ResidualsAxes, 'on');
            yline(app.ResidualsAxes, 0, 'k--', 'LineWidth', 1);
            hold(app.ResidualsAxes, 'off');
        end
        
        function exportDataButtonPushed(app, ~)
            % Export collected data to file
            if isempty(app.DataBuffer)
                app.StatusLabel.Text = 'No data to export';
                return;
            end
            
            [filename, pathname] = uiputfile({'*.csv', 'CSV files (*.csv)'; ...
                '*.mat', 'MATLAB files (*.mat)'}, 'Export Data');
            
            if filename ~= 0
                try
                    fullpath = fullfile(pathname, filename);
                    [~, ~, ext] = fileparts(filename);
                    
                    if strcmp(ext, '.csv')
                        % Export as CSV
                        data = [app.TimeBuffer, app.DataBuffer];
                        writematrix(data, fullpath, 'WriteMode', 'overwrite');
                        headers = {'Time_s', 'Voltage_V'};
                        writecell(headers, fullpath, 'WriteMode', 'overwritesheet', 'Range', 'A1');
                        writematrix(data, fullpath, 'WriteMode', 'append');
                    else
                        % Export as MAT
                        time_data = app.TimeBuffer;
                        voltage_data = app.DataBuffer;
                        save(fullpath, 'time_data', 'voltage_data');
                    end
                    
                    app.StatusLabel.Text = ['Data exported to ' filename];
                    
                catch ME
                    app.StatusLabel.Text = ['Export failed: ' ME.message];
                end
            end
        end
        
        function exportModelButtonPushed(app, ~)
            % Export fitted model parameters
            if isempty(app.FittedParameters)
                app.StatusLabel.Text = 'No model to export';
                return;
            end
            
            [filename, pathname] = uiputfile({'*.json', 'JSON files (*.json)'; ...
                '*.mat', 'MATLAB files (*.mat)'}, 'Export Model');
            
            if filename ~= 0
                try
                    fullpath = fullfile(pathname, filename);
                    [~, ~, ext] = fileparts(filename);
                    
                    if strcmp(ext, '.json')
                        % Export as JSON
                        jsonStr = jsonencode(app.FittedParameters, 'PrettyPrint', true);
                        fid = fopen(fullpath, 'w');
                        fprintf(fid, '%s', jsonStr);
                        fclose(fid);
                    else
                        % Export as MAT
                        model_parameters = app.FittedParameters;
                        save(fullpath, 'model_parameters');
                    end
                    
                    app.StatusLabel.Text = ['Model exported to ' filename];
                    
                catch ME
                    app.StatusLabel.Text = ['Model export failed: ' ME.message];
                end
            end
        end
        
        function saveSessionButtonPushed(app, ~)
            % Save complete session data
            [filename, pathname] = uiputfile('*.mat', 'Save Session');
            
            if filename ~= 0
                try
                    fullpath = fullfile(pathname, filename);
                    
                    % Compile session data
                    sessionData = struct();
                    sessionData.timeData = app.TimeBuffer;
                    sessionData.voltageData = app.DataBuffer;
                    sessionData.fittedParameters = app.FittedParameters;
                    sessionData.circuitModel = app.CircuitModelDropDown.Value;
                    sessionData.sampleRate = app.SampleRateSpinner.Value;
                    sessionData.timestamp = datetime('now');
                    sessionData.simulationMode = app.SimulationModeCheckBox.Value;
                    
                    save(fullpath, 'sessionData');
                    app.StatusLabel.Text = ['Session saved to ' filename];
                    
                catch ME
                    app.StatusLabel.Text = ['Save failed: ' ME.message];
                end
            end
        end
        
        function loadSessionButtonPushed(app, ~)
            % Load session data
            [filename, pathname] = uigetfile('*.mat', 'Load Session');
            
            if filename ~= 0
                try
                    fullpath = fullfile(pathname, filename);
                    loaded = load(fullpath);
                    
                    if isfield(loaded, 'sessionData')
                        sessionData = loaded.sessionData;
                        
                        % Restore data
                        app.TimeBuffer = sessionData.timeData;
                        app.DataBuffer = sessionData.voltageData;
                        app.FittedParameters = sessionData.fittedParameters;
                        
                        % Restore UI settings
                        if isfield(sessionData, 'circuitModel')
                            app.CircuitModelDropDown.Value = sessionData.circuitModel;
                        end
                        if isfield(sessionData, 'sampleRate')
                            app.SampleRateSpinner.Value = sessionData.sampleRate;
                        end
                        if isfield(sessionData, 'simulationMode')
                            app.SimulationModeCheckBox.Value = sessionData.simulationMode;
                        end
                        
                        % Update plots
                        app.updatePlot();
                        
                        app.StatusLabel.Text = ['Session loaded from ' filename];
                    else
                        app.StatusLabel.Text = 'Invalid session file format';
                    end
                    
                catch ME
                    app.StatusLabel.Text = ['Load failed: ' ME.message];
                end
            end
        end
    end
    
    methods (Access = private)
        
        function createComponents(app)
            % Create UIFigure and components
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1400 800];
            app.UIFigure.Name = 'Enhanced ESP32 Data Analyzer';
            app.UIFigure.Resize = 'on';
            
            % Connection Panel
            app.ConnectionPanel = uipanel(app.UIFigure);
            app.ConnectionPanel.Title = 'Connection';
            app.ConnectionPanel.Position = [20 720 350 70];
            
            app.SerialPortDropDown = uidropdown(app.ConnectionPanel);
            app.SerialPortDropDown.Position = [10 25 120 22];
            
            app.RefreshPortsButton = uibutton(app.ConnectionPanel, 'push');
            app.RefreshPortsButton.Position = [140 25 60 22];
            app.RefreshPortsButton.Text = 'Refresh';
            app.RefreshPortsButton.ButtonPushedFcn = createCallbackFcn(app, @refreshPortsButtonPushed, true);
            
            app.ConnectButton = uibutton(app.ConnectionPanel, 'push');
            app.ConnectButton.Position = [210 25 60 22];
            app.ConnectButton.Text = 'Connect';
            app.ConnectButton.ButtonPushedFcn = createCallbackFcn(app, @connectButtonPushed, true);
            
            app.DisconnectButton = uibutton(app.ConnectionPanel, 'push');
            app.DisconnectButton.Position = [280 25 60 22];
            app.DisconnectButton.Text = 'Disconnect';
            app.DisconnectButton.ButtonPushedFcn = createCallbackFcn(app, @disconnectButtonPushed, true);
            
            app.SimulationModeCheckBox = uicheckbox(app.ConnectionPanel);
            app.SimulationModeCheckBox.Position = [10 5 120 22];
            app.SimulationModeCheckBox.Text = 'Simulation Mode';
            app.SimulationModeCheckBox.ValueChangedFcn = createCallbackFcn(app, @simulationModeChanged, true);
            
            % Status Label
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [380 750 600 22];
            app.StatusLabel.Text = 'Ready';
            app.StatusLabel.FontWeight = 'bold';
            
            % Acquisition Panel
            app.AcquisitionPanel = uipanel(app.UIFigure);
            app.AcquisitionPanel.Title = 'Data Acquisition';
            app.AcquisitionPanel.Position = [20 620 350 90];
            
            app.StartAcquisitionButton = uibutton(app.AcquisitionPanel, 'push');
            app.StartAcquisitionButton.Position = [10 45 80 22];
            app.StartAcquisitionButton.Text = 'Start';
            app.StartAcquisitionButton.ButtonPushedFcn = createCallbackFcn(app, @startAcquisitionButtonPushed, true);
            
            app.StopAcquisitionButton = uibutton(app.AcquisitionPanel, 'push');
            app.StopAcquisitionButton.Position = [100 45 80 22];
            app.StopAcquisitionButton.Text = 'Stop';
            app.StopAcquisitionButton.ButtonPushedFcn = createCallbackFcn(app, @stopAcquisitionButtonPushed, true);
            
            app.ClearDataButton = uibutton(app.AcquisitionPanel, 'push');
            app.ClearDataButton.Position = [190 45 80 22];
            app.ClearDataButton.Text = 'Clear';
            app.ClearDataButton.ButtonPushedFcn = createCallbackFcn(app, @clearDataButtonPushed, true);
            
            % Sample Rate
            uilabel(app.AcquisitionPanel, 'Position', [10 20 80 22], 'Text', 'Sample Rate:');
            app.SampleRateSpinner = uispinner(app.AcquisitionPanel);
            app.SampleRateSpinner.Position = [90 20 60 22];
            app.SampleRateSpinner.Limits = [0.1 100];
            app.SampleRateSpinner.Value = 10;
            app.SampleRateSpinner.ValueChangedFcn = createCallbackFcn(app, @sampleRateChanged, true);
            uilabel(app.AcquisitionPanel, 'Position', [155 20 20 22], 'Text', 'Hz');
            
            % Duration
            uilabel(app.AcquisitionPanel, 'Position', [180 20 60 22], 'Text', 'Duration:');
            app.DurationSpinner = uispinner(app.AcquisitionPanel);
            app.DurationSpinner.Position = [240 20 60 22];
            app.DurationSpinner.Limits = [1 3600];
            app.DurationSpinner.Value = 60;
            uilabel(app.AcquisitionPanel, 'Position', [305 20 15 22], 'Text', 's');
            
            % Visualization Panel
            app.VisualizationPanel = uipanel(app.UIFigure);
            app.VisualizationPanel.Title = 'Data Visualization';
            app.VisualizationPanel.Position = [20 20 700 590];
            
            app.DataAxes = uiaxes(app.VisualizationPanel);
            app.DataAxes.Position = [20 320 660 240];
            
            app.ResidualsAxes = uiaxes(app.VisualizationPanel);
            app.ResidualsAxes.Position = [20 50 660 240];
            
            % Analysis Panel
            app.AnalysisPanel = uipanel(app.UIFigure);
            app.AnalysisPanel.Title = 'Circuit Analysis';
            app.AnalysisPanel.Position = [740 350 640 360];
            
            uilabel(app.AnalysisPanel, 'Position', [20 310 100 22], 'Text', 'Circuit Model:');
            app.CircuitModelDropDown = uidropdown(app.AnalysisPanel);
            app.CircuitModelDropDown.Position = [130 310 150 22];
            
            app.FitModelButton = uibutton(app.AnalysisPanel, 'push');
            app.FitModelButton.Position = [300 310 80 22];
            app.FitModelButton.Text = 'Fit Model';
            app.FitModelButton.ButtonPushedFcn = createCallbackFcn(app, @fitModelButtonPushed, true);
            
            % Parameter Table
            uilabel(app.AnalysisPanel, 'Position', [20 280 100 22], 'Text', 'Parameters:');
            app.ParameterTable = uitable(app.AnalysisPanel);
            app.ParameterTable.Position = [20 180 300 100];
            
            % Goodness of Fit Table
            uilabel(app.AnalysisPanel, 'Position', [340 280 120 22], 'Text', 'Goodness of Fit:');
            app.GoodnessTable = uitable(app.AnalysisPanel);
            app.GoodnessTable.Position = [340 180 280 100];
            
            % Export Panel
            app.ExportPanel = uipanel(app.UIFigure);
            app.ExportPanel.Title = 'Data Export & Session';
            app.ExportPanel.Position = [740 20 640 320];
            
            app.ExportDataButton = uibutton(app.ExportPanel, 'push');
            app.ExportDataButton.Position = [20 250 120 22];
            app.ExportDataButton.Text = 'Export Data';
            app.ExportDataButton.ButtonPushedFcn = createCallbackFcn(app, @exportDataButtonPushed, true);
            
            app.ExportModelButton = uibutton(app.ExportPanel, 'push');
            app.ExportModelButton.Position = [160 250 120 22];
            app.ExportModelButton.Text = 'Export Model';
            app.ExportModelButton.ButtonPushedFcn = createCallbackFcn(app, @exportModelButtonPushed, true);
            
            app.SaveSessionButton = uibutton(app.ExportPanel, 'push');
            app.SaveSessionButton.Position = [300 250 120 22];
            app.SaveSessionButton.Text = 'Save Session';
            app.SaveSessionButton.ButtonPushedFcn = createCallbackFcn(app, @saveSessionButtonPushed, true);
            
            app.LoadSessionButton = uibutton(app.ExportPanel, 'push');
            app.LoadSessionButton.Position = [440 250 120 22];
            app.LoadSessionButton.Text = 'Load Session';
            app.LoadSessionButton.ButtonPushedFcn = createCallbackFcn(app, @loadSessionButtonPushed, true);
            
            % Show the figure
            app.UIFigure.Visible = 'on';
        end
    end
    
    methods (Access = public)
        
        function app = ESP32DataAnalyzer
            % Construct app
            createComponents(app)
            startupFcn(app)
        end
        
        function delete(app)
            % Cleanup on app deletion
            if ~isempty(app.Timer) && isvalid(app.Timer)
                stop(app.Timer);
                delete(app.Timer);
            end
            
            app.cleanupConnection();
            delete(app.UIFigure);
        end
    end
end
