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
        function TabGroupSelectionChanged(app, event)
            selectedTab = app.TabGroup.SelectedTab;
            app.StatusLabel.Text = sprintf("Active: %s", selectedTab.Title);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1000 700];
            app.UIFigure.Name = sprintf('%s v%s', app.AppTitle, app.Version);
            % app.UIFigure.Icon = 'icon_eis.png'; % Optional: add custom icon

            % Create main TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [20 60 960 620];
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);

            % Create Connection Tab
            app.ConnectionTab = uitab(app.TabGroup);
            app.ConnectionTab.Title = 'Connection';
            app.ConnectionTab.BackgroundColor = [0.94 0.94 0.94];
            
            % Add placeholder content for Connection Tab
            connectionLabel = uilabel(app.ConnectionTab);
            connectionLabel.Position = [50 500 300 30];
            connectionLabel.Text = '🌐 ESP32 Connection Interface';
            connectionLabel.FontSize = 16;
            connectionLabel.FontWeight = 'bold';
            
            connectionDesc = uilabel(app.ConnectionTab);
            connectionDesc.Position = [50 450 800 60];
            connectionDesc.Text = ['Connect to ESP32 via USB Serial or Wi-Fi. ' ...
                                 'This interface will support both communication modes ' ...
                                 'with automatic device detection and status monitoring.'];
            connectionDesc.WordWrap = 'on';

            % Create Dataset Tab
            app.DatasetTab = uitab(app.TabGroup);
            app.DatasetTab.Title = 'Dataset';
            app.DatasetTab.BackgroundColor = [0.94 0.94 0.94];
            
            % Add placeholder content for Dataset Tab
            datasetLabel = uilabel(app.DatasetTab);
            datasetLabel.Position = [50 500 300 30];
            datasetLabel.Text = '📂 Dataset Management';
            datasetLabel.FontSize = 16;
            datasetLabel.FontWeight = 'bold';
            
            datasetDesc = uilabel(app.DatasetTab);
            datasetDesc.Position = [50 450 800 60];
            datasetDesc.Text = ['Load, save, and manage EIS datasets with metadata. ' ...
                              'Support for .mat and .csv files with comprehensive ' ...
                              'sample information and measurement parameters.'];
            datasetDesc.WordWrap = 'on';

            % Create Live Plot Tab
            app.LivePlotTab = uitab(app.TabGroup);
            app.LivePlotTab.Title = 'Live Plot';
            app.LivePlotTab.BackgroundColor = [0.94 0.94 0.94];
            
            % Add placeholder content for Live Plot Tab
            plotLabel = uilabel(app.LivePlotTab);
            plotLabel.Position = [50 500 300 30];
            plotLabel.Text = '📊 Real-time EIS Visualization';
            plotLabel.FontSize = 16;
            plotLabel.FontWeight = 'bold';
            
            plotDesc = uilabel(app.LivePlotTab);
            plotDesc.Position = [50 450 800 60];
            plotDesc.Text = ['Real-time Bode and Nyquist plots during EIS measurements. ' ...
                           'Interactive plotting with zoom, pan, and data cursor capabilities. ' ...
                           'Frequency sweep from 1 Hz to 100 kHz with customizable parameters.'];
            plotDesc.WordWrap = 'on';

            % Create Fitting Tab
            app.FittingTab = uitab(app.TabGroup);
            app.FittingTab.Title = 'Fitting';
            app.FittingTab.BackgroundColor = [0.94 0.94 0.94];
            
            % Add placeholder content for Fitting Tab
            fittingLabel = uilabel(app.FittingTab);
            fittingLabel.Position = [50 500 300 30];
            fittingLabel.Text = '📈 Equivalent Circuit Fitting';
            fittingLabel.FontSize = 16;
            fittingLabel.FontWeight = 'bold';
            
            fittingDesc = uilabel(app.FittingTab);
            fittingDesc.Position = [50 450 800 80];
            fittingDesc.Text = ['Fit impedance data to equivalent circuit models including ' ...
                              'Randles circuit, RC circuits, and custom models. ' ...
                              'Parameter estimation with confidence intervals and ' ...
                              'goodness-of-fit statistics.'];
            fittingDesc.WordWrap = 'on';

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
