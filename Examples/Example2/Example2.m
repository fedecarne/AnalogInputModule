function Example2

%%%
% Test logging during one particular state. The start logging command is
% sent from Bpod via Serial port1 when that given state is reached. The
% stop logging is another state. 
% Data is retrieved at the end of the trial.
%%%

global BpodSystem

Ain = BpodAnalogIn('COM39');

MaxTrials = 10000;

BpodSystem.ProtocolFigures.AnalogModuleFig = figure('Position', [1400 700 500 300],'name','Analog Input Module','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.AnalogModulePlot = axes('Position', [.12 .17 .83 .77]);

Ain.AinPlot(BpodSystem.GUIHandles.AnalogModulePlot,'init');

AMControl = Ain.ControlPanel('init');

S = Ain.ControlPanel('retrieve',AMControl);

Ain.SamplingRate = S.SamplingRate;
Ain.ActiveChannels = S.ActiveChannels;
Ain.VoltageRange = S.VoltageRange;

StimTime = 1;

%% Main trial loop
for currentTrial = 1:MaxTrials
   
    S = Ain.ControlPanel('retrieve',AMControl);
    Ain.SamplingRate = S.SamplingRate;%Sampling period 100ms
    Ain.ActiveChannels = S.ActiveChannels;
    Ain.VoltageRange = S.VoltageRange;
    
    % Assemble state matrix
    sma = NewStateMatrix(); 
    sma = AddState(sma, 'Name', 'WaitForPoke', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port1In', 'Delay'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', 0.5,...
        'StateChangeConditions', {'Tup', 'DeliverStimulus','Port1Out', 'EarlyWithdrawal'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', StimTime,...
        'StateChangeConditions', {'Tup', 'WaitForResponse','Port1Out', 'EarlyWithdrawal'},...
        'OutputActions', {'LED', 1,'Serial1',9}); %Start logging data
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', 0.2,...
        'StateChangeConditions', {'Port1Out', 'Reward'},...
        'OutputActions', {'Serial1',10}); %Stop logging data
    sma = AddState(sma, 'Name', 'EarlyWithdrawal', ...
        'Timer', 0.2,...
        'StateChangeConditions', {'Tup', 'Punish'},...
        'OutputActions', {'Serial1',10}); %Stop logging data
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
        if isfield(BpodSystem.Data.RawEvents.Trial{1, currentTrial}.Events,'Serial1_9')
            BpodSystem.Data.RawEvents.Trial{1, currentTrial}.Events.Serial1_9
        end
        if isfield(BpodSystem.Data.RawEvents.Trial{1, currentTrial}.Events,'Serial1_10')
            BpodSystem.Data.RawEvents.Trial{1, currentTrial}.Events.Serial1_10
        end        
        
        data = RetrieveData;
        if ~isempty(data)
            disp(['sampling period: ' num2str(1000*data.x(end)/(length(data.x)-1))])
            AnalogModulePlot(BpodSystem.GUIHandles.AnalogModulePlot,'update',data);
        end

    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

