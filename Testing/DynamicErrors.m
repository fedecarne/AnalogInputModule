clear all -g
close all

% Connect whith AnalogIn Module
conn = AnalogModule('COM13');

% Connect with Pulse Pal Wave Generator
WaveGen=PulsePalWaveGen('COM14');
WaveGen.playbackMode = 'triggered';


ProgramAnalogModuleParam('ActiveChannels', 8);
ProgramAnalogModuleParam('VoltageRange', 1:8, 1*ones(1,8)); %-10V to 10V
SamplingPeriod = 0.5; %in ms
ProgramAnalogModuleParam('SamplingPeriod', SamplingPeriod);


WaveGen.duration = 1;
WaveGen.frequency = 50;
WaveGen.amplitude = 20;
WaveGen.waveform = 'sine';
pause(1);

ChannelToTest = 7;

%%
close all
    
trigger(WaveGen)

StartLogging;

pause(WaveGen.duration-0.1) % stop logging before waveform finishes

data = RetrieveData;
xdata = data.x;
ydata = data.y;

initial_delay = 100; %in ms
y = ydata(1,ceil(initial_delay/SamplingPeriod):end);
x = xdata(1,ceil(initial_delay/SamplingPeriod):end);


%% plotting
width = 4;
height = 3;

f1 = figure('Visible','off');
set(gcf, 'PaperUnits', 'inches')
set(gcf, 'PaperSize',[width height])
set(gcf, 'PaperPosition',[0 0 width height])
plot(x(1:100),y(1:100),'-','linewidth',1)
box off
axis([x(1) x(100) -12 12])
ylabel('Signal (V)')
xlabel('Time (s)')
print('-dpng', 'sine.png','-r300');
close
    

f2 = figure('Visible','off');
set(gcf, 'PaperUnits', 'inches')
set(gcf, 'PaperSize',[width height])
set(gcf, 'PaperPosition',[0 0 width height])
Fs = 1/SamplingPeriod*1000;
snr(y,Fs);
grid off
legend boxoff
h = gca;
h.Box = 'off';
sn = snr(y,Fs);
s = sinad(y);
t = thd(y);
h.Title.String = ['SNR: ' num2str(sn,'%2.0f') ' dB    '...
                  'THD: ' num2str(t,'%2.0f') ' dB    '...
                  'SINAD: ' num2str(s,'%2.0f') ' dB'];
h.Title.FontSize=9;
print('-dpng', 'fourier.png','-r300');
close

%%

% SNR Vs Sampling Freq


Fs = 500:1000:20000;
nFs = size(Fs,2);

WaveGen.duration = 1;
WaveGen.frequency = 10;
WaveGen.amplitude = 20;
WaveGen.waveform = 'sine';
pause(1);

SNR = nan(1,nFs);

for i=1:nFs
i
    SamplingPeriod = 1000/Fs(i);
    ProgramAnalogModuleParam('SamplingPeriod', SamplingPeriod);
    pause(0.5);
    
    trigger(WaveGen)

    StartLogging;

    pause(WaveGen.duration-0.1) % stop logging before waveform finishes

    data = RetrieveData;
    xdata = data.x;
    ydata = data.y;

    initial_delay = 100; %in ms
    y = ydata(1,ceil(initial_delay/SamplingPeriod):end);

    SNR(1,i) = snr(y,Fs(i));
    SINAD = sinad(y);
    THD = thd(y);
    
    [size(ydata,2) (WaveGen.duration-0.1)*Fs(i)]
    xdata(1)
end

%% plotting
width = 4;
height = 3;

f1 = figure('Visible','off');
set(gcf, 'PaperUnits', 'inches')
set(gcf, 'PaperSize',[width height])
set(gcf, 'PaperPosition',[0 0 width height])
plot(Fs/1000,SNR,'.','markersize',20)
h=gca;
h.YAxis.Limits = [50 70];
box off
grid
ylabel('SNR')
xlabel('Sampling Frequency (kHz)')
print('-dpng', 'SnrVsFs.png','-r300');
%close
