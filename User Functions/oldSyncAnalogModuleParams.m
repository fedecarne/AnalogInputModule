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

function ConfirmBit = SyncAnalogModuleParams

% Import virtual serial port object into this workspace from base
global AnalogModuleSystem;
    Params = AnalogModuleSystem.Params;

    ChannelActive = Params.ChannelActive;
    VoltageRange = Params.VoltageRange;
    Threshold = Params.Threshold;
   
    % Check ChannelActive
    % Check VoltageRange
    % Check Threshold

    % Convert ChannelActive from vector to 1 Byte
    % Convert VoltageRange from vector to 1 Byte

    % Arrange program into a single byte-string

    FormattedProgramTimestamps = TimeData(1:end); 
    if PulsePalSystem.FirmwareVersion < 19 % Pulse Pal 1
        SingleByteOutputParams = [IsBiphasic; Phase1Voltages; Phase2Voltages; CustomTrainID; CustomTrainTarget; CustomTrainLoop; RestingVoltages];
        FormattedParams = [SingleByteOutputParams(1:end) Chan1TrigAddressBytes Chan2TrigAddressBytes TriggerMode];
        ByteString = [PulsePalSystem.OpMenuByte 73 typecast(FormattedProgramTimestamps, 'uint8') FormattedParams];
    else % Pulse Pal 2
        FormattedVoltages = [Phase1Voltages; Phase2Voltages; RestingVoltages];
        FormattedVoltages = uint16(FormattedVoltages(1:end));
        SingleByteOutputParams = [IsBiphasic; CustomTrainID; CustomTrainTarget; CustomTrainLoop;];
        FormattedParams = [SingleByteOutputParams(1:end) Chan1TrigAddressBytes Chan2TrigAddressBytes TriggerMode];
        ByteString = [PulsePalSystem.OpMenuByte 73 typecast(FormattedProgramTimestamps, 'uint8') typecast(FormattedVoltages, 'uint8') FormattedParams];
    end
    PulsePalSerialInterface('write', ByteString, 'uint8');
    ConfirmBit = PulsePalSerialInterface('read', 1, 'uint8'); % Get confirmation
    OriginalProgMatrix = PulsePalSystem.CurrentProgram; % Compile Legacy Pulse Pal program matrix
    if isempty(OriginalProgMatrix)
        DefaultParams = load(fullfile(PulsePalSystem.PulsePalPath, 'Programs', 'ParameterMatrix_Example.mat'));
        OriginalProgMatrix = DefaultParams.ParameterMatrix;
    end
    OutputChanMatrix = [Params.IsBiphasic; Params.Phase1Voltage; Params.Phase2Voltage; Params.Phase1Duration; Params.InterPhaseInterval; Params.Phase2Duration; Params.InterPulseInterval; Params.BurstDuration; Params.InterBurstInterval; Params.PulseTrainDuration; Params.PulseTrainDelay; Params.LinkTriggerChannel1; Params.LinkTriggerChannel2; Params.CustomTrainID; Params.CustomTrainTarget; Params.CustomTrainLoop; Params.RestingVoltage];
    OriginalProgMatrix(2:18,2:5) = num2cell(OutputChanMatrix);
    OriginalProgMatrix(2,8:9) = num2cell(Params.TriggerMode);
    PulsePalSystem.CurrentProgram = OriginalProgMatrix; % Update Legacy Pulse Pal program matrix
    