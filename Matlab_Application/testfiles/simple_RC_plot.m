% Simple R+(R||C) Circuit Analysis - Multiple Circuits
% Generate Bode and Nyquist plots for 5 different R+(R||C) circuits

clear; close all; clc;

%% Define 5 different circuits
circuits = [
    10,   100,   6.8e-6;    % Circuit 1
    10,   1e3,   470e-6;    % Circuit 2
    100,  10e3,  470e-9;    % Circuit 3
    510,  100e3, 10e-9;    % Circuit 4
    1e3,  1e6,   100e-12;    % Circuit 5
];

%% Frequency range: 1 Hz to 200 kHz
f = logspace(0, log10(200000), 1000);  % 1 Hz to 200 kHz
omega = 2*pi*f;
j = 1i;

%% Process each circuit in separate window
for i = 1:size(circuits, 1)

    % Get circuit parameters
    Rs = circuits(i, 1);
    R = circuits(i, 2);
    C = circuits(i, 3);

    %% Calculate impedance Z = Rs + (R || C)
    % Capacitor impedance
    Zc = 1 ./ (j * omega * C);

    % Parallel combination of R and C
    Z_parallel = (R .* Zc) ./ (R + Zc);

    % Total impedance
    Z = Rs + Z_parallel;

    %% Calculate characteristic frequency
    fc = 1 / (2 * pi * R * C);

    %% Create separate figure for this circuit
    figure('Position', [100 + i*50, 100 + i*30, 1200, 500], ...
           'Name', sprintf('Circuit %d', i));

    %% Nyquist Plot
    subplot(1, 3, 1);
    plot(real(Z), -imag(Z), 'b-', 'LineWidth', 2);
    grid on; axis equal;
    xlabel('Z'' (Real, Ω)');
    ylabel('-Z'''' (Imaginary, Ω)');
    title('Nyquist Plot');

    %% Bode Magnitude
    subplot(1, 3, 2);
    semilogx(f, 20*log10(abs(Z)), 'b-', 'LineWidth', 2);
    grid on;
    xlabel('Frequency (Hz)');
    ylabel('|Z| (dB)');
    title('Bode Magnitude');

    %% Bode Phase
    subplot(1, 3, 3);
    phase_deg = angle(Z) * 180 / pi;
    semilogx(f, phase_deg, 'b-', 'LineWidth', 2);
    grid on;
    xlabel('Frequency (Hz)');
    ylabel('Phase (degrees)');
    title('Bode Phase');
    ylim([-90, 10]);

    %% Format capacitance with appropriate units
    if C >= 1e-6
        C_str = sprintf('%.1fμF', C*1e6);
    elseif C >= 1e-9
        C_str = sprintf('%.0fnF', C*1e9);
    else
        C_str = sprintf('%.0fpF', C*1e12);
    end

    %% Add main title
    sgtitle(sprintf('Circuit %d: Rs=%.0fΩ, R=%.0fΩ, C=%s, fc=%.1fHz', ...
            i, Rs, R, C_str, fc), 'FontSize', 14);

    %% Display parameters
    fprintf('Circuit %d Parameters:\n', i);
    fprintf('  Rs = %.0f Ω\n', Rs);
    fprintf('  R = %.0f Ω\n', R);
    fprintf('  C = %.2e F (%s)\n', C, C_str);
    fprintf('  Characteristic frequency fc = %.1f Hz\n\n', fc);

end

fprintf('All 5 circuits plotted in separate windows!\n');