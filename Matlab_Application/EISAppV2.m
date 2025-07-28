classdef EISAppV2 < matlab.apps.AppBase
    % EISAppV2 - Path-based Electrochemical Impedance Spectroscopy Application
    % Version 2.0 with server integration and three operating modes
    
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        MainPanel              matlab.ui.container.Panel
        
        % Navigation
        ProgressPanel          matlab.ui.container.Panel
        ProgressLabel          matlab.ui.control.Label
        BackButton             matlab.ui.control.Button
        NextButton             matlab.ui.control.Button
        CancelButton           matlab.ui.control.Button
        
        % Status Bar
        StatusPanel            matlab.ui.container.Panel
        StatusLabel            matlab.ui.control.Label
        StatusLamp             matlab.ui.control.Lamp
    end
    
    properties (Access = private)
        % App Configuration
        Version = "2.0.0"
        AppTitle = "EIS Analysis Tool V2"
        
        % Navigation State
        CurrentScreen = "ServerConnection"
        ScreenHistory = {}
        
        % Server Configuration
        MQTTClient
        HTTPBaseURL = ""
        ServerConfig = struct(...
            'mqtt_broker', '', ...
            'mqtt_port', 1883, ...
            'mqtt_username', '', ...
            'mqtt_password', '', ...
            'nodered_url', '', ...
            'device_id', 'esp32_001' ...
        )
        
        % ESP32 Status
        ESP32Status = struct(...
            'mode', 'UNKNOWN', ...
            'active', false, ...
            'measurements_remaining', 0, ...
            'next_measurement', '', ...
            'client_id', '' ...
        )
        
        % User Selections
        SelectedBoard = ""      % AD5940/AD5941
        SelectedMode = ""       % realtime/scheduled/database
        SelectedDataset = struct()
        
        % Screen Containers
        ServerConnectionScreen
        ModeSelectionScreen
        BoardSelectionScreen
        MeasurementModeScreen
        ScheduledConfigScreen
        RealtimeMeasurementScreen
        DatabaseBrowserScreen
        AnalysisFittingScreen
        
        % Current Data
        CurrentMeasurementData = struct()
        IsConnectedToServer = false
        
        % Measurement Timer (for real-time mode)
        MeasurementTimer
        FrequencyVector
        CurrentFrequencyIndex = 1
        IsRunningMeasurement = false
    end
    
    methods (Access = public)
        
        function app = EISAppV2
            % Constructor
            createUIComponents(app);
            registerCallbacks(app);
            initializeApp(app);
        end
        
        function delete(app)
            % Destructor - Clean up connections
            cleanupConnections(app);
            delete(app.UIFigure);
        end
    end
    
    methods (Access = private)
        
        function createUIComponents(app)
            % Create main UI figure and components
            createMainFigure(app);
            createNavigationComponents(app);
            createStatusBar(app);
            createAllScreens(app);
            showScreen(app, "ServerConnection");
        end
        
        function createMainFigure(app)
            % Create main application window
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100, 100, 1000, 700];
            app.UIFigure.Name = app.AppTitle;
            app.UIFigure.Icon = '';
            app.UIFigure.Resize = 'off';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @closeApp, true);
            
            % Main content panel
            app.MainPanel = uipanel(app.UIFigure);
            app.MainPanel.Position = [20, 80, 960, 560];
            app.MainPanel.BorderType = 'none';
            app.MainPanel.BackgroundColor = [0.94, 0.94, 0.94];
        end
        
        function createNavigationComponents(app)
            % Create navigation panel and buttons
            app.ProgressPanel = uipanel(app.UIFigure);
            app.ProgressPanel.Position = [20, 650, 960, 40];
            app.ProgressPanel.BorderType = 'line';
            app.ProgressPanel.BackgroundColor = [0.9, 0.9, 0.9];
            
            % Progress indicator
            app.ProgressLabel = uilabel(app.ProgressPanel);
            app.ProgressLabel.Position = [20, 10, 600, 22];
            app.ProgressLabel.Text = 'Step 1: Server Connection';
            app.ProgressLabel.FontWeight = 'bold';
            
            % Navigation buttons
            app.BackButton = uibutton(app.ProgressPanel, 'push');
            app.BackButton.Position = [720, 8, 70, 25];
            app.BackButton.Text = '← Back';
            app.BackButton.Enable = 'off';
            app.BackButton.ButtonPushedFcn = createCallbackFcn(app, @goBack, true);
            
            app.NextButton = uibutton(app.ProgressPanel, 'push');
            app.NextButton.Position = [800, 8, 70, 25];
            app.NextButton.Text = 'Next →';
            app.NextButton.Enable = 'off';
            app.NextButton.ButtonPushedFcn = createCallbackFcn(app, @goNext, true);
            
            app.CancelButton = uibutton(app.ProgressPanel, 'push');
            app.CancelButton.Position = [880, 8, 70, 25];
            app.CancelButton.Text = 'Cancel';
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @closeApp, true);
        end
        
        function createStatusBar(app)
            % Create status bar at bottom
            app.StatusPanel = uipanel(app.UIFigure);
            app.StatusPanel.Position = [20, 20, 960, 40];
            app.StatusPanel.BorderType = 'line';
            app.StatusPanel.BackgroundColor = [0.95, 0.95, 0.95];
            
            app.StatusLamp = uilamp(app.StatusPanel);
            app.StatusLamp.Position = [30, 12, 20, 20];
            app.StatusLamp.Color = 'red';
            
            app.StatusLabel = uilabel(app.StatusPanel);
            app.StatusLabel.Position = [60, 10, 880, 22];
            app.StatusLabel.Text = 'Ready to connect to server';
        end
        
        function createAllScreens(app)
            % Create all screen containers (initially hidden)
            createServerConnectionScreen(app);
            createModeSelectionScreen(app);
            createBoardSelectionScreen(app);
            createMeasurementModeScreen(app);
            createScheduledConfigScreen(app);
            createRealtimeMeasurementScreen(app);
            createDatabaseBrowserScreen(app);
            createAnalysisFittingScreen(app);
        end
        
        function createServerConnectionScreen(app)
            % Server connection configuration screen
            app.ServerConnectionScreen = uipanel(app.MainPanel);
            app.ServerConnectionScreen.Position = [1, 1, 958, 558];
            app.ServerConnectionScreen.BorderType = 'none';
            app.ServerConnectionScreen.BackgroundColor = [0.94, 0.94, 0.94];
            app.ServerConnectionScreen.Visible = 'off';
            
            % Title
            title_label = uilabel(app.ServerConnectionScreen);
            title_label.Position = [50, 480, 400, 30];
            title_label.Text = 'Server Connection Configuration';
            title_label.FontSize = 18;
            title_label.FontWeight = 'bold';
            
            % MQTT Configuration Panel
            mqtt_panel = uipanel(app.ServerConnectionScreen);
            mqtt_panel.Position = [50, 280, 400, 180];
            mqtt_panel.Title = 'MQTT Broker Settings';
            mqtt_panel.FontWeight = 'bold';
            
            % MQTT Broker IP
            uilabel(mqtt_panel, 'Position', [20, 130, 100, 22], 'Text', 'Broker IP:');
            app.ServerConnectionScreen.MQTTBrokerField = uieditfield(mqtt_panel, 'text');
            app.ServerConnectionScreen.MQTTBrokerField.Position = [130, 130, 200, 22];
            app.ServerConnectionScreen.MQTTBrokerField.Value = '192.168.1.100';
            
            % MQTT Port
            uilabel(mqtt_panel, 'Position', [20, 100, 100, 22], 'Text', 'Port:');
            app.ServerConnectionScreen.MQTTPortField = uieditfield(mqtt_panel, 'numeric');
            app.ServerConnectionScreen.MQTTPortField.Position = [130, 100, 200, 22];
            app.ServerConnectionScreen.MQTTPortField.Value = 1883;
            
            % MQTT Username
            uilabel(mqtt_panel, 'Position', [20, 70, 100, 22], 'Text', 'Username:');
            app.ServerConnectionScreen.MQTTUsernameField = uieditfield(mqtt_panel, 'text');
            app.ServerConnectionScreen.MQTTUsernameField.Position = [130, 70, 200, 22];
            
            % MQTT Password
            uilabel(mqtt_panel, 'Position', [20, 40, 100, 22], 'Text', 'Password:');
            app.ServerConnectionScreen.MQTTPasswordField = uieditfield(mqtt_panel, 'text');
            app.ServerConnectionScreen.MQTTPasswordField.Position = [130, 40, 200, 22];
            app.ServerConnectionScreen.MQTTPasswordField.DisplayText = 'password';
            
            % Node-RED Configuration Panel
            nodered_panel = uipanel(app.ServerConnectionScreen);
            nodered_panel.Position = [480, 280, 400, 180];
            nodered_panel.Title = 'Node-RED Server Settings';
            nodered_panel.FontWeight = 'bold';
            
            % Node-RED URL
            uilabel(nodered_panel, 'Position', [20, 130, 100, 22], 'Text', 'Server URL:');
            app.ServerConnectionScreen.NodeREDURLField = uieditfield(nodered_panel, 'text');
            app.ServerConnectionScreen.NodeREDURLField.Position = [130, 130, 200, 22];
            app.ServerConnectionScreen.NodeREDURLField.Value = 'http://192.168.1.100:1880';
            
            % Device ID
            uilabel(nodered_panel, 'Position', [20, 100, 100, 22], 'Text', 'Device ID:');
            app.ServerConnectionScreen.DeviceIDField = uieditfield(nodered_panel, 'text');
            app.ServerConnectionScreen.DeviceIDField.Position = [130, 100, 200, 22];
            app.ServerConnectionScreen.DeviceIDField.Value = 'esp32_001';
            
            % Connection Test Panel
            test_panel = uipanel(app.ServerConnectionScreen);
            test_panel.Position = [50, 80, 830, 180];
            test_panel.Title = 'Connection Test';
            test_panel.FontWeight = 'bold';
            
            % Test Connection Button
            test_button = uibutton(test_panel, 'push');
            test_button.Position = [50, 120, 150, 30];
            test_button.Text = 'Test Connection';
            test_button.FontWeight = 'bold';
            test_button.ButtonPushedFcn = createCallbackFcn(app, @testServerConnection, true);
            
            % ESP32 Status Panel
            status_panel = uipanel(test_panel);
            status_panel.Position = [230, 50, 550, 100];
            status_panel.Title = 'ESP32 Status';
            status_panel.FontWeight = 'bold';
            
            app.ServerConnectionScreen.ESP32StatusLabel = uilabel(status_panel);
            app.ServerConnectionScreen.ESP32StatusLabel.Position = [20, 50, 500, 22];
            app.ServerConnectionScreen.ESP32StatusLabel.Text = 'ESP32 status unknown - click Test Connection';
            
            app.ServerConnectionScreen.ESP32StatusLamp = uilamp(status_panel);
            app.ServerConnectionScreen.ESP32StatusLamp.Position = [20, 20, 20, 20];
            app.ServerConnectionScreen.ESP32StatusLamp.Color = 'yellow';
            
            % Connection Status
            app.ServerConnectionScreen.ConnectionStatusLabel = uilabel(test_panel);
            app.ServerConnectionScreen.ConnectionStatusLabel.Position = [50, 80, 500, 22];
            app.ServerConnectionScreen.ConnectionStatusLabel.Text = 'Not connected';
            
            % Save Configuration Button
            save_button = uibutton(test_panel, 'push');
            save_button.Position = [50, 20, 150, 30];
            save_button.Text = 'Save & Connect';
            save_button.Enable = 'off';
            save_button.ButtonPushedFcn = createCallbackFcn(app, @saveServerConfig, true);
            
            % Store references for callbacks
            app.ServerConnectionScreen.TestButton = test_button;
            app.ServerConnectionScreen.SaveButton = save_button;
        end
        
        function createModeSelectionScreen(app)
            % Mode selection screen (Database vs Measurement)
            app.ModeSelectionScreen = uipanel(app.MainPanel);
            app.ModeSelectionScreen.Position = [1, 1, 958, 558];
            app.ModeSelectionScreen.BorderType = 'none';
            app.ModeSelectionScreen.BackgroundColor = [0.94, 0.94, 0.94];
            app.ModeSelectionScreen.Visible = 'off';
            
            % Title
            title_label = uilabel(app.ModeSelectionScreen);
            title_label.Position = [50, 480, 400, 30];
            title_label.Text = 'Select Operation Mode';
            title_label.FontSize = 18;
            title_label.FontWeight = 'bold';
            
            % ESP32 Status Display
            status_panel = uipanel(app.ModeSelectionScreen);
            status_panel.Position = [50, 380, 850, 80];
            status_panel.Title = 'ESP32 Current Status';
            status_panel.FontWeight = 'bold';
            
            app.ModeSelectionScreen.ESP32StatusLabel = uilabel(status_panel);
            app.ModeSelectionScreen.ESP32StatusLabel.Position = [50, 30, 600, 22];
            app.ModeSelectionScreen.ESP32StatusLabel.Text = 'ESP32 Status: Loading...';
            app.ModeSelectionScreen.ESP32StatusLabel.FontSize = 14;
            
            app.ModeSelectionScreen.RefreshStatusButton = uibutton(status_panel, 'push');
            app.ModeSelectionScreen.RefreshStatusButton.Position = [700, 25, 100, 30];
            app.ModeSelectionScreen.RefreshStatusButton.Text = 'Refresh';
            app.ModeSelectionScreen.RefreshStatusButton.ButtonPushedFcn = createCallbackFcn(app, @refreshESP32Status, true);
            
            % Database Analysis Option
            db_panel = uipanel(app.ModeSelectionScreen);
            db_panel.Position = [100, 200, 300, 150];
            db_panel.Title = '📊 Database Analysis';
            db_panel.FontWeight = 'bold';
            db_panel.BackgroundColor = [0.9, 0.95, 1.0];
            
            db_desc = uilabel(db_panel);
            db_desc.Position = [20, 80, 260, 40];
            db_desc.Text = 'Analyze historical measurement data from the server database';
            db_desc.WordWrap = 'on';
            
            app.ModeSelectionScreen.DatabaseButton = uibutton(db_panel, 'push');
            app.ModeSelectionScreen.DatabaseButton.Position = [20, 20, 260, 40];
            app.ModeSelectionScreen.DatabaseButton.Text = 'Browse Database';
            app.ModeSelectionScreen.DatabaseButton.FontWeight = 'bold';
            app.ModeSelectionScreen.DatabaseButton.ButtonPushedFcn = createCallbackFcn(app, @selectDatabaseMode, true);
            
            % Measurement Option
            meas_panel = uipanel(app.ModeSelectionScreen);
            meas_panel.Position = [550, 200, 300, 150];
            meas_panel.Title = '🔬 New Measurement';
            meas_panel.FontWeight = 'bold';
            meas_panel.BackgroundColor = [0.95, 1.0, 0.9];
            
            meas_desc = uilabel(meas_panel);
            meas_desc.Position = [20, 80, 260, 40];
            meas_desc.Text = 'Perform new impedance measurements with ESP32 boards';
            meas_desc.WordWrap = 'on';
            
            app.ModeSelectionScreen.MeasurementButton = uibutton(meas_panel, 'push');
            app.ModeSelectionScreen.MeasurementButton.Position = [20, 20, 260, 40];
            app.ModeSelectionScreen.MeasurementButton.Text = 'Start Measurement';
            app.ModeSelectionScreen.MeasurementButton.FontWeight = 'bold';
            app.ModeSelectionScreen.MeasurementButton.ButtonPushedFcn = createCallbackFcn(app, @selectMeasurementMode, true);
        end
        
        function createBoardSelectionScreen(app)
            % Board selection screen (AD5940 vs AD5941)
            app.BoardSelectionScreen = uipanel(app.MainPanel);
            app.BoardSelectionScreen.Position = [1, 1, 958, 558];
            app.BoardSelectionScreen.BorderType = 'none';
            app.BoardSelectionScreen.BackgroundColor = [0.94, 0.94, 0.94];
            app.BoardSelectionScreen.Visible = 'off';
            
            % Title
            title_label = uilabel(app.BoardSelectionScreen);
            title_label.Position = [50, 480, 400, 30];
            title_label.Text = 'Select Measurement Board';
            title_label.FontSize = 18;
            title_label.FontWeight = 'bold';
            
            % AD5940 Board Option
            ad5940_panel = uipanel(app.BoardSelectionScreen);
            ad5940_panel.Position = [100, 250, 300, 200];
            ad5940_panel.Title = 'AD5940 - General Purpose';
            ad5940_panel.FontWeight = 'bold';
            ad5940_panel.BackgroundColor = [0.9, 0.95, 1.0];
            
            ad5940_desc = uilabel(ad5940_panel);
            ad5940_desc.Position = [20, 120, 260, 60];
            ad5940_desc.Text = 'General purpose impedance measurements. Suitable for most EIS applications and research.';
            ad5940_desc.WordWrap = 'on';
            
            % AD5940 Specifications
            ad5940_specs = uilabel(ad5940_panel);
            ad5940_specs.Position = [20, 60, 260, 50];
            ad5940_specs.Text = '• Frequency: 0.1 Hz - 200 kHz' + newline + '• Excitation: 1-2200 mV p-p';
            ad5940_specs.FontSize = 11;
            
            app.BoardSelectionScreen.AD5940Button = uibutton(ad5940_panel, 'push');
            app.BoardSelectionScreen.AD5940Button.Position = [20, 15, 260, 35];
            app.BoardSelectionScreen.AD5940Button.Text = 'Select AD5940';
            app.BoardSelectionScreen.AD5940Button.FontWeight = 'bold';
            app.BoardSelectionScreen.AD5940Button.ButtonPushedFcn = createCallbackFcn(app, @selectAD5940Board, true);
            
            % AD5941 Board Option
            ad5941_panel = uipanel(app.BoardSelectionScreen);
            ad5941_panel.Position = [550, 250, 300, 200];
            ad5941_panel.Title = 'AD5941 - Battery Focused';
            ad5941_panel.FontWeight = 'bold';
            ad5941_panel.BackgroundColor = [1.0, 0.95, 0.9];
            
            ad5941_desc = uilabel(ad5941_panel);
            ad5941_desc.Position = [20, 120, 260, 60];
            ad5941_desc.Text = 'Optimized for battery characterization and energy storage applications.';
            ad5941_desc.WordWrap = 'on';
            
            % AD5941 Specifications
            ad5941_specs = uilabel(ad5941_panel);
            ad5941_specs.Position = [20, 60, 260, 50];
            ad5941_specs.Text = '• Battery impedance analysis' + newline + '• Precharge control support';
            ad5941_specs.FontSize = 11;
            
            app.BoardSelectionScreen.AD5941Button = uibutton(ad5941_panel, 'push');
            app.BoardSelectionScreen.AD5941Button.Position = [20, 15, 260, 35];
            app.BoardSelectionScreen.AD5941Button.Text = 'Select AD5941';
            app.BoardSelectionScreen.AD5941Button.FontWeight = 'bold';
            app.BoardSelectionScreen.AD5941Button.ButtonPushedFcn = createCallbackFcn(app, @selectAD5941Board, true);
        end
        
        function createMeasurementModeScreen(app)
            % Measurement mode selection (Real-time vs Scheduled)
            app.MeasurementModeScreen = uipanel(app.MainPanel);
            app.MeasurementModeScreen.Position = [1, 1, 958, 558];
            app.MeasurementModeScreen.BorderType = 'none';
            app.MeasurementModeScreen.BackgroundColor = [0.94, 0.94, 0.94];
            app.MeasurementModeScreen.Visible = 'off';
            
            % Title
            title_label = uilabel(app.MeasurementModeScreen);
            title_label.Position = [50, 480, 500, 30];
            title_label.Text = sprintf('Measurement Mode - %s Board', app.SelectedBoard);
            title_label.FontSize = 18;
            title_label.FontWeight = 'bold';
            
            % Real-time Mode Option
            realtime_panel = uipanel(app.MeasurementModeScreen);
            realtime_panel.Position = [100, 250, 300, 200];
            realtime_panel.Title = '🔴 Real-time Interactive';
            realtime_panel.FontWeight = 'bold';
            realtime_panel.BackgroundColor = [1.0, 0.95, 0.95];
            
            realtime_desc = uilabel(realtime_panel);
            realtime_desc.Position = [20, 120, 260, 60];
            realtime_desc.Text = 'Interactive measurements with live data visualization and immediate analysis.';
            realtime_desc.WordWrap = 'on';
            
            realtime_features = uilabel(realtime_panel);
            realtime_features.Position = [20, 60, 260, 50];
            realtime_features.Text = '• Live plotting' + newline + '• Immediate fitting & analysis';
            realtime_features.FontSize = 11;
            
            app.MeasurementModeScreen.RealtimeButton = uibutton(realtime_panel, 'push');
            app.MeasurementModeScreen.RealtimeButton.Position = [20, 15, 260, 35];
            app.MeasurementModeScreen.RealtimeButton.Text = 'Real-time Mode';
            app.MeasurementModeScreen.RealtimeButton.FontWeight = 'bold';
            app.MeasurementModeScreen.RealtimeButton.ButtonPushedFcn = createCallbackFcn(app, @selectRealtimeMode, true);
            
            % Scheduled Mode Option
            scheduled_panel = uipanel(app.MeasurementModeScreen);
            scheduled_panel.Position = [550, 250, 300, 200];
            scheduled_panel.Title = '⏱️ Scheduled Autonomous';
            scheduled_panel.FontWeight = 'bold';
            scheduled_panel.BackgroundColor = [0.95, 0.95, 1.0];
            
            scheduled_desc = uilabel(scheduled_panel);
            scheduled_desc.Position = [20, 120, 260, 60];
            scheduled_desc.Text = 'Program measurement schedule and let ESP32 run autonomously.';
            scheduled_desc.WordWrap = 'on';
            
            scheduled_features = uilabel(scheduled_panel);
            scheduled_features.Position = [20, 60, 260, 50];
            scheduled_features.Text = '• Long-term studies' + newline + '• Unattended operation';
            scheduled_features.FontSize = 11;
            
            app.MeasurementModeScreen.ScheduledButton = uibutton(scheduled_panel, 'push');
            app.MeasurementModeScreen.ScheduledButton.Position = [20, 15, 260, 35];
            app.MeasurementModeScreen.ScheduledButton.Text = 'Scheduled Mode';
            app.MeasurementModeScreen.ScheduledButton.FontWeight = 'bold';
            app.MeasurementModeScreen.ScheduledButton.ButtonPushedFcn = createCallbackFcn(app, @selectScheduledMode, true);
        end
        
        function createScheduledConfigScreen(app)
            % Scheduled measurement configuration screen
            app.ScheduledConfigScreen = uipanel(app.MainPanel);
            app.ScheduledConfigScreen.Position = [1, 1, 958, 558];
            app.ScheduledConfigScreen.BorderType = 'none';
            app.ScheduledConfigScreen.BackgroundColor = [0.94, 0.94, 0.94];
            app.ScheduledConfigScreen.Visible = 'off';
            
            % Title
            title_label = uilabel(app.ScheduledConfigScreen);
            title_label.Position = [50, 480, 600, 30];
            title_label.Text = sprintf('Schedule Configuration - %s Board', app.SelectedBoard);
            title_label.FontSize = 18;
            title_label.FontWeight = 'bold';
            
            % Configuration Panel
            config_panel = uipanel(app.ScheduledConfigScreen);
            config_panel.Position = [50, 200, 850, 250];
            config_panel.Title = 'Measurement Schedule Parameters';
            config_panel.FontWeight = 'bold';
            
            % Number of measurements
            uilabel(config_panel, 'Position', [50, 200, 150, 22], 'Text', 'Number of measurements:');
            app.ScheduledConfigScreen.NumMeasurementsField = uieditfield(config_panel, 'numeric');
            app.ScheduledConfigScreen.NumMeasurementsField.Position = [220, 200, 100, 22];
            app.ScheduledConfigScreen.NumMeasurementsField.Value = 10;
            app.ScheduledConfigScreen.NumMeasurementsField.Limits = [1, 1000];
            
            % Interval
            uilabel(config_panel, 'Position', [50, 170, 150, 22], 'Text', 'Interval (hours):');
            app.ScheduledConfigScreen.IntervalField = uieditfield(config_panel, 'numeric');
            app.ScheduledConfigScreen.IntervalField.Position = [220, 170, 100, 22];
            app.ScheduledConfigScreen.IntervalField.Value = 24;
            app.ScheduledConfigScreen.IntervalField.Limits = [0.1, 8760]; % Up to 1 year
            
            % Frequency range
            uilabel(config_panel, 'Position', [50, 140, 150, 22], 'Text', 'Frequency start (Hz):');
            app.ScheduledConfigScreen.FreqStartField = uieditfield(config_panel, 'numeric');
            app.ScheduledConfigScreen.FreqStartField.Position = [220, 140, 100, 22];
            app.ScheduledConfigScreen.FreqStartField.Value = 0.1;
            
            uilabel(config_panel, 'Position', [50, 110, 150, 22], 'Text', 'Frequency end (Hz):');
            app.ScheduledConfigScreen.FreqEndField = uieditfield(config_panel, 'numeric');
            app.ScheduledConfigScreen.FreqEndField.Position = [220, 110, 100, 22];
            app.ScheduledConfigScreen.FreqEndField.Value = 100000;
            
            % Points per measurement
            uilabel(config_panel, 'Position', [50, 80, 150, 22], 'Text', 'Points per measurement:');
            app.ScheduledConfigScreen.NumPointsField = uieditfield(config_panel, 'numeric');
            app.ScheduledConfigScreen.NumPointsField.Position = [220, 80, 100, 22];
            app.ScheduledConfigScreen.NumPointsField.Value = 50;
            app.ScheduledConfigScreen.NumPointsField.Limits = [10, 200];
            
            % Schedule summary
            summary_panel = uipanel(config_panel);
            summary_panel.Position = [400, 50, 400, 170];
            summary_panel.Title = 'Schedule Summary';
            summary_panel.FontWeight = 'bold';
            summary_panel.BackgroundColor = [0.95, 0.95, 1.0];
            
            app.ScheduledConfigScreen.SummaryLabel = uilabel(summary_panel);
            app.ScheduledConfigScreen.SummaryLabel.Position = [20, 50, 360, 100];
            app.ScheduledConfigScreen.SummaryLabel.Text = 'Configure parameters to see summary';
            app.ScheduledConfigScreen.SummaryLabel.WordWrap = 'on';
            app.ScheduledConfigScreen.SummaryLabel.VerticalAlignment = 'top';
            
            % Update summary when parameters change
            app.ScheduledConfigScreen.NumMeasurementsField.ValueChangedFcn = createCallbackFcn(app, @updateScheduleSummary, true);
            app.ScheduledConfigScreen.IntervalField.ValueChangedFcn = createCallbackFcn(app, @updateScheduleSummary, true);
            
            % Program Schedule Button
            program_button = uibutton(app.ScheduledConfigScreen, 'push');
            program_button.Position = [400, 100, 200, 50];
            program_button.Text = 'Program Schedule & Exit';
            program_button.FontWeight = 'bold';
            program_button.FontSize = 14;
            program_button.BackgroundColor = [0.2, 0.6, 0.2];
            program_button.FontColor = 'white';
            program_button.ButtonPushedFcn = createCallbackFcn(app, @programSchedule, true);
        end
        
        function createRealtimeMeasurementScreen(app)
            % Real-time measurement screen - placeholder for now
            app.RealtimeMeasurementScreen = uipanel(app.MainPanel);
            app.RealtimeMeasurementScreen.Position = [1, 1, 958, 558];
            app.RealtimeMeasurementScreen.BorderType = 'none';
            app.RealtimeMeasurementScreen.BackgroundColor = [0.94, 0.94, 0.94];
            app.RealtimeMeasurementScreen.Visible = 'off';
            
            % Placeholder label
            placeholder_label = uilabel(app.RealtimeMeasurementScreen);
            placeholder_label.Position = [400, 250, 200, 30];
            placeholder_label.Text = 'Real-time Measurement Screen';
            placeholder_label.FontSize = 16;
            placeholder_label.FontWeight = 'bold';
            placeholder_label.HorizontalAlignment = 'center';
            
            % Note
            note_label = uilabel(app.RealtimeMeasurementScreen);
            note_label.Position = [300, 200, 400, 30];
            note_label.Text = '(Implementation will continue to Analysis/Fitting)';
            note_label.HorizontalAlignment = 'center';
        end
        
        function createDatabaseBrowserScreen(app)
            % Database browser screen - placeholder for now
            app.DatabaseBrowserScreen = uipanel(app.MainPanel);
            app.DatabaseBrowserScreen.Position = [1, 1, 958, 558];
            app.DatabaseBrowserScreen.BorderType = 'none';
            app.DatabaseBrowserScreen.BackgroundColor = [0.94, 0.94, 0.94];
            app.DatabaseBrowserScreen.Visible = 'off';
            
            % Placeholder label
            placeholder_label = uilabel(app.DatabaseBrowserScreen);
            placeholder_label.Position = [400, 250, 200, 30];
            placeholder_label.Text = 'Database Browser Screen';
            placeholder_label.FontSize = 16;
            placeholder_label.FontWeight = 'bold';
            placeholder_label.HorizontalAlignment = 'center';
            
            % Note
            note_label = uilabel(app.DatabaseBrowserScreen);
            note_label.Position = [300, 200, 400, 30];
            note_label.Text = '(Implementation will continue to Analysis/Fitting)';
            note_label.HorizontalAlignment = 'center';
        end
        
        function createAnalysisFittingScreen(app)
            % Analysis and fitting screen - placeholder for now
            app.AnalysisFittingScreen = uipanel(app.MainPanel);
            app.AnalysisFittingScreen.Position = [1, 1, 958, 558];
            app.AnalysisFittingScreen.BorderType = 'none';
            app.AnalysisFittingScreen.BackgroundColor = [0.94, 0.94, 0.94];
            app.AnalysisFittingScreen.Visible = 'off';
            
            % Placeholder label
            placeholder_label = uilabel(app.AnalysisFittingScreen);
            placeholder_label.Position = [400, 250, 200, 30];
            placeholder_label.Text = 'Analysis & Fitting Screen';
            placeholder_label.FontSize = 16;
            placeholder_label.FontWeight = 'bold';
            placeholder_label.HorizontalAlignment = 'center';
            
            % Note
            note_label = uilabel(app.AnalysisFittingScreen);
            note_label.Position = [300, 200, 400, 30];
            note_label.Text = '(Final endpoint for all paths)';
            note_label.HorizontalAlignment = 'center';
        end
        
        function registerCallbacks(app)
            % Register any additional callbacks if needed
            % Most callbacks are registered during component creation
        end
        
        function initializeApp(app)
            % Initialize application
            updateStatusBar(app, 'Ready to connect to server', 'red');
            app.UIFigure.Visible = 'on';
        end
        
        % Navigation Methods
        function showScreen(app, screenName)
            % Hide all screens and show the specified one
            hideAllScreens(app);
            
            switch screenName
                case "ServerConnection"
                    app.ServerConnectionScreen.Visible = 'on';
                    updateProgressLabel(app, 'Step 1: Server Connection');
                    app.BackButton.Enable = 'off';
                    app.NextButton.Enable = 'off';
                    
                case "ModeSelection"
                    app.ModeSelectionScreen.Visible = 'on';
                    updateProgressLabel(app, 'Step 2: Operation Mode Selection');
                    app.BackButton.Enable = 'on';
                    app.NextButton.Enable = 'off';
                    refreshESP32Status(app);
                    
                case "BoardSelection"
                    app.BoardSelectionScreen.Visible = 'on';
                    updateProgressLabel(app, 'Step 3: Board Selection');
                    app.BackButton.Enable = 'on';
                    app.NextButton.Enable = 'off';
                    
                case "MeasurementMode"
                    app.MeasurementModeScreen.Visible = 'on';
                    updateProgressLabel(app, 'Step 4: Measurement Mode');
                    % Update title with selected board
                    title_label = findobj(app.MeasurementModeScreen, 'Type', 'uilabel', 'FontSize', 18);
                    if ~isempty(title_label)
                        title_label.Text = sprintf('Measurement Mode - %s Board', app.SelectedBoard);
                    end
                    app.BackButton.Enable = 'on';
                    app.NextButton.Enable = 'off';
                    
                case "ScheduledConfig"
                    app.ScheduledConfigScreen.Visible = 'on';
                    updateProgressLabel(app, 'Step 5: Schedule Configuration');
                    % Update title with selected board
                    title_label = findobj(app.ScheduledConfigScreen, 'Type', 'uilabel', 'FontSize', 18);
                    if ~isempty(title_label)
                        title_label.Text = sprintf('Schedule Configuration - %s Board', app.SelectedBoard);
                    end
                    app.BackButton.Enable = 'on';
                    app.NextButton.Enable = 'off';
                    updateScheduleSummary(app);
                    
                case "RealtimeMeasurement"
                    app.RealtimeMeasurementScreen.Visible = 'on';
                    updateProgressLabel(app, 'Step 5: Real-time Measurement');
                    app.BackButton.Enable = 'on';
                    app.NextButton.Enable = 'off';
                    
                case "DatabaseBrowser"
                    app.DatabaseBrowserScreen.Visible = 'on';
                    updateProgressLabel(app, 'Step 3: Database Browser');
                    app.BackButton.Enable = 'on';
                    app.NextButton.Enable = 'off';
                    
                case "AnalysisFitting"
                    app.AnalysisFittingScreen.Visible = 'on';
                    updateProgressLabel(app, 'Final: Analysis & Fitting');
                    app.BackButton.Enable = 'on';
                    app.NextButton.Enable = 'off';
            end
            
            app.CurrentScreen = screenName;
        end
        
        function hideAllScreens(app)
            % Hide all screen panels
            screens = {'ServerConnectionScreen', 'ModeSelectionScreen', ...
                      'BoardSelectionScreen', 'MeasurementModeScreen', ...
                      'ScheduledConfigScreen', 'RealtimeMeasurementScreen', ...
                      'DatabaseBrowserScreen', 'AnalysisFittingScreen'};
            
            for i = 1:length(screens)
                if isprop(app, screens{i}) && isvalid(app.(screens{i}))
                    app.(screens{i}).Visible = 'off';
                end
            end
        end
        
        function updateProgressLabel(app, text)
            app.ProgressLabel.Text = text;
        end
        
        function updateStatusBar(app, message, lampColor)
            app.StatusLabel.Text = message;
            if nargin > 2
                app.StatusLamp.Color = lampColor;
            end
        end
        
        % Callback Methods
        function testServerConnection(app, ~)
            % Test connection to MQTT broker and Node-RED
            updateStatusBar(app, 'Testing server connection...', 'yellow');
            
            try
                % Get configuration values
                mqtt_broker = app.ServerConnectionScreen.MQTTBrokerField.Value;
                mqtt_port = app.ServerConnectionScreen.MQTTPortField.Value;
                mqtt_username = app.ServerConnectionScreen.MQTTUsernameField.Value;
                mqtt_password = app.ServerConnectionScreen.MQTTPasswordField.Value;
                nodered_url = app.ServerConnectionScreen.NodeREDURLField.Value;
                device_id = app.ServerConnectionScreen.DeviceIDField.Value;
                
                % Store temporary config
                temp_config = struct(...
                    'mqtt_broker', mqtt_broker, ...
                    'mqtt_port', mqtt_port, ...
                    'mqtt_username', mqtt_username, ...
                    'mqtt_password', mqtt_password, ...
                    'nodered_url', nodered_url, ...
                    'device_id', device_id ...
                );
                
                % Test MQTT connection
                testMQTTConnection(app, temp_config);
                
                % Test Node-RED connection
                testNodeREDConnection(app, temp_config);
                
                % Get ESP32 status
                getESP32Status(app);
                
                % Enable Save button if tests pass
                app.ServerConnectionScreen.SaveButton.Enable = 'on';
                app.ServerConnectionScreen.ConnectionStatusLabel.Text = 'Connection test successful!';
                updateStatusBar(app, 'Server connection test successful', 'green');
                
            catch ME
                app.ServerConnectionScreen.ConnectionStatusLabel.Text = sprintf('Connection failed: %s', ME.message);
                updateStatusBar(app, 'Server connection test failed', 'red');
                app.ServerConnectionScreen.SaveButton.Enable = 'off';
            end
        end
        
        function testMQTTConnection(app, config)
            % Test MQTT broker connection
            try
                % Create temporary MQTT client for testing
                if ~isempty(config.mqtt_username)
                    test_client = mqttclient(config.mqtt_broker, 'Port', config.mqtt_port, ...
                                           'Username', config.mqtt_username, 'Password', config.mqtt_password);
                else
                    test_client = mqttclient(config.mqtt_broker, 'Port', config.mqtt_port);
                end
                
                % Test publish/subscribe
                subscribe(test_client, 'test/connection');
                publish(test_client, 'test/connection', 'MATLAB connection test');
                
                % Clean up test client
                clear test_client;
                
            catch ME
                error('MQTT connection failed: %s', ME.message);
            end
        end
        
        function testNodeREDConnection(app, config)
            % Test Node-RED HTTP connection
            try
                test_url = sprintf('%s/api/status', config.nodered_url);
                response = webread(test_url);
                % Node-RED connection successful if we get here
            catch ME
                error('Node-RED connection failed: %s', ME.message);
            end
        end
        
        function getESP32Status(app)
            % Get current ESP32 status via MQTT
            try
                if isempty(app.MQTTClient) || ~isvalid(app.MQTTClient)
                    return;
                end
                
                % Subscribe to ESP32 status topic with timeout
                status_msg = receive(app.MQTTClient, 'esp32/status/mode', 'Timeout', 5);
                
                if ~isempty(status_msg)
                    app.ESP32Status = jsondecode(status_msg.Data);
                    updateESP32StatusDisplay(app);
                else
                    app.ESP32Status.mode = 'NO_RESPONSE';
                    app.ESP32Status.active = false;
                end
                
            catch ME
                app.ESP32Status.mode = 'ERROR';
                app.ESP32Status.active = false;
                fprintf('ESP32 status error: %s\n', ME.message);
            end
        end
        
        function updateESP32StatusDisplay(app)
            % Update ESP32 status display in UI
            status_text = '';
            lamp_color = 'yellow';
            
            switch app.ESP32Status.mode
                case 'STANDBY'
                    status_text = '🟢 ESP32 Status: STANDBY - Ready for commands';
                    lamp_color = 'green';
                    
                case 'SCHEDULED'
                    if isfield(app.ESP32Status, 'measurements_remaining')
                        status_text = sprintf('🟡 ESP32 Status: SCHEDULED - %d measurements remaining', ...
                                            app.ESP32Status.measurements_remaining);
                    else
                        status_text = '🟡 ESP32 Status: SCHEDULED - Running autonomous measurements';
                    end
                    lamp_color = 'yellow';
                    
                case 'REALTIME'
                    status_text = '🔴 ESP32 Status: REALTIME - Connected to another client';
                    lamp_color = 'red';
                    
                case 'NO_RESPONSE'
                    status_text = '⚫ ESP32 Status: NO RESPONSE - Device may be offline';
                    lamp_color = 'black';
                    
                case 'ERROR'
                    status_text = '🔴 ESP32 Status: ERROR - Communication failed';
                    lamp_color = 'red';
                    
                otherwise
                    status_text = '⚪ ESP32 Status: UNKNOWN';
                    lamp_color = 'yellow';
            end
            
            % Update server connection screen
            if isfield(app.ServerConnectionScreen, 'ESP32StatusLabel')
                app.ServerConnectionScreen.ESP32StatusLabel.Text = status_text;
                app.ServerConnectionScreen.ESP32StatusLamp.Color = lamp_color;
            end
            
            % Update mode selection screen
            if isfield(app.ModeSelectionScreen, 'ESP32StatusLabel')
                app.ModeSelectionScreen.ESP32StatusLabel.Text = status_text;
            end
            
            % Enable/disable measurement mode based on status
            updateModeAvailability(app);
        end
        
        function updateModeAvailability(app)
            % Enable/disable mode options based on ESP32 status
            if ~isfield(app.ModeSelectionScreen, 'MeasurementButton')
                return;
            end
            
            switch app.ESP32Status.mode
                case 'STANDBY'
                    app.ModeSelectionScreen.MeasurementButton.Enable = 'on';
                    app.ModeSelectionScreen.MeasurementButton.Text = 'Start Measurement';
                    
                case {'SCHEDULED', 'REALTIME'}
                    app.ModeSelectionScreen.MeasurementButton.Enable = 'off';
                    app.ModeSelectionScreen.MeasurementButton.Text = 'Measurement (Device Busy)';
                    
                otherwise
                    app.ModeSelectionScreen.MeasurementButton.Enable = 'off';
                    app.ModeSelectionScreen.MeasurementButton.Text = 'Measurement (Status Unknown)';
            end
        end
        
        function saveServerConfig(app, ~)
            % Save server configuration and establish connections
            try
                % Store configuration
                app.ServerConfig.mqtt_broker = app.ServerConnectionScreen.MQTTBrokerField.Value;
                app.ServerConfig.mqtt_port = app.ServerConnectionScreen.MQTTPortField.Value;
                app.ServerConfig.mqtt_username = app.ServerConnectionScreen.MQTTUsernameField.Value;
                app.ServerConfig.mqtt_password = app.ServerConnectionScreen.MQTTPasswordField.Value;
                app.ServerConfig.nodered_url = app.ServerConnectionScreen.NodeREDURLField.Value;
                app.ServerConfig.device_id = app.ServerConnectionScreen.DeviceIDField.Value;
                
                % Create MQTT client
                createMQTTClient(app);
                
                app.IsConnectedToServer = true;
                updateStatusBar(app, 'Connected to server', 'green');
                
                % Navigate to mode selection
                showScreen(app, "ModeSelection");
                
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, sprintf('Failed to save configuration: %s', ME.message), 'Configuration Error');
                updateStatusBar(app, 'Failed to connect to server', 'red');
            end
        end
        
        function createMQTTClient(app)
            % Create and configure MQTT client
            if ~isempty(app.ServerConfig.mqtt_username)
                app.MQTTClient = mqttclient(app.ServerConfig.mqtt_broker, ...
                                          'Port', app.ServerConfig.mqtt_port, ...
                                          'Username', app.ServerConfig.mqtt_username, ...
                                          'Password', app.ServerConfig.mqtt_password);
            else
                app.MQTTClient = mqttclient(app.ServerConfig.mqtt_broker, ...
                                          'Port', app.ServerConfig.mqtt_port);
            end
            
            % Subscribe to ESP32 status updates
            subscribe(app.MQTTClient, 'esp32/status/mode');
        end
        
        function refreshESP32Status(app, ~)
            % Refresh ESP32 status
            updateStatusBar(app, 'Refreshing ESP32 status...', 'yellow');
            getESP32Status(app);
            updateStatusBar(app, 'ESP32 status updated', 'green');
        end
        
        % Mode Selection Callbacks
        function selectDatabaseMode(app, ~)
            app.SelectedMode = "database";
            showScreen(app, "DatabaseBrowser");
        end
        
        function selectMeasurementMode(app, ~)
            if strcmp(app.ESP32Status.mode, 'STANDBY')
                app.SelectedMode = "measurement";
                showScreen(app, "BoardSelection");
            else
                EISAppUtils.showWarningAlert(app.UIFigure, 'ESP32 is currently busy. Please wait for it to become available.', 'Device Busy');
            end
        end
        
        % Board Selection Callbacks
        function selectAD5940Board(app, ~)
            app.SelectedBoard = "AD5940";
            showScreen(app, "MeasurementMode");
        end
        
        function selectAD5941Board(app, ~)
            app.SelectedBoard = "AD5941";
            showScreen(app, "MeasurementMode");
        end
        
        % Measurement Mode Callbacks
        function selectRealtimeMode(app, ~)
            app.SelectedMode = "realtime";
            showScreen(app, "RealtimeMeasurement");
        end
        
        function selectScheduledMode(app, ~)
            app.SelectedMode = "scheduled";
            showScreen(app, "ScheduledConfig");
        end
        
        function updateScheduleSummary(app, ~)
            % Update schedule summary display
            if ~isfield(app.ScheduledConfigScreen, 'SummaryLabel')
                return;
            end
            
            num_measurements = app.ScheduledConfigScreen.NumMeasurementsField.Value;
            interval_hours = app.ScheduledConfigScreen.IntervalField.Value;
            
            total_duration_hours = num_measurements * interval_hours;
            total_duration_days = total_duration_hours / 24;
            
            summary_text = sprintf(['Schedule Summary:\n\n' ...
                                  '• %d measurements total\n' ...
                                  '• Every %.1f hours\n' ...
                                  '• Total duration: %.1f hours (%.1f days)\n' ...
                                  '• Board: %s\n\n' ...
                                  'After programming, the ESP32 will run\n' ...
                                  'autonomously and you can close MATLAB.'], ...
                                 num_measurements, interval_hours, ...
                                 total_duration_hours, total_duration_days, ...
                                 app.SelectedBoard);
            
            app.ScheduledConfigScreen.SummaryLabel.Text = summary_text;
        end
        
        function programSchedule(app, ~)
            % Program the measurement schedule to ESP32
            try
                % Prepare schedule configuration
                schedule_config = struct();
                schedule_config.board = app.SelectedBoard;
                schedule_config.measurements = app.ScheduledConfigScreen.NumMeasurementsField.Value;
                schedule_config.interval_hours = app.ScheduledConfigScreen.IntervalField.Value;
                schedule_config.freq_start = app.ScheduledConfigScreen.FreqStartField.Value;
                schedule_config.freq_end = app.ScheduledConfigScreen.FreqEndField.Value;
                schedule_config.num_points = app.ScheduledConfigScreen.NumPointsField.Value;
                schedule_config.start_time = datetime('now');
                
                % Send schedule to ESP32 via MQTT
                publish(app.MQTTClient, 'esp32/cmd/schedule', jsonencode(schedule_config));
                
                % Show success message
                success_msg = sprintf(['Schedule programmed successfully!\n\n' ...
                                     'The ESP32 will now run %d measurements\n' ...
                                     'every %.1f hours using the %s board.\n\n' ...
                                     'You can now close MATLAB.\n' ...
                                     'Use the Database Analysis mode to\n' ...
                                     'view results later.'], ...
                                    schedule_config.measurements, ...
                                    schedule_config.interval_hours, ...
                                    schedule_config.board);
                
                EISAppUtils.showSuccessAlert(app.UIFigure, success_msg, 'Schedule Programmed');
                
                % Update status
                updateStatusBar(app, 'Schedule programmed - ESP32 running autonomously', 'green');
                
                % Close application after a delay
                pause(2);
                closeApp(app);
                
            catch ME
                EISAppUtils.showErrorAlert(app.UIFigure, sprintf('Failed to program schedule: %s', ME.message), 'Programming Error');
            end
        end
        
        % Navigation Callbacks
        function goBack(app, ~)
            % Navigate to previous screen
            switch app.CurrentScreen
                case "ModeSelection"
                    showScreen(app, "ServerConnection");
                case "BoardSelection"
                    showScreen(app, "ModeSelection");
                case "MeasurementMode"
                    showScreen(app, "BoardSelection");
                case "ScheduledConfig"
                    showScreen(app, "MeasurementMode");
                case "RealtimeMeasurement"
                    showScreen(app, "MeasurementMode");
                case "DatabaseBrowser"
                    showScreen(app, "ModeSelection");
                case "AnalysisFitting"
                    % Determine where to go back based on selected mode
                    if strcmp(app.SelectedMode, "database")
                        showScreen(app, "DatabaseBrowser");
                    else
                        showScreen(app, "RealtimeMeasurement");
                    end
            end
        end
        
        function goNext(app, ~)
            % Navigate to next screen (if enabled)
            % Implementation depends on specific screen logic
        end
        
        function closeApp(app, ~)
            % Clean up and close application
            answer = uiconfirm(app.UIFigure, ...
                'Are you sure you want to exit the EIS Application?', ...
                'Confirm Exit', ...
                'Options', {'Yes', 'No'}, ...
                'DefaultOption', 'No');
            
            if strcmp(answer, 'Yes')
                cleanupConnections(app);
                delete(app);
            end
        end
        
        function cleanupConnections(app)
            % Clean up MQTT and other connections
            try
                if ~isempty(app.MQTTClient) && isvalid(app.MQTTClient)
                    clear app.MQTTClient;
                end
                
                if ~isempty(app.MeasurementTimer) && isvalid(app.MeasurementTimer)
                    stop(app.MeasurementTimer);
                    delete(app.MeasurementTimer);
                end
            catch ME
                fprintf('Cleanup warning: %s\n', ME.message);
            end
        end
    end
end