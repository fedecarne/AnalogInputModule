% Connect whith AnalogIn Module
Ain = BpodAnalogIn('COM39');

% Set AnalogIn properties
Ain.ActiveChannels = 1;
Ain.SamplingRate = 100000;
Ain.VoltageRange = {1:8, '-10V:10V'};

Ain.StartUARTstreaming

%Ain.StopUARTstreaming
%Ain.delete


