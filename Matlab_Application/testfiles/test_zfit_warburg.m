% Standalone Zfit Test Script - Warburg Model
% Circuit: Rs + ((R + Warburg) || CPE)
% User selects Warburg Short or Warburg Open
% Compatible with existing .mat file structure

clear; close all; clc;

%% Configuration
% Specify the .mat file to test
mat_file = 'HojaA.mat';  % Change this to test different files:
                         % '100_10k_470n.mat', '10_100_6.8u.mat',
                         % '10_1k_470u.mat', '1k_1M_100p.mat',
                         % '510_100k_10n.mat'

% Select Warburg type: 'short' or 'open'
warburg_type = 'open';  % 'short' for reflective boundary, 'open' for transmissive

fprintf('=== Zfit Analysis - Warburg Model ===\n');
fprintf('File: %s\n', mat_file);
fprintf('Warburg type: %s\n\n', warburg_type);

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

%% Define Warburg Element Functions
% Zfit requires SINGLE-LETTER function names
% W = Warburg Short, O = Warburg Open

if strcmp(warburg_type, 'short')
    % Create Warburg Short function (W) if it doesn't exist
    if ~exist('W.m', 'file')
        fid = fopen('W.m', 'w');
        fprintf(fid, 'function z = W(p, f)\n');
        fprintf(fid, '%% Warburg Short (finite-length diffusion with reflective boundary)\n');
        fprintf(fid, '%% Z_Ws = (Aw/sqrt(w)) * tanh(B*sqrt(jw)) / sqrt(jw)\n');
        fprintf(fid, '%% p(1) = Aw: Warburg coefficient\n');
        fprintf(fid, '%% p(2) = B: Diffusion time constant related parameter\n');
        fprintf(fid, 'omega = 2*pi*f;\n');
        fprintf(fid, 'Aw = p(1);\n');
        fprintf(fid, 'B = p(2);\n');
        fprintf(fid, 'z = (Aw ./ sqrt(omega)) .* tanh(B .* sqrt(1i*omega)) ./ sqrt(1i*omega);\n');
        fprintf(fid, 'end\n');
        fclose(fid);
        fprintf('Created W.m (Warburg Short)\n\n');
    end
    warburg_letter = 'W';
    warburg_name = 'Warburg Short';

elseif strcmp(warburg_type, 'open')
    % Create Warburg Open function (O) if it doesn't exist
    if ~exist('O.m', 'file')
        fid = fopen('O.m', 'w');
        fprintf(fid, 'function z = O(p, f)\n');
        fprintf(fid, '%% Warburg Open (finite-length diffusion with transmissive boundary)\n');
        fprintf(fid, '%% Z_Wo = (Aw/sqrt(w)) * coth(B*sqrt(jw)) / sqrt(jw)\n');
        fprintf(fid, '%% p(1) = Aw: Warburg coefficient\n');
        fprintf(fid, '%% p(2) = B: Diffusion time constant related parameter\n');
        fprintf(fid, 'omega = 2*pi*f;\n');
        fprintf(fid, 'Aw = p(1);\n');
        fprintf(fid, 'B = p(2);\n');
        fprintf(fid, 'z = (Aw ./ sqrt(omega)) .* coth(B .* sqrt(1i*omega)) ./ sqrt(1i*omega);\n');
        fprintf(fid, 'end\n');
        fclose(fid);
        fprintf('Created O.m (Warburg Open)\n\n');
    end
    warburg_letter = 'O';
    warburg_name = 'Warburg Open';
else
    error('warburg_type must be either ''short'' or ''open''');
end

%% Circuit Model and Fitting
% Circuit: Rs + ((R + Warburg) || CPE)
% This represents: Series resistance + (Charge transfer resistance + Warburg diffusion) in parallel with CPE

% Initial parameter guess
Rs_guess = min(Z_real);                      % Series resistance (high-freq limit)
Rct_guess = (max(Z_real) - min(Z_real))/2;  % Charge transfer resistance
Aw_guess = 100;                              % Warburg coefficient
B_guess = 0.1;                               % Diffusion parameter
Q_guess = 1e-9;                              % CPE pseudo-capacitance
n_guess = 0.85;                              % CPE exponent

% Circuit string: Rs + ((Rct + Warburg) || CPE)
circuit_string = sprintf('s(R1,p(s(R1,%s2),E2))', warburg_letter);
param_guess = [Rs_guess, Rct_guess, Aw_guess, B_guess, Q_guess, n_guess];

fprintf('Circuit model: Rs + ((Rct + %s) || CPE)\n', warburg_name);
fprintf('  Rs: Series resistance\n');
fprintf('  Rct: Charge transfer resistance\n');
fprintf('  %s: %s element (2 params: Aw, B)\n', warburg_letter, warburg_name);
fprintf('  CPE: Constant Phase Element (2 params: Q, n)\n');
fprintf('Fitting...\n\n');

% Fitting parameters
LB = [0, 0, 0, 0, 1e-12, 0.5];   % Lower bounds
UB = [inf, inf, inf, inf, 1, 1.0]; % Upper bounds
indexes = [];                      % Use all data points
fitstring = 'fitNP';               % Non-proportional weighting

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

fprintf('Circuit: Rs + ((Rct + %s) || CPE)\n\n', warburg_name);

fprintf('Fitted Parameters:\n');
fprintf('  Rs  = %.2f Ω\n', pbest(1));
fprintf('  Rct = %.2f Ω\n', pbest(2));
fprintf('  Aw  = %.2e Ω·s^0.5\n', pbest(3));
fprintf('  B   = %.2e s^0.5\n', pbest(4));
fprintf('  Q   = %.2e F·s^(n-1)\n', pbest(5));
fprintf('  n   = %.4f\n\n', pbest(6));

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
