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

function ProgramAnalogModuleParam(ParamCode, varargin)

% ParamCode = Parameter code for transmission from the following list:
% 1: Sampling Period
%       varargin{1}: sampling period
% 2: Voltage Range
%       varargin{1}: ParamChannel
%       varargin{2}: ParamValue
% 3: Active Channels
%       varargin{1}: ParamChannel
%       varargin{2}: ParamValue
% 4: Thresholds
%       varargin{1}: ParamChannel
%       varargin{2}: ParamValue
% 5: ResetValues
%       varargin{1}: ParamChannel
%       varargin{2}: ParamValue

% To Do:
% Add confirmation byte

% convert string param code to integer
global AnalogModuleSystem;

ValidParamCodes = 1:4;
if ischar(ParamCode)
    ParamCode = strcmpi(ParamCode, AnalogModuleSystem.ParamNames);
    if sum(ParamCode) == 0
        error('Error: invalid parameter code.')
    end
    ParamCode = find(ParamCode);
elseif ~ismember(ParamCode, ValidParamCodes)
        error('Error: invalid parameter code.')
end

switch ParamCode
    
    case 1 % Sampling Period
        ParamValue = varargin{1};
        
        if ParamValue<0 || ParamValue>1000
           error('Sampling period (ms) must be a value from 0 to 1000.');
        end
        
        SamplingPerdiodUS = ParamValue*1000; % in US
        AnalogModuleSystem.SerialPort.write(uint8([213 75]), 'uint8', SamplingPerdiodUS , 'uint32');
        AnalogModuleSystem.SamplingPeriod = ParamValue;
        
    case 2 % Voltage Range
        
        %1: '-10V - 10V'
        %2: '-5V - 5V'
        %3: '-2.5V - 2.5V'
        %4: '0V - 10V'
        
        % Builds bytes with individual voltage ranges
        % Prepared to be easily loaded in ADC range registers
        
        ParamChannel = varargin{1};
        ParamValue = varargin{2};
        
        if any(ParamValue<1 | ParamValue>4)
           error('VoltageRange must be a value from 1 to 4');
        end
        
        auxbyte1=0;
        auxbyte2=0;
        AnalogModuleSystem.VoltageRange = ones(8,1);
        for i=1:length(ParamChannel)
            AnalogModuleSystem.VoltageRange(ParamChannel(i)) = ParamValue(i);
            if ParamChannel(i)<5
                auxbyte1 = bitor((ParamValue(i)-1)*2^(2*(4-ParamChannel(i))),auxbyte1);
            else
                auxbyte2 = bitor((ParamValue(i)-1)*2^(2*(8-ParamChannel(i))),auxbyte2);
            end
        end

        VoltageRangeByte1 = auxbyte1;
        VoltageRangeByte2 = auxbyte2;
        AnalogModuleSystem.SerialPort.write(uint8([213 83 VoltageRangeByte1 VoltageRangeByte2]), 'uint8');


    case 3 % Active Channels
        
        ParamValue = varargin{1}; % is a list of active channels
        
        if any(ParamValue<1 | ParamValue>8)
           error('ChannelActive must be a value from 0 to 7.');
        end
        
        auxbyte=0;
        for i=1:length(ParamValue)
            auxbyte = bitor(2^(8-ParamValue(i)), auxbyte);
        end
        
        ActiveChannelsByte = auxbyte;
        AnalogModuleSystem.ActiveChannels = sort(ParamValue);
        AnalogModuleSystem.SerialPort.write(uint8([213 82 ActiveChannelsByte]), 'uint8');

    case 4 % Threshold
        
        ParamChannel = varargin{1};
        ParamValue = varargin{2};
        
        AnalogModuleSystem.CurrentThresholds = zeros(8,1);
        
        for i=1:length(ParamChannel)
            AnalogModuleSystem.CurrentThresholds(ParamChannel(i)) = ParamValue(i);
        end
        
        %Rescale thresholds according to voltage range.
        RawThresholds = ScaleValue('toRaw',AnalogModuleSystem.CurrentThresholds,AnalogModuleSystem.VoltageRange);
        AnalogModuleSystem.SerialPort.write(uint8([213 67]), 'uint8',RawThresholds', 'uint32');
        
    case 5 % ResetValues
        
        ParamChannel = varargin{1};
        ParamValue = varargin{2};
        
        AnalogModuleSystem.CurrentResetValues = zeros(8,1);
        
        for i=1:length(ParamChannel)
            AnalogModuleSystem.CurrentResetValues(ParamChannel(i)) = ParamValue(i);
        end
        
        %Rescale thresholds according to voltage range.
        RawResetValues = ScaleValue('toRaw',AnalogModuleSystem.CurrentResetValues,AnalogModuleSystem.VoltageRange);
        AnalogModuleSystem.SerialPort.write(uint8([213 64]), 'uint8',RawResetValues', 'uint32');  
end


% ConfirmBit =    AnalogModuleSystem.Port.read(1, 'uint8');
% if ConfirmBit == 1
%     AnalogModuleSystem.Params.(AnalogModuleSystem.ParamNames{ParamCode})(Channel) = OriginalValue;
%     AnalogModuleSystem.CurrentProgram{ParamCode+1,Channel+1} = OriginalValue;
% end
