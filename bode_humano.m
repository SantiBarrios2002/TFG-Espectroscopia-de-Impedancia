% Correct format:
num = [1e-6 1];
den = [1.1e-5 1];
gain = 100;
sys = tf(gain*num, den);  % Create transfer function correctly

% Display the transfer function
disp('Transfer Function:')
sys

% Calculate key characteristics
dc_gain = dcgain(sys);
[wn, zeta] = damp(sys);
[Gm, Pm, Wcg, Wcp] = margin(sys);
% poles = pole(sys);
zeros = tzero(sys);
bw = bandwidth(sys);

% Create a figure for the Bode plot with important information
figure
bode(sys);
title('Bode Plot');
grid on

% Add textbox with important characteristics
annotation('textbox', [0.15, 0.15, 0.3, 0.3], 'String', {
    ['DC Gain: ' num2str(dc_gain) ' (' num2str(20*log10(dc_gain)) ' dB)'], ...
    ['Bandwidth: ' num2str(bw) ' rad/s'], ...
    ['Phase Margin: ' num2str(Pm) '° at ' num2str(Wcp) ' rad/s'], ...
    ['Gain Margin: ' num2str(20*log10(Gm)) ' dB at ' num2str(Wcg) ' rad/s'], ...
    ['Time Constant: ' num2str(8.5e-4) ' s'], ...
    ['Zero: ' num2str(-1/(5e-5)) ' rad/s']}, ...
    'FitBoxToText', 'on', 'BackgroundColor', 'white');

% Create a figure for the Nyquist plot
figure
nyquist(sys);
title('Nyquist Plot');
grid on

% Add information to Nyquist plot too
annotation('textbox', [0.6, 0.15, 0.3, 0.2], 'String', {
    ['DC Gain: ' num2str(dc_gain)], ...
    ['Phase Margin: ' num2str(Pm) '°']}, ...
    'FitBoxToText', 'on', 'BackgroundColor', 'white');