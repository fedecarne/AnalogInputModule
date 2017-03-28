% Connect whith AnalogIn Module
Ain = BpodAnalogIn('COM37');

% Connect with Bpod Wave Generator
WaveGen = BpodWavePlayer('COM36');
WaveGen.TriggerMode = 'Normal';
WaveGen.SamplingRate = 10;
WaveGen
.OutputRange = '-10V:10V';


Duration = 5;
Frequency = 1;
Amplitude = 5;
ChannelToTest = 7;

t = 0:1/WaveGen.SamplingRate:Duration;
y = Amplitude*sin(2*pi*Frequency*t);
WaveGen.loadWaveform(1,y);

WaveGen.play(1,1);

Ain.ActiveChannels = 8;
Ain.SamplingRate = 100;
Ain.VoltageRange = {1:8, '-10V:10V'};

close all

WaveGen.play(1,1);

Ain.StartLogging;

pause(Duration-0.1) % stop logging before waveform finishes

data = Ain.RetrieveData;
    
xdata = data.x;
ydata = data.y;

initial_delay = 0.100; %in ms
y = ydata(1,ceil(initial_delay*Ain.SamplingRate):end);
x = xdata(1,ceil(initial_delay*Ain.SamplingRate):end);


%plotting
width = 4;
height = 3;

f1 = figure%('Visible','off');
set(gcf, 'PaperUnits', 'inches')
set(gcf, 'PaperSize',[width height])
set(gcf, 'PaperPosition',[0 0 width height])
plot(x(1:100),y(1:100),'-','linewidth',1)
box off
axis([x(1) x(100) -12 12])
ylabel('Signal (V)')
xlabel('Time (s)')
%print('-dpng', 'sine.png','-r300');
%close

