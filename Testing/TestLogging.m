% Connect whith AnalogIn Module
Ain = BpodAnalogIn('COM37');

% Connect with Bpod Wave Generator
WaveGen = BpodWavePlayer('COM36');
WaveGen.TriggerMode = 'Normal';
WaveGen.SamplingRate = 10;
WaveGen.OutputRange = '-10V:10V';


Duration = 5;
Frequency = 1;
Amplitude = 5;
ChannelToTest = 7;

t = 0:1/WaveGen.SamplingRate:Duration;
y = Amplitude*sin(2*pi*Frequency*t);
y = Amplitude*ones(1,size(t,2));
WaveGen.loadWaveform(1,y);

WaveGen.play(1,1);

Ain.ActiveChannels = 8;
Ain.SamplingRate = 2000;
Ain.VoltageRange = {1:8, '-10V:10V'};


