close all

% Connect whith AnalogIn Module
conn = AnalogModule('COM13');
global AnalogModuleSystem

% Connect with Pulse Pal Wave Generator
WaveGen=PulsePalWaveGen('COM14');
WaveGen.playbackMode = 'triggered';

ProgramAnalogModuleParam('VoltageRange', 1:8, 1*ones(1,8)); %-10V to 10V
SamplingPeriod = 50; %in ms
ProgramAnalogModuleParam('SamplingPeriod', SamplingPeriod);

duration = 1; % seconds
WaveGen.customWaveformSF = 10;
WaveGen.customWaveform = 0*zeros(1,duration*WaveGen.customWaveformSF);
WaveGen.waveform = 'custom';

ChannelToTest = 7;
PointsToTest = -10:20/(10-1):10;
nPoints = size(PointsToTest,2);

MeasuredPoint = nan(1,nPoints);
MeasuredPointSE= nan(1,nPoints);

close all
figure;
hold on
for i=1:nPoints

    WaveGen.customWaveform = PointsToTest(i)*ones(1,duration*WaveGen.customWaveformSF);
    pause(0.5);
    
    trigger(WaveGen)
        
    StartLogging;

    pause(duration-0.2) % stop logging before waveform finishes

    data = RetrieveData;
    xdata = data.x;
    ydata = data.y;
    
    hold on
    plot(data.x,data.y,'.')
    axis([0 data.x(end) -12 12])
    
    y = ydata(ChannelToTest+1,ceil(400/SamplingPeriod):end);
    x = xdata(1,ceil(400/SamplingPeriod):end);
    plot(x,y,'o')
    
    MeasuredPoint(i) = mean(y);
    MeasuredPointSE(i) = std(y)/sqrt(size(y,2));
end

figure
hold on
errorbar(PointsToTest,MeasuredPoint,MeasuredPointSE/2,'.','MarkerSize',10)
axis([-11 11 -11 11]);
p = polyfit(PointsToTest,MeasuredPoint,1);
pfit = polyval(p,-10:10);
plot(-10:10,pfit)

text(-9,10,['Gain error: ' num2str(100*(1-p(1)),'%1.3f') '%'],'FontSize',12)
text(-9,8,['Offset error: ' num2str(1000*p(2),'%1.1f') ' mV'],'FontSize',12)

xlabel('Set Voltage (V)','FontSize',12)
ylabel('Measured Voltage (V)','FontSize',12)
