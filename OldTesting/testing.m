
% Connect whith AnalogIn Module
conn = AnalogModule('COM13');
global AnalogModuleSystem

% Connect with Pulse Pal Wave Generator
WaveGen=PulsePalWaveGen('COM14');
WaveGen.playbackMode = 'triggered';


ProgramAnalogModuleParam('VoltageRange', 1:8, 1*ones(1,8)); %-10V to 10V
ProgramAnalogModuleParam('SamplingPeriod', 20);

WaveGen.frequency = 5;
WaveGen.duration = 2;

trigger(WaveGen)
StartLogging;

pause(WaveGen.duration)

% Send 'Retrieve' command to the AM
AnalogModuleSystem.SerialPort.write(uint8([213 70]), 'uint8');
waiting = 1; timeout=0;TimeOut = 2; tic; catchfirst=0;
while waiting
    
    if AnalogModuleSystem.SerialPort.bytesAvailable>0 && catchfirst==0
        tStart = tic;
        catchfirst = 1;
    end
    
    bytesAvailable1 = AnalogModuleSystem.SerialPort.bytesAvailable;
    pause(0.2);
    bytesAvailable2 = AnalogModuleSystem.SerialPort.bytesAvailable;
    if bytesAvailable1 == bytesAvailable2 && bytesAvailable2>0
        waiting=0;
    end
    if toc> TimeOut
        timeout=1;
        disp('A TimeOut has occurred.')
        r =[];
        return
    end
end

t=toc(tStart);
disp('---------------');
disp(['N bytes: ' num2str(AnalogModuleSystem.SerialPort.bytesAvailable)]);
disp(['Transfering time: ' num2str(t) 's.']);

tStart = tic;

i=0;
rawdata = nan(1,floor(AnalogModuleSystem.SerialPort.bytesAvailable/4));
while AnalogModuleSystem.SerialPort.bytesAvailable>3
    i=i+1;
    rawdata(1,i) = AnalogModuleSystem.SerialPort.read(1, 'uint32');
end

t=toc(tStart);
disp(['Reading time: ' num2str(t) 's.']);

nActiveChannels = size(AnalogModuleSystem.ActiveChannels,2);
y = nan(nActiveChannels,ceil(size(rawdata,2)/(nActiveChannels+1)));
for i=1:nActiveChannels
    x = ScaleTime(rawdata(1:nActiveChannels+1:end));
    d = rawdata(i+1:nActiveChannels+1:end);
    zerofill = size(y,2)-size(d,2);
    y(i,:) = ScaleValue('toVolts',[d zeros(1,zerofill)],AnalogModuleSystem.VoltageRange(AnalogModuleSystem.ActiveChannels(i)));
end
r.x = x;
r.y = y;

plot(r.x,r.y)
axis([0 r.x(end) -10 10])


