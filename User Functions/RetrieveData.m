%{
----------------------------------------------------------------------------

This file is part of the Sanworks Pulse Pal repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

function r = RetrieveData(varargin)
% This function retrieves data from the SD memory card
% TO DO:

verbose=1;

global AnalogModuleSystem;

while AnalogModuleSystem.SerialPort.bytesAvailable>0
    AnalogModuleSystem.SerialPort.read(1, 'uint8');
end

% Send 'Retrieve' command to the AM
AnalogModuleSystem.SerialPort.write(uint8([213 70]), 'uint8');

            
% Wait for SD transmition or time out
waiting = 1; timeout=0;SDTransferTimeOut = 2; tic; catchfirst=0;
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
    if toc> SDTransferTimeOut
        timeout=1;
        disp('An SD TimeOut has occurred.')
        r =[];
        return
    end
end


t=toc(tStart);
if verbose
    disp('---------------');
    disp(['N bytes: ' num2str(AnalogModuleSystem.SerialPort.bytesAvailable)]);
    disp(['Transfering time: ' num2str(t) 's.']);
end

tStart = tic;

i=0;
rawdata = nan(1,AnalogModuleSystem.SerialPort.bytesAvailable/4);
while AnalogModuleSystem.SerialPort.bytesAvailable>3
    i=i+1;
    rawdata(1,i) = AnalogModuleSystem.SerialPort.read(1, 'uint32');
end

t=toc(tStart);
disp(['Reading time: ' num2str(t) 's.']);

nActiveChannels = size(AnalogModuleSystem.ActiveChannels,2);
y = nan(nActiveChannels,size(rawdata,2)/(nActiveChannels+1));
for i=1:nActiveChannels
    x = ScaleTime(rawdata(1:nActiveChannels+1:end));
    y(i,:) = ScaleValue('toVolts',rawdata(i+1:nActiveChannels+1:end),AnalogModuleSystem.VoltageRange(AnalogModuleSystem.ActiveChannels(i)));
end
r.x = x;
r.y = y;

