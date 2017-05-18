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
        HardwareChannelMapping = [1 2 5 6 8 7 4 3]; % channel mapping from chip to board
    end
   
    properties
        Port % ArCOM Serial port
        RootPath = fileparts(which('AnalogInObject'));
        SamplingRate % 1Hz-50kHz, affects all channels
        VoltageRange
        ActiveChannels
        Thresholds
        ResetValues
        StreamChannel = 1;
        GUIhandles
        nSamplesToLog = 0; % 0 = infinite
    end
    
    properties (SetAccess = protected)
        FirmwareVersion = 0;
    end
    
    properties (Access = private)
        CurrentFirmwareVersion = 1;
        opMenuByte = 213; % Byte code to access op menu
        RangeMultipliers = [20 10 5 10];
        RangeOffsets = [10 5 2.5 0];
        RangeIndex = ones(1,8);
    end
    
    methods
        
        function obj = BpodAnalogIn(varargin)
           
            disp('Searching for AnalogIn device. Please wait.')

            if nargin > 0
                portString = varargin{1};
            else
                PortList = obj.findPulsePal();
                if ~isempty(PortList)
                    error(['You must call BpodAnalogIn with a serial port string argument. Likely serial ports are: ' PortList])
                else
                    error('You must call BpodAnalogIn with a serial port string argument.')
                end
            end
            
            try
                obj.Port = ArCOMObject_Ain(portString, 115200);
            catch
                disp('Was not able to find BpodAnalogIn module. Try disconnect and connect again.')
            end
            obj.Port.write([obj.opMenuByte double('O')], 'uint8');
            pause(.1);
            HandShakeOkByte = obj.Port.read(1, 'uint8');
            if HandShakeOkByte == 161
                obj.FirmwareVersion = obj.Port.read(1, 'uint32');
                disp(['AnalogIn module V' num2str(obj.FirmwareVersion) ' found.']);
            else
                disp('Error: AnalogIn returned an unexpected handshake signature.')
            end
            
            obj.setDefaultParams;
        end
       
        function setDefaultParams(obj)
            % Loads default parameters and sends them to the device
            obj.VoltageRange  = repmat(obj.ValidRanges(1), 1, obj.nChannels);
            obj.SamplingRate = 1000;
            obj.ActiveChannels = 1:obj.nChannels;            
            obj.Thresholds = [(1:8)', zeros(obj.nChannels,1)];
            obj.ResetValues = [(1:8)', zeros(obj.nChannels,1)];
        end
        
        function set.nSamplesToLog(obj, nSamples)
            % Used to acquire a fixed number of samples
            obj.Port.write([213 'W'], 'uint8', nSamples, 'uint32');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting nSamplesToLog: module did not acknowledge new value.');
            end
            obj.nSamplesToLog = nSamples;
        end
               
        function set.SamplingRate(obj, sf)
            
            if sf < obj.ValidSamplingRates(1) || sf > obj.ValidSamplingRates(2)
                error(['Error setting sampling rate: valid rates are in range: [' num2str(obj.ValidSamplingRates) '] Hz'])
            end
            
            SamplingPeriodMicroseconds = (1/sf)*1000000;
            obj.Port.write(uint8([213 double('P')]), 'uint8', SamplingPeriodMicroseconds,'uint32');
            obj.SamplingRate = sf;
            
        end
        
        function set.ActiveChannels(obj, channels)
            % Expects a list of channel indices, i.e. [1 2 3 8]
            
            activechan = obj.HardwareChannelMapping(channels);
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
            obj.Port.write(uint8([213 double('A') ActiveChannelsByte]), 'uint8');
            
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
            
            VoltageRangeIndex = ones(1,obj.nChannels);
            for i = 1:obj.nChannels
                RangeString = value{i};
                RangeIndex = find(strcmp(RangeString, obj.ValidRanges),1);
                if isempty(RangeIndex)
                    error(['Invalid range specified: ' RangeString '. Valid ranges are: ' obj.ValidRanges]);
                end
                VoltageRangeIndex(obj.HardwareChannelMapping(i)) = RangeIndex;
            end
            obj.Port.write(uint8([213 double('R') VoltageRangeIndex-1]), 'uint8');
            obj.RangeIndex = VoltageRangeIndex;
            obj.VoltageRange = value;

        end
        
        function set.Thresholds(obj, value)
                        
            % Expects: [1,  5.0;...
            %           3,  -2.3;...
            %           7,  -5];
            
            Channels = value(:,1); 
            Channels = obj.HardwareChannelMapping(Channels);
            Values = value(:,2); 
            
            % Add validation
            
            % Set non-mentioned channels to 0
            Thresholds = zeros(8,1);
            for i=1:size(Values,1)
                Thresholds(Channels(i)) = Values(i,1);
            end
            
            %Rescale thresholds according to voltage range.
            RawThresholds = obj.ScaleValue('toRaw',Thresholds,obj.VoltageRange);
            obj.Port.write(uint8([213 double('T')]), 'uint8',RawThresholds', 'uint32');
            
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
            Channels = obj.HardwareChannelMapping(Channels);
            Values = value(:,2);
                        
            % Add validation
      
            % Set non-mentioned channels to 0
            ResetValues = zeros(8,1);
            for i=1:size(Values,1)
                ResetValues(Channels(i)) = Values(i);
            end
            
            % Flush
            flush(obj.Port)
            
            %Rescale thresholds according to voltage range.
            RawResetValues = obj.ScaleValue('toRaw',ResetValues,obj.VoltageRange);
            obj.Port.write(uint8([213 double('B')]), 'uint8',RawResetValues', 'uint32');
            
            obj.ResetValues = zeros(8,1);
            for i=1:size(Values)
                obj.ResetValues(Channels(i)) = Values(i);
            end
        end
        
        function set.StreamChannel(obj, Channel)
                        
            % Flush
            flush(obj.Port)
            
            MappedChannel = obj.HardwareChannelMapping(Channel);
            obj.Port.write(uint8([213 double('C') MappedChannel-1]), 'uint8');
            obj.StreamChannel = obj.HardwareChannelMapping(Channel);
        end
        
        function StartLogging(obj)
            
            obj.Port.write(uint8([213 double('L')]), 'uint8');
            
        end
        
        function StopLogging(obj)
            
            obj.Port.write(uint8([213 double('Z')]), 'uint8');
            
        end

        
        function r = RetrieveData(obj)
                                    
            while obj.Port.bytesAvailable>0
                obj.Port.read(1, 'uint8');
            end
            
            % Send 'Retrieve' command to the AM
            obj.Port.write(uint8([213 double('D')]), 'uint8');
            nSamples = obj.Port.read(1, 'uint32');
            nActiveChannels = size(obj.ActiveChannels,2);
            nValues = nActiveChannels*nSamples;
            RawData = obj.Port.read(nValues, 'uint16');
            r = struct;
            r.y = zeros(nActiveChannels, nSamples);
            ReshapedRawData = reshape(RawData, nActiveChannels, nSamples);
            for i = 1:nActiveChannels
                thisMappedChannel = obj.HardwareChannelMapping(i);
                thisMultiplier = obj.RangeMultipliers(obj.RangeIndex(thisMappedChannel));
                thisOffset = obj.RangeOffsets(obj.RangeIndex(thisMappedChannel));
                r.y(i,:) = ((double(ReshapedRawData(thisMappedChannel,:))/8192)*thisMultiplier)-thisOffset;
            end
            Period = 1/obj.SamplingRate;
            r.x = 0:Period:(Period*double(nSamples)-Period);
            
        end
        
        function StartThresholdCrossing(obj)
            obj.Port.write(uint8([213 double('N')]), 'uint8');
        end
        
        function StopThresholdCrossing(obj)
            obj.Port.write(uint8([213 double('M')]), 'uint8');
        end
        
        function StartUARTstreaming(obj)
            obj.Port.write(uint8([213 double('H')]), 'uint8');
        end
        
        function StopUARTstreaming(obj)
            obj.Port.write(uint8([213 double('I')]), 'uint8');
        end
        
        function StartUSBstreaming(obj,What)
            
            flush(obj.Port);
            switch 1
                case strcmp(What,'Signal')
                    obj.Port.write(uint8([213 double('S')]), 'uint8');
                case strcmp(What,'Events')
                    obj.Port.write(uint8([213 double('E')]), 'uint8');
                otherwise
                    error('StartUSBstreaming method needs an argument: Signal or Events.')
            end
        end
        
        function StopUSBstreaming(obj,varargin)
            
            switch 1
                case isempty(varargin)
                    obj.Port.write(uint8([213 double('X')]), 'uint8');
                    obj.Port.write(uint8([213 double('Y')]), 'uint8');
                    
                case strcmp(varargin,'Signal')
                    obj.Port.write(uint8([213 double('X')]), 'uint8');
                    
                case strcmp(varargin,'Events')
                    obj.Port.write(uint8([213 double('Y')]), 'uint8');
            end
        end
        
        function delete(obj)
             
            %Send disconnect command
            obj.Port.write(uint8([213 double('Q')]), 'uint8');

            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
            disp('AnalogModule successfully disconnected.')
        end

        % Method defined in a separate file
        h = Streamer(obj);
        h = AinPlot(obj, AxesHandle, Action, varargin)
        S = ControlPanel(obj, varargin)
        
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
        
        function ValueOut = ScaleValue(obj,Action,ValueIn,RangeString)
            
            %validate input: nrows in ValueIn == n values in Range
            
            ValueOut = nan(size(ValueIn));
            
            for i=1:size(ValueIn,1)
                
                switch obj.RangeIndex(i)
                    case 4 %'0V - 10V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 10/2^13 - 0.0;
                            case 'toRaw'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+0.0)*2^13/10);
                        end
                    case 3 %'-2.5V - 2.5V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 5/2^13 - 2.5;
                            case 'toRaw'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+2.5)*2^13/5);
                        end
                    case 2 %'5V - 5V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 10/2^13 - 5.0;
                            case 'toRaw'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+5.0)*2^13/10);
                        end
                    case 1 %'-10V - 10V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 0.002455851742364 -10.091771492112841;
                                %ValueOut(i,:) = ValueIn(i,:);
                            case 'toRaw'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+10.0)*2^13/20);
                        end
                    otherwise
                end
            end
        end
        
        function ScaledTime = ScaleTime(obj, RawTime, SamplingRate)
            ScaledTime = (RawTime-1)*1/obj.SamplingRate;
        end
    end
end    