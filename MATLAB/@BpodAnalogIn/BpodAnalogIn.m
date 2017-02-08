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

classdef BpodAnalogIn < handle
   
    properties(Constant)
        ValidRanges = {'-10V:10V', '-5V:5V', '-2.5V:2.5V','0V:10V'};
        ValidSamplingRates = [1 200000]; % Range of valid sampling rates
        nChannels = 8; % Number of input channels
    end
   
    properties
        Port % ArCOM Serial port
        RootPath = fileparts(which('AnalogInObject'));
        SamplingRate % 1Hz-50kHz, affects all channels
        VoltageRange
        ActiveChannels
        Thresholds
        ResetValues
    end
    
    properties (SetAccess = protected)
        FirmwareVersion = 0;
    end
    
    properties (Access = private)
        CurrentFirmwareVersion = 1;
        opMenuByte = 213; % Byte code to access op menu
        WaveformsLoaded = zeros(1,256);
        maxSimultaneousChannels = 4;
    end
    
    methods
        function obj = BpodAnalogIn(varargin)
           
            disp('Searching for AnalogIn device. Please wait.')

            if nargin > 0
                portString = varargin{1};
            else
                PortList = obj.findPulsePal();
                if ~isempty(PortList)
                    error(['You must call PulsePalObject with a serial port string argument. Likely serial ports are: ' PortList])
                else
                    error('You must call PulsePalObject with a serial port string argument.')
                end
            end
            
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write([obj.opMenuByte 72], 'uint8');
            pause(.1);
            HandShakeOkByte = obj.Port.read(1, 'uint8');
            if HandShakeOkByte == 75
                obj.FirmwareVersion = obj.Port.read(1, 'uint8');
                disp('AnalogIn module found.');
            else
                disp('Error: AnalogIn returned an unexpected handshake signature.')
            end
            
            obj.setDefaultParams;
        end
        
        % Method defined in a separate file
        h = Streamer(obj);
        h = Plot(obj);
        
        
        function setDefaultParams(obj)
            % Loads default parameters and sends them to the device
            obj.VoltageRange  = {1,obj.ValidRanges{1}};
            obj.ActiveChannels = 1:obj.nChannels;
            obj.SamplingRate = 1000;% 1Hz-50kHz, affects all channels
            obj.Thresholds = [(1:8)', zeros(obj.nChannels,1)];
            obj.ResetValues = zeros(1,obj.nChannels);
        end
               
        function set.SamplingRate(obj, sf)
            if sf < obj.ValidSamplingRates(1) || sf > obj.ValidSamplingRates(2)
                error(['Error setting sampling rate: valid rates are in range: [' num2str(obj.ValidSamplingRates) '] Hz'])
            end
            SamplingPeriodMicroseconds = (1/sf)*1000000;        
            obj.Port.write(uint8([213 75]), 'uint8', typecast(single(SamplingPeriodMicroseconds),'uint32'),'uint32');
            obj.SamplingRate = sf;
            if sf > 100000
                obj.maxSimultaneousChannels = 1;
            elseif sf > 75000
                obj.maxSimultaneousChannels = 2;
            elseif sf > 50000
                obj.maxSimultaneousChannels = 3;
            else
                obj.maxSimultaneousChannels = 4;
            end 
            
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting output range. Confirm code not returned.');
            end
        end
        
        function set.ActiveChannels(obj, activechan)
        
            if size(activechan,2)>obj.nChannels
                error(['ActiveChannels must be a vector of size smaller than ' num2str(obj.nChannels)]);
            end
            if any(activechan<1 | activechan>8)
               error('Elements in ActiveChannels must be a value from 0 to 7.');
            end
            
            auxbyte=0;
            for i=1:length(activechan)
                auxbyte = bitor(2^(8-activechan(i)), auxbyte);
            end

            ActiveChannelsByte = auxbyte;
            obj.Port.write(uint8([213 82 ActiveChannelsByte]), 'uint8');
            
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting active channels. Confirm code not returned.');
            end
            obj.ActiveChannels = sort(activechan);
        end
        
        function set.VoltageRange(obj, value)
            
            %1: '-10V - 10V'
            %2: '-5V - 5V'
            %3: '-2.5V - 2.5V'
            %4: '0V - 10V'
        
            % Expects: {1,'-10V-10V'; 3,'-2.5V-2.5V'; 7,'0V-10V'};
            
            Channels = [value{:,1}]; 
            RangeIndex = nan(1,size(Channels,2));
            for i=1:size(Channels,2)
                RangeString = value(i,2);
                RangeIndex(i) = find(strcmp(RangeString, obj.ValidRanges),1);
                if isempty(RangeIndex)
                    error(['Invalid range specified: ' RangeString '. Valid ranges are: ' obj.ValidRanges]);
                end
            end
                
            auxbyte1=0;
            auxbyte2=0;
            for i=1:size(Channels)
                if Channels(i)<5
                    auxbyte1 = bitor((RangeIndex(i)-1)*2^(2*(4-Channels(i))),auxbyte1);
                else
                    auxbyte2 = bitor((RangeIndex(i)-1)*2^(2*(8-Channels(i))),auxbyte2);
                end
            end

            VoltageRangeByte1 = auxbyte1;
            VoltageRangeByte2 = auxbyte2;
            
            obj.Port.write(uint8([213 83 VoltageRangeByte1 VoltageRangeByte2]), 'uint8');
            
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting output range. Confirm code not returned.');
            end
            
            obj.VoltageRange = obj.ValidRanges(ones(8,1));
            for i=1:size(Channels)
                obj.VoltageRange(Channels(i)) = obj.ValidRanges(RangeIndex(i));
            end
        end
        
        function set.Thresholds(obj, value)
            
            % Expects: [1,  5.0;...
            %           3,  -2.3;...
            %           7,  -5];
            
            Channels = value(:,1); 
            %Thr = value(:,2);
            
            % Add validation
            % ...
            
            % Set non-mentioned channels to 0
            Thr = zeros(8,1);
            for i=1:length(Thr)
                Thr(Channels(i)) = Thr(i);
            end
            
            %Rescale thresholds according to voltage range.
            RawThresholds = ScaleValue('toRaw',Thr,obj.VoltageRange);
            obj.Port.write(uint8([213 67]), 'uint8',RawThresholds', 'uint32');
            
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting output range. Confirm code not returned.');
            end
            
            obj.Thresholds = zeros(8,1);
            for i=1:size(Channels)
                obj.Thresholds(Channels(i)) = Thresholds(i);
            end
        end

        function set.ResetValues(obj, value)
            
            % Expects: [1,  5.0;...
            %           3,  -2.3;...
            %           7,  -5];
            
            Channels = value(:,1); 
            Values = value(:,2);
            
            % Add validation
            % ...
            
            % Set non-mentioned channels to 0
            Values = zeros(8,1);
            for i=1:length(ParamChannel)
                Values(Channels(i)) = Thr(i);
            end
            
            %Rescale thresholds according to voltage range.
            RawResetValues = ScaleValue('toRaw',Values,obj.ResetValues);
            obj.Port.write(uint8([213 64]), 'uint8',RawResetValues', 'uint32');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting output range. Confirm code not returned.');
            end
            
            obj.ResetValues = zeros(8,1);
            for i=1:size(Channels)
                obj.ResetValues(Channels(i)) = Values(i);
            end
        end
        
        function StartLogging(obj)
            
            obj.Port.write(uint8([213 68]), 'uint8');
            
        end
        
        function StopLogging(obj)
            
            obj.Port.write(uint8([213 68]), 'uint8');
            
        end
        
        function r = RetrieveData(obj)
            
            verbose=1;
                        
            while obj.Port.bytesAvailable>0
                obj.Port.read(1, 'uint8');
            end
            
            % Send 'Retrieve' command to the AM
            obj.Port.write(uint8([213 70]), 'uint8');
            
            % Wait for SD transmition or time out
            waiting = 1;timeout=0;TransferTimeOut = 60; tic; catchfirst=0;
            while waiting
                
                if obj.Port.bytesAvailable>0 && catchfirst==0
                    tStart = tic;
                    catchfirst = 1;
                end
                
                bytesAvailable1 = obj.Port.bytesAvailable;
                pause(0.2);
                bytesAvailable2 = obj.Port.bytesAvailable;
                if bytesAvailable1 == bytesAvailable2 && bytesAvailable2>0
                    waiting=0;
                end
                disp(toc)
                if toc> TransferTimeOut
                    timeout=1;
                    disp('An transfer timeout has occurred.')
                    r =[];
                    return
                end
            end
                       
            t=toc(tStart);
            if verbose
                disp('---------------');
                disp(['N bytes: ' num2str(obj.Port.bytesAvailable)]);
                disp(['Transfering time: ' num2str(t) 's.']);
            end
            
            tStart = tic;
            
            i=0;
            rawdata = nan(1,obj.Port.bytesAvailable/4);
            while obj.Port.bytesAvailable>3
                i=i+1;
                rawdata(1,i) = obj.Port.read(1, 'uint32');
            end
            
            t=toc(tStart);
            disp(['Reading time: ' num2str(t) 's.']);
            
            nActiveChannels = size(obj.ActiveChannels,2);
            y = nan(nActiveChannels,size(rawdata,2)/(nActiveChannels+1));
            for i=1:nActiveChannels
                x = ScaleTime(rawdata(1:nActiveChannels+1:end),obj.SamplingRate);
                d = rawdata(i+1:nActiveChannels+1:end);
                zerofill = size(y,2)-size(d,2);
                y(i,:) = ScaleValue('toVolts',[d zeros(1,zerofill)],obj.VoltageRange(obj.ActiveChannels(i)));
            end
            r.x = x;
            r.y = y;
            
        end
        
        function StartThresholdCrossing(obj)
            obj.Port.write(uint8([213 76]), 'uint8');
        end
        
        function StopThresholdCrossing(obj)
            obj.Port.write(uint8([213 77]), 'uint8');
        end

        function delete(obj)
             
            %Send disconnect command
            AnalogModuleSystem.SerialPort.write(uint8([213 81]), 'uint8');

            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
            disp('AnalogModule successfully disconnected.')
        end

    end
    
    methods (Access = private)
        function portStrings = findPulsePal(obj) % If no COM port is specified, give the user a list of likely candidates
            if ispc
                [~, RawString] = system('powershell.exe -inputformat none -command Get-WMIObject Win32_SerialPort');
                PortLocations = strfind(RawString, 'Arduino Due (');
                nCandidatePorts = length(PortLocations);
                ArduinoPorts = cell(1,nCandidatePorts);
                for x = 1:nCandidatePorts
                    Clip = RawString(PortLocations(x):PortLocations(x)+19);
                    PortNameLocation = strfind(Clip, 'COM');
                    PortName = Clip(PortNameLocation:end);
                    ArduinoPorts{x} = PortName(uint8(PortName)>47);
                end
            elseif ismac
                [~, RawSerialPortList] = system('ls /dev/tty.*');
                ArduinoPorts = obj.parseCOMString_MAC(RawSerialPortList);
            else
                [~, RawSerialPortList] = system('ls /dev/ttyACM*');
                ArduinoPorts = obj.parseCOMString_LINUX(RawSerialPortList);
            end
            nCandidatePorts = length(ArduinoPorts);
            if nCandidatePorts > 0
                ports = unique(ArduinoPorts);
                portStrings = [];
                for i = 1:length(ports)
                    portStrings = [portStrings '''' ports{i} ''''];
                    if i < length(ports)
                        portStrings = [portStrings ', '];
                    end
                end
            else
                portStrings = '';
            end
        end
           
        function Ports = parseCOMString_LINUX(obj, string)
            string = strtrim(string);
            PortStringPositions = strfind(string, '/dev/ttyACM');
            nPorts = length(PortStringPositions);
            CandidatePorts = cell(1,nPorts);
            nGoodPorts = 0;
            for x = 1:nPorts
                if PortStringPositions(x)+11 <= length(string)
                    CandidatePort = strtrim(string(PortStringPositions(x):PortStringPositions(x)+11));
                    nGoodPorts = nGoodPorts + 1;
                    CandidatePorts{nGoodPorts} = CandidatePort;
                end
            end
            Ports = CandidatePorts(1:nGoodPorts);
        end
        
        function Ports = parseCOMString_MAC(obj, string)
            string = strtrim(string);
            string = lower(string);
            nSpaces = sum(string == char(9)) + sum(string == char(10));
            if nSpaces > 0
                Spaces = find((string == char(9)) + (string == char(10)));
                Pos = 1;
                Ports = cell(1,nSpaces);
                for x = 1:nSpaces
                    Ports{x} = string(Pos:Spaces(x) - 1);
                    Pos = Pos + length(Ports{x}) + 1;
                end
                Ports{x+1} = string(Pos:length(string));
            else
                Ports{1} = string;
            end

            % Eliminate bluetooth ports
            nGoodPortsFound = 0;
            TempList = cell(1,1);
            for x = 1:length(Ports)
                Portstring = Ports{x};
                ValidPort = 1;
                for y = 1:(length(Portstring) - 4)
                    if sum(Portstring(y:y+3) == 'blue') == 4
                        ValidPort = 0;
                    end
                end
                if ValidPort == 1
                    nGoodPortsFound = nGoodPortsFound + 1;
                    TempList{nGoodPortsFound} = Portstring;
                end
            end
            Ports = TempList;
        end
    end
    
    methods(Static)
        
        function ValueOut = ScaleValue(Action,ValueIn,Range)
            
            %validate input: nrows in ValueIn == n values in Range
            
            ValueOut = nan(size(ValueIn));
            
            for i=1:size(ValueIn,1)
                
                switch Range(i)
                    case 4 %'0V - 10V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 10/16384.000 - 0.0;
                            case 'toRaw'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+0.0)*16384/10);
                        end
                    case 3 %'-2.5V - 2.5V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 5/16384.000 - 2.5;
                            case 'toRaw'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+2.5)*16384/5);
                        end
                    case 2 %'5V - 5V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 10/16384.000 - 5.0;
                            case 'toRaw'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+5.0)*16384/10);
                        end
                    case 1 %'-10V - 10V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 20/16384.000 - 10.0 - 0.022;
                            case 'toRaw'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+10.0)*16384.00/20);
                        end
                    otherwise
                end
            end
        end
        
        function ScaledTime = ScaleTime(RawTime, SamplingRate)
            ScaledTime = (RawTime-1)*1/SamplingRate;
        end
    end
end    