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
function r = AnalogModule(varargin)

% Determine if using Octave
if (exist('OCTAVE_VERSION'))
  UsingOctave = 1;
else
  UsingOctave = 0;
end

% Add Analog Module folders to path
AnalogModulePath = fileparts(which('AnalogModule'));
Folder1 = fullfile(AnalogModulePath, 'User Functions');
Folder2 = fullfile(AnalogModulePath, 'Accessory Functions');
Folder3 = fullfile(AnalogModulePath, 'Interface');
Folder4 = fullfile(AnalogModulePath, 'GUI');
Folder5 = fullfile(AnalogModulePath, 'Media');
Folder6 = fullfile(AnalogModulePath, 'Programs');
addpath(Folder1, Folder2, Folder3, Folder4, Folder5, Folder6);
try
    evalin('base', 'AnalogModuleSystem;');
    disp('AnalogModule is already open. Close it with EndAnalogModule first.');
    r = 0;
catch
    if ~UsingOctave
      ClosePreviousAnalogModuleInstances;
    end
    global AnalogModuleSystem;
    if ~UsingOctave
      rng('shuffle', 'twister'); % Seed the random number generator by CPU clock
    end
    % Initialize empty fields
    AnalogModuleSystem = struct;
    AnalogModuleSystem.GUIHandles = struct;
    AnalogModuleSystem.Graphics = struct;
    AnalogModuleSystem.LastProgramSent = [];
    AnalogModuleSystem.SerialPort = [];
    AnalogModuleSystem.CurrentProgram = [];
    AnalogModuleSystem.UsingOctave = UsingOctave;
    AnalogModuleSystem.Params = DefaultAnalogModuleParameters;
    AnalogModuleSystem.AnalogModulePath = AnalogModulePath;
    AnalogModuleSystem.ParamNames = {'SamplingPeriod','VoltageRange','ActiveChannels','Thresholds','ResetValues'};
    AnalogModuleSystem.SamplingPeriod = 250;
    AnalogModuleSystem.VoltageRange = 1;
    AnalogModuleSystem.ActiveChannels = 1:8;
    AnalogModuleSystem.CurrentThresholds = zeros(8,1);
    
    if ~UsingOctave
      AnalogModuleSystem.OS = strtrim(system_dependent('getos'));
    else
      AnalogModuleSystem.OS = ''; % Only used to avoid a communication problem with MATLAB on WinXP, unnecessary for octave
    end
    AnalogModuleSystem.OpMenuByte = 213;
    if (nargin == 0) && (strcmp(AnalogModuleSystem.OS, 'Microsoft Windows XP'))
        error('Error: On Windows XP, please specify a serial port. For instance, if AnalogModuleSystem is on port COM3, use: AnalogModuleSystem(''COM3'')');
    end
    if (nargin == 0) && UsingOctave
        error('Error: On Octave, please specify a serial port. For instance, if AnalogModuleSystem is on port COM3, use: AnalogModuleSystem(''COM3'')');
    end
    try
        % Connect to hardware
        if nargin > 1
            AnalogModuleSerialInit(varargin{1}, varargin{2});
        elseif nargin > 0
            AnalogModuleSerialInit(varargin{1});
        else
            AnalogModuleSerialInit;
        end
        pause(.1);
        SetAnalogModuleVersion;
        r = 1;
    catch
        if ~UsingOctave
            evalin('base','clear AnalogModuleSystem')
        end
        evalin('base','clear AnalogModuleSystem')
        rethrow(lasterror)
        msgbox('Error: Unable to connect to AnalogModuleSystem.', 'Modal')
    end
end