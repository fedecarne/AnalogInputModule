close all

% Connect whith AnalogIn Module
Ain = BpodAnalogIn('COM38');
Ain = BpodAnalogIn('COM39');

Ain.ActiveChannels = 1;
Ain.SamplingRate = 200;
Ain.VoltageRange = {1:8, '-10V:10V'};

% Connect with Bpod Wave Generator
WaveGen = BpodWavePlayer('COM36');

WaveGen.TriggerMode = 'Normal';
WaveGen.SamplingRate = 1000;
WaveGen.OutputRange = '-10V:10V';

impedance = '500K';
impedance = '0K';
%impedance = '1000K';

Duration = 1;
ChannelToTest = 1;
PointsToTest = -10:20/10:10;

nPoints = size(PointsToTest,2);

MeasuredPoint = nan(1,nPoints);
MeasuredPointSE= nan(1,nPoints);
MaxError= nan(1,nPoints);

close all
figure;
hold on
for i=1:nPoints

    WaveGen.loadWaveform(1,PointsToTest(i)*ones(1,Duration*WaveGen.SamplingRate));
    
    pause(0.5);
    
    WaveGen.play(1,1)
        
    Ain.StartLogging;

    pause(Duration-0.2) % stop logging before waveform finishes

    data = Ain.RetrieveData;
    xdata = data.x;
    ydata = data.y;
    
    hold on
    plot(data.x,data.y,'.')
    
    y = ydata(1,ceil(0.2*Ain.SamplingRate):end);
    x = xdata(1,ceil(0.2*Ain.SamplingRate):end);
    plot(x,y,'o')
    
    MeasuredPoint(i) = mean(y);
    MaxError(i) = max(abs(y-PointsToTest(i)));
    MeasuredPointSE(i) = std(y)/sqrt(size(y,2));
end

save(['data-' impedance '.mat'],'PointsToTest','MeasuredPoint')
    
%% plotting
width = 8;
height = 3;

f1 = figure%('Visible','off');
set(gcf, 'PaperUnits', 'inches')
set(gcf, 'PaperSize',[width height])
set(gcf, 'PaperPosition',[0 0 width height])

subplot(1,2,1)
hold on
errorbar(PointsToTest,MeasuredPoint,MeasuredPointSE/2,'.','MarkerSize',10)
axis([-11 11 -11 11]);
p = polyfit(PointsToTest,MeasuredPoint,1);
pfit = polyval(p,-10:10);
plot(-10:10,pfit)
text(-9,10,['Gain error: ' num2str(100*(1-p(1)),'%1.3f') '%'],'FontSize',12)
text(-9,8,['Offset error: ' num2str(10^3*p(2),'%1.1f') ' mV'],'FontSize',12)
text(-9,6,['Max error: ' num2str(10^3*max(MaxError),'%1.1f') ' mV'],'FontSize',12)
xlabel('Set Voltage (V)','FontSize',12)
ylabel('Measured Voltage (V)','FontSize',12)

subplot(1,2,2)
hold on
errorbar(PointsToTest,PointsToTest-MeasuredPoint,MeasuredPointSE/2,'.','MarkerSize',10)
axis([-11 11 -0.1 0.1]);
p = polyfit(PointsToTest,PointsToTest-MeasuredPoint,1);
pfit = polyval(p,-10:10);
plot(-10:10,pfit)
text(-9,0.09,['Gain error: ' num2str(100*(p(1)),'%1.3f') '%'],'FontSize',12)
text(-9,0.07,['Offset error: ' num2str(10^3*p(2),'%1.1f') ' mV'],'FontSize',12)
text(-9,0.05,['Max error: ' num2str(10^3*max(MaxError),'%1.1f') ' mV'],'FontSize',12)
xlabel('Set Voltage (V)','FontSize',12)
ylabel('Error (V)','FontSize',12)
print('-dpng', ['figs/static-' impedance '.png'],'-r300');
close