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

global AnalogModuleSystem;

nBytesAvailable = AnalogModuleSystem.SerialPort.bytesAvailable;
if nBytesAvailable > 0
	AnalogModuleSystem.SerialPort.read(nBytesAvailable, 'uint8')
end

%Send disconnect command
AnalogModuleSystem.SerialPort.write(uint8([213 81]), 'uint8');

%Close serial port
AnalogModuleSystem.SerialPort.close;
clear global AnalogModuleSystem

disp('AnalogModule successfully disconnected.')