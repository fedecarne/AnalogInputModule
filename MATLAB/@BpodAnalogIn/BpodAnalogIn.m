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
   
    properties
        About = struct; % Contains a text string describing each field
        Port % ArCOM Serial port
        GUIhandles
        SamplingRate % 1Hz-50kHz, affects all channels
        VoltageRange
        nActiveChannels
        Thresholds
        ResetValues
        StreamChannel_ID = 1;
        nSamplesToLog = Inf; % 0 = infinite
    end
    
    properties(Constant)
        ValidRanges = {'-10V:10V', '-5V:5V', '-2.5V:2.5V','0V:10V'};
        ValidSamplingRates = [1 100000]; % Range of valid sampling rates
    end
    
    properties (Access = private)
        CurrentFirmwareVersion = 1;
        opMenuByte = 213; % Byte code to access op menu
        RangeMultipliers = [20 10 5 10];
        RangeOffsets = [10 5 2.5 0];
        RangeIndex = ones(1,8);
        nPhysicalChannels = 8; % Number of physical channels
        RootPath = fileparts(which('AnalogInObject'));
        FirmwareVersion = 0;
    end
    
    methods
        
        function obj = BpodAnalogIn(portString)
            try
                obj.Port = ArCOMObject_Ain(portString, 115200);
            catch
                error('Was not able to find BpodAnalogIn module. Try disconnect and connect again.')
            end
            obj.Port.write([obj.opMenuByte 'O'], 'uint8');
            pause(.1);
            HandShakeOkByte = obj.Port.read(1, 'uint8');
            if HandShakeOkByte == 161
                obj.FirmwareVersion = obj.Port.read(1, 'uint32');
                disp(['AnalogIn module V' num2str(obj.FirmwareVersion) ' found.']);
            else
                error('Error: AnalogIn returned an unexpected handshake signature.')
            end
            
            obj.setDefaultParams;
            obj.About.Port = 'ArCOM USB serial port object, to simplify data transactions with Arduino. See https://github.com/sanworks/ArCOM';
            obj.About.GUIhandles = 'A struct containing handles of the UI';
            obj.About.SamplingRate = 'Sampling rate for all channels (in Hz)';
            obj.About.VoltageRange = 'Voltage range mapped to 12 bits of each channel. Valid ranges are in .ValidRanges';
            obj.About.nActiveChannels = 'Number of channels to read, beginning with channel 1. Fewer channels -> faster sampling.';
            obj.About.Thresholds = 'Threshold, in volts, generates an event when crossed. The event will be sent to the state machine if SendBpodEvents was called earlier.';
            obj.About.ResetValues = 'Threshold reset voltages for each channel. Voltage must go below this value to enable the next event.';
            obj.About.StreamChannelID = 'Index of a single channel to stream (to USB, or to an output module).';
            obj.About.nSamplesToLog = 'Number of samples to log following a call to StartLogging(). 0 = Infinite.';
            obj.About.METHODS = 'type methods(myObject) at the command line to see a list of valid methods.';
        end
       
        function setDefaultParams(obj)
            % Loads default parameters and sends them to the device
            obj.VoltageRange  = repmat(obj.ValidRanges(1), 1, obj.nPhysicalChannels);
            obj.SamplingRate = 1000;
            obj.nActiveChannels = 8;            
            obj.Thresholds = zeros(1,obj.nPhysicalChannels);
            obj.ResetValues = zeros(1,obj.nPhysicalChannels);
        end
        
        function set.nSamplesToLog(obj, nSamples)
            nSamples2Send = nSamples;
            if nSamples == Inf
                nSamples2Send = 0;
            end
            % Used to acquire a fixed number of samples
            obj.Port.write([213 'W'], 'uint8', nSamples2Send, 'uint32');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting nSamplesToLog: module did not acknowledge new value.');
            end
            if nSamples == 0
               nSamples = Inf;
            end
            obj.nSamplesToLog = nSamples;
        end
               
        function set.SamplingRate(obj, sf)
            
            if sf < obj.ValidSamplingRates(1) || sf > obj.ValidSamplingRates(2)
                error(['Error setting sampling rate: valid rates are in range: [' num2str(obj.ValidSamplingRates) '] Hz'])
            end
            obj.Port.write([213 'P'], 'uint8', sf,'uint32');
            obj.SamplingRate = sf;
            
        end
        
        function set.nActiveChannels(obj, nChannels)
            if nChannels < 1 || nChannels > obj.nPhysicalChannels
                error(['Error setting active channel count: nChannels must be in the range 1:' num2str(obj.nPhysicalChannels)]);
            end
            obj.Port.write(uint8([213 'A' nChannels]), 'uint8');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting active channels. Confirm code not returned.');
            end
            obj.nActiveChannels = nChannels;
        end
        
        function set.VoltageRange(obj, value)
            
            %1: '-10V - 10V'
            %2: '-5V - 5V'
            %3: '-2.5V - 2.5V'
            %4: '0V - 10V'
            
            VoltageRangeIndex = ones(1,obj.nPhysicalChannels);
            for i = 1:obj.nPhysicalChannels
                RangeString = value{i};
                RangeIndex = find(strcmp(RangeString, obj.ValidRanges),1);
                if isempty(RangeIndex)
                    error(['Invalid range specified: ' RangeString '. Valid ranges are: ' obj.ValidRanges]);
                end
                VoltageRangeIndex(i) = RangeIndex;
            end
            obj.Port.write(uint8([213 'R' VoltageRangeIndex-1]), 'uint8');
            obj.RangeIndex = VoltageRangeIndex;
            obj.VoltageRange = value;

        end
        
        function set.Thresholds(obj, value)
            % Add validation
            
            %Rescale thresholds according to voltage range.
            RawThresholds = obj.ScaleValue('toBits',value,obj.VoltageRange);
            obj.Port.write([213 'T'], 'uint8', RawThresholds, 'uint32');
            
            obj.Thresholds = value;
        end

        function set.ResetValues(obj, value)
            % Add validation
            
            %Rescale thresholds according to voltage range.
            RawResetValues = obj.ScaleValue('toBits',value,obj.VoltageRange);
            obj.Port.write([213 'B'], 'uint8',RawResetValues, 'uint32');
            obj.ResetValues = value;
        end
        
        function set.StreamChannel_ID(obj, Channel)
            obj.Port.write(uint8([213 'C' Channel-1]), 'uint8');
            obj.StreamChannel_ID = Channel;
        end
        
        function StartLogging(obj)
            obj.Port.write(uint8([213 'L']), 'uint8');
        end
        
        function StopLogging(obj)
            obj.Port.write(uint8([213 'Z']), 'uint8');  
        end

        
        function r = RetrieveData(obj)   
            
            while obj.Port.bytesAvailable>0
                obj.Port.read(1, 'uint8');
            end
            
            % Send 'Retrieve' command to the AM
            obj.Port.write([213 'D'], 'uint8');
            nSamples = obj.Port.read(1, 'uint32');
            nValues = obj.nActiveChannels*nSamples;
            RawData = obj.Port.read(nValues, 'uint16');
            r = struct;
            r.y = zeros(obj.nActiveChannels, nSamples);
            ReshapedRawData = reshape(RawData, obj.nActiveChannels, nSamples);
            for i = 1:obj.nActiveChannels
                thisMultiplier = obj.RangeMultipliers(obj.RangeIndex(i));
                thisOffset = obj.RangeOffsets(obj.RangeIndex(i));
                r.y(i,:) = ((double(ReshapedRawData(i,:))/8192)*thisMultiplier)-thisOffset;
            end
            Period = 1/obj.SamplingRate;
            r.x = 0:Period:(Period*double(nSamples)-Period);
        end
        
        function StartThresholdEvents(obj)
            obj.Port.write([213 'N'], 'uint8');
        end
        
        function StopThresholdEvents(obj)
            obj.Port.write([213 'M'], 'uint8');
        end
        
        function StartUARTstreaming(obj)
            obj.Port.write([213 'H'], 'uint8');
        end
        
        function StopUARTstreaming(obj)
            obj.Port.write([213 'I'], 'uint8');
        end
        
        function StartUSBstreaming(obj,What)
            switch What
                case 'Signal'
                    obj.Port.write([213 'S'], 'uint8');
                case 'Events'
                    obj.Port.write([213 'E'], 'uint8');
                otherwise
                    error('StartUSBstreaming method needs an argument: Signal or Events.')
            end
        end
        
        function StopUSBstreaming(obj,varargin)
            if nargin == 0
                obj.Port.write([213 'X'], 'uint8');
                obj.Port.write([213 'Y'], 'uint8');
            else
                switch varargin{1}
                    case 'Signal'
                        obj.Port.write([213 'X'], 'uint8');
                    case 'Events'
                        obj.Port.write([213 'Y'], 'uint8');
                end
            end
        end
        
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
            disp('AnalogModule successfully disconnected.')
        end

        % UI Methods defined in a separate file
        h = Streamer(obj);
        h = AinPlot(obj, AxesHandle, Action, varargin)
        S = ControlPanel(obj, varargin)
        
    end
    
    methods (Access = private) 
        function ValueOut = ScaleValue(obj,Action,ValueIn,RangeString)
            
            %validate input: nrows in ValueIn == n values in Range
            
            ValueOut = nan(size(ValueIn));
            
            for i=1:size(ValueIn,1)
                
                switch obj.RangeIndex(i)
                    case 4 %'0V - 10V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 10/2^13 - 0.0;
                            case 'toBits'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+0.0)*2^13/10);
                        end
                    case 3 %'-2.5V - 2.5V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 5/2^13 - 2.5;
                            case 'toBits'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+2.5)*2^13/5);
                        end
                    case 2 %'5V - 5V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 10/2^13 - 5.0;
                            case 'toBits'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+5.0)*2^13/10);
                        end
                    case 1 %'-10V - 10V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 0.002455851742364 -10.091771492112841;
                                %ValueOut(i,:) = ValueIn(i,:);
                            case 'toBits'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+10.0)*2^13/20);
                        end
                    otherwise
                end
            end
        end
    end
end    