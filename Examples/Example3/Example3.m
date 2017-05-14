function Example3

%%%
% Test detect thresholds and produce events
%%%

global BpodSystem


Ain = BpodAnalogIn('COM39');

MaxTrials = 10000;

BpodSystem.ProtocolFigures.AnalogModuleFig = figure('Position', [1400 700 500 300],'name','Analog Input Module','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.AnalogModulePlot = axes('Position', [.12 .17 .83 .77]);

Ain.AinPlot(BpodSystem.GUIHandles.AnalogModulePlot,'init');

AMControl = Ain.ControlPanel('init');
S = Ain.ControlPanel('retrieve',AMControl);

Ain.SamplingRate = 100;
Ain.ActiveChannels = S.ActiveChannels;
Ain.VoltageRange = S.VoltageRange;

StimTime = 1;

Ain.StartThresholdCrossing
%% Main trial loop
for currentTrial = 1:MaxTrials

    S = Ain.ControlPanel('retrieve',AMControl);
    Ain.SamplingRate = S.SamplingRate;%Sampling period 100ms
    Ain.ActiveChannels = S.ActiveChannels;
    Ain.VoltageRange = S.VoltageRange;
    
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

