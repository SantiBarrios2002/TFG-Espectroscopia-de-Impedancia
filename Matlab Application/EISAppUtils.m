classdef EISAppUtils < handle
    % Utility functions for EIS App
    
    methods (Static)
        
        function showSuccessAlert(parent, message, title)
            % Display success alert with green checkmark
            if nargin < 3
                title = 'Success';
            end
            uialert(parent, message, title, 'Icon', 'success');
        end
        
        function showErrorAlert(parent, message, title)
            % Display error alert with red X
            if nargin < 3
                title = 'Error';
            end
            uialert(parent, message, title, 'Icon', 'error');
        end
        
        function showWarningAlert(parent, message, title)
            % Display warning alert with yellow triangle
            if nargin < 3
                title = 'Warning';
            end
            uialert(parent, message, title, 'Icon', 'warning');
        end
        
        function showInfoAlert(parent, message, title)
            % Display info alert with blue i
            if nargin < 3
                title = 'Information';
            end
            uialert(parent, message, title, 'Icon', 'info');
        end
        
        function version = getAppVersion()
            % Return current app version
            version = "1.0.0";
        end
        
        function timestamp = getCurrentTimestamp()
            % Return formatted timestamp
            timestamp = string(datetime('now', 'yyyy-mm-dd HH:MM:SS'));
        end
    end
end
