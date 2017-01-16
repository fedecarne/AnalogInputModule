function AnalogTesting3

%%%
% Test detect thresholds and produce events
%%%

global BpodSystem
MaxTrials = 10000;
%% Define parameters
global AnalogModuleSystem

% Initialize Analog Module connection
AnalogModule;

while AnalogModuleSystem.SerialPort.bytesAvailable>0
    AnalogModuleSystem.SerialPort.read(1, 'uint8');
end

AMControl = AnalogModuleControl('init');

S = AnalogModuleControl('retrieve',AMControl);

ProgramAnalogModuleParam('SamplingPeriod', S.SamplingPeriod);%Sampling period 100ms
ProgramAnalogModuleParam('ActiveChannels', S.ActiveChannels);
ProgramAnalogModuleParam('VoltageRange', S.ActiveChannels,S.VoltageRange(S.ActiveChannels)); %Voltge Range: -10V - +10V
ProgramAnalogModuleParam('Thresholds',S.ActiveChannels,S.Thresholds); %Thresholds in Volts
ProgramAnalogModuleParam('ResetValues',S.ActiveChannels,S.ResetValues); %Thresholds in Volts

StimTime = 1;

ThresholdCrossing('Start');
%% Main trial loop
for currentTrial = 1:MaxTrials

    S = AnalogModuleControl('retrieve',AMControl);
    ProgramAnalogModuleParam('SamplingPeriod', S.SamplingPeriod);%Sampling period 100ms
    ProgramAnalogModuleParam('ActiveChannels', S.ActiveChannels);
    ProgramAnalogModuleParam('VoltageRange', S.ActiveChannels,S.VoltageRange(S.ActiveChannels)); %Voltge Range: -10V - +10V
    ProgramAnalogModuleParam('Thresholds',S.ActiveChannels,S.Thresholds); %Thresholds in Volts
    ProgramAnalogModuleParam('ResetValues',S.ActiveChannels,S.ResetValues); %Thresholds in Volts

    sma = NewStateMatrix(); % Assemble state matrix
    sma = AddState(sma, 'Name', 'WaitForPoke', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port1In', 'Delay'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', 0.5,...
        'StateChangeConditions', {'Tup', 'DeliverStimulus'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', StimTime,...
        'StateChangeConditions', {'Tup', 'WaitForResponse','Port1Out', 'EarlyWithdrawal'},...
        'OutputActions', {'LED', 1});
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', 0.2,...
        'StateChangeConditions', {'Port1Out', 'Reward','Serial1_8','Reward'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'EarlyWithdrawal', ...
        'Timer', 0.2,...
        'StateChangeConditions', {'Tup', 'Punish'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'Punish', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {}); 
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    
    %ThresholdCrossing('Stop');
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        BpodSystem.Data.RawEvents.Trial{1, currentTrial}.Events  
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

