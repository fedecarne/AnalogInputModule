clear all -g
close all

% Connect whith AnalogIn Module
Ain.delete
Ain = BpodAnalogIn('COM39');
Ain.ActiveChannels = 1;
Ain.SamplingRate = 100000;
Ain.VoltageRange = {1:8, '-10V:10V'};

% Connect with Bpod Wave Generator
WaveGen = BpodWavePlayer('COM36');
WaveGen.TriggerMode = 'Normal';
WaveGen.SamplingRate = 50000;
WaveGen.OutputRange = '-10V:10V';

% Load waveform
Duration = 1.5;
Frequency = 100;
Amplitude = 10;
ChannelToTest = 1;

t = 0:1/WaveGen.SamplingRate:Duration;
y = Amplitude*sin(2*pi*Frequency*t);
WaveGen.loadWaveform(1,y);

close all

%% Run
WaveGen.play(1,1);
Ain.StartLogging;
pause(Duration) % stop logging before waveform finishes
data = Ain.RetrieveData;
    
%%
xdata = data.x;
ydata = data.y;
plot(xdata,ydata)
xdata(end)

initial_delay = 0.100; %in ms
y = ydata(1,ceil(initial_delay*Ain.SamplingRate):end);
x = xdata(1,ceil(initial_delay*Ain.SamplingRate):end);

% plotting
width = 4;
height = 3;

f1 = figure%('Visible','off');
set(gcf, 'PaperUnits', 'inches')
set(gcf, 'PaperSize',[width height])
set(gcf, 'PaperPosition',[0 0 width height])
plot(x,y,'-','linewidth',1)
box off
xlim = get(gca,'xlim');
axis([xlim -12 12])
ylabel('Signal (V)')
xlabel('Time (s)')
print('-dpng', 'figs/sine.png','-r300');
close
    

f2 = figure%('Visible','off');
set(gcf, 'PaperUnits', 'inches')
set(gcf, 'PaperSize',[width height])
set(gcf, 'PaperPosition',[0 0 width height])
Fs = Ain.SamplingRate;
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
print('-dpng', 'figs/fourier.png','-r300');
close

%%

% SNR Vs Sampling Freq


Fs = 1000:20000:120400;
nFs = size(Fs,2);

Duration = 1;
Frequency = 100;
Amplitude = 10;

t = 0:1/WaveGen.SamplingRate:Duration;
yload = Amplitude*sin(2*pi*Frequency*t);
WaveGen.loadWaveform(1,yload);

SNR = nan(1,nFs);
for i=1:nFs

    disp(['Sampling: ' num2str(Fs(i))])
    
    Ain.SamplingRate = Fs(i);

    pause(0.5);
    
    WaveGen.play(1,1)

    Ain.StartLogging;

    pause(Duration-0.1) % stop logging before waveform finishes

    data = Ain.RetrieveData;
    xdata = data.x;
    ydata = data.y;

    initial_delay = 0.100; %in ms
    y = ydata(1,ceil(initial_delay*Ain.SamplingRate):end);
    size(ydata,2)
    (Duration-0.1)*Ain.SamplingRate

    SNR(1,i) = snr(y,Fs(i));
    SINAD = sinad(y);
    THD = thd(y);
    
end

%% plotting
width = 4;
height = 3;

f1 = figure;%('Visible','off');
set(gcf, 'PaperUnits', 'inches')
set(gcf, 'PaperSize',[width height])
set(gcf, 'PaperPosition',[0 0 width height])
plot(Fs/1000,SNR,'.','markersize',20)
h=gca;
h.YAxis.Limits = [0 60];
box off
grid
ylabel('SNR (dB)')
xlabel('Sampling Frequency (kHz)')
print('-dpng', 'figs/SnrVsFs.png','-r300');
%close

