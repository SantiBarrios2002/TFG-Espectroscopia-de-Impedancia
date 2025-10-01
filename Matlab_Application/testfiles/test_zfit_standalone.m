% Standalone Zfit Test Script
% Simplified version - RC model only with impedance plot, R² value, and std deviation
% Compatible with existing .mat file structure

clear; close all; clc;

%% Configuration
% Specify the .mat file to test
mat_file = '100_10k_470n.mat';  % Change this to test different files:
                         % '100_10k_470n.mat', '10_100_6.8u.mat',
                         % '10_1k_470u.mat', '1k_1M_100p.mat',
                         % '510_100k_10n.mat'

fprintf('=== Zfit Analysis ===\n');
fprintf('File: %s\n\n', mat_file);

%% Load .mat file
data_path = fullfile('reference_measurement_isx3', mat_file);

if ~exist(data_path, 'file')
    error('File not found: %s', data_path);
end

% Load the .mat file
loaded_data = load(data_path);

% Extract data from struct
% Expected fields: frequency, impedance_real, impedance_imag
if isfield(loaded_data, 'frequency')
    freq = loaded_data.frequency;
elseif isfield(loaded_data, 'freq')
    freq = loaded_data.freq;
elseif isfield(loaded_data, 'f')
    freq = loaded_data.f;
else
    error('Could not find frequency data in .mat file');
end

% Extract real and imaginary parts
if isfield(loaded_data, 'impedance_real') && isfield(loaded_data, 'impedance_imag')
    Z_real = loaded_data.impedance_real;
    Z_imag = loaded_data.impedance_imag;
elseif isfield(loaded_data, 'Zreal') && isfield(loaded_data, 'Zimag')
    Z_real = loaded_data.Zreal;
    Z_imag = loaded_data.Zimag;
elseif isfield(loaded_data, 'Z_real') && isfield(loaded_data, 'Z_imag')
    Z_real = loaded_data.Z_real;
    Z_imag = loaded_data.Z_imag;
elseif isfield(loaded_data, 'realZ') && isfield(loaded_data, 'imagZ')
    Z_real = loaded_data.realZ;
    Z_imag = loaded_data.imagZ;
else
    error('Could not find impedance data in .mat file');
end

% Ensure column vectors
freq = freq(:);
Z_real = Z_real(:);
Z_imag = Z_imag(:);

% Create data matrix for Zfit [freq, real(Z), imag(Z)]
data = [freq, Z_real, Z_imag];

fprintf('Data points: %d\n', length(freq));
fprintf('Frequency range: %.2f - %.2f Hz\n\n', min(freq), max(freq));

%% Circuit Model and Fitting
% Initial parameter guess based on data
Rs_guess = min(Z_real);  % Series resistance (high-freq limit)
R_guess = max(Z_real) - min(Z_real);  % Parallel resistance
C_guess = 1e-9;  % Initial capacitance guess

circuit_string = 's(R1,p(R1,C1))';  % Rs in series with R||C
param_guess = [Rs_guess, R_guess, C_guess];

fprintf('Circuit model: Rs + (R||C)\n');
fprintf('Fitting...\n');

% Fitting parameters
LB = [0, 0, 1e-12];  % Lower bounds
UB = [inf, inf, 1];  % Upper bounds
indexes = [];        % Use all data points
fitstring = 'fitNP'; % Non-proportional weighting

% Perform fitting and plot
[pbest, zbest, fval, exitflag, output] = Zfit(data, 'z', circuit_string, ...
    param_guess, indexes, fitstring, LB, UB);

%% Calculate Statistics
% Experimental impedance (complex)
Z_exp = Z_real + 1i*Z_imag;

% Fitted impedance (complex)
Z_fit = zbest(:,1) + 1i*zbest(:,2);

% Calculate residuals
residuals_real = Z_real - zbest(:,1);
residuals_imag = Z_imag - zbest(:,2);
residuals_magnitude = abs(Z_exp) - abs(Z_fit);

% Standard deviation
std_real = std(residuals_real);
std_imag = std(residuals_imag);
std_magnitude = std(residuals_magnitude);

% R-squared (coefficient of determination)
% For real part
SS_res_real = sum(residuals_real.^2);
SS_tot_real = sum((Z_real - mean(Z_real)).^2);
R2_real = 1 - (SS_res_real / SS_tot_real);

% For imaginary part
SS_res_imag = sum(residuals_imag.^2);
SS_tot_imag = sum((Z_imag - mean(Z_imag)).^2);
R2_imag = 1 - (SS_res_imag / SS_tot_imag);

% Overall R² (combined)
SS_res_total = sum(residuals_real.^2 + residuals_imag.^2);
SS_tot_total = sum((Z_real - mean(Z_real)).^2 + (Z_imag - mean(Z_imag)).^2);
R2_overall = 1 - (SS_res_total / SS_tot_total);

%% Display Results
fprintf('\n=== FITTING RESULTS ===\n\n');

fprintf('Fitted Parameters:\n');
fprintf('  Rs = %.2f Ω\n', pbest(1));
fprintf('  R  = %.2f Ω\n', pbest(2));
fprintf('  C  = %.2e F\n', pbest(3));
fc = 1 / (2 * pi * pbest(2) * pbest(3));
fprintf('  fc = %.2f Hz\n\n', fc);

fprintf('Goodness of Fit:\n');
fprintf('  R² (overall)    = %.6f\n', R2_overall);
fprintf('  R² (real part)  = %.6f\n', R2_real);
fprintf('  R² (imag part)  = %.6f\n\n', R2_imag);

fprintf('Standard Deviation:\n');
fprintf('  σ (real part)   = %.2f Ω\n', std_real);
fprintf('  σ (imag part)   = %.2f Ω\n', std_imag);
fprintf('  σ (magnitude)   = %.2f Ω\n\n', std_magnitude);

fprintf('Optimization Info:\n');
fprintf('  Exit flag: %d\n', exitflag);
if isfield(output, 'funcCount')
    fprintf('  Function evaluations: %d\n', output.funcCount);
elseif isfield(output, 'funcount')
    fprintf('  Function evaluations: %d\n', output.funcount);
end
fprintf('  Final fval: %.2e\n', fval);
