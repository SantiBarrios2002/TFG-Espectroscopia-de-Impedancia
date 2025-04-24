%% Circuit Zboard

R1=100;
R2=200;
R3=300;
R4=340;
R5=510;
R6=1e3;
R7=2e3;
R8=3.01e3;
R9=4.02e3;
R10=4.99e3;
C11=1000e-12;
C12=0.01e-6;

R = R1+R2+R3+R4+R5+R6+R7+R8+R9+R10;
C = (C11*C12)/(C11+C12);


num = [R*C 1];
den = [1];
gain = 1;
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

% % Create a figure for the Nichols plot
% figure
% nichols(sys);
% title('Nichols Chart');
% grid on
% ngrid
% 
% % Step response for time domain characteristics
% figure
% step(sys);
% title('Step Response');
% grid on
% 
% % Calculate time-domain metrics
% stepinfo_data = stepinfo(sys);
% 
% % Add information to step response
% annotation('textbox', [0.15, 0.15, 0.3, 0.3], 'String', {
%     ['Rise Time: ' num2str(stepinfo_data.RiseTime) ' s'], ...
%     ['Settling Time: ' num2str(stepinfo_data.SettlingTime) ' s'], ...
%     ['Overshoot: ' num2str(stepinfo_data.Overshoot) ' %'], ...
%     ['Peak: ' num2str(stepinfo_data.Peak)]}, ...
%     'FitBoxToText', 'on', 'BackgroundColor', 'white');
