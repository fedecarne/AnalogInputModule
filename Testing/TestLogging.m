% Connect whith AnalogIn Module
Ain = BpodAnalogIn('COM38');

% Set AnalogIn properties
Ain.ActiveChannels = 5;
Ain.SamplingRate = 100;
Ain.VoltageRange = {1:8, '-10V:10V'};

% Connect and configure Bpod Wave Generator
WaveGen = BpodWavePlayer('COM36');
WaveGen.TriggerMode = 'Normal';
WaveGen.SamplingRate = 100;
WaveGen.OutputRange = '-10V:10V';

%% Run play and record commands
WaveGen.play(1,1);
Ain.StartLogging;
pause(Duration-0.1) % stop logging before waveform finishes
data = Ain.RetrieveData;
xdata = data.x;
ydata = data.y;
%%


%plotting
width = 4;
height = 3;
f1 = figure;
set(gcf, 'PaperUnits', 'inches')
set(gcf, 'PaperSize',[width height])
set(gcf, 'PaperPosition',[0 0 width height])
plot(x,y,'-','linewidth',1)
box off
axis([x x -12 12])
ylabel('Signal (V)')
xlabel('Time (s)')


