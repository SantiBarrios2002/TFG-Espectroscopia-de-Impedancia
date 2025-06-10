classdef EISApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure          matlab.ui.Figure
        TabGroup          matlab.ui.container.TabGroup
        ConnectionTab     matlab.ui.container.Tab
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
        % Connection properties
        SerialConnection
        WiFiConnection
        ConnectionType = "None"
        IsConnected = false
        
        % Connection UI components
        ConnectionModeDropDown    matlab.ui.control.DropDown
        USBPortDropDown          matlab.ui.control.DropDown
        WiFiIPEditField          matlab.ui.control.EditField
        ConnectButton            matlab.ui.control.Button
        DisconnectButton         matlab.ui.control.Button
        RefreshPortsButton       matlab.ui.control.Button
        ConnectionStatusLabel    matlab.ui.control.Label
        ConnectionIndicatorLamp  matlab.ui.control.Lamp    

        % Live Plot UI components
        StartMeasurementButton    matlab.ui.control.Button
        StopMeasurementButton     matlab.ui.control.Button
        ClearPlotsButton         matlab.ui.control.Button
        FreqStartEditField       matlab.ui.control.NumericEditField
        FreqEndEditField         matlab.ui.control.NumericEditField
        NumPointsEditField       matlab.ui.control.NumericEditField
        
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
        LivePlotStatusLabel     matlab.ui.control.Label

        % Data source control
        UseSimulatedDataCheckBox matlab.ui.control.CheckBox
        DataSourceStatusLabel matlab.ui.control.Label

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
        FittingStatusLabel      matlab.ui.control.Label
        ExportFitButton         matlab.ui.control.Button
        
        % Fitting data and results
        FittingResults          struct
        CurrentModel            char = 'Randles'
        FittedParameters        double
        FitQuality              struct
      
        ZfitCircuitStrings    cell = {'s(R1,p(R1,C1))', 's(p(R1,C1),R1)', 's(R1,C1)'}
        ZfitCircuitNames      cell = {'Randles Circuit', 'RC Circuit', 'Warburg Element'}
        
        % Report Tab components
        ReportTab                matlab.ui.container.Tab
        ReportTextArea          matlab.ui.control.TextArea
        GenerateReportButton    matlab.ui.control.Button
        ExportReportPDFButton   matlab.ui.control.Button
        ExportReportExcelButton matlab.ui.control.Button
        ExportLivePlotButton    matlab.ui.control.Button 
        ExportFittingPlotButton matlab.ui.control.Button
        ReportStatusLabel       matlab.ui.control.Label
    

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

        function ConnectionModeChanged(app, ~)
            % Toggle visibility of connection panels
            panels = app.ConnectionTab.UserData;
            
            if strcmp(app.ConnectionModeDropDown.Value, 'USB Serial')
                panels.USBPanel.Visible = 'on';
                panels.WiFiPanel.Visible = 'off';
                app.ConnectionType = "USB";
            else
                panels.USBPanel.Visible = 'off';
                panels.WiFiPanel.Visible = 'on';
                app.ConnectionType = "WiFi";
            end
            
            % Reset connection status
            app.updateConnectionStatus(false, 'Connection mode changed');
        end
        
        function RefreshUSBPorts(app, ~)
            % Scan for available serial ports
            try
                ports = serialportlist("available");
                if isempty(ports)
                    app.USBPortDropDown.Items = {'No ports found'};
                    app.USBPortDropDown.Enable = 'off';
                else
                    app.USBPortDropDown.Items = ports;
                    app.USBPortDropDown.Enable = 'on';
                    if isscalar(ports)
                        app.USBPortDropDown.Value = ports(1);
                    end
                end
                app.ConnectionStatusLabel.Text = sprintf('Found %d available ports', length(ports));
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Error scanning ports: %s', ME.message), ...
                    'Port Scan Error');
                app.USBPortDropDown.Items = {'Error scanning'};
                app.USBPortDropDown.Enable = 'off';
            end
        end
        
        function ConnectToESP32(app, ~)
            % Attempt connection based on selected mode
            try
                if strcmp(app.ConnectionType, "USB")
                    app.connectUSB();
                elseif strcmp(app.ConnectionType, "WiFi")
                    app.connectWiFi();
                else
                    error('No connection mode selected');
                end
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Connection failed: %s', ME.message), ...
                    'Connection Error');
                app.updateConnectionStatus(false, sprintf('Connection failed: %s', ME.message));
            end
        end
        
        function DisconnectFromESP32(app, ~)
            % Disconnect from ESP32
            try
                if app.IsConnected
                    if strcmp(app.ConnectionType, "USB") && ~isempty(app.SerialConnection)
                        delete(app.SerialConnection);
                        app.SerialConnection = [];
                    elseif strcmp(app.ConnectionType, "WiFi") && ~isempty(app.WiFiConnection)
                        delete(app.WiFiConnection);
                        app.WiFiConnection = [];
                    end
                end
                
                app.updateConnectionStatus(false, 'Disconnected successfully');
                EISAppUtils.showSuccessAlert(app.UIFigure, 'Disconnected from ESP32', 'Disconnected');
                
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Disconnect error: %s', ME.message), ...
                    'Disconnect Error');
            end
        end
    
        function createConnectionTab(app)
            % Clear existing content
            delete(app.ConnectionTab.Children);
            
            % Main title
            titleLabel = uilabel(app.ConnectionTab);
            titleLabel.Position = [30 550 400 30];
            titleLabel.Text = '🌐 ESP32 Connection Interface';
            titleLabel.FontSize = 18;
            titleLabel.FontWeight = 'bold';
            
            % Connection mode selection
            modeLabel = uilabel(app.ConnectionTab);
            modeLabel.Position = [30 500 150 22];
            modeLabel.Text = 'Connection Mode:';
            modeLabel.FontWeight = 'bold';
            
            app.ConnectionModeDropDown = uidropdown(app.ConnectionTab);
            app.ConnectionModeDropDown.Position = [180 500 150 22];
            app.ConnectionModeDropDown.Items = {'USB Serial', 'Wi-Fi'};
            app.ConnectionModeDropDown.Value = 'USB Serial';
            app.ConnectionModeDropDown.ValueChangedFcn = createCallbackFcn(app, @ConnectionModeChanged, true);
            
            % USB Serial Panel
            usbPanel = uipanel(app.ConnectionTab);
            usbPanel.Position = [30 350 400 120];
            usbPanel.Title = 'USB Serial Configuration';
            usbPanel.FontWeight = 'bold';
            
            portLabel = uilabel(usbPanel);
            portLabel.Position = [20 70 80 22];
            portLabel.Text = 'COM Port:';
            
            app.USBPortDropDown = uidropdown(usbPanel);
            app.USBPortDropDown.Position = [100 70 150 22];
            app.USBPortDropDown.Items = {'Scanning...'};
            
            app.RefreshPortsButton = uibutton(usbPanel, 'push');
            app.RefreshPortsButton.Position = [270 70 80 22];
            app.RefreshPortsButton.Text = 'Refresh';
            app.RefreshPortsButton.ButtonPushedFcn = createCallbackFcn(app, @RefreshUSBPorts, true);
            
            baudLabel = uilabel(usbPanel);
            baudLabel.Position = [20 40 80 22];
            baudLabel.Text = 'Baud Rate:';
            
            baudValue = uilabel(usbPanel);
            baudValue.Position = [100 40 100 22];
            baudValue.Text = '115200';
            baudValue.FontWeight = 'bold';
            
            % Wi-Fi Panel
            wifiPanel = uipanel(app.ConnectionTab);
            wifiPanel.Position = [450 350 400 120];
            wifiPanel.Title = 'Wi-Fi Configuration';
            wifiPanel.FontWeight = 'bold';
            wifiPanel.Visible = 'off';
            
            ipLabel = uilabel(wifiPanel);
            ipLabel.Position = [20 70 80 22];
            ipLabel.Text = 'IP Address:';
            
            app.WiFiIPEditField = uieditfield(wifiPanel, 'text');
            app.WiFiIPEditField.Position = [100 70 150 22];
            app.WiFiIPEditField.Value = '192.168.1.100';
            app.WiFiIPEditField.Placeholder = 'e.g., 192.168.1.100';
            
            portLabel2 = uilabel(wifiPanel);
            portLabel2.Position = [20 40 80 22];
            portLabel2.Text = 'Port:';
            
            portValue = uilabel(wifiPanel);
            portValue.Position = [100 40 100 22];
            portValue.Text = '8080';
            portValue.FontWeight = 'bold';
            
            % Connection buttons
            app.ConnectButton = uibutton(app.ConnectionTab, 'push');
            app.ConnectButton.Position = [30 280 100 30];
            app.ConnectButton.Text = 'Connect';
            app.ConnectButton.FontSize = 14;
            app.ConnectButton.FontWeight = 'bold';
            app.ConnectButton.BackgroundColor = [0.2 0.7 0.2];
            app.ConnectButton.FontColor = [1 1 1];
            app.ConnectButton.ButtonPushedFcn = createCallbackFcn(app, @ConnectToESP32, true);
            
            app.DisconnectButton = uibutton(app.ConnectionTab, 'push');
            app.DisconnectButton.Position = [150 280 100 30];
            app.DisconnectButton.Text = 'Disconnect';
            app.DisconnectButton.FontSize = 14;
            app.DisconnectButton.BackgroundColor = [0.8 0.2 0.2];
            app.DisconnectButton.FontColor = [1 1 1];
            app.DisconnectButton.Enable = 'off';
            app.DisconnectButton.ButtonPushedFcn = createCallbackFcn(app, @DisconnectFromESP32, true);
            
            % Connection status
            statusPanel = uipanel(app.ConnectionTab);
            statusPanel.Position = [30 180 820 80];
            statusPanel.Title = 'Connection Status';
            statusPanel.FontWeight = 'bold';
            
            app.ConnectionIndicatorLamp = uilamp(statusPanel);
            app.ConnectionIndicatorLamp.Position = [20 30 20 20];
            app.ConnectionIndicatorLamp.Color = [0.8 0.8 0.8];
            
            app.ConnectionStatusLabel = uilabel(statusPanel);
            app.ConnectionStatusLabel.Position = [60 25 700 30];
            app.ConnectionStatusLabel.Text = 'Not Connected - Select connection mode and click Connect';
            app.ConnectionStatusLabel.FontSize = 12;
            
            % Store panel references for visibility control
            app.ConnectionTab.UserData = struct('USBPanel', usbPanel, 'WiFiPanel', wifiPanel);
            
            % Initialize USB ports
            app.RefreshUSBPorts();
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
            
            % Data Source Panel
            dataSourcePanel = uipanel(app.LivePlotTab);
            dataSourcePanel.Position = [30 530 900 50];
            dataSourcePanel.Title = 'Data Source';
            dataSourcePanel.FontWeight = 'bold';
            
            app.UseSimulatedDataCheckBox = uicheckbox(dataSourcePanel);
            app.UseSimulatedDataCheckBox.Position = [20 10 200 22];
            app.UseSimulatedDataCheckBox.Text = 'Use Simulated Data';
            app.UseSimulatedDataCheckBox.Value = false;
            app.UseSimulatedDataCheckBox.ValueChangedFcn = createCallbackFcn(app, @DataSourceChanged, true);
            
            app.DataSourceStatusLabel = uilabel(dataSourcePanel);
            app.DataSourceStatusLabel.Position = [240 10 620 22];
            app.DataSourceStatusLabel.Text = 'No ESP32 connection - Please connect hardware or enable simulated data';
            app.DataSourceStatusLabel.FontColor = [0.8 0.2 0.2];
            
            % Control Panel
            controlPanel = uipanel(app.LivePlotTab);
            controlPanel.Position = [30 440 900 80]; 
            controlPanel.Title = 'Measurement Controls';
            controlPanel.FontWeight = 'bold';
            
            % Frequency range controls
            freqLabel = uilabel(controlPanel);
            freqLabel.Position = [20 40 120 22];
            freqLabel.Text = 'Frequency Range:';
            freqLabel.FontWeight = 'bold';
            
            % First row of controls
            startLabel = uilabel(controlPanel);
            startLabel.Position = [20 20 60 22];
            startLabel.Text = 'Start (Hz):';
            
            app.FreqStartEditField = uieditfield(controlPanel, 'numeric');
            app.FreqStartEditField.Position = [85 20 80 22];
            app.FreqStartEditField.Value = 1;
            app.FreqStartEditField.Limits = [0.001 1000000];
            
            endLabel = uilabel(controlPanel);
            endLabel.Position = [180 20 60 22];
            endLabel.Text = 'End (Hz):';
            
            app.FreqEndEditField = uieditfield(controlPanel, 'numeric');
            app.FreqEndEditField.Position = [245 20 80 22];
            app.FreqEndEditField.Value = 100000;
            app.FreqEndEditField.Limits = [0.001 1000000];
            
            pointsLabel = uilabel(controlPanel);
            pointsLabel.Position = [340 20 50 22];
            pointsLabel.Text = 'Points:';
            
            app.NumPointsEditField = uieditfield(controlPanel, 'numeric');
            app.NumPointsEditField.Position = [395 20 60 22];
            app.NumPointsEditField.Value = 50;
            app.NumPointsEditField.Limits = [10 200];
            
            % Control buttons - PROPERLY SPACED
            app.StartMeasurementButton = uibutton(controlPanel, 'push');
            app.StartMeasurementButton.Position = [480 20 120 30];
            app.StartMeasurementButton.Text = 'Start Measurement';
            app.StartMeasurementButton.FontWeight = 'bold';
            app.StartMeasurementButton.BackgroundColor = [0.2 0.7 0.2];
            app.StartMeasurementButton.FontColor = [1 1 1];
            app.StartMeasurementButton.ButtonPushedFcn = createCallbackFcn(app, @StartMeasurement, true);
            
            app.StopMeasurementButton = uibutton(controlPanel, 'push');
            app.StopMeasurementButton.Position = [620 20 80 30];
            app.StopMeasurementButton.Text = 'Stop';
            app.StopMeasurementButton.BackgroundColor = [0.8 0.2 0.2];
            app.StopMeasurementButton.FontColor = [1 1 1];
            app.StopMeasurementButton.Enable = 'off';
            app.StopMeasurementButton.ButtonPushedFcn = createCallbackFcn(app, @StopMeasurement, true);
            
            app.ClearPlotsButton = uibutton(controlPanel, 'push');
            app.ClearPlotsButton.Position = [720 20 80 30];
            app.ClearPlotsButton.Text = 'Clear Plots';
            app.ClearPlotsButton.ButtonPushedFcn = createCallbackFcn(app, @ClearPlots, true);
            
            % Create plot panels with adjusted positions
            app.createPlotPanels();
            
            % Initialize timer and update status
            app.MeasurementTimer = timer('ExecutionMode', 'fixedRate', ...
                                        'Period', 0.5, ...
                                        'TimerFcn', @(~,~) app.updateMeasurement());
            
            % Export Plot Button for Live Plot
            app.ExportLivePlotButton = uibutton(app.LivePlotTab, 'push');
            app.ExportLivePlotButton.Position = [860 440 60 30];
            app.ExportLivePlotButton.Text = 'Export Plot';
            app.ExportLivePlotButton.ButtonPushedFcn = createCallbackFcn(app, @ExportLivePlots, true);

            app.updateDataSourceStatus();
        end

        function createPlotPanels(app)
            % Nyquist Plot Panel - Made larger
            nyquistPanel = uipanel(app.LivePlotTab);
            nyquistPanel.Position = [30 150 450 280];  
            nyquistPanel.Title = 'Nyquist Plot (Re(Z) vs -Im(Z))';
            nyquistPanel.FontWeight = 'bold';
            
            app.NyquistAxes = uiaxes(nyquistPanel);
            app.NyquistAxes.Position = [20 20 410 240];  
            app.NyquistAxes.XLabel.String = 'Real Part (Ω)';
            app.NyquistAxes.YLabel.String = '-Imaginary Part (Ω)';
            app.NyquistAxes.Title.String = '';
            grid(app.NyquistAxes, 'on');
            axis(app.NyquistAxes, 'equal');
            
            % Bode Magnitude Plot Panel - Made larger
            bodeMagPanel = uipanel(app.LivePlotTab);
            bodeMagPanel.Position = [500 280 450 150]; 
            bodeMagPanel.Title = 'Bode Plot - Magnitude';
            bodeMagPanel.FontWeight = 'bold';
            
            app.BodeMagAxes = uiaxes(bodeMagPanel);
            app.BodeMagAxes.Position = [20 20 410 110]; 
            app.BodeMagAxes.XLabel.String = 'Frequency (Hz)';
            app.BodeMagAxes.YLabel.String = '|Z| (Ω)';
            app.BodeMagAxes.XScale = 'log';
            app.BodeMagAxes.YScale = 'log';
            app.BodeMagAxes.Title.String = '';
            grid(app.BodeMagAxes, 'on');
            
            % Bode Phase Plot Panel - Made larger
            bodePhasePanel = uipanel(app.LivePlotTab);
            bodePhasePanel.Position = [500 150 450 150];  
            bodePhasePanel.Title = 'Bode Plot - Phase';
            bodePhasePanel.FontWeight = 'bold';
            
            app.BodePhaseAxes = uiaxes(bodePhasePanel);
            app.BodePhaseAxes.Position = [20 20 410 110];  
            app.BodePhaseAxes.XLabel.String = 'Frequency (Hz)';
            app.BodePhaseAxes.YLabel.String = 'Phase (°)';
            app.BodePhaseAxes.XScale = 'log';
            app.BodePhaseAxes.Title.String = '';
            grid(app.BodePhaseAxes, 'on');
            
            % Status display 
            statusPanel = uipanel(app.LivePlotTab);
            statusPanel.Position = [30 80 920 60];  
            statusPanel.Title = 'Measurement Status';
            statusPanel.FontWeight = 'bold';
            
            app.LivePlotStatusLabel = uilabel(statusPanel);
            app.LivePlotStatusLabel.Position = [20 20 860 22];  % Made wider
            app.LivePlotStatusLabel.Text = 'Ready to start measurement';
            app.LivePlotStatusLabel.FontSize = 12;
        end

        function StartMeasurement(app, ~)
            % Check for valid data source before starting
            if ~app.IsConnected && ~app.UseSimulatedDataCheckBox.Value
                EISAppUtils.showWarningAlert(app.UIFigure, ...
                    ['No valid data source available. Please either:' newline ...
                     '• Connect to ESP32 hardware, or' newline ...
                     '• Enable "Use Simulated Data" option for testing'], ...
                    'No Data Source');
                return;
            end
            
            try
                % Prepare frequency vector
                app.FrequencyVector = logspace(log10(app.FreqStartEditField.Value), ...
                                             log10(app.FreqEndEditField.Value), ...
                                             app.NumPointsEditField.Value);
                
                % Initialize data storage
                app.ImpedanceData = complex(zeros(size(app.FrequencyVector)));
                app.CurrentFrequencyIndex = 1;
                app.IsRunningMeasurement = true;
                
                % Update UI
                app.StartMeasurementButton.Enable = 'off';
                app.StopMeasurementButton.Enable = 'on';
                app.FreqStartEditField.Enable = 'off';
                app.FreqEndEditField.Enable = 'off';
                app.NumPointsEditField.Enable = 'off';
                app.UseSimulatedDataCheckBox.Enable = 'off'; % Lock during measurement
                
                % Determine data source for status message
                if app.IsConnected && ~app.UseSimulatedDataCheckBox.Value
                    dataSource = 'ESP32 hardware';
                else
                    dataSource = 'simulated data';
                end
                
                app.LivePlotStatusLabel.Text = sprintf('Starting measurement using %s: %d points from %.2f Hz to %.2f Hz', ...
                    dataSource, length(app.FrequencyVector), app.FrequencyVector(1), app.FrequencyVector(end));
                
                % Start timer for measurements
                start(app.MeasurementTimer);
                
                % Clear previous plots
                app.ClearPlots();
                
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Failed to start measurement: %s', ME.message), ...
                    'Measurement Error');
                app.resetMeasurementUI();
            end
        end

        function StopMeasurement(app, ~)
            % Stop EIS measurement
            if isvalid(app.MeasurementTimer)
                stop(app.MeasurementTimer);
            end
            
            app.IsRunningMeasurement = false;
            app.resetMeasurementUI();
            app.LivePlotStatusLabel.Text = sprintf('Measurement stopped at point %d of %d', ...
                app.CurrentFrequencyIndex-1, length(app.FrequencyVector));
        end

        function ClearPlots(app, ~)
            % Clear all plots
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
            
            app.LivePlotStatusLabel.Text = 'Plots cleared';
        end

        function updateMeasurement(app)
            % Update measurement progress and acquire data
            if ~app.IsRunningMeasurement || app.CurrentFrequencyIndex > length(app.FrequencyVector)
                app.StopMeasurement();
                return;
            end
            
            try
                % Get current frequency
                currentFreq = app.FrequencyVector(app.CurrentFrequencyIndex);
                
                % Determine data source based on connection and user preference
                if app.IsConnected && ~app.UseSimulatedDataCheckBox.Value
                    % Use real ESP32 data
                    impedanceValue = app.getEISDataFromESP32(currentFreq);
                    dataSource = 'ESP32';
                else
                    % Use simulated data (either by choice or necessity)
                    impedanceValue = app.generateSimulatedEISData(currentFreq);
                    dataSource = 'simulated';
                end
                
                % Store data
                app.ImpedanceData(app.CurrentFrequencyIndex) = impedanceValue;
                
                % Update plots
                app.updateEISPlots();
                
                % Update status with data source info
                app.LivePlotStatusLabel.Text = sprintf('Measuring (%s): Point %d/%d (%.2f Hz)', ...
                    dataSource, app.CurrentFrequencyIndex, length(app.FrequencyVector), currentFreq);
                
                % Move to next frequency
                app.CurrentFrequencyIndex = app.CurrentFrequencyIndex + 1;
                
                % Check if measurement is complete
                if app.CurrentFrequencyIndex > length(app.FrequencyVector)
                    app.StopMeasurement();
                    app.saveCurrentMeasurement();
                    app.LivePlotStatusLabel.Text = sprintf('Measurement completed successfully using %s data!', dataSource);
                    EISAppUtils.showSuccessAlert(app.UIFigure, ...
                        sprintf('EIS measurement completed successfully using %s data', dataSource), ...
                        'Measurement Complete');
                end
                
            catch ME
                app.StopMeasurement();
                EISAppUtils.showErrorAlert(app.UIFigure, ...
                    sprintf('Measurement error: %s', ME.message), ...
                    'Measurement Error');
            end
        end

        function DataSourceChanged(app, ~)
            % Handle data source checkbox change
            app.updateDataSourceStatus();
        end

        function updateDataSourceStatus(app)
            % Update data source status display
            if app.IsConnected
                % ESP32 is connected
                app.DataSourceStatusLabel.Text = 'ESP32 Connected - Using real hardware data';
                app.DataSourceStatusLabel.FontColor = [0.2 0.8 0.2]; % Green
                app.UseSimulatedDataCheckBox.Enable = 'on';
                app.UseSimulatedDataCheckBox.Value = false; % Prefer real data when available
            else
                % No ESP32 connection
                if app.UseSimulatedDataCheckBox.Value
                    app.DataSourceStatusLabel.Text = 'No ESP32 connection - Using simulated data for testing';
                    app.DataSourceStatusLabel.FontColor = [0.8 0.6 0.2]; % Orange
                else
                    app.DataSourceStatusLabel.Text = 'No ESP32 connection - Please connect hardware or enable simulated data';
                    app.DataSourceStatusLabel.FontColor = [0.8 0.2 0.2]; % Red
                end
                app.UseSimulatedDataCheckBox.Enable = 'on';
            end
        end
    
        function impedance = generateSimulatedEISData(app, frequency)
            % Generate simulated EIS data using Randles circuit model
            % Parameters for simulation
            Rs = 0.1;      % Solution resistance (Ohms)
            Rct = 0.5;     % Charge transfer resistance (Ohms)
            Cdl = 1e-3;    % Double layer capacitance (F)
            sigma = 0.02;  % Warburg coefficient
            
            % Angular frequency
            omega = 2 * pi * frequency;
            
            % Warburg impedance (simplified)
            Zw = sigma / sqrt(omega) * (1 - 1i);
            
            % Double layer capacitance impedance
            Zcap = 1 / (1i * omega * Cdl);
            
            % Parallel combination of Rct and Cdl
            Zparallel = (Rct * Zcap) / (Rct + Zcap);
            
            % Total impedance: Rs + (Rct || Cdl) + Zw
            impedance = Rs + Zparallel + Zw;
            
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
        
        function resetMeasurementUI(app)
            % Reset UI after measurement stops
            app.StartMeasurementButton.Enable = 'on';
            app.StopMeasurementButton.Enable = 'off';
            app.FreqStartEditField.Enable = 'on';
            app.FreqEndEditField.Enable = 'on';
            app.NumPointsEditField.Enable = 'on';
            app.UseSimulatedDataCheckBox.Enable = 'on'; % Re-enable after measurement
            app.IsRunningMeasurement = false;
            
            % Update data source status
            app.updateDataSourceStatus();
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
            
            % Dataset Table Panel
            tablePanel = uipanel(app.DatasetTab);
            tablePanel.Position = [30 280 900 210];
            tablePanel.Title = 'Dataset History';
            tablePanel.FontWeight = 'bold';
            
            app.DatasetTable = uitable(tablePanel);
            app.DatasetTable.Position = [20 20 860 170];
            app.DatasetTable.ColumnName = {'Filename', 'Date', 'Points', 'Freq Range', 'Sample Name', 'Notes'};
            app.DatasetTable.ColumnWidth = {150, 120, 60, 100, 120, 200};
            app.DatasetTable.ColumnEditable = [false false false false true true];
            app.DatasetTable.CellSelectionCallback = createCallbackFcn(app, @DatasetTableSelection, true);
            app.DatasetTable.CellEditCallback = createCallbackFcn(app, @DatasetTableEdit, true);
            
            % Metadata Panel
            metadataPanel = uipanel(app.DatasetTab);
            metadataPanel.Position = [30 120 900 150];
            metadataPanel.Title = 'Sample Metadata';
            metadataPanel.FontWeight = 'bold';
            
            % Sample name
            nameLabel = uilabel(metadataPanel);
            nameLabel.Position = [20 100 100 22];
            nameLabel.Text = 'Sample Name:';
            nameLabel.FontWeight = 'bold';
            
            app.SampleNameEditField = uieditfield(metadataPanel, 'text');
            app.SampleNameEditField.Position = [130 100 200 22];
            app.SampleNameEditField.Placeholder = 'Enter sample name';
            app.SampleNameEditField.ValueChangedFcn = createCallbackFcn(app, @UpdateMetadata, true);
            
            % Date and time (auto-filled)
            dateLabel = uilabel(metadataPanel);
            dateLabel.Position = [350 100 80 22];
            dateLabel.Text = 'Date/Time:';
            dateLabel.FontWeight = 'bold';
            
            dateValue = uilabel(metadataPanel);
            dateValue.Position = [440 100 150 22];
            dateValue.Text = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'));
            
            % Notes
            notesLabel = uilabel(metadataPanel);
            notesLabel.Position = [20 70 100 22];
            notesLabel.Text = 'Notes:';
            notesLabel.FontWeight = 'bold';
            
            app.SampleNotesTextArea = uitextarea(metadataPanel);
            app.SampleNotesTextArea.Position = [20 20 560 45];
            app.SampleNotesTextArea.Placeholder = 'Enter measurement notes, conditions, or observations...';
            app.SampleNotesTextArea.ValueChangedFcn = createCallbackFcn(app, @UpdateMetadata, true);
            
            % Quick metadata buttons
            quickLabel = uilabel(metadataPanel);
            quickLabel.Position = [600 100 100 22];
            quickLabel.Text = 'Quick Tags:';
            quickLabel.FontWeight = 'bold';
            
            tempButton = uibutton(metadataPanel, 'push');
            tempButton.Position = [600 70 80 25];
            tempButton.Text = 'Add Temp';
            tempButton.ButtonPushedFcn = @(~,~) app.addQuickTag('Temperature: °C');
            
            socButton = uibutton(metadataPanel, 'push');
            socButton.Position = [690 70 80 25];
            socButton.Text = 'Add SOC';
            socButton.ButtonPushedFcn = @(~,~) app.addQuickTag('SOC: %');
            
            cycleButton = uibutton(metadataPanel, 'push');
            cycleButton.Position = [780 70 80 25];
            cycleButton.Text = 'Add Cycle';
            cycleButton.ButtonPushedFcn = @(~,~) app.addQuickTag('Cycle: ');
            
            % Status Panel
            statusPanel = uipanel(app.DatasetTab);
            statusPanel.Position = [30 50 900 60];
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
            if app.UseSimulatedDataCheckBox.Value
                dataset.metadata.dataSource = 'Simulated';
            else
                dataset.metadata.dataSource = 'ESP32';
            end

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
            modelPanel.Position = [30 520 900 50];
            modelPanel.Title = 'Circuit Model Selection';
            modelPanel.FontWeight = 'bold';
            
            modelLabel = uilabel(modelPanel);
            modelLabel.Position = [20 15 100 22];
            modelLabel.Text = 'Select Model:';
            modelLabel.FontWeight = 'bold';
            
            app.ModelDropDown = uidropdown(modelPanel);
            app.ModelDropDown.Position = [130 15 150 22];
            app.ModelDropDown.Items = {'Randles Circuit', 'RC Circuit', 'Warburg Element'};
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
            plotsPanel.Position = [30 120 900 220];
            plotsPanel.Title = 'Fit Visualization';
            plotsPanel.FontWeight = 'bold';
            
            % Fitting plot (Nyquist with overlay)
            app.FittingAxes = uiaxes(plotsPanel);
            app.FittingAxes.Position = [20 20 420 180];
            app.FittingAxes.XLabel.String = 'Real Part (Ω)';
            app.FittingAxes.YLabel.String = '-Imaginary Part (Ω)';
            app.FittingAxes.Title.String = 'Measured vs Fitted Data';
            grid(app.FittingAxes, 'on');
            
            % Residuals plot
            app.ResidualsAxes = uiaxes(plotsPanel);
            app.ResidualsAxes.Position = [460 20 420 180];
            app.ResidualsAxes.XLabel.String = 'Frequency (Hz)';
            app.ResidualsAxes.YLabel.String = 'Residuals (%)';
            app.ResidualsAxes.Title.String = 'Fitting Residuals';
            app.ResidualsAxes.XScale = 'log';
            grid(app.ResidualsAxes, 'on');
            
            % Status Panel
            statusPanel = uipanel(app.FittingTab);
            statusPanel.Position = [30 50 900 60];
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
        end

        function ModelChanged(app, ~)
            % Handle model selection change
            app.CurrentModel = app.ModelDropDown.Value;
            app.updateParameterTable();
            app.FittingStatusLabel.Text = sprintf('Model changed to: %s', app.CurrentModel);
        end

        function updateParameterTable(app)
            % Update parameter table based on selected model using Zfit notation
            selectedIndex = find(strcmp(app.ModelDropDown.Value, app.ZfitCircuitNames));
            
            switch selectedIndex
                case 1 % Randles Circuit: s(R1,p(R1,C1)) - 3 parameters
                    paramData = {
                        'Rs', 'Rs', 100, 'Ω';
                        'Rct', 'Rct', 1000, 'Ω';
                        'Cdl', 'Cdl', 1e-6, 'F'
                    };
                case 2 % RC Circuit: s(p(R1,C1),R1) - 3 parameters  
                    paramData = {
                        'R1', 'R1', 100, 'Ω';
                        'C1', 'C1', 1e-6, 'F';
                        'R2', 'R2', 1000, 'Ω'
                    };
                case 3 % Warburg Element: s(R1,C1) - 2 parameters
                    paramData = {
                        'Rs', 'Rs', 100, 'Ω';
                        'C1', 'C1', 1e-6, 'F'
                    };
                otherwise % Default case
                    paramData = {
                        'Rs', 'Rs', 100, 'Ω';
                        'Rct', 'Rct', 1000, 'Ω';
                        'Cdl', 'Cdl', 1e-6, 'F'
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
            realFields = fieldNames(contains(lower(fieldNames), {'real', 'zr', 'zreal'}));
            imagFields = fieldNames(contains(lower(fieldNames), {'imag', 'zi', 'zimag'}));
            
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
            contentPanel.Position = [30 120 900 390];
            contentPanel.Title = 'Report Content';
            contentPanel.FontWeight = 'bold';
            
            app.ReportTextArea = uitextarea(contentPanel);
            app.ReportTextArea.Position = [20 20 860 350];
            app.ReportTextArea.Editable = 'off';
            app.ReportTextArea.Value = {'Click "Generate Report" to create a comprehensive EIS analysis summary.'};
            app.ReportTextArea.FontName = 'Courier New';
            app.ReportTextArea.FontSize = 11;
            
            % Status Panel
            statusPanel = uipanel(app.ReportTab);
            statusPanel.Position = [30 50 900 60];
            statusPanel.Title = 'Report Status';
            statusPanel.FontWeight = 'bold';
            
            app.ReportStatusLabel = uilabel(statusPanel);
            app.ReportStatusLabel.Position = [20 20 860 22];
            app.ReportStatusLabel.Text = 'Ready to generate report. Ensure you have measurement data and fitting results.';
            app.ReportStatusLabel.FontSize = 12;
        end

        function GenerateReport(app, ~)
            % Generate comprehensive EIS analysis report
            try
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

        function reportContent = compileReportContent(app)
            % Compile comprehensive report content
            reportLines = {};
            
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
                reportLines{end+1} = sprintf('ESP32 Status: Connected (%s)', app.ConnectionType);
            else
                reportLines{end+1} = 'ESP32 Status: Not Connected';
            end
            reportLines{end+1} = '';
            
            % Dataset Information
            reportLines{end+1} = '2. DATASET INFORMATION';
            reportLines{end+1} = '----------------------------------------';
            if ~isempty(app.CurrentDataset)
                reportLines{end+1} = sprintf('Sample Name: %s', app.CurrentDataset.metadata.sampleName);
                reportLines{end+1} = sprintf('Measurement Date: %s', app.CurrentDataset.metadata.measurementDate);
                reportLines{end+1} = sprintf('Data Points: %d', app.CurrentDataset.metadata.numPoints);
                reportLines{end+1} = sprintf('Frequency Range: %s', app.CurrentDataset.metadata.freqRange);
                reportLines{end+1} = sprintf('Notes: %s', app.CurrentDataset.metadata.notes);
                if isfield(app.CurrentDataset.metadata, 'dataSource')
                    reportLines{end+1} = sprintf('Data Source: %s', app.CurrentDataset.metadata.dataSource);
                end
            else
                reportLines{end+1} = 'No dataset loaded.';
            end
            reportLines{end+1} = '';
            
            % Measurement Parameters
            if app.IsRunningMeasurement || ~isempty(app.FrequencyVector)
                reportLines{end+1} = '3. MEASUREMENT PARAMETERS';
                reportLines{end+1} = '----------------------------------------';
                reportLines{end+1} = sprintf('Start Frequency: %.2f Hz', app.FreqStartEditField.Value);
                reportLines{end+1} = sprintf('End Frequency: %.2f Hz', app.FreqEndEditField.Value);
                reportLines{end+1} = sprintf('Number of Points: %d', app.NumPointsEditField.Value);
                reportLines{end+1} = sprintf('Simulated Data: %s', string(app.UseSimulatedDataCheckBox.Value));
                reportLines{end+1} = '';
            end
            
            % Fitting Results
            reportLines{end+1} = '4. FITTING RESULTS';
            reportLines{end+1} = '----------------------------------------';
            if ~isempty(app.FittedParameters)
                reportLines{end+1} = sprintf('Circuit Model: %s', app.CurrentModel);
                reportLines{end+1} = sprintf('R-squared: %.6f', app.FitQuality.rsquared);
                reportLines{end+1} = sprintf('RMSE: %.6e', app.FitQuality.rmse);
                reportLines{end+1} = sprintf('Chi-squared: %.6e', app.FitQuality.chisquared);
                reportLines{end+1} = sprintf('Exit Flag: %d', app.FitQuality.exitflag);
                reportLines{end+1} = '';
                reportLines{end+1} = 'Fitted Parameters:';
                
                paramNames = app.InitialGuessTable.Data(:,1);
                for i = 1:length(app.FittedParameters)
                    reportLines{end+1} = sprintf('  %s: %.6e', paramNames{i}, app.FittedParameters(i));
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
                for i = 1:min(5, length(app.DatasetHistory))  % Show up to 5 recent datasets
                    dataset = app.DatasetHistory{i};
                    reportLines{end+1} = sprintf('  %d. %s (%s)', i, dataset.metadata.filename, dataset.metadata.measurementDate);
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
            
            reportContent = reportLines;
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


        function connectUSB(app)
            % Connect via USB Serial
            selectedPort = app.USBPortDropDown.Value;
            
            if strcmp(selectedPort, 'No ports found') || strcmp(selectedPort, 'Error scanning')
                error('No valid port selected');
            end
            
            app.updateConnectionStatus(false, 'Connecting via USB...');
            
            % Create serial connection
            app.SerialConnection = serialport(selectedPort, 115200);
            app.SerialConnection.Timeout = 5;
            
            % Test connection with handshake
            if app.testESP32Connection()
                app.updateConnectionStatus(true, sprintf('Connected via USB on %s', selectedPort));
                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    sprintf('Successfully connected to ESP32 on %s', selectedPort), ...
                    'USB Connection Successful');
            else
                delete(app.SerialConnection);
                app.SerialConnection = [];
                error('ESP32 handshake failed');
            end
        end
        
        function connectWiFi(app)
            % Connect via Wi-Fi TCP
            ipAddress = app.WiFiIPEditField.Value;
            port = 8080;
            
            % Validate IP address format
            if ~app.isValidIP(ipAddress)
                error('Invalid IP address format');
            end
            
            app.updateConnectionStatus(false, 'Connecting via Wi-Fi...');
            
            % Create TCP connection
            app.WiFiConnection = tcpclient(ipAddress, port, 'Timeout', 10);
            
            % Test connection with handshake
            if app.testESP32Connection()
                app.updateConnectionStatus(true, sprintf('Connected via Wi-Fi to %s:%d', ipAddress, port));
                EISAppUtils.showSuccessAlert(app.UIFigure, ...
                    sprintf('Successfully connected to ESP32 at %s:%d', ipAddress, port), ...
                    'Wi-Fi Connection Successful');
            else
                delete(app.WiFiConnection);
                app.WiFiConnection = [];
                error('ESP32 handshake failed');
            end
        end
        
        function success = testESP32Connection(app)
            % Test connection with ping-pong handshake
            success = false;
            
            try
                % Send ping command
                if strcmp(app.ConnectionType, "USB")
                    writeline(app.SerialConnection, "ping");
                    response = readline(app.SerialConnection);
                else % WiFi
                    write(app.WiFiConnection, uint8("ping"));
                    pause(0.1);
                    response = char(read(app.WiFiConnection, app.WiFiConnection.NumBytesAvailable));
                end
                
                % Check for expected response
                if contains(response, "pong")
                    success = true;
                end
                
            catch
                success = false;
            end
        end
        
        function updateConnectionStatus(app, connected, message)
            % Update connection status display
            app.IsConnected = connected;
            
            if connected
                app.ConnectionIndicatorLamp.Color = [0.2 0.8 0.2]; % Green
                app.ConnectButton.Enable = 'off';
                app.DisconnectButton.Enable = 'on';
                app.StatusLamp.Color = [0.2 0.8 0.2]; % Update main status
                app.StatusLabel.Text = 'Connected to ESP32';
            else
                app.ConnectionIndicatorLamp.Color = [0.8 0.2 0.2]; % Red
                app.ConnectButton.Enable = 'on';
                app.DisconnectButton.Enable = 'off';
                app.StatusLamp.Color = [0.8 0.8 0.8]; % Gray
                app.StatusLabel.Text = 'Not Connected';
            end
            
            app.ConnectionStatusLabel.Text = message;
            
            % Update data source status when connection changes
            app.updateDataSourceStatus();
        end
        
        function valid = isValidIP(~, ipStr)
            % Validate IP address format
            pattern = '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$';
            valid = ~isempty(regexp(ipStr, pattern, 'once'));
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
            app.createConnectionTabContainer();
            app.createDatasetTabContainer();
            app.createLivePlotTabContainer();
            app.createFittingTabContainer();
            app.createReportTabContainer();
        end

        function createConnectionTabContainer(app)
            % Create Connection Tab
            app.ConnectionTab = uitab(app.TabGroup);
            app.ConnectionTab.Title = 'Connection';
            app.ConnectionTab.BackgroundColor = [0.94 0.94 0.94];
            app.createConnectionTab();
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
