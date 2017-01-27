clear all -g
close all

% Connect whith AnalogIn Module
conn = AnalogModule('COM13');

% Connect with Pulse Pal Wave Generator
WaveGen=PulsePalWaveGen('COM14');
WaveGen.playbackMode = 'triggered';


ProgramAnalogModuleParam('ActiveChannels', [1:8]);
ProgramAnalogModuleParam('VoltageRange', 1:8, 1*ones(1,8)); %-10V to 10V
Fs = 4800;
SamplingPeriod = 1000/Fs; %in ms
ProgramAnalogModuleParam('SamplingPeriod', SamplingPeriod);


WaveGen.duration = 0.0025;
WaveGen.frequency = 2000;
WaveGen.amplitude = 20;
WaveGen.waveform = 'sine';
pause(1);

ChannelToTest = 7;

%%    
StartLogging;
trigger(WaveGen)

%pause(WaveGen.duration-0.1) % stop logging before waveform finishes

data = RetrieveData;
xdata = data.x;
ydata = data.y;

(10^-3)/(xdata(2)-xdata(1))

%% plotting
width = 4;
height = 3;

%f1 = figure('Visible','off');
%figure
set(gcf, 'PaperUnits', 'inches')
set(gcf, 'PaperSize',[width height])
set(gcf, 'PaperPosition',[0 0 width height])
plot(xdata,ydata,'-','linewidth',1)
box off
% axis([x(1) x(100) -12 12])
ylabel('Signal (V)')
xlabel('Time (s)')
%print('-dpng', 'sine.png','-r300');
