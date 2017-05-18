%{
----------------------------------------------------------------------------

This file is part of the Sanworks Analog Module repository
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
function AnalogModuleSerialInit(varargin)

global AnalogModuleSystem

disp('Searching for AnalogModule device. Please wait.')

LastPortPath = fullfile(AnalogModuleSystem.AnalogModulePath, 'LastSerialPortUsed.mat');
if nargin > 1
    Ports = varargin(1);
else
    % Make list of all ports
    if ispc
        Ports = FindAnalogModulePorts;
    elseif ismac
        [trash, RawSerialPortList] = system('ls /dev/tty.*');
        Ports = ParseCOMString_MAC(RawSerialPortList);
    else
        VerifyMatlabSerialPortAccessForUbuntu;
        [trash, RawSerialPortList] = system('ls /dev/ttyACM*');
        Ports = ParseCOMString_LINUX(RawSerialPortList);
    end
    if isempty(Ports)
        error('Could not connect to Analog Module: no available serial ports found.');
    end
    % Make it search on the last successful port first
    if (exist(LastPortPath) == 2)
        load(LastPortPath);
        pos = strmatch(LastComPortUsed, Ports, 'exact'); 
        if ~isempty(pos)
            Temp = Ports;
            Ports{1} = LastComPortUsed;
            Ports(2:length(Temp)) = Temp(1:length(Temp) ~= pos);
        end
    end
end

if isempty(Ports)
    error('Could not connect to Analog Module: no available serial ports found.');
end
if isempty(Ports{1})
    error('Could not connect to Analog Module: no available serial ports found.');
end

%%Exclude Serial Port used by bpod
try 
    global BpodSystem
    bpodPort = BpodSystem.SerialPort.Port;
    for i=1:length(Ports)
        if (strcmp(Ports{1,i},bpodPort))
            Ports{i}=[];
        end
    end
    Ports = Ports(~cellfun('isempty',Ports));
end


Found = 0;
i = 0;
while (Found == 0) && (i < length(Ports))
  i = i + 1;
  disp(['Trying port ' Ports{i}])

    try
      TestPort = ArCOMObject(Ports{i}, 115200);
      AvailablePort = 1;
    catch
      AvailablePort = 0;
    end
    if AvailablePort == 1
        pause(.5);

        %Handshake
        TestPort.write(uint8([AnalogModuleSystem.OpMenuByte 72]), 'uint8');
        tic
        while TestPort.bytesAvailable == 0
          TestPort.write(uint8([AnalogModuleSystem.OpMenuByte 72]), 'uint8');
          if toc > 1
            break
          end
          pause(.1);
        end
        g = 0;
        try
          Byte = TestPort.read(1, 'uint8');
        catch
          error('Cound not connect to Analog Module') 
        end
        if Byte == 75
          Found = i;
        end
        %Close Port
        TestPort.close;
        pause(.1);
    end
end
    
if Found ~= 0
    if ispc
        PortString = [Ports{Found}];
    else
        PortString = Ports{Found};
    end

    if nargin > 1         
     forceOption = varargin{2};
         switch lower(forceOption)
            case 'java'
              AnalogModuleSystem.SerialPort = ArCOMObject(PortString, 115200,'java');
            case 'psychtoolbox'
              AnalogModuleSystem.SerialPort = ArCOMObject(PortString, 115200,'psychtoolbox');
            otherwise
              error('The third argument to ArCOM(''init'' must be either ''java'' or ''psychtoolbox''');
        end
    else
      AnalogModuleSystem.SerialPort = ArCOMObject(PortString, 115200);
    end

else
    error('Error: could not find your Analog Module device. Please make sure it is connected and drivers are installed.');                 
end



LastComPortUsed = Ports{Found};
if AnalogModuleSystem.UsingOctave
    save('-mat7-binary', LastPortPath, 'LastComPortUsed');
else
    save(LastPortPath, 'LastComPortUsed');
end
pause(.1);
disp(['AnalogModule connected on port ' Ports{Found}]);
    


function VerifyMatlabSerialPortAccessForUbuntu
if exist([matlabroot '/bin/glnxa64/java.opts']) ~= 2
    disp(' ');
    disp('**ALERT**')
    disp('Linux64 detected. A file must be copied to the MATLAB root, to gain access to virtual serial ports.')
    disp('This file only needs to be copied once.')
    input('Will try to copy this file from the repository automatically. Press return... ')
    try
        system(['sudo cp ' AnalogModuleSystem.AnalogModulePath 'java.opts ' matlabroot '/bin/glnxa64']);
        disp(' ');
        disp('**SUCCESS**')
        disp('File copied! Please restart MATLAB and run AnalogModule again.')
        return
    catch
        disp('File copy error! MATLAB may not have administrative privileges.')
        disp('Please copy /AnalogModule/MATLAB/java.opts to the MATLAB java library path.')
        disp('The path is typically /usr/local/MATLAB/R2014a/bin/glnxa64, where r2014a is your MATLAB release.')
        return
    end
end