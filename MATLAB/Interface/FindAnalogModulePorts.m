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
% This function is a hacky way to find available Serial ports on Windows platforms.
% It was intended as a substitute for instrfind, a MATLAB instrument
% control toolbox command. If you have instrument control toolbox
% installed, you can use the following instead: Ports = instrfind;

function SerialPorts = FindAnalogModulePorts

% Find Arduino Due ports

% ------New discovery method, using powershell. 
[Status, RawString] = system('powershell.exe -inputformat none -command "Get-WMIObject Win32_SerialPort"');
PortLocations = strfind(RawString, 'Arduino Due (');
nCandidatePorts = length(PortLocations);
ArduinoPorts = cell(1,nCandidatePorts);
for x = 1:nCandidatePorts
    Clip = RawString(PortLocations(x):PortLocations(x)+19);
    PortNameLocation = strfind(Clip, 'COM');
    PortName = Clip(PortNameLocation:end);
    ArduinoPorts{x} = PortName(uint8(PortName)>47);
end
if nCandidatePorts > 0
    ArduinoPorts = unique(ArduinoPorts);
    nPorts = length(ArduinoPorts);
else
    nPorts = 0;
end

SerialPorts = ArduinoPorts(1:nPorts);