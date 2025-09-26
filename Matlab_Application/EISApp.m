classdef EISApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure          matlab.ui.Figure
        TabGroup          matlab.ui.container.TabGroup
        DatasetTab        matlab.ui.container.Tab
        LivePlotTab       matlab.ui.container.Tab
        FittingTab        matlab.ui.container.Tab
        
        % Status components
        StatusPanel       matlab.ui.container.Panel
        StatusLabel       matlab.ui.control.Label
        StatusLamp        matlab.ui.control.Lamp
    end
    
    properties (Access = private)
        Version = "1.0.0"
        AppTitle = "EIS Analysis Tool"
    end

    properties (Access = private)
        % Connection properties (Serial only)
        SerialConnection
        IsConnected = false

        % Serial connection UI components
        SerialPortDropDown       matlab.ui.control.DropDown
        ConnectButton            matlab.ui.control.Button
        DisconnectButton         matlab.ui.control.Button
        RefreshPortsButton       matlab.ui.control.Button    

        % Live Plot UI components (plot-only mode)
        
        % Plot components
        NyquistAxes              matlab.ui.control.UIAxes
        BodeMagAxes              matlab.ui.control.UIAxes
        BodePhaseAxes            matlab.ui.control.UIAxes

        % Data and measurement
        MeasurementTimer         timer
        CurrentFrequencyIndex    double = 1
        FrequencyVector          double
        ImpedanceData           double
        IsRunningMeasurement    logical = false
        LivePlotStatusList      matlab.ui.control.ListBox

        % Data source control (removed - ESP32 handles configuration)

        % Plot handles for updating
        NyquistPlotHandle
        BodeMagPlotHandle
        BodePhasePlotHandle
        
        % Dataset Management UI components
        LoadDatasetButton         matlab.ui.control.Button
        SaveDatasetButton         matlab.ui.control.Button
        DatasetTable             matlab.ui.control.Table
        SampleNameEditField      matlab.ui.control.EditField
        SampleNotesTextArea      matlab.ui.control.TextArea
        DatasetStatusLabel       matlab.ui.control.Label
        PlotDatasetButton        matlab.ui.control.Button
        BodePlotTypeDropDown     matlab.ui.control.DropDown
        DatasetNyquistAxes       matlab.ui.control.UIAxes
        DatasetBodeAxes          matlab.ui.control.UIAxes
        
        % Dataset storage
        CurrentDataset           struct
        DatasetHistory          cell
        SelectedDatasetIndex    double = 0

        % Fitting UI components
        ModelDropDown            matlab.ui.control.DropDown
        FitButton               matlab.ui.control.Button
        InitialGuessTable       matlab.ui.control.Table
        FittingResultsTable     matlab.ui.control.Table
        FittingAxes             matlab.ui.control.UIAxes
        ResidualsAxes           matlab.ui.control.UIAxes
        CircuitAxes             matlab.ui.control.UIAxes
        FittingStatusLabel      matlab.ui.control.Label
        ExportFitButton         matlab.ui.control.Button
        
        % Fitting data and results
        FittingResults          struct
        CurrentModel            char = 'Randles'
        FittedParameters        double
        FitQuality              struct
      
        ZfitCircuitStrings    cell = {'s(R1,p(R1,E2))', 's(R1,p(s(R1,G2),E2))', 's(R1,p(s(R1,H2),E2))'}
        ZfitCircuitNames      cell = {'Randles Circuit', 'Randles + Warburg (Short)', 'Randles + Warburg (Open)'}
        
        % Report Tab components
        ReportTab                matlab.ui.container.Tab
        ReportTextArea          matlab.ui.control.TextArea
        GenerateReportButton    matlab.ui.control.Button
        ExportReportPDFButton   matlab.ui.control.Button
        ExportReportExcelButton matlab.ui.control.Button
        ExportLivePlotButton    matlab.ui.control.Button 
        ExportFittingPlotButton matlab.ui.control.Button
        ReportStatusLabel       matlab.ui.control.Label
        CheckDataButton         matlab.ui.control.Button
    

    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Initialize app
            app.StatusLabel.Text = "Ready";
            app.StatusLamp.Color = [0.8 0.8 0.8]; % Gray for ready state
            
            % Display welcome message
            uialert(app.UIFigure, ...
                sprintf('Welcome to %s v%s\nSelect a tab to begin.', ...
                app.AppTitle, app.Version), ...
                'Welcome', 'Icon', 'info');
        end

        % Tab selection callback
        function TabGroupSelectionChanged(app, ~)
            selectedTab = app.TabGroup.SelectedTab;
            app.StatusLabel.Text = sprintf("Active: %s", selectedTab.Title);
        end

    

        function createLivePlotTab(app)
            % Clear existing content
            delete(app.LivePlotTab.Children);

            % Main title
            titleLabel = uilabel(app.LivePlotTab);
            titleLabel.Position = [30 580 400 25];
            titleLabel.Text = '📊 Real-time EIS Visualization';
            titleLabel.FontSize = 18;
            titleLabel.FontWeight = 'bold';

            % Serial connection panel
            connectionPanel = uipanel(app.LivePlotTab);
            connectionPanel.Position = [30 520 900 50];
            connectionPanel.Title = 'ESP32 Serial Connection';
            connectionPanel.FontWeight = 'bold';

            % Port selection
            uilabel(connectionPanel, 'Position', [20 15 60 22], 'Text', 'Port:');
            app.SerialPortDropDown = uidropdown(connectionPanel);
            app.SerialPortDropDown.Position = [80 15 120 22];
            app.SerialPortDropDown.Items = {'Select port...'};

            % Refresh button
            app.RefreshPortsButton = uibutton(connectionPanel, 'push');
            app.RefreshPortsButton.Position = [220 15 60 22];
            app.RefreshPortsButton.Text = 'Refresh';
            app.RefreshPortsButton.ButtonPushedFcn = createCallbackFcn(app, @RefreshPorts, true);

            % Connect button
            app.ConnectButton = uibutton(connectionPanel, 'push');
            app.ConnectButton.Position = [300 15 80 22];
            app.ConnectButton.Text = 'Connect';
            app.ConnectButton.BackgroundColor = [0.2 0.7 0.2];
            app.ConnectButton.FontColor = [1 1 1];
            app.ConnectButton.ButtonPushedFcn = createCallbackFcn(app, @ConnectSerial, true);

            % Disconnect button
            app.DisconnectButton = uibutton(connectionPanel, 'push');
            app.DisconnectButton.Position = [400 15 80 22];
            app.DisconnectButton.Text = 'Disconnect';
            app.DisconnectButton.BackgroundColor = [0.8 0.2 0.2];
            app.DisconnectButton.FontColor = [1 1 1];
            app.DisconnectButton.Enable = 'off';
            app.DisconnectButton.ButtonPushedFcn = createCallbackFcn(app, @DisconnectSerial, true);

            % Info label
            infoLabel = uilabel(app.LivePlotTab);
            infoLabel.Position = [30 480 700 25];
            infoLabel.Text = 'ℹ️ Connect to ESP32, then firmware will run measurements automatically';
            infoLabel.FontSize = 12;
            infoLabel.FontColor = [0.2 0.4 0.8];

            % Create plot panels with adjusted positions
            app.createPlotPanels();

            % Initialize timer for receiving data
            app.MeasurementTimer = timer('ExecutionMode', 'fixedRate', ...
                                        'Period', 0.1, ...
                                        'TimerFcn', @(~,~) app.updateMeasurement());

            % Control buttons
            clearButton = uibutton(app.LivePlotTab, 'push');
            clearButton.Position = [800 480 60 30];
            clearButton.Text = 'Clear';
            clearButton.ButtonPushedFcn = createCallbackFcn(app, @ClearPlots, true);

            % Export Plot Button for Live Plot
            app.ExportLivePlotButton = uibutton(app.LivePlotTab, 'push');
            app.ExportLivePlotButton.Position = [880 480 60 30];
            app.ExportLivePlotButton.Text = 'Export';
            app.ExportLivePlotButton.ButtonPushedFcn = createCallbackFcn(app, @ExportLivePlots, true);

            % Initialize ports list
            app.RefreshPorts();
        end

        function createPlotPanels(app)
            % Nyquist Plot Panel - Repositioned for new layout
            nyquistPanel = uipanel(app.LivePlotTab);
            nyquistPanel.Position = [30 180 450 280];
            nyquistPanel.Title = 'Nyquist Plot (Re(Z) vs -Im(Z))';
            nyquistPanel.FontWeight = 'bold';

            app.NyquistAxes = uiaxes(nyquistPanel);
            app.NyquistAxes.Position = [20 20 410 240];
            app.NyquistAxes.XLabel.String = 'Real Part (Ω)';
            app.NyquistAxes.YLabel.String = '-Imaginary Part (Ω)';
            app.NyquistAxes.Title.String = '';
            grid(app.NyquistAxes, 'on');
            axis(app.NyquistAxes, 'equal');

            % Bode Magnitude Plot Panel
            bodeMagPanel = uipanel(app.LivePlotTab);
            bodeMagPanel.Position = [500 340 450 120];
            bodeMagPanel.Title = 'Bode Plot - Magnitude';
            bodeMagPanel.FontWeight = 'bold';

            app.BodeMagAxes = uiaxes(bodeMagPanel);
            app.BodeMagAxes.Position = [20 20 410 80];
            app.BodeMagAxes.XLabel.String = 'Frequency (Hz)';
            app.BodeMagAxes.YLabel.String = '|Z| (Ω)';
            app.BodeMagAxes.XScale = 'log';
            app.BodeMagAxes.YScale = 'log';
            app.BodeMagAxes.Title.String = '';
            grid(app.BodeMagAxes, 'on');

            % Bode Phase Plot Panel
            bodePhasePanel = uipanel(app.LivePlotTab);
            bodePhasePanel.Position = [500 200 450 120];
            bodePhasePanel.Title = 'Bode Plot - Phase';
            bodePhasePanel.FontWeight = 'bold';

            app.BodePhaseAxes = uiaxes(bodePhasePanel);
            app.BodePhaseAxes.Position = [20 20 410 80];
            app.BodePhaseAxes.XLabel.String = 'Frequency (Hz)';
            app.BodePhaseAxes.YLabel.String = 'Phase (°)';
            app.BodePhaseAxes.XScale = 'log';
            app.BodePhaseAxes.Title.String = '';
            grid(app.BodePhaseAxes, 'on');

            % Status display
            statusPanel = uipanel(app.LivePlotTab);
            statusPanel.Position = [30 80 920 90];
            statusPanel.Title = 'Live Data Status';
            statusPanel.FontWeight = 'bold';

            app.LivePlotStatusList = uilistbox(statusPanel);
            app.LivePlotStatusList.Position = [10 10 900 70];
            app.LivePlotStatusList.Items = {'Not connected - select port and click Connect'};
            app.LivePlotStatusList.FontSize = 10;
        end

        function addStatusMessage(app, message)
            % Add a timestamped message to the status list
            timestamp = string(datetime('now', 'Format', 'HH:mm:ss'));
            timestampedMessage = sprintf('[%s] %s', timestamp, message);

            % Add to list
            currentItems = app.LivePlotStatusList.Items;
            newItems = [currentItems, {timestampedMessage}];

            % Keep only last 50 messages to prevent memory issues
            if length(newItems) > 50
                newItems = newItems(end-49:end);
            end

            app.LivePlotStatusList.Items = newItems;

            % Auto-scroll to bottom (latest message)
            app.LivePlotStatusList.Value = newItems{end};
        end

        function ClearPlots(app, ~)
            % Clear all plots - useful for clearing received data
            cla(app.NyquistAxes);
            cla(app.BodeMagAxes);
            cla(app.BodePhaseAxes);

            % Reset plot properties
            app.NyquistAxes.XLabel.String = 'Real Part (Ω)';
            app.NyquistAxes.YLabel.String = '-Imaginary Part (Ω)';
            grid(app.NyquistAxes, 'on');
            axis(app.NyquistAxes, 'equal');

            app.BodeMagAxes.XLabel.String = 'Frequency (Hz)';
            app.BodeMagAxes.YLabel.String = '|Z| (Ω)';
            app.BodeMagAxes.XScale = 'log';
            app.BodeMagAxes.YScale = 'log';
            grid(app.BodeMagAxes, 'on');

            app.BodePhaseAxes.XLabel.String = 'Frequency (Hz)';
            app.BodePhaseAxes.YLabel.String = 'Phase (°)';
            app.BodePhaseAxes.XScale = 'log';
            grid(app.BodePhaseAxes, 'on');

            app.addStatusMessage('Plots cleared');
        end

        function updateMeasurement(app)
            % Receive and process incoming EIS data from ESP32
            try
                if app.IsConnected
                    % Check for incoming serial data
                    if app.SerialConnection.NumBytesAvailable > 0
                        line = readline(app.SerialConnection);
                        app.processIncomingLine(line);
                    end
                else
                    % Don't spam with this message, only show occasionally
                end

            catch ME
                app.addStatusMessage(sprintf('Data reception error: %s', ME.message));
            end
        end

        function RefreshPorts(app, ~)
            % Refresh available serial ports
            try
                ports = serialportlist("available");
                if isempty(ports)
                    app.SerialPortDropDown.Items = {'No ports found'};
                    app.ConnectButton.Enable = 'off';
                else
                    app.SerialPortDropDown.Items = ports;
                    app.ConnectButton.Enable = 'on';
                    if isscalar(ports)
                        app.SerialPortDropDown.Value = ports(1);
                    end
                end
                app.addStatusMessage(sprintf('Found %d available ports', length(ports)));
            catch ME
                app.addStatusMessage(sprintf('Error scanning ports: %s', ME.message));
                app.SerialPortDropDown.Items = {'Error scanning'};
                app.ConnectButton.Enable = 'off';
            end
        end

        function ConnectSerial(app, ~)
            % Connect to selected serial port
            try
                selectedPort = app.SerialPortDropDown.Value;

                if strcmp(selectedPort, 'No ports found') || strcmp(selectedPort, 'Error scanning') || strcmp(selectedPort, 'Select port...')
                    EISAppUtils.showErrorAlert(app.UIFigure, 'Please select a valid port', 'Connection Error');
                    return;
                end

                app.addStatusMessage(sprintf('Connecting to %s...', selectedPort));

                % Create serial connection
                app.SerialConnection = serialport(selectedPort, 115200);
                app.SerialConnection.Timeout = 5;

                % Update UI
                app.IsConnected = true;
                app.ConnectButton.Enable = 'off';
                app.DisconnectButton.Enable = 'on';
                app.SerialPortDropDown.Enable = 'off';
                app.RefreshPortsButton.Enable = 'off';

                % Start timer
                start(app.MeasurementTimer);

                app.addStatusMessage(sprintf('Connected to %s - waiting for ESP32 data', selectedPort));

                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    sprintf('Connected to ESP32 on %s', selectedPort), ...
                    'Connection Successful');

            catch ME
                app.addStatusMessage(sprintf('Connection failed: %s', ME.message));
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Connection failed: %s', ME.message), ...
                    'Connection Error');
            end
        end

        function DisconnectSerial(app, ~)
            % Disconnect from ESP32
            try
                if app.IsConnected && ~isempty(app.SerialConnection)
                    stop(app.MeasurementTimer);
                    delete(app.SerialConnection);
                    app.SerialConnection = [];
                end

                % Update UI
                app.IsConnected = false;
                app.ConnectButton.Enable = 'on';
                app.DisconnectButton.Enable = 'off';
                app.SerialPortDropDown.Enable = 'on';
                app.RefreshPortsButton.Enable = 'on';

                app.addStatusMessage('Disconnected successfully');

                EISAppUtils.showSuccessAlert(app.UIFigure, 'Disconnected from ESP32', 'Disconnected');

            catch ME
                app.addStatusMessage(sprintf('Disconnect error: %s', ME.message));
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Disconnect error: %s', ME.message), ...
                    'Disconnect Error');
            end
        end

        function processIncomingLine(app, line)
            % Process incoming text line from ESP32
            try
                % Parse AD5940 EIS data (format: "Freq:1.44 RzMag: 958066432.000000 Ohm , RzPhase: 0.425207")
                if contains(line, 'Freq:') && contains(line, 'RzMag:') && contains(line, 'RzPhase:')
                    % Extract frequency
                    freq_match = regexp(line, 'Freq:([\d.]+)', 'tokens');
                    % Extract magnitude
                    mag_match = regexp(line, 'RzMag:\s*([\d.]+)', 'tokens');
                    % Extract phase
                    phase_match = regexp(line, 'RzPhase:\s*([\d.-]+)', 'tokens');

                    if ~isempty(freq_match) && ~isempty(mag_match) && ~isempty(phase_match)
                        % Parse values
                        frequency = str2double(freq_match{1}{1});
                        magnitude = str2double(mag_match{1}{1});
                        phase = str2double(phase_match{1}{1});

                        % Convert to complex impedance
                        real_z = magnitude * cos(deg2rad(phase));
                        imag_z = magnitude * sin(deg2rad(phase));
                        impedance = complex(real_z, imag_z);

                        % Store data
                        if isempty(app.FrequencyVector)
                            app.FrequencyVector = frequency;
                            app.ImpedanceData = impedance;
                        else
                            app.FrequencyVector(end+1) = frequency;
                            app.ImpedanceData(end+1) = impedance;
                        end

                        % Update plots
                        app.updateEISPlots();

                        % Update status
                        app.addStatusMessage(sprintf('Point %d: f=%.2f Hz, |Z|=%.2f Ω, φ=%.2f°', ...
                            length(app.FrequencyVector), frequency, magnitude, phase));
                    end
                % Parse AD5941 EIS data (format: "Freq: 1.000000 (real, image) = ,123.456 , 78.901 ,mOhm")
                elseif contains(line, 'Freq:') && contains(line, '(real, image)') && contains(line, 'mOhm')
                    % Extract frequency and impedance components
                    tokens = regexp(line, 'Freq:\s*([\d.]+).*=\s*,([\d.-]+)\s*,\s*([\d.-]+)\s*,mOhm', 'tokens');

                    if ~isempty(tokens) && length(tokens{1}) == 3
                        % Parse values
                        frequency = str2double(tokens{1}{1});
                        real_z = str2double(tokens{1}{2}) / 1000; % Convert mOhm to Ohm
                        imag_z = str2double(tokens{1}{3}) / 1000; % Convert mOhm to Ohm

                        % Create complex impedance
                        impedance = complex(real_z, imag_z);
                        magnitude = abs(impedance);
                        phase = angle(impedance) * 180/pi; % Convert to degrees

                        % Store data
                        if isempty(app.FrequencyVector)
                            app.FrequencyVector = frequency;
                            app.ImpedanceData = impedance;
                        else
                            app.FrequencyVector(end+1) = frequency;
                            app.ImpedanceData(end+1) = impedance;
                        end

                        % Update plots
                        app.updateEISPlots();

                        % Update status
                        app.addStatusMessage(sprintf('Point %d: f=%.2f Hz, |Z|=%.2f Ω, φ=%.2f°', ...
                            length(app.FrequencyVector), frequency, magnitude, phase));
                    end
                % Parse AD5941 calibration data (format: "i: 1   Freq: 1.00  RcalVolt:(-86.000000,50.000000)")
                elseif contains(line, 'i:') && contains(line, 'Freq:') && contains(line, 'RcalVolt:')
                    app.addStatusMessage(sprintf('Calibration: %s', line));
                elseif contains(line, 'Enter choice (1 or 2):')
                    % Handle board selection prompt
                    app.addStatusMessage('ESP32 requesting board selection...');
                else
                    % Display other ESP32 messages
                    app.addStatusMessage(sprintf('ESP32: %s', line));
                end

            catch ME
                app.addStatusMessage(sprintf('Line processing error: %s', ME.message));
            end
        end

    
        function impedance = generateSimulatedEISData(app, frequency)
            % Generate simulated EIS data based on selected circuit model

            % Get selected model
            selectedIndex = find(strcmp(app.ModelDropDown.Value, app.ZfitCircuitNames));

            % Parameters for simulation
            Rs = 0.1;       % Solution resistance (Ohms)
            Rct = 0.5;      % Charge transfer resistance (Ohms)
            Q = 1e-3;       % CPE magnitude parameter (F⋅s^(n-1))
            n = 0.9;        % CPE phase exponent (dimensionless)
            sigma = 0.02;   % Warburg coefficient (Ω⋅s^-0.5)
            B = 0.1;        % Warburg B parameter (s^-0.5)

            % Angular frequency
            omega = 2 * pi * frequency;

            % CPE impedance: Z_CPE = 1/(Q*(jω)^n)
            Zcpe = 1 ./ (Q * (1i * omega).^n);

            switch selectedIndex
                case 1 % Standard Randles Circuit: s(R1,p(R1,E2))
                    % Parallel combination of Rct and CPE
                    Zparallel = (Rct .* Zcpe) ./ (Rct + Zcpe);
                    % Total impedance: Rs + (Rct || CPE)
                    impedance = Rs + Zparallel;

                case 2 % Randles + Warburg (Short): s(R1,p(s(R1,G2),E2))
                    % Warburg impedance with short circuit boundary
                    Zw = (1 ./ (sigma * sqrt(1i * omega))) .* tanh(B * sqrt(1i * omega));
                    % Series combination of Rct and Warburg
                    Zseries = Rct + Zw;
                    % Parallel combination with CPE
                    Zparallel = (Zseries .* Zcpe) ./ (Zseries + Zcpe);
                    % Total impedance: Rs + ((Rct + Zw) || CPE)
                    impedance = Rs + Zparallel;

                case 3 % Randles + Warburg (Open): s(R1,p(s(R1,H2),E2))
                    % Warburg impedance with open circuit boundary
                    Zw = (1 ./ (sigma * sqrt(1i * omega))) ./ tanh(B * sqrt(1i * omega));
                    % Series combination of Rct and Warburg
                    Zseries = Rct + Zw;
                    % Parallel combination with CPE
                    Zparallel = (Zseries .* Zcpe) ./ (Zseries + Zcpe);
                    % Total impedance: Rs + ((Rct + Zw) || CPE)
                    impedance = Rs + Zparallel;

                otherwise % Default to standard Randles
                    Zparallel = (Rct .* Zcpe) ./ (Rct + Zcpe);
                    impedance = Rs + Zparallel;
            end

            % Add some noise for realism
            noise = 0.01 * (randn + 1i * randn);
            impedance = impedance + noise;
        end

        function impedance = getEISDataFromESP32(app, frequency)
            % Get real EIS data from ESP32 (placeholder for future implementation)
            try
                % Send frequency command to ESP32
                command = sprintf("EIS_FREQ:%.6f", frequency);
                
                if strcmp(app.ConnectionType, "USB")
                    writeline(app.SerialConnection, command);
                    pause(0.1); % Wait for measurement
                    response = readline(app.SerialConnection);
                else % WiFi
                    write(app.WiFiConnection, uint8(command));
                    pause(0.1);
                    response = char(read(app.WiFiConnection, app.WiFiConnection.NumBytesAvailable));
                end
                
                % Parse response (format: "REAL:value,IMAG:value")
                tokens = regexp(response, 'REAL:([-\d\.]+),IMAG:([-\d\.]+)', 'tokens');
                if ~isempty(tokens)
                    realPart = str2double(tokens{1}{1});
                    imagPart = str2double(tokens{1}{2});
                    impedance = complex(realPart, imagPart);
                else
                    error('Invalid response format from ESP32');
                end
                
            catch
                % Fallback to simulated data if communication fails
                impedance = app.generateSimulatedEISData(frequency);
            end
        end
        
        function updateEISPlots(app)
            % Update all EIS plots with current data
            validIndices = 1:(app.CurrentFrequencyIndex-1);
            
            if isempty(validIndices)
                return;
            end
            
            frequencies = app.FrequencyVector(validIndices);
            impedances = app.ImpedanceData(validIndices);
            
            % Update Nyquist plot
            realParts = real(impedances);
            imagParts = -imag(impedances); % Negative for conventional display
            
            if isempty(app.NyquistPlotHandle) || ~isvalid(app.NyquistPlotHandle)
                app.NyquistPlotHandle = plot(app.NyquistAxes, realParts, imagParts, ...
                    'bo-', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'blue');
            else
                set(app.NyquistPlotHandle, 'XData', realParts, 'YData', imagParts);
            end
            
            % Update Bode magnitude plot
            magnitudes = abs(impedances);
            
            if isempty(app.BodeMagPlotHandle) || ~isvalid(app.BodeMagPlotHandle)
                app.BodeMagPlotHandle = loglog(app.BodeMagAxes, frequencies, magnitudes, ...
                    'ro-', 'LineWidth', 2, 'MarkerSize', 4);
            else
                set(app.BodeMagPlotHandle, 'XData', frequencies, 'YData', magnitudes);
            end
            
            % Update Bode phase plot
            phases = angle(impedances) * 180 / pi; % Convert to degrees
            
            if isempty(app.BodePhasePlotHandle) || ~isvalid(app.BodePhasePlotHandle)
                app.BodePhasePlotHandle = semilogx(app.BodePhaseAxes, frequencies, phases, ...
                    'go-', 'LineWidth', 2, 'MarkerSize', 4);
            else
                set(app.BodePhasePlotHandle, 'XData', frequencies, 'YData', phases);
            end
            
            % Auto-scale axes
            if length(validIndices) > 1
                axis(app.NyquistAxes, 'tight');
                axis(app.BodeMagAxes, 'tight');
                axis(app.BodePhaseAxes, 'tight');
            end
        end
        

        function createDatasetTab(app)
            % Clear existing content
            delete(app.DatasetTab.Children);
            
            % Main title
            titleLabel = uilabel(app.DatasetTab);
            titleLabel.Position = [30 580 400 25];
            titleLabel.Text = '📂 Dataset Management';
            titleLabel.FontSize = 18;
            titleLabel.FontWeight = 'bold';
            
            % File Operations Panel
            filePanel = uipanel(app.DatasetTab);
            filePanel.Position = [30 500 900 70];
            filePanel.Title = 'File Operations';
            filePanel.FontWeight = 'bold';
            
            app.LoadDatasetButton = uibutton(filePanel, 'push');
            app.LoadDatasetButton.Position = [20 25 120 30];
            app.LoadDatasetButton.Text = 'Load Dataset';
            app.LoadDatasetButton.FontWeight = 'bold';
            app.LoadDatasetButton.BackgroundColor = [0.2 0.6 0.8];
            app.LoadDatasetButton.FontColor = [1 1 1];
            app.LoadDatasetButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataset, true);
            
            app.SaveDatasetButton = uibutton(filePanel, 'push');
            app.SaveDatasetButton.Position = [160 25 120 30];
            app.SaveDatasetButton.Text = 'Save Dataset';
            app.SaveDatasetButton.FontWeight = 'bold';
            app.SaveDatasetButton.BackgroundColor = [0.2 0.7 0.2];
            app.SaveDatasetButton.FontColor = [1 1 1];
            app.SaveDatasetButton.Enable = 'off';
            app.SaveDatasetButton.ButtonPushedFcn = createCallbackFcn(app, @SaveDataset, true);
            
            % Export options
            exportLabel = uilabel(filePanel);
            exportLabel.Position = [320 35 100 22];
            exportLabel.Text = 'Export Format:';
            
            exportDropdown = uidropdown(filePanel);
            exportDropdown.Position = [320 10 100 22];
            exportDropdown.Items = {'.mat', '.csv', '.xlsx'};
            exportDropdown.Value = '.mat';
            
            exportButton = uibutton(filePanel, 'push');
            exportButton.Position = [440 25 100 30];
            exportButton.Text = 'Export Data';
            exportButton.ButtonPushedFcn = createCallbackFcn(app, @ExportDataset, true);

            app.PlotDatasetButton = uibutton(filePanel, 'push');
            app.PlotDatasetButton.Position = [560 25 100 30];
            app.PlotDatasetButton.Text = 'Plot Data';
            app.PlotDatasetButton.FontWeight = 'bold';
            app.PlotDatasetButton.BackgroundColor = [0.8 0.2 0.6];
            app.PlotDatasetButton.FontColor = [1 1 1];
            app.PlotDatasetButton.Enable = 'off';
            app.PlotDatasetButton.ButtonPushedFcn = createCallbackFcn(app, @PlotLoadedDataset, true);

            % Bode plot type selection
            bodeLabel = uilabel(filePanel);
            bodeLabel.Position = [680 35 80 22];
            bodeLabel.Text = 'Bode Plot:';

            app.BodePlotTypeDropDown = uidropdown(filePanel);
            app.BodePlotTypeDropDown.Position = [680 10 100 22];
            app.BodePlotTypeDropDown.Items = {'Magnitude', 'Phase'};
            app.BodePlotTypeDropDown.Value = 'Magnitude';
            app.BodePlotTypeDropDown.ValueChangedFcn = createCallbackFcn(app, @BodePlotTypeChanged, true);
            
            % Dataset Table Panel
            tablePanel = uipanel(app.DatasetTab);
            tablePanel.Position = [30 380 900 110];
            tablePanel.Title = 'Dataset History';
            tablePanel.FontWeight = 'bold';
            
            app.DatasetTable = uitable(tablePanel);
            app.DatasetTable.Position = [20 20 860 70];
            app.DatasetTable.ColumnName = {'Filename', 'Date', 'Points', 'Freq Range', 'Sample Name', 'Notes'};
            app.DatasetTable.ColumnWidth = {150, 120, 60, 100, 120, 200};
            app.DatasetTable.ColumnEditable = [false false false false true true];
            app.DatasetTable.CellSelectionCallback = createCallbackFcn(app, @DatasetTableSelection, true);
            app.DatasetTable.CellEditCallback = createCallbackFcn(app, @DatasetTableEdit, true);
            
            % Metadata Panel
            metadataPanel = uipanel(app.DatasetTab);
            metadataPanel.Position = [30 260 900 110];
            metadataPanel.Title = 'Sample Metadata';
            metadataPanel.FontWeight = 'bold';
            
            % Sample name
            nameLabel = uilabel(metadataPanel);
            nameLabel.Position = [20 70 100 22];
            nameLabel.Text = 'Sample Name:';
            nameLabel.FontWeight = 'bold';

            app.SampleNameEditField = uieditfield(metadataPanel, 'text');
            app.SampleNameEditField.Position = [130 70 200 22];
            app.SampleNameEditField.Placeholder = 'Enter sample name';
            app.SampleNameEditField.ValueChangedFcn = createCallbackFcn(app, @UpdateMetadata, true);

            % Date and time (auto-filled)
            dateLabel = uilabel(metadataPanel);
            dateLabel.Position = [350 70 80 22];
            dateLabel.Text = 'Date/Time:';
            dateLabel.FontWeight = 'bold';

            dateValue = uilabel(metadataPanel);
            dateValue.Position = [440 70 150 22];
            dateValue.Text = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'));

            % Notes
            notesLabel = uilabel(metadataPanel);
            notesLabel.Position = [20 45 100 22];
            notesLabel.Text = 'Notes:';
            notesLabel.FontWeight = 'bold';

            app.SampleNotesTextArea = uitextarea(metadataPanel);
            app.SampleNotesTextArea.Position = [20 10 560 30];
            app.SampleNotesTextArea.Placeholder = 'Enter measurement notes, conditions, or observations...';
            app.SampleNotesTextArea.ValueChangedFcn = createCallbackFcn(app, @UpdateMetadata, true);

            % Quick metadata buttons
            quickLabel = uilabel(metadataPanel);
            quickLabel.Position = [600 70 100 22];
            quickLabel.Text = 'Quick Tags:';
            quickLabel.FontWeight = 'bold';

            tempButton = uibutton(metadataPanel, 'push');
            tempButton.Position = [600 40 80 25];
            tempButton.Text = 'Add Temp';
            tempButton.ButtonPushedFcn = @(~,~) app.addQuickTag('Temperature: °C');

            socButton = uibutton(metadataPanel, 'push');
            socButton.Position = [690 40 80 25];
            socButton.Text = 'Add SOC';
            socButton.ButtonPushedFcn = @(~,~) app.addQuickTag('SOC: %');

            cycleButton = uibutton(metadataPanel, 'push');
            cycleButton.Position = [780 40 80 25];
            cycleButton.Text = 'Add Cycle';
            cycleButton.ButtonPushedFcn = @(~,~) app.addQuickTag('Cycle: ');
            
            % Plot Panel
            plotPanel = uipanel(app.DatasetTab);
            plotPanel.Position = [30 100 900 150];
            plotPanel.Title = 'Dataset Plots';
            plotPanel.FontWeight = 'bold';

            % Nyquist plot
            app.DatasetNyquistAxes = uiaxes(plotPanel);
            app.DatasetNyquistAxes.Position = [20 20 420 110];
            app.DatasetNyquistAxes.Title.String = 'Nyquist Plot';
            app.DatasetNyquistAxes.XLabel.String = 'Real Impedance (Ω)';
            app.DatasetNyquistAxes.YLabel.String = 'Imaginary Impedance (Ω)';
            app.DatasetNyquistAxes.Box = 'on';
            app.DatasetNyquistAxes.FontSize = 10;

            % Bode plot
            app.DatasetBodeAxes = uiaxes(plotPanel);
            app.DatasetBodeAxes.Position = [460 20 420 110];
            app.DatasetBodeAxes.Title.String = 'Bode Magnitude';
            app.DatasetBodeAxes.XLabel.String = 'Frequency (Hz)';
            app.DatasetBodeAxes.YLabel.String = '|Z| (Ω)';
            app.DatasetBodeAxes.XScale = 'log';
            app.DatasetBodeAxes.YScale = 'log';
            app.DatasetBodeAxes.Box = 'on';
            app.DatasetBodeAxes.FontSize = 10;

            % Status Panel
            statusPanel = uipanel(app.DatasetTab);
            statusPanel.Position = [30 30 900 60];
            statusPanel.Title = 'Status';
            statusPanel.FontWeight = 'bold';
            
            app.DatasetStatusLabel = uilabel(statusPanel);
            app.DatasetStatusLabel.Position = [20 20 860 22];
            app.DatasetStatusLabel.Text = 'No dataset loaded. Load existing data or perform measurement to create new dataset.';
            app.DatasetStatusLabel.FontSize = 12;
            
            % Initialize dataset history
            app.DatasetHistory = {};
            app.updateDatasetTable();
        end

        function LoadDataset(app, ~)
            % Load dataset from file
            [filename, pathname] = uigetfile({'*.mat', 'MATLAB Files (*.mat)'; ...
                                             '*.csv', 'CSV Files (*.csv)'; ...
                                             '*.*', 'All Files (*.*)'}, ...
                                             'Select Dataset File');
            
            if isequal(filename, 0)
                return; % User cancelled
            end
            
            try
                fullpath = fullfile(pathname, filename);
                [~, ~, ext] = fileparts(filename);
                
                if strcmp(ext, '.mat')
                    loadedData = load(fullpath);
                    if isfield(loadedData, 'dataset')
                        dataset = loadedData.dataset;
                    else
                        % Try to construct dataset from variables
                        dataset = app.constructDatasetFromVariables(loadedData);
                    end
                elseif strcmp(ext, '.csv')
                    dataset = app.loadCSVDataset(fullpath);
                else
                    error('Unsupported file format');
                end
                
                % Validate dataset structure
                dataset = app.validateDatasetStructure(dataset, filename);
                
                % Add to history and update UI
                app.addDatasetToHistory(dataset);
                app.CurrentDataset = dataset;
                app.updateDatasetUI(dataset);
                app.SaveDatasetButton.Enable = 'on';
                app.PlotDatasetButton.Enable = 'on';

                app.DatasetStatusLabel.Text = sprintf('Loaded: %s (%d points, %.1f-%.1f Hz)', ...
                    filename, length(dataset.frequency), min(dataset.frequency), max(dataset.frequency));
                
                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    sprintf('Successfully loaded dataset: %s', filename), ...
                    'Dataset Loaded');
                
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Failed to load dataset: %s', ME.message), ...
                    'Load Error');
            end
        end

        function SaveDataset(app, ~)
            % Save current dataset
            if isempty(app.CurrentDataset)
                EISAppUtils.showWarningAlert(app.UIFigure, ...
                    'No dataset to save. Please load data or perform a measurement first.', ...
                    'No Data');
                return;
            end
            
            % Get save location
            defaultName = sprintf('EIS_Dataset_%s.mat', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
            [filename, pathname] = uiputfile({'*.mat', 'MATLAB Files (*.mat)'}, ...
                                             'Save Dataset As', defaultName);
            
            if isequal(filename, 0)
                return; % User cancelled
            end
            
            try
                % Update metadata before saving
                app.CurrentDataset.metadata.sampleName = app.SampleNameEditField.Value;
                app.CurrentDataset.metadata.notes = app.SampleNotesTextArea.Value;
                app.CurrentDataset.metadata.saveDate = datetime('now');
                
                % Save dataset
                dataset = app.CurrentDataset;
                fullpath = fullfile(pathname, filename);
                save(fullpath, 'dataset', '-v7.3');
                
                % Update filename in current dataset
                app.CurrentDataset.metadata.filename = filename;
                
                app.DatasetStatusLabel.Text = sprintf('Saved: %s', filename);
                
                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    sprintf('Dataset saved successfully: %s', filename), ...
                    'Save Complete');
                
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Failed to save dataset: %s', ME.message), ...
                    'Save Error');
            end
        end

        function ExportDataset(app, ~)
            % Export dataset in various formats
            if isempty(app.CurrentDataset)
                EISAppUtils.showWarningAlert(app.UIFigure, ...
                    'No dataset to export. Please load data or perform a measurement first.', ...
                    'No Data');
                return;
            end
            
            % Get export format and location
            [filename, pathname, filterIndex] = uiputfile({...
                '*.csv', 'CSV Files (*.csv)'; ...
                '*.xlsx', 'Excel Files (*.xlsx)'; ...
                '*.mat', 'MATLAB Files (*.mat)'}, ...
                'Export Dataset As');
            
            if isequal(filename, 0)
                return; % User cancelled
            end
            
            try
                fullpath = fullfile(pathname, filename);
                dataset = app.CurrentDataset;
                
                switch filterIndex
                    case 1 % CSV
                        app.exportToCSV(dataset, fullpath);
                    case 2 % Excel
                        app.exportToExcel(dataset, fullpath);
                    case 3 % MATLAB
                        save(fullpath, 'dataset', '-v7.3');
                end
                
                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    sprintf('Dataset exported successfully: %s', filename), ...
                    'Export Complete');
                
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Failed to export dataset: %s', ME.message), ...
                    'Export Error');
            end
        end

        function PlotLoadedDataset(app, ~)
            % Plot the currently loaded dataset
            if isempty(app.CurrentDataset)
                EISAppUtils.showWarningAlert(app.UIFigure, ...
                    'No dataset to plot. Please load a dataset first.', ...
                    'No Data');
                return;
            end

            if ~isfield(app.CurrentDataset, 'frequency') || ~isfield(app.CurrentDataset, 'impedance')
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    'Invalid dataset structure. Missing frequency or impedance data.', ...
                    'Invalid Data');
                return;
            end

            try
                frequency = app.CurrentDataset.frequency;
                impedance = app.CurrentDataset.impedance;

                % Clear previous plots
                cla(app.DatasetNyquistAxes);

                % Nyquist plot (Real vs -Imaginary impedance)
                plot(app.DatasetNyquistAxes, real(impedance), -imag(impedance), 'bo-', ...
                    'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'b');
                app.DatasetNyquistAxes.Title.String = 'Nyquist Plot';
                app.DatasetNyquistAxes.XLabel.String = 'Real Impedance (Ω)';
                app.DatasetNyquistAxes.YLabel.String = '-Imaginary Impedance (Ω)';
                grid(app.DatasetNyquistAxes, 'on');
                axis(app.DatasetNyquistAxes, 'equal');

                % Update Bode plot based on dropdown selection
                app.updateBodePlot();

                % Update status
                app.DatasetStatusLabel.Text = sprintf('Plotted dataset: %d points (%.1f-%.1f Hz)', ...
                    length(frequency), min(frequency), max(frequency));

                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    'Dataset plotted successfully!', ...
                    'Plot Complete');

            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Failed to plot dataset: %s', ME.message), ...
                    'Plot Error');
            end
        end

        function BodePlotTypeChanged(app, ~)
            % Handle Bode plot type change - replot if data is available
            if ~isempty(app.CurrentDataset) && app.PlotDatasetButton.Enable == "on"
                app.updateBodePlot();
            end
        end

        function updateBodePlot(app)
            % Update the Bode plot based on current selection
            if isempty(app.CurrentDataset) || ~isfield(app.CurrentDataset, 'frequency') || ~isfield(app.CurrentDataset, 'impedance')
                return;
            end

            try
                frequency = app.CurrentDataset.frequency;
                impedance = app.CurrentDataset.impedance;

                % Clear previous plot
                cla(app.DatasetBodeAxes);

                if strcmp(app.BodePlotTypeDropDown.Value, 'Magnitude')
                    % Bode magnitude plot
                    magnitude = abs(impedance);
                    semilogx(app.DatasetBodeAxes, frequency, magnitude, 'ro-', ...
                        'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'r');
                    app.DatasetBodeAxes.Title.String = 'Bode Magnitude';
                    app.DatasetBodeAxes.YLabel.String = '|Z| (Ω)';
                    app.DatasetBodeAxes.YScale = 'log';
                else
                    % Bode phase plot
                    phase = angle(impedance) * 180 / pi; % Convert to degrees
                    semilogx(app.DatasetBodeAxes, frequency, phase, 'go-', ...
                        'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'g');
                    app.DatasetBodeAxes.Title.String = 'Bode Phase';
                    app.DatasetBodeAxes.YLabel.String = 'Phase (°)';
                    app.DatasetBodeAxes.YScale = 'linear';
                end

                app.DatasetBodeAxes.XLabel.String = 'Frequency (Hz)';
                grid(app.DatasetBodeAxes, 'on');

            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Failed to update plot: %s', ME.message), ...
                    'Plot Error');
            end
        end

        function dataset = validateDatasetStructure(app, data, filename)
            % Ensure dataset has required fields
            dataset = struct();
            
            % Required fields
            if isfield(data, 'frequency') && isfield(data, 'impedance')
                dataset.frequency = data.frequency;
                dataset.impedance = data.impedance;
            else
                error('Dataset must contain frequency and impedance data');
            end
            
            % Metadata
            if isfield(data, 'metadata')
                dataset.metadata = data.metadata;
            else
                dataset.metadata = struct();
            end
            
            % Ensure metadata has required fields
            if ~isfield(dataset.metadata, 'filename')
                dataset.metadata.filename = filename;
            end
            if ~isfield(dataset.metadata, 'measurementDate')
                dataset.metadata.measurementDate = datetime('now');
            end
            if ~isfield(dataset.metadata, 'sampleName')
                dataset.metadata.sampleName = '';
            end
            if ~isfield(dataset.metadata, 'notes')
                dataset.metadata.notes = '';
            end
            if ~isfield(dataset.metadata, 'numPoints')
                dataset.metadata.numPoints = length(dataset.frequency);
            end
            if ~isfield(dataset.metadata, 'freqRange')
                dataset.metadata.freqRange = sprintf('%.1f-%.1f Hz', ...
                    min(dataset.frequency), max(dataset.frequency));
            end
        end

        function addDatasetToHistory(app, dataset)
            % Add dataset to history table
            app.DatasetHistory{end+1} = dataset;
            app.updateDatasetTable();
        end

        function updateDatasetTable(app)
            % Update the dataset table display
            if isempty(app.DatasetHistory)
                app.DatasetTable.Data = {};
                return;
            end
            
            tableData = cell(length(app.DatasetHistory), 6);
            for i = 1:length(app.DatasetHistory)
                dataset = app.DatasetHistory{i};
        
                % Ensure all data is in compatible format
                tableData{i, 1} = char(dataset.metadata.filename);
                
                % Convert datetime to char string
                if isdatetime(dataset.metadata.measurementDate)
                    tableData{i, 2} = char(dataset.metadata.measurementDate);
                elseif isstring(dataset.metadata.measurementDate)
                    tableData{i, 2} = char(dataset.metadata.measurementDate);
                else
                    tableData{i, 2} = char(string(dataset.metadata.measurementDate));
                end
                
                % Ensure numeric values are properly handled
                tableData{i, 3} = double(dataset.metadata.numPoints);
                tableData{i, 4} = char(dataset.metadata.freqRange);
                tableData{i, 5} = char(dataset.metadata.sampleName);
                tableData{i, 6} = char(dataset.metadata.notes);
            end
            
            app.DatasetTable.Data = tableData;
        end
        
        function updateDatasetUI(app, dataset)
            % Update UI with dataset information
            app.SampleNameEditField.Value = dataset.metadata.sampleName;
            app.SampleNotesTextArea.Value = dataset.metadata.notes;
        end

        function addQuickTag(app, tag)
            % Add quick tag to notes
            currentNotes = app.SampleNotesTextArea.Value;
            
            % Handle cell array vs string conversion
            if iscell(currentNotes)
                currentNotesStr = currentNotes{1}; % Extract string from cell
            else
                currentNotesStr = char(currentNotes); % Convert to char
            end
            
            if isempty(currentNotesStr)
                app.SampleNotesTextArea.Value = tag;
            else
                app.SampleNotesTextArea.Value = [currentNotesStr, '; ', tag];
            end
            
            % Update metadata if dataset exists
            if ~isempty(app.CurrentDataset)
                app.UpdateMetadata();
            end
        end

        function DatasetTableSelection(app, event)
            % Handle table row selection
            if ~isempty(event.Indices)
                selectedRow = event.Indices(1);
                if selectedRow <= length(app.DatasetHistory)
                    app.SelectedDatasetIndex = selectedRow;
                    app.CurrentDataset = app.DatasetHistory{selectedRow};
                    app.updateDatasetUI(app.CurrentDataset);
                    app.SaveDatasetButton.Enable = 'on';
                    app.PlotDatasetButton.Enable = 'on';
                end
            end
        end

        function UpdateMetadata(app, ~)
            % Update current dataset metadata
            if ~isempty(app.CurrentDataset)
                app.CurrentDataset.metadata.sampleName = app.SampleNameEditField.Value;
                app.CurrentDataset.metadata.notes = app.SampleNotesTextArea.Value;
                
                % Update table if this dataset is in history
                if app.SelectedDatasetIndex > 0
                    app.DatasetHistory{app.SelectedDatasetIndex} = app.CurrentDataset;
                    app.updateDatasetTable();
                end
            end
        end

        function saveCurrentMeasurement(app)
            % Save current measurement as dataset
            if app.IsRunningMeasurement || isempty(app.FrequencyVector) || isempty(app.ImpedanceData)
                return;
            end
            
            % Create dataset structure
            dataset = struct();
            dataset.frequency = app.FrequencyVector;
            dataset.impedance = app.ImpedanceData;
            
            % Add metadata with proper data types
            dataset.metadata = struct();
            dataset.metadata.filename = sprintf('Measurement_%s.mat', string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
            dataset.metadata.measurementDate = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')); % CHAR format
            dataset.metadata.numPoints = double(length(app.FrequencyVector)); % DOUBLE format
            dataset.metadata.freqRange = sprintf('%.1f-%.1f Hz', min(app.FrequencyVector), max(app.FrequencyVector));
            dataset.metadata.sampleName = char(app.SampleNameEditField.Value); % CHAR format
            dataset.metadata.notes = char(app.SampleNotesTextArea.Value); % CHAR format
            dataset.metadata.dataSource = 'ESP32';

            % Set as current dataset
            app.CurrentDataset = dataset;
            app.addDatasetToHistory(dataset);
            app.SaveDatasetButton.Enable = 'on';
            
            app.DatasetStatusLabel.Text = sprintf('Measurement data ready for saving (%d points)', ...
                length(app.FrequencyVector));
        end

        function createFittingTab(app)
            % Clear existing content
            delete(app.FittingTab.Children);
            
            % Main title
            titleLabel = uilabel(app.FittingTab);
            titleLabel.Position = [30 580 400 25];
            titleLabel.Text = '📈 Equivalent Circuit Fitting';
            titleLabel.FontSize = 18;
            titleLabel.FontWeight = 'bold';
            
            % Model Selection Panel
            modelPanel = uipanel(app.FittingTab);
            modelPanel.Position = [30 520 530 50];
            modelPanel.Title = 'Circuit Model Selection';
            modelPanel.FontWeight = 'bold';
            
            modelLabel = uilabel(modelPanel);
            modelLabel.Position = [20 15 100 22];
            modelLabel.Text = 'Select Model:';
            modelLabel.FontWeight = 'bold';
            
            app.ModelDropDown = uidropdown(modelPanel);
            app.ModelDropDown.Position = [130 15 150 22];
            app.ModelDropDown.Items = {'Randles Circuit', 'Randles + Warburg (Short)', 'Randles + Warburg (Open)'};
            app.ModelDropDown.Value = 'Randles Circuit';
            app.ModelDropDown.ValueChangedFcn = createCallbackFcn(app, @ModelChanged, true);
            
            % Initial guess and fit button
            app.FitButton = uibutton(modelPanel, 'push');
            app.FitButton.Position = [300 10 120 30];
            app.FitButton.Text = 'Fit Model to Data';
            app.FitButton.FontWeight = 'bold';
            app.FitButton.BackgroundColor = [0.2 0.7 0.2];
            app.FitButton.FontColor = [1 1 1];
            app.FitButton.ButtonPushedFcn = createCallbackFcn(app, @FitModel, true);
            
            app.ExportFitButton = uibutton(modelPanel, 'push');
            app.ExportFitButton.Position = [440 10 120 30];
            app.ExportFitButton.Text = 'Export Results';
            app.ExportFitButton.Enable = 'off';
            app.ExportFitButton.ButtonPushedFcn = createCallbackFcn(app, @ExportFittingResults, true);

            % Circuit Diagram Panel
            circuitPanel = uipanel(app.FittingTab);
            circuitPanel.Position = [580 520 350 50];
            circuitPanel.Title = 'Circuit Diagram';
            circuitPanel.FontWeight = 'bold';

            app.CircuitAxes = uiaxes(circuitPanel);
            app.CircuitAxes.Position = [10 5 330 35];
            app.CircuitAxes.XTick = [];
            app.CircuitAxes.YTick = [];
            app.CircuitAxes.Box = 'off';

            % Parameters Panel
            paramPanel = uipanel(app.FittingTab);
            paramPanel.Position = [30 350 430 160];
            paramPanel.Title = 'Model Parameters';
            paramPanel.FontWeight = 'bold';
            
            % Initial guess table
            guessLabel = uilabel(paramPanel);
            guessLabel.Position = [20 120 150 22];
            guessLabel.Text = 'Initial Parameter Guess:';
            guessLabel.FontWeight = 'bold';
            
            app.InitialGuessTable = uitable(paramPanel);
            app.InitialGuessTable.Position = [20 20 380 95];
            app.InitialGuessTable.ColumnName = {'Parameter', 'Symbol', 'Initial Value', 'Unit'};
            app.InitialGuessTable.ColumnWidth = {80, 60, 100, 60};
            app.InitialGuessTable.ColumnEditable = [false false true false];
            
            % Results Panel
            resultsPanel = uipanel(app.FittingTab);
            resultsPanel.Position = [480 350 450 160];
            resultsPanel.Title = 'Fitting Results';
            resultsPanel.FontWeight = 'bold';
            
            app.FittingResultsTable = uitable(resultsPanel);
            app.FittingResultsTable.Position = [20 20 410 130];
            app.FittingResultsTable.ColumnName = {'Parameter', 'Fitted Value', 'Std Error', 'R²'};
            app.FittingResultsTable.ColumnWidth = {80, 100, 80, 60};
            app.FittingResultsTable.ColumnEditable = false(1,4);
            
            % Plots Panel
            plotsPanel = uipanel(app.FittingTab);
            plotsPanel.Position = [30 130 900 210];
            plotsPanel.Title = 'Fit Visualization';
            plotsPanel.FontWeight = 'bold';
            
            % Fitting plot (Nyquist with overlay)
            app.FittingAxes = uiaxes(plotsPanel);
            app.FittingAxes.Position = [20 20 420 170];
            app.FittingAxes.XLabel.String = 'Real Part (Ω)';
            app.FittingAxes.YLabel.String = '-Imaginary Part (Ω)';
            app.FittingAxes.Title.String = 'Measured vs Fitted Data';
            grid(app.FittingAxes, 'on');
            
            % Residuals plot
            app.ResidualsAxes = uiaxes(plotsPanel);
            app.ResidualsAxes.Position = [460 20 420 170];
            app.ResidualsAxes.XLabel.String = 'Frequency (Hz)';
            app.ResidualsAxes.YLabel.String = 'Residuals (%)';
            app.ResidualsAxes.Title.String = 'Fitting Residuals';
            app.ResidualsAxes.XScale = 'log';
            grid(app.ResidualsAxes, 'on');
            
            % Status Panel
            statusPanel = uipanel(app.FittingTab);
            statusPanel.Position = [30 60 900 60];
            statusPanel.Title = 'Fitting Status';
            statusPanel.FontWeight = 'bold';
            
            app.FittingStatusLabel = uilabel(statusPanel);
            app.FittingStatusLabel.Position = [20 20 860 22];
            app.FittingStatusLabel.Text = 'Select a circuit model and load data to begin fitting';
            app.FittingStatusLabel.FontSize = 12;
            
            % Export Plot Button for Fitting Tab
            app.ExportFittingPlotButton = uibutton(app.FittingTab, 'push');
            app.ExportFittingPlotButton.Position = [860 340 60 30];
            app.ExportFittingPlotButton.Text = 'Export Plot';
            app.ExportFittingPlotButton.ButtonPushedFcn = createCallbackFcn(app, @ExportFittingPlots, true);

            % Initialize with Randles circuit
            app.updateParameterTable();
            app.drawCircuitDiagram();
        end

        function ModelChanged(app, ~)
            % Handle model selection change
            app.CurrentModel = app.ModelDropDown.Value;
            app.updateParameterTable();
            app.drawCircuitDiagram();
            app.FittingStatusLabel.Text = sprintf('Model changed to: %s', app.CurrentModel);
        end

        function drawCircuitDiagram(app)
            % Draw a simple circuit diagram for the selected model
            cla(app.CircuitAxes);
            hold(app.CircuitAxes, 'on');

            selectedIndex = find(strcmp(app.ModelDropDown.Value, app.ZfitCircuitNames));
            if isempty(selectedIndex)
                selectedIndex = 1;
            end

            switch selectedIndex
                case 1 % Randles Circuit: s(Rs,p(Rct,Cdl))
                    app.drawRandlesCircuit();
                case 2 % Randles + Warburg (Short): s(Rs,p(s(Rct,Gw),Cdl))
                    app.drawRandlesWarburgCircuit('G');
                case 3 % Randles + Warburg (Open): s(Rs,p(s(Rct,Hw),Cdl))
                    app.drawRandlesWarburgCircuit('H');
            end

            % Set axis properties
            app.CircuitAxes.XLim = [0 10];
            app.CircuitAxes.YLim = [0 2];
            app.CircuitAxes.XTick = [];
            app.CircuitAxes.YTick = [];
            app.CircuitAxes.Box = 'off';
            axis(app.CircuitAxes, 'equal');
            hold(app.CircuitAxes, 'off');
        end

        function drawRandlesCircuit(app)
            % Draw Randles circuit: Rs in series with (Rct || Cdl)
            % Main line
            plot(app.CircuitAxes, [0.5 1.5], [1 1], 'k-', 'LineWidth', 2); % Left terminal
            plot(app.CircuitAxes, [8.5 9.5], [1 1], 'k-', 'LineWidth', 2); % Right terminal

            % Rs (series resistor)
            plot(app.CircuitAxes, [1.5 3], [1 1], 'k-', 'LineWidth', 2);
            app.drawResistor(app.CircuitAxes, 2.25, 1, 'Rs');

            % Connection to parallel branch
            plot(app.CircuitAxes, [3 4], [1 1], 'k-', 'LineWidth', 2);
            plot(app.CircuitAxes, [7 8.5], [1 1], 'k-', 'LineWidth', 2);

            % Parallel branch - vertical connections
            plot(app.CircuitAxes, [4 4], [0.5 1.5], 'k-', 'LineWidth', 2);
            plot(app.CircuitAxes, [7 7], [0.5 1.5], 'k-', 'LineWidth', 2);

            % Rct (top branch)
            plot(app.CircuitAxes, [4 7], [1.5 1.5], 'k-', 'LineWidth', 2);
            app.drawResistor(app.CircuitAxes, 5.5, 1.5, 'Rct');

            % CPE (bottom branch)
            plot(app.CircuitAxes, [4 7], [0.5 0.5], 'k-', 'LineWidth', 2);
            app.drawCPE(app.CircuitAxes, 5.5, 0.5, 'CPE');

            % Terminals
            plot(app.CircuitAxes, 0.5, 1, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
            plot(app.CircuitAxes, 9.5, 1, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
        end

        function drawRandlesWarburgCircuit(app, warburgType)
            % Draw Randles circuit with Warburg element: Rs + (Rct+Warburg || Cdl)
            % warburgType: 'G' for short circuit, 'H' for open circuit
            cla(app.CircuitAxes);
            hold(app.CircuitAxes, 'on');

            % Main horizontal line
            plot(app.CircuitAxes, [0.5 1.5], [1 1], 'k-', 'LineWidth', 2); % Left terminal
            plot(app.CircuitAxes, [8.5 9.5], [1 1], 'k-', 'LineWidth', 2); % Right terminal

            % Rs (series resistor)
            plot(app.CircuitAxes, [1.5 3], [1 1], 'k-', 'LineWidth', 2);
            app.drawResistor(app.CircuitAxes, 2.25, 1, 'Rs');

            % Parallel section connections
            plot(app.CircuitAxes, [3 4], [1 1], 'k-', 'LineWidth', 2);
            plot(app.CircuitAxes, [7 8.5], [1 1], 'k-', 'LineWidth', 2);

            % Vertical connections for parallel branches
            plot(app.CircuitAxes, [4 4], [0.3 1.7], 'k-', 'LineWidth', 2);
            plot(app.CircuitAxes, [7 7], [0.3 1.7], 'k-', 'LineWidth', 2);

            % Top branch: Rct in series with Warburg
            plot(app.CircuitAxes, [4 4.8], [1.7 1.7], 'k-', 'LineWidth', 2);
            plot(app.CircuitAxes, [5.5 6.2], [1.7 1.7], 'k-', 'LineWidth', 2);
            plot(app.CircuitAxes, [6.8 7], [1.7 1.7], 'k-', 'LineWidth', 2);

            % Draw Rct
            app.drawResistor(app.CircuitAxes, 5.15, 1.7, 'Rct');

            % Draw Warburg element
            if strcmp(warburgType, 'G')
                app.drawWarburg(app.CircuitAxes, 6.5, 1.7, 'Gw', 'Short');
            else
                app.drawWarburg(app.CircuitAxes, 6.5, 1.7, 'Hw', 'Open');
            end

            % Bottom branch: CPE (Q,n)
            plot(app.CircuitAxes, [4 7], [0.3 0.3], 'k-', 'LineWidth', 2);
            app.drawCPE(app.CircuitAxes, 5.5, 0.3, 'CPE');

            % Terminals
            plot(app.CircuitAxes, 0.5, 1, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
            plot(app.CircuitAxes, 9.5, 1, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
        end

        function drawWarburg(app, ax, x, y, label, type)
            % Draw a Warburg element symbol at position (x,y)
            % type: 'Short' or 'Open'
            w = 0.3; h = 0.2;

            % Draw zigzag pattern for Warburg
            plot(ax, [x-w x-w/2 x x+w/2 x+w], [y y+h y-h y+h y], 'k-', 'LineWidth', 2);

            % Add boundary condition indicator
            if strcmp(type, 'Short')
                % Short circuit - line at end
                plot(ax, [x+w x+w], [y-h/2 y+h/2], 'k-', 'LineWidth', 3);
            else
                % Open circuit - gap at end
                plot(ax, [x+w-0.05 x+w-0.05], [y-h/2 y+h/2], 'k-', 'LineWidth', 3);
                plot(ax, [x+w+0.05 x+w+0.05], [y-h/2 y+h/2], 'k-', 'LineWidth', 3);
            end

            text(ax, x, y+0.35, label, 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
        end

        function drawResistor(app, ax, x, y, label)
            % Draw a resistor symbol at position (x,y)
            w = 0.4; h = 0.15;
            plot(ax, [x-w x-w/2 x-w/4 x+w/4 x+w/2 x+w], [y y+h y-h y+h y-h y], 'k-', 'LineWidth', 2);
            text(ax, x, y+0.3, label, 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
        end

        function drawCapacitor(app, ax, x, y, label)
            % Draw a capacitor symbol at position (x,y)
            gap = 0.1;
            plot(ax, [x-gap x-gap], [y-0.2 y+0.2], 'k-', 'LineWidth', 3);
            plot(ax, [x+gap x+gap], [y-0.2 y+0.2], 'k-', 'LineWidth', 3);
            text(ax, x, y+0.3, label, 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
        end

        function drawCPE(app, ax, x, y, label)
            % Draw a CPE (Constant Phase Element) symbol at position (x,y)
            gap = 0.1;
            % Left plate (straight line)
            plot(ax, [x-gap x-gap], [y-0.2 y+0.2], 'k-', 'LineWidth', 3);
            % Right plate (curved line to indicate non-ideal behavior)
            theta = linspace(-pi/3, pi/3, 20);
            curve_x = x + gap + 0.02 * cos(theta + pi/2);
            curve_y = y + 0.2 * sin(theta);
            plot(ax, curve_x, curve_y, 'k-', 'LineWidth', 3);
            text(ax, x, y+0.3, label, 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
        end

        function updateParameterTable(app)
            % Update parameter table based on selected model using Zfit notation
            selectedIndex = find(strcmp(app.ModelDropDown.Value, app.ZfitCircuitNames));
            
            switch selectedIndex
                case 1 % Randles Circuit: s(R1,p(R1,E2)) - 4 parameters
                    paramData = {
                        'Rs', 'Rs', 100, 'Ω';
                        'Rct', 'Rct', 1000, 'Ω';
                        'Q', 'CPE_Q', 1e-6, 'F⋅s^(n-1)';
                        'n', 'CPE_n', 0.9, '-'
                    };
                case 2 % Randles + Warburg (Short): s(R1,p(s(R1,G2),E2)) - 6 parameters
                    paramData = {
                        'Rs', 'Rs', 100, 'Ω';
                        'Rct', 'Rct', 1000, 'Ω';
                        'σ', 'Warburg_sigma', 0.02, 'Ω⋅s^-0.5';
                        'B', 'Warburg_B', 0.1, 's^-0.5';
                        'Q', 'CPE_Q', 1e-6, 'F⋅s^(n-1)';
                        'n', 'CPE_n', 0.9, '-'
                    };
                case 3 % Randles + Warburg (Open): s(R1,p(s(R1,H2),E2)) - 6 parameters
                    paramData = {
                        'Rs', 'Rs', 100, 'Ω';
                        'Rct', 'Rct', 1000, 'Ω';
                        'σ', 'Warburg_sigma', 0.02, 'Ω⋅s^-0.5';
                        'B', 'Warburg_B', 0.1, 's^-0.5';
                        'Q', 'CPE_Q', 1e-6, 'F⋅s^(n-1)';
                        'n', 'CPE_n', 0.9, '-'
                    };
                otherwise % Default case
                    paramData = {
                        'Rs', 'Rs', 100, 'Ω';
                        'Rct', 'Rct', 1000, 'Ω';
                        'Q', 'CPE_Q', 1e-6, 'F⋅s^(n-1)';
                        'n', 'CPE_n', 0.9, '-'
                    };
            end
            
            % Set the table data
            app.InitialGuessTable.Data = paramData;
        end

        function FitModel(app, ~)
            % Perform model fitting using Zfit
            if isempty(app.CurrentDataset) || ~isfield(app.CurrentDataset, 'frequency') || ~isfield(app.CurrentDataset, 'impedance')
                EISAppUtils.showWarningAlert(app.UIFigure, ...
                    'No dataset available for fitting. Please load data or perform a measurement first.', ...
                    'No Data');
                return;
            end
            
            % Check if table has data
            if isempty(app.InitialGuessTable.Data)
                EISAppUtils.showWarningAlert(app.UIFigure, ...
                    'Parameter table is empty. Please select a model first.', ...
                    'No Parameters');
                return;
            end
            
            try
                app.FittingStatusLabel.Text = 'Zfit fitting in progress...';
                drawnow;
                
                % ROBUST DATA PREPARATION
                frequency = app.CurrentDataset.frequency;
                impedance = app.CurrentDataset.impedance;
                
                % Ensure both are column vectors and same length
                frequency = frequency(:);  % Force column vector
                impedance = impedance(:);  % Force column vector
                
                % Check dimensions match
                if length(frequency) ~= length(impedance)
                    error('Frequency and impedance arrays must have the same length: freq=%d, imp=%d', ...
                        length(frequency), length(impedance));
                end
                
                % Remove any NaN or Inf values
                validIndices = isfinite(frequency) & isfinite(impedance);
                frequency = frequency(validIndices);
                impedance = impedance(validIndices);
                
                % Check we still have enough data
                if length(frequency) < 5
                    error('Insufficient valid data points for fitting (need at least 5, got %d)', length(frequency));
                end
                
                % Create Zfit data matrix: MUST be [frequency, real(Z), imag(Z)]
                zfitData = [frequency, real(impedance), imag(impedance)];
                
                % Final verification
                if size(zfitData, 2) ~= 3
                    error('Zfit data matrix must have exactly 3 columns, got %d', size(zfitData, 2));
                end
                
                if size(zfitData, 1) < 3
                    error('Zfit data matrix must have at least 3 rows, got %d', size(zfitData, 1));
                end
                
                % Get circuit string and initial parameters
                selectedIndex = find(strcmp(app.ModelDropDown.Value, app.ZfitCircuitNames));
                if isempty(selectedIndex)
                    selectedIndex = 1; % Default to first model
                end
                
                circuitString = app.ZfitCircuitStrings{selectedIndex};
                
                % Safely extract initial parameters
                tableData = app.InitialGuessTable.Data;
                if size(tableData, 2) < 3
                    error('Parameter table does not have enough columns');
                end
                
                initialParams = cell2mat(tableData(:,3));
                
                % Set up Zfit parameters
                plotString = ''; % No plotting from Zfit
                indexes = []; % Use all data points
                fitString = 'fitP'; % Proportional weighting
                
                % Set parameter bounds (optional)
                LB = initialParams * 0.01; % Lower bounds: 1% of initial
                UB = initialParams * 100;  % Upper bounds: 100x initial
                
                % Set optimization options
                options = optimset('Display', 'off', 'MaxFunEvals', 1000, 'MaxIter', 500);

                % DEBUG: Add these lines right before calling Zfit
                fprintf('=== ZFIT DEBUG INFO ===\n');
                fprintf('Frequency vector size: %s\n', mat2str(size(frequency)));
                fprintf('Impedance vector size: %s\n', mat2str(size(impedance)));
                fprintf('ZfitData matrix size: %s\n', mat2str(size(zfitData)));
                fprintf('Initial params size: %s\n', mat2str(size(initialParams)));
                fprintf('Circuit string: %s\n', circuitString);
                
                % Show first few rows of data
                fprintf('First 3 rows of zfitData:\n');
                disp(zfitData(1:min(3,end),:));
                
                % Check for any NaN or Inf values
                fprintf('Any NaN in zfitData: %d\n', any(isnan(zfitData(:))));
                fprintf('Any Inf in zfitData: %d\n', any(isinf(zfitData(:))));
                
                % Check parameter array
                fprintf('Initial parameters:\n');
                disp(initialParams);
                fprintf('========================\n');
                
                % Call Zfit
                [fittedParams, fittedZ, fval, exitflag, output] = ...
                    Zfit(zfitData, plotString, circuitString, initialParams, indexes, fitString, LB, UB, options);
                
                % Convert fitted impedance back to complex form
                fittedImpedance = complex(fittedZ(:,1), fittedZ(:,2));
                
                % Calculate fit quality
                fitQuality = app.calculateZfitQuality(impedance, fittedImpedance, fval, exitflag);
                
                % Store results
                app.FittedParameters = fittedParams;
                app.FitQuality = fitQuality;
                
                % Update results table and plots
                app.updateZfitResultsTable(fittedParams, fitQuality);
                app.plotZfitResults(frequency, impedance, fittedImpedance);
                
                % Update status
                app.FittingStatusLabel.Text = sprintf('Zfit completed. R² = %.4f, Exit: %d', ...
                    fitQuality.rsquared, exitflag);
                app.ExportFitButton.Enable = 'on';
                
                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    sprintf('Zfit completed successfully.\nR² = %.4f\nExit flag: %d', ...
                    fitQuality.rsquared, exitflag), 'Zfit Complete');
                
            catch ME
                app.FittingStatusLabel.Text = 'Zfit fitting failed';
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Zfit failed: %s', ME.message), 'Zfit Error');
            end
        end

        function fitQuality = calculateZfitQuality(app, measured, fitted, fval, exitflag)
            % Calculate fit quality metrics from Zfit results
            
            % Calculate R-squared
            SSres = sum(abs(measured - fitted).^2);
            SStot = sum(abs(measured - mean(measured)).^2);
            rsquared = 1 - SSres/SStot;
            
            % Calculate RMSE
            rmse = sqrt(mean(abs(measured - fitted).^2));
            
            % Calculate normalized chi-squared (from Zfit fval)
            chisquared_norm = fval / length(measured);
            
            fitQuality = struct();
            fitQuality.rsquared = rsquared;
            fitQuality.rmse = rmse;
            fitQuality.chisquared = chisquared_norm;
            fitQuality.fval = fval;
            fitQuality.exitflag = exitflag;
            fitQuality.residuals = measured - fitted;
        end

        function updateZfitResultsTable(app, fittedParams, fitQuality)
            % Update results table with Zfit fitted parameters
            paramNames = app.InitialGuessTable.Data(:,1);
            
            resultsData = cell(length(fittedParams), 4);
            for i = 1:length(fittedParams)
                resultsData{i,1} = char(paramNames{i});
                resultsData{i,2} = sprintf('%.6g', fittedParams(i));
                resultsData{i,3} = 'N/A'; % Standard error calculation would require more complex analysis
                if i == 1
                    resultsData{i,4} = sprintf('%.4f', fitQuality.rsquared);
                else
                    resultsData{i,4} = '';
                end
            end
            
            app.FittingResultsTable.Data = resultsData;
        end

        function plotZfitResults(app, frequency, measured, fitted)
            % Plot Zfit results
            
            % Nyquist plot with overlay
            cla(app.FittingAxes);
            hold(app.FittingAxes, 'on');
            
            plot(app.FittingAxes, real(measured), -imag(measured), 'bo', ...
                'MarkerSize', 6, 'DisplayName', 'Measured');
            plot(app.FittingAxes, real(fitted), -imag(fitted), 'r-', ...
                'LineWidth', 2, 'DisplayName', 'Zfit Model');
            
            legend(app.FittingAxes, 'Location', 'best');
            grid(app.FittingAxes, 'on');
            axis(app.FittingAxes, 'equal');
            hold(app.FittingAxes, 'off');
            
            % Residuals plot
            residuals = abs(measured - fitted) ./ abs(measured) * 100;
            
            cla(app.ResidualsAxes);
            semilogx(app.ResidualsAxes, frequency, residuals, 'ro-', ...
                'LineWidth', 1.5, 'MarkerSize', 4);
            grid(app.ResidualsAxes, 'on');
            title(app.ResidualsAxes, 'Zfit Residuals (%)');
        end

        function ExportFittingResults(app, ~)
            % Export Zfit fitting results
            if isempty(app.FittedParameters)
                EISAppUtils.showWarningAlert(app.UIFigure, ...
                    'No fitting results to export. Please perform fitting first.', ...
                    'No Results');
                return;
            end
            
            [filename, pathname] = uiputfile({'*.xlsx', 'Excel Files (*.xlsx)'; ...
                                             '*.csv', 'CSV Files (*.csv)'; ...
                                             '*.mat', 'MATLAB Files (*.mat)'}, ...
                                             'Export Zfit Results');
            
            if isequal(filename, 0)
                return;
            end
            
            try
                fullpath = fullfile(pathname, filename);
                [~, ~, ext] = fileparts(filename);
                
                % Prepare export data
                exportData = struct();
                exportData.model = app.CurrentModel;
                exportData.circuitString = app.ZfitCircuitStrings{find(strcmp(app.ModelDropDown.Value, app.ZfitCircuitNames))};
                exportData.parameters = app.FittedParameters;
                exportData.parameterNames = app.InitialGuessTable.Data(:,1);
                exportData.fitQuality = app.FitQuality;
                exportData.exportDate = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
                
                switch ext
                    case '.mat'
                        save(fullpath, 'exportData', '-v7.3');
                    case '.xlsx'
                        % Create table for Excel export
                        paramTable = table(exportData.parameterNames, exportData.parameters, ...
                            'VariableNames', {'Parameter', 'Value'});
                        writetable(paramTable, fullpath, 'Sheet', 'Parameters');
                    case '.csv'
                        % Create CSV export
                        paramTable = table(exportData.parameterNames, exportData.parameters, ...
                            'VariableNames', {'Parameter', 'Value'});
                        writetable(paramTable, fullpath);
                end
                
                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    sprintf('Zfit results exported successfully: %s', filename), ...
                    'Export Complete');
                
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Failed to export results: %s', ME.message), ...
                    'Export Error');
            end
        end

        function dataset = constructDatasetFromVariables(app, loadedData)
            % Construct dataset from loaded variables when no 'dataset' field exists
            dataset = struct();
            
            % Try to find frequency and impedance data in common variable names
            fieldNames = fieldnames(loadedData);
            
            % Look for frequency data
            freqFields = fieldNames(contains(lower(fieldNames), {'freq', 'f'}));
            if ~isempty(freqFields)
                dataset.frequency = loadedData.(freqFields{1});
            else
                error('Could not find frequency data in loaded file');
            end
            
            % Look for impedance data (real and imaginary parts)
            realFields = fieldNames(contains(lower(fieldNames), {'real', 'zr', 'zreal', 'impedance_real'}));
            imagFields = fieldNames(contains(lower(fieldNames), {'imag', 'zi', 'zimag', 'impedance_imag'}));
            
            if ~isempty(realFields) && ~isempty(imagFields)
                realPart = loadedData.(realFields{1});
                imagPart = loadedData.(imagFields{1});
                dataset.impedance = complex(realPart, imagPart);
            else
                error('Could not find impedance data (real and imaginary parts) in loaded file');
            end
        end

        function dataset = loadCSVDataset(app, fullpath)
            % Load dataset from CSV file
            try
                data = readmatrix(fullpath);
                if size(data, 2) < 3
                    error('CSV file must have at least 3 columns: frequency, real(Z), imag(Z)');
                end
                
                dataset = struct();
                dataset.frequency = data(:, 1);
                dataset.impedance = complex(data(:, 2), data(:, 3));
                
                % Add basic metadata
                dataset.metadata = struct();
                [~, filename, ~] = fileparts(fullpath);
                dataset.metadata.filename = filename;
                dataset.metadata.measurementDate = datetime('now');
                dataset.metadata.sampleName = '';
                dataset.metadata.notes = '';
                
            catch ME
                error('Failed to load CSV file: %s', ME.message);
            end
        end

        function exportToCSV(app, dataset, fullpath)
            % Export dataset to CSV format
            data = [dataset.frequency(:), real(dataset.impedance(:)), imag(dataset.impedance(:))];
            headers = {'Frequency_Hz', 'Real_Z_Ohm', 'Imag_Z_Ohm'};
            
            % Create table and write to CSV
            dataTable = array2table(data, 'VariableNames', headers);
            writetable(dataTable, fullpath);
        end

        function exportToExcel(app, dataset, fullpath)
            % Export dataset to Excel format
            data = [dataset.frequency(:), real(dataset.impedance(:)), imag(dataset.impedance(:))];
            headers = {'Frequency_Hz', 'Real_Z_Ohm', 'Imag_Z_Ohm'};
            
            % Create table and write to Excel
            dataTable = array2table(data, 'VariableNames', headers);
            writetable(dataTable, fullpath, 'Sheet', 'EIS_Data');
            
            % Add metadata sheet
            metadataTable = table({dataset.metadata.filename; dataset.metadata.sampleName; ...
                                  char(dataset.metadata.measurementDate); dataset.metadata.notes}, ...
                                 {'Filename'; 'Sample Name'; 'Date'; 'Notes'}, ...
                                 'VariableNames', {'Value', 'Parameter'});
            writetable(metadataTable, fullpath, 'Sheet', 'Metadata');
        end

        function DatasetTableEdit(app, event)
            % Handle editing of dataset table cells
            if ~isempty(event.Indices)
                row = event.Indices(1);
                col = event.Indices(2);
                
                % Only allow editing of sample name (col 5) and notes (col 6)
                if col == 5 || col == 6
                    if row <= length(app.DatasetHistory)
                        if col == 5
                            app.DatasetHistory{row}.metadata.sampleName = event.NewData;
                        elseif col == 6
                            app.DatasetHistory{row}.metadata.notes = event.NewData;
                        end
                    end
                end
            end
        end

        function ExportLivePlots(app, ~)
            try
                [file, path] = uiputfile({'*.png';'*.pdf'}, 'Export Live Plot As');
                if isequal(file,0), return; end
                f = figure('Visible','off');
                t = tiledlayout(f,1,3,'TileSpacing','compact');
                nexttile; copyobj(app.NyquistAxes, gca); title('Nyquist');
                nexttile; copyobj(app.BodeMagAxes, gca); title('Bode Mag');
                nexttile; copyobj(app.BodePhaseAxes, gca); title('Bode Phase');
                exportgraphics(t, fullfile(path,file));
                close(f);
                EISAppUtils.showSuccessAlert(app.UIFigure, 'Live plots exported successfully.', 'Export Complete');
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, sprintf('Failed to export plot: %s', ME.message), 'Export Error');
            end
        end

        function ExportFittingPlots(app, ~)
            try
                [file, path] = uiputfile({'*.png';'*.pdf'}, 'Export Fitting Plot As');
                if isequal(file,0), return; end
                f = figure('Visible','off');
                t = tiledlayout(f,1,2,'TileSpacing','compact');
                nexttile; copyobj(app.FittingAxes, gca); title('Nyquist Fit');
                nexttile; copyobj(app.ResidualsAxes, gca); title('Residuals');
                exportgraphics(t, fullfile(path,file));
                close(f);
                EISAppUtils.showSuccessAlert(app.UIFigure, 'Fitting plots exported successfully.', 'Export Complete');
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, sprintf('Failed to export plot: %s', ME.message), 'Export Error');
            end
        end

        function createReportTab(app)
            % Clear existing content
            delete(app.ReportTab.Children);
            
            % Main title
            titleLabel = uilabel(app.ReportTab);
            titleLabel.Position = [30 580 400 25];
            titleLabel.Text = '📋 EIS Analysis Report';
            titleLabel.FontSize = 18;
            titleLabel.FontWeight = 'bold';
            
            % Report Generation Panel
            generationPanel = uipanel(app.ReportTab);
            generationPanel.Position = [30 520 900 50];
            generationPanel.Title = 'Report Generation';
            generationPanel.FontWeight = 'bold';
            
            app.GenerateReportButton = uibutton(generationPanel, 'push');
            app.GenerateReportButton.Position = [20 15 120 25];
            app.GenerateReportButton.Text = 'Generate Report';
            app.GenerateReportButton.FontWeight = 'bold';
            app.GenerateReportButton.BackgroundColor = [0.2 0.6 0.8];
            app.GenerateReportButton.FontColor = [1 1 1];
            app.GenerateReportButton.ButtonPushedFcn = createCallbackFcn(app, @GenerateReport, true);
            
            app.ExportReportPDFButton = uibutton(generationPanel, 'push');
            app.ExportReportPDFButton.Position = [160 15 100 25];
            app.ExportReportPDFButton.Text = 'Export PDF';
            app.ExportReportPDFButton.BackgroundColor = [0.8 0.2 0.2];
            app.ExportReportPDFButton.FontColor = [1 1 1];
            app.ExportReportPDFButton.Enable = 'off';
            app.ExportReportPDFButton.ButtonPushedFcn = createCallbackFcn(app, @ExportReportPDF, true);
            
            app.ExportReportExcelButton = uibutton(generationPanel, 'push');
            app.ExportReportExcelButton.Position = [280 15 100 25];
            app.ExportReportExcelButton.Text = 'Export Excel';
            app.ExportReportExcelButton.BackgroundColor = [0.2 0.7 0.2];
            app.ExportReportExcelButton.FontColor = [1 1 1];
            app.ExportReportExcelButton.Enable = 'off';
            app.ExportReportExcelButton.ButtonPushedFcn = createCallbackFcn(app, @ExportReportExcel, true);
            
            % Report Content Area
            contentPanel = uipanel(app.ReportTab);
            contentPanel.Position = [30 140 900 370];
            contentPanel.Title = 'Report Content';
            contentPanel.FontWeight = 'bold';
            
            app.ReportTextArea = uitextarea(contentPanel);
            app.ReportTextArea.Position = [20 20 860 330];
            app.ReportTextArea.Editable = 'off';
            app.ReportTextArea.Value = {'Click "Generate Report" to create a comprehensive EIS analysis summary.'};
            app.ReportTextArea.FontName = 'Courier New';
            app.ReportTextArea.FontSize = 11;
            
            % Status Panel
            statusPanel = uipanel(app.ReportTab);
            statusPanel.Position = [30 70 900 60];
            statusPanel.Title = 'Report Status';
            statusPanel.FontWeight = 'bold';
                       
            app.ReportStatusLabel = uilabel(statusPanel);
            app.ReportStatusLabel.Position = [20 20 860 22];
            app.ReportStatusLabel.Text = 'Ready to generate report. Ensure you have: 1) Dataset loaded, 2) Plots generated, 3) Fitting performed.';
            app.ReportStatusLabel.FontSize = 12;

            % Add this button in your createReportTab function after the Generate Report button:
            app.CheckDataButton = uibutton(generationPanel, 'push');
            app.CheckDataButton.Position = [400 15 100 25];
            app.CheckDataButton.Text = 'Check Data';
            app.CheckDataButton.ButtonPushedFcn = createCallbackFcn(app, @CheckReportData, true);
        end
        
        function CheckReportData(app, ~)
                % Check data availability without generating report
                validationResult = app.validateReportData();
                
                if validationResult.isValid && ~validationResult.hasWarnings
                    EISAppUtils.showSuccessAlert(app.UIFigure, ...
                        'All required data is available for report generation.', ...
                        'Data Check Complete');
                elseif validationResult.hasWarnings
                    warningText = strjoin(validationResult.warnings, newline);
                    EISAppUtils.showWarningAlert(app.UIFigure, ...
                        sprintf('Report can be generated but some data is missing:%s%s', newline, warningText), ...
                        'Data Check Warning');
                else
                    missingText = strjoin(validationResult.missingItems, newline);
                    EISAppUtils.showErrorAlert(app.UIFigure, ...
                        sprintf('Cannot generate report. Missing:%s%s', newline, missingText), ...
                        'Data Check Failed');
                end
            end

        function GenerateReport(app, ~)
            % Generate comprehensive EIS analysis report with validation
            try
                app.ReportStatusLabel.Text = 'Validating data for report generation...';
                drawnow;
                
                % Validate data availability
                validationResult = app.validateReportData();
                
                if ~validationResult.isValid
                    % Show warning dialog with missing data details
                    app.showReportValidationWarning(validationResult);
                    app.ReportStatusLabel.Text = 'Report generation cancelled - missing required data.';
                    return;
                end
                
                app.ReportStatusLabel.Text = 'Generating report...';
                drawnow;
                
                % Collect data from all tabs
                reportContent = app.compileReportContent();
                
                % Update report text area
                app.ReportTextArea.Value = reportContent;
                
                % Enable export buttons
                app.ExportReportPDFButton.Enable = 'on';
                app.ExportReportExcelButton.Enable = 'on';
                
                app.ReportStatusLabel.Text = 'Report generated successfully. Ready for export.';
                
                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    'EIS analysis report generated successfully.', ...
                    'Report Generated');
                
            catch ME
                app.ReportStatusLabel.Text = 'Report generation failed.';
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Failed to generate report: %s', ME.message), ...
                    'Report Error');
            end
        end

        function validationResult = validateReportData(app)
            % Validate that essential data exists for report generation
            validationResult = struct();
            validationResult.isValid = true;
            validationResult.missingItems = {};
            validationResult.warnings = {};
            
            % Check for dataset
            if isempty(app.CurrentDataset)
                validationResult.isValid = false;
                validationResult.missingItems{end+1} = 'No dataset loaded';
            else
                % Check dataset completeness
                if ~isfield(app.CurrentDataset, 'frequency') || isempty(app.CurrentDataset.frequency)
                    validationResult.isValid = false;
                    validationResult.missingItems{end+1} = 'Dataset missing frequency data';
                end
                
                if ~isfield(app.CurrentDataset, 'impedance') || isempty(app.CurrentDataset.impedance)
                    validationResult.isValid = false;
                    validationResult.missingItems{end+1} = 'Dataset missing impedance data';
                end
            end
            
            % Check for measurement data (plots)
            hasLivePlotData = ~isempty(app.FrequencyVector) && ~isempty(app.ImpedanceData);
            if ~hasLivePlotData
                validationResult.warnings{end+1} = 'No live measurement plots available';
            end
            
            % Check for fitting results
            if isempty(app.FittedParameters)
                validationResult.warnings{end+1} = 'No fitting results available';
            end
            
            % Check if plots have been generated
            hasNyquistPlot = ~isempty(app.NyquistAxes.Children);
            hasBodePlots = ~isempty(app.BodeMagAxes.Children) && ~isempty(app.BodePhaseAxes.Children);
            hasFittingPlot = ~isempty(app.FittingAxes.Children);
            
            if ~hasNyquistPlot && ~hasBodePlots
                validationResult.warnings{end+1} = 'No EIS plots have been generated';
            end
            
            if ~hasFittingPlot
                validationResult.warnings{end+1} = 'No fitting plots have been generated';
            end
            
            % If only warnings exist, still allow report generation but inform user
            if isempty(validationResult.missingItems) && ~isempty(validationResult.warnings)
                validationResult.hasWarnings = true;
            else
                validationResult.hasWarnings = false;
            end
        end

        function showReportValidationWarning(app, validationResult)
            % Show detailed warning about missing data for report generation
            
            if ~isempty(validationResult.missingItems)
                % Critical missing data - prevent report generation
                missingText = strjoin(validationResult.missingItems, newline);
                warningMessage = sprintf(['Cannot generate report due to missing essential data:' newline newline ...
                                        '%s' newline newline ...
                                        'Please:' newline ...
                                        '• Load a dataset in the Dataset tab, or' newline ...
                                        '• Perform a measurement in the Live Plot tab'], missingText);
                
                uialert(app.UIFigure, warningMessage, 'Missing Required Data', 'Icon', 'error');
                
            elseif validationResult.hasWarnings
                % Only warnings - allow user to choose
                warningText = strjoin(validationResult.warnings, newline);
                warningMessage = sprintf(['Report can be generated but some data is missing:' newline newline ...
                                        '%s' newline newline ...
                                        'The report will be incomplete. Continue anyway?'], warningText);
                
                selection = uiconfirm(app.UIFigure, warningMessage, 'Incomplete Data Warning', ...
                                     'Options', {'Generate Report', 'Cancel'}, ...
                                     'DefaultOption', 'Cancel', ...
                                     'Icon', 'warning');
                
                if strcmp(selection, 'Cancel')
                    validationResult.isValid = false;
                end
            end
        end
        
        function reportContent = compileReportContent(app)
            % Compile comprehensive report content with proper cell array handling
            reportLines = {};
            
            try
                % Header
                reportLines{end+1} = '========================================';
                reportLines{end+1} = '      EIS ANALYSIS REPORT';
                reportLines{end+1} = '========================================';
                reportLines{end+1} = sprintf('Generated: %s', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
                reportLines{end+1} = sprintf('App Version: %s', app.Version);
                reportLines{end+1} = '';
                
                % Connection Status
                reportLines{end+1} = '1. CONNECTION STATUS';
                reportLines{end+1} = '----------------------------------------';
                if app.IsConnected
                    connectionType = app.safeStringConvert(app.ConnectionType);
                    reportLines{end+1} = sprintf('ESP32 Status: Connected (%s)', connectionType);
                else
                    reportLines{end+1} = 'ESP32 Status: Not Connected';
                end
                reportLines{end+1} = '';
                
                % Dataset Information
                reportLines{end+1} = '2. DATASET INFORMATION';
                reportLines{end+1} = '----------------------------------------';
                if ~isempty(app.CurrentDataset) && isstruct(app.CurrentDataset) && isfield(app.CurrentDataset, 'metadata')
                    % Safe extraction of metadata with cell array handling
                    sampleName = app.safeStringConvert(app.CurrentDataset.metadata.sampleName);
                    measurementDate = app.safeStringConvert(app.CurrentDataset.metadata.measurementDate);
                    notes = app.safeStringConvert(app.CurrentDataset.metadata.notes);
                    freqRange = app.safeStringConvert(app.CurrentDataset.metadata.freqRange);
                    
                    reportLines{end+1} = sprintf('Sample Name: %s', sampleName);
                    reportLines{end+1} = sprintf('Measurement Date: %s', measurementDate);
                    reportLines{end+1} = sprintf('Data Points: %d', app.CurrentDataset.metadata.numPoints);
                    reportLines{end+1} = sprintf('Frequency Range: %s', freqRange);
                    reportLines{end+1} = sprintf('Notes: %s', notes);
                    
                    if isfield(app.CurrentDataset.metadata, 'dataSource')
                        dataSource = app.safeStringConvert(app.CurrentDataset.metadata.dataSource);
                        reportLines{end+1} = sprintf('Data Source: %s', dataSource);
                    end
                else
                    reportLines{end+1} = 'No dataset loaded.';
                end
                reportLines{end+1} = '';
                
                % Measurement Parameters
                reportLines{end+1} = '3. MEASUREMENT PARAMETERS';
                reportLines{end+1} = '----------------------------------------';
                if ~isempty(app.FrequencyVector)
                    reportLines{end+1} = sprintf('Start Frequency: %.2f Hz', min(app.FrequencyVector));
                    reportLines{end+1} = sprintf('End Frequency: %.2f Hz', max(app.FrequencyVector));
                    reportLines{end+1} = sprintf('Number of Points: %d', length(app.FrequencyVector));
                    reportLines{end+1} = 'Data Source: ESP32 Firmware';
                else
                    reportLines{end+1} = 'No measurement data available.';
                end
                reportLines{end+1} = '';
                
                % Fitting Results
                reportLines{end+1} = '4. FITTING RESULTS';
                reportLines{end+1} = '----------------------------------------';
                if ~isempty(app.FittedParameters) && ~isempty(app.FitQuality)
                    currentModel = app.safeStringConvert(app.CurrentModel);
                    reportLines{end+1} = sprintf('Circuit Model: %s', currentModel);
                    reportLines{end+1} = sprintf('R-squared: %.6f', app.FitQuality.rsquared);
                    reportLines{end+1} = sprintf('RMSE: %.6e', app.FitQuality.rmse);
                    reportLines{end+1} = sprintf('Chi-squared: %.6e', app.FitQuality.chisquared);
                    reportLines{end+1} = sprintf('Exit Flag: %d', app.FitQuality.exitflag);
                    reportLines{end+1} = '';
                    reportLines{end+1} = 'Fitted Parameters:';
                    
                    % Safe parameter name extraction
                    if ~isempty(app.InitialGuessTable.Data)
                        paramNames = app.InitialGuessTable.Data(:,1);
                        for i = 1:length(app.FittedParameters)
                            paramName = app.safeStringConvert(paramNames{i});
                            reportLines{end+1} = sprintf('  %s: %.6e', paramName, app.FittedParameters(i));
                        end
                    end
                else
                    reportLines{end+1} = 'No fitting results available.';
                end
                reportLines{end+1} = '';
                
                % Dataset History
                if ~isempty(app.DatasetHistory)
                    reportLines{end+1} = '5. DATASET HISTORY';
                    reportLines{end+1} = '----------------------------------------';
                    reportLines{end+1} = sprintf('Total Datasets: %d', length(app.DatasetHistory));
                    for i = 1:min(5, length(app.DatasetHistory))
                        dataset = app.DatasetHistory{i};
                        if isstruct(dataset) && isfield(dataset, 'metadata')
                            filename = app.safeStringConvert(dataset.metadata.filename);
                            measurementDate = app.safeStringConvert(dataset.metadata.measurementDate);
                            reportLines{end+1} = sprintf('  %d. %s (%s)', i, filename, measurementDate);
                        end
                    end
                    if length(app.DatasetHistory) > 5
                        reportLines{end+1} = sprintf('  ... and %d more datasets', length(app.DatasetHistory) - 5);
                    end
                    reportLines{end+1} = '';
                end
                
                % Footer
                reportLines{end+1} = '========================================';
                reportLines{end+1} = 'End of Report';
                reportLines{end+1} = '========================================';
                
            catch ME
                % Fallback in case of any errors
                reportLines = {
                    'Error generating detailed report:';
                    ME.message;
                    '';
                    'Basic Information:';
                    sprintf('App Version: %s', app.Version);
                    sprintf('Generated: %s', string(datetime('now')));
                };
            end
            
            reportContent = reportLines;
        end

        function str = safeStringConvert(app, input)
            % Safely convert various input types to string, handling cell arrays
            if isempty(input)
                str = 'N/A';
            elseif iscell(input)
                % Handle cell arrays
                if isempty(input)
                    str = 'N/A';
                elseif length(input) == 1
                    % Single cell - extract content
                    cellContent = input{1};
                    if ischar(cellContent) || isstring(cellContent)
                        str = char(cellContent);
                    elseif isnumeric(cellContent)
                        str = num2str(cellContent);
                    else
                        str = 'N/A';
                    end
                else
                    % Multiple cells - join them
                    try
                        str = strjoin(cellfun(@char, input, 'UniformOutput', false), ', ');
                    catch
                        str = sprintf('Cell array with %d elements', length(input));
                    end
                end
            elseif isstring(input)
                str = char(input);
            elseif ischar(input)
                str = input;
            elseif isnumeric(input)
                if isscalar(input)
                    str = num2str(input);
                else
                    str = sprintf('Numeric array [%dx%d]', size(input,1), size(input,2));
                end
            elseif isdatetime(input)
                str = char(input);
            elseif islogical(input)
                str = string(input);
            else
                str = sprintf('Unknown type: %s', class(input));
            end
            
            % Ensure output is never empty
            if isempty(str)
                str = 'N/A';
            end
        end

        function ExportReportPDF(app, ~)
            % Export report as PDF
            [filename, pathname] = uiputfile('*.pdf', 'Export Report as PDF');
            if isequal(filename, 0)
                return;
            end
            
            try
                % Create a figure for PDF export
                fig = figure('Visible', 'off', 'Position', [100, 100, 800, 1000]);
                
                % Create text annotation with report content
                reportText = strjoin(app.ReportTextArea.Value, '\n');
                annotation(fig, 'textbox', [0.05, 0.05, 0.9, 0.9], ...
                    'String', reportText, ...
                    'FontName', 'Courier New', ...
                    'FontSize', 10, ...
                    'VerticalAlignment', 'top', ...
                    'HorizontalAlignment', 'left', ...
                    'Interpreter', 'none');
                
                % Export as PDF
                fullpath = fullfile(pathname, filename);
                exportgraphics(fig, fullpath, 'ContentType', 'vector');
                close(fig);
                
                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    sprintf('Report exported as PDF: %s', filename), ...
                    'PDF Export Complete');
                
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Failed to export PDF: %s', ME.message), ...
                    'PDF Export Error');
            end
        end

        function ExportReportExcel(app, ~)
            % Export report as Excel file
            [filename, pathname] = uiputfile('*.xlsx', 'Export Report as Excel');
            if isequal(filename, 0)
                return;
            end
            
            try
                fullpath = fullfile(pathname, filename);
                
                % Create report summary table
                reportTable = table(app.ReportTextArea.Value, 'VariableNames', {'Report_Content'});
                writetable(reportTable, fullpath, 'Sheet', 'Report');
                
                % Add dataset information if available
                if ~isempty(app.CurrentDataset)
                    dataTable = table([app.CurrentDataset.frequency(:), real(app.CurrentDataset.impedance(:)), imag(app.CurrentDataset.impedance(:))], ...
                        'VariableNames', {'Frequency_Hz_Real_Z_Imag_Z'});
                    writetable(dataTable, fullpath, 'Sheet', 'Data');
                end
                
                % Add fitting results if available
                if ~isempty(app.FittedParameters)
                    paramNames = app.InitialGuessTable.Data(:,1);
                    fittingTable = table(paramNames, app.FittedParameters, ...
                        'VariableNames', {'Parameter', 'Value'});
                    writetable(fittingTable, fullpath, 'Sheet', 'Fitting_Results');
                end
                
                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    sprintf('Report exported as Excel: %s', filename), ...
                    'Excel Export Complete');
                
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Failed to export Excel: %s', ME.message), ...
                    'Excel Export Error');
            end
        end


    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)
            % Main orchestrator - calls specialized creation methods
            app.createMainWindow();
            app.createTabGroup();
            app.createAllTabs();
            app.createStatusBar();
            app.finalizeUI();
        end

        function createMainWindow(app)
            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1000 700];
            app.UIFigure.Name = sprintf('%s v%s', app.AppTitle, app.Version);
            % app.UIFigure.Icon = 'icon_eis.png'; % Optional: add custom icon
        end

        function createTabGroup(app)
            % Create main TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [20 60 960 620];
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);
        end

        function createAllTabs(app)
            app.createDatasetTabContainer();
            app.createLivePlotTabContainer();
            app.createFittingTabContainer();
            app.createReportTabContainer();
        end
        
        function createDatasetTabContainer(app)
            % Create Dataset Tab
            app.DatasetTab = uitab(app.TabGroup);
            app.DatasetTab.Title = 'Dataset';
            app.DatasetTab.BackgroundColor = [0.94 0.94 0.94];
            
            % Create the detailed dataset interface
            app.createDatasetTab();
        end

        function createLivePlotTabContainer(app)
            app.LivePlotTab = uitab(app.TabGroup);
            app.LivePlotTab.Title = 'Live Plot';
            app.LivePlotTab.BackgroundColor = [0.94 0.94 0.94];
            
            % Create the detailed live plot interface
            app.createLivePlotTab();
         end

        function createFittingTabContainer(app)
            % Create Fitting Tab
            app.FittingTab = uitab(app.TabGroup);
            app.FittingTab.Title = 'Fitting';
            app.FittingTab.BackgroundColor = [0.94 0.94 0.94];
                
            % Create the detailed fitting interface
            app.createFittingTab();
        end

        function createStatusBar(app)
            % Create Status Panel at bottom
            app.StatusPanel = uipanel(app.UIFigure);
            app.StatusPanel.Position = [20 10 960 40];
            app.StatusPanel.BorderType = 'line';
            app.StatusPanel.BackgroundColor = [0.96 0.96 0.96];

            % Create Status Label
            app.StatusLabel = uilabel(app.StatusPanel);
            app.StatusLabel.Position = [40 8 400 22];
            app.StatusLabel.Text = 'Initializing...';
            app.StatusLabel.FontSize = 12;

            % Create Status Lamp
            app.StatusLamp = uilamp(app.StatusPanel);
            app.StatusLamp.Position = [10 10 18 18];
            app.StatusLamp.Color = [0.8 0.8 0.8];
        end

        function createReportTabContainer(app)
            % Create Report Tab
            app.ReportTab = uitab(app.TabGroup);
            app.ReportTab.Title = 'Report';
            app.ReportTab.BackgroundColor = [0.94 0.94 0.94];
            
            % Create the detailed report interface
            app.createReportTab();
        end


        function finalizeUI(app)
            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end

    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = EISApp

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
