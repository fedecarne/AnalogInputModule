function Streamer(obj)

global AinStreamer

%Initialize AinStreamer
AinStreamer.T=0;
AinStreamer.TimeWindow = 5; % in seconds
AinStreamer.TimerPeriod = 0.01;% in seconds
AinStreamer.SamplingRate = 250; % hardware timer interval in us
AinStreamer.SelectedChannel = 0;
AinStreamer.SelectedRange = 1;
AinStreamer.Running = 0;
AinStreamer.Logging = 0;
AinStreamer.CurrentWindow = 'Signal';

AinStreamer.Figure = figure('Name','AnalogModule Streamer',...
                                     'NumberTitle','off',...
                                     'MenuBar','none',...
                                     'Color',0.95*[1 1 1],...
                                     'Position',[1090,650,820,400],...
                                     'CloseRequestFcn',{@(hpb,eventdata)CloseReq(hpb,eventdata,guidata(hpb),obj)});

set(gcf,'toolbar','figure');
% set(gcf,'menubar','figure');

tabgp = uitabgroup('Position',[0.01,0.1,0.7,0.9],'SelectionChangedFcn',{@(hpb,eventdata)TabChange_Callback(hpb,eventdata,guidata(hpb),obj)});
Signal_tab = uitab(tabgp,'Title','Signal','BackgroundColor',0.52*[1 1 1]);
Event_tab = uitab(tabgp,'Title','Events','BackgroundColor',0.52*[1 1 1]);
Log_tab = uitab(tabgp,'Title','Log','BackgroundColor',0.52*[1 1 1]);

%------------------------------------------------------------------------------
AinStreamer.Signal.Axis = axes('parent', Signal_tab,...
                                        'Position',[.09,.1,.88,.83],...
                                        'FontSize',14,...
                                        'Color','k'); 
                                         
AinStreamer.Signal.Axis.GridColor = [1 1 1];
grid(AinStreamer.Signal.Axis,'on')                                                                              
                                        
AinStreamer.Signal.Plot = line(nan,nan,...
                               'Parent',AinStreamer.Signal.Axis,...
                               'LineStyle','-',...
                               'Marker','.',...
                               'MarkerSize',10,...
                               'Color',[1 1 0],...
                               'LineWidth',2);

%------------------------------------------------------------------------------
%Events tab
AinStreamer.Events.Axis = axes('parent', Event_tab,...
                                'Position',[.09,.1,.88,.83],...
                                'FontSize',14,...
                                'Color','k'); 
                                         
AinStreamer.Events.Axis.GridColor = [1 1 1];
grid(AinStreamer.Events.Axis,'on'); 
AinStreamer.Events.Axis.YLim = [-1 16];
AinStreamer.Events.Axis.YTick = 0.5:2:14.5;
AinStreamer.Events.Axis.YTickLabel = {'Ch0','Ch1','Ch2','Ch3','Ch4','Ch5','Ch6','Ch7'};
             
c = colormap(lines(8));
for i=1:8
    AinStreamer.Events.Plot(i) = line(nan,nan,...
                                       'Parent',AinStreamer.Events.Axis,...
                                       'LineStyle','-',...
                                       'Color', c(i,:),...
                                       'LineWidth',2);

end

%------------------------------------------------------------------------------
%Log tab
AinStreamer.Log.Axis = axes('parent', Log_tab,...
                            'Position',[.09,.1,.88,.83],...
                            'FontSize',14,...
                            'Color','k'); 
                                         
AinStreamer.Log.Axis.GridColor = [1 1 1];
grid(AinStreamer.Log.Axis,'on');                                                                           
             
c = colormap(parula(8));
for i=1:8
    AinStreamer.Log.Plot(i) = line(nan,nan,...
                                   'Parent',AinStreamer.Log.Axis,...
                                   'LineStyle','-',...
                                   'Marker','.',...
                                   'MarkerSize',10,...
                                   'Color', c(i,:),...
                                   'LineWidth',2);
end

%--------------------------------------------------------------------------------

Start_btn = uicontrol('Style', 'pushbutton',...
                      'String', 'Start',...
                      'Units','normalized','Position', [0.75 0.07 0.1 0.06],...
                      'FontSize',12,'Callback', {@(hpb,eventdata)Start_btn_Callback(hpb,eventdata,guidata(hpb),obj)});

Stop_btn = uicontrol('Style', 'pushbutton',...
                     'String', 'Stop',...
                     'Units','normalized','Position', [0.86 0.07 0.1 0.06],...
                     'FontSize',12,'Callback', {@(hpb,eventdata)Stop_btn_Callback(hpb,eventdata,guidata(hpb),obj)});
                 
AinStreamer.handles.Channel_bg = uibuttongroup('Title','Channel',...
                           'BackgroundColor',0.95*[1 1 1],...
                           'Position',[0.72 0.35 0.11 0.35],...
                           'SelectionChangedFcn',{@(hpb,eventdata)Channel_bg_Callback(hpb,eventdata,guidata(hpb),obj)});
       
PosY = 0.95;
for i=1:8
    PosY = PosY -0.11;
    Channel_bn(i) = uicontrol(AinStreamer.handles.Channel_bg,'Style',...
                              'radiobutton',...
                              'BackgroundColor',0.95*[1 1 1],...
                              'String',['Channel ' num2str(i-1)],...
                              'Units','normalized',...
                              'Position',[0.07 PosY 0.9 0.12]);
end

AinStreamer.handles.Range_bg = uibuttongroup('Title','Range',...
                                            'Position',[0.72 0.15 0.11 0.2],...
                                            'BackgroundColor',0.95*[1 1 1],...
                                            'SelectionChangedFcn',{@(hpb,eventdata)Range_bg_Callback(hpb,eventdata,guidata(hpb),obj)});
   
Range_str = {'0V - 10V', '-2.5V - 2.5V', '-5V - 5V', '-10V - 10V'};

PosY = 0.97;
for i=1:4
    PosY = PosY -0.21;
    Range_bn(i) = uicontrol(AinStreamer.handles.Range_bg,'Style',...
                          'radiobutton',...
                          'BackgroundColor',0.95*[1 1 1],...
                          'String',Range_str{i},...
                          'FontSize',7,...
                          'Units','normalized',...
                          'Position',[0.07 PosY 0.9 0.12]);
end

Win_txt = uicontrol('Style', 'text',...
                    'String', 'TimeWin',...
                    'Units','normalized',...
                    'Position', [0.55 0.01 0.07 0.06],...
                    'BackgroundColor',0.95*[1 1 1],...
                    'FontSize',10);
                 
Win_edt = uicontrol('Style', 'edit',...
                    'String', '5',...
                    'Units','normalized',...
                    'Position', [0.63 0.025 0.04 0.045],...
                    'FontSize',10,'Callback', {@(hpb,eventdata)Win_edt_Callback(hpb,eventdata,guidata(hpb),obj)});
                 
SamplingRate_txt = uicontrol('Style', 'text',...
                    'String', 'SampPeriod (ms)',...
                    'Units','normalized',...
                    'Position', [0.02 0.01 0.13 0.06],...
                    'BackgroundColor',0.95*[1 1 1],...
                    'FontSize',10);
                
AinStreamer.handles.SamplingRate_edt = uicontrol('Style', 'edit',...
                    'String', '250',...
                    'Units','normalized',...
                    'Position', [0.15 0.025 0.04 0.045],...
                    'FontSize',10,'Callback', {@(hpb,eventdata)SamplingRate_edt_Callback(hpb,eventdata,guidata(hpb),obj)});
                
AinStreamer.handles.Message_txt = uicontrol('Style', 'text',...
                    'String', '',...
                    'HorizontalAlignment','left',...
                    'ForegroundColor', 'red',...
                    'Units','normalized',...
                    'Position', [0.23 0.01 0.23 0.06],...
                    'BackgroundColor',0.95*[1 1 1],...
                    'FontSize',10);
                 
AinStreamer.handles.Value_txt = uicontrol('Style', 'text',...
                     'String', '-.-',...
                     'Units','normalized',...
                     'Position', [0.72 0.76 0.27 0.19],...
                     'ForegroundColor',[1 1 0],...    
                     'BackgroundColor',[0 0 0],...
                     'FontSize',40);
                 
Threshold_bg = uibuttongroup('Title','Thresholds',...
                             'BackgroundColor',0.95*[1 1 1],...
                             'Position',[0.84 0.15 0.15 0.55],...
                             'SelectionChangedFcn',{@(hpb,eventdata)Threshold_bg_Callback(hpb,eventdata,guidata(hpb),obj)});
       
PosY = 0.95;
for i=1:8
    PosY = PosY -0.10;
    Threshold_txt(i) = uicontrol(Threshold_bg,'Style',...
                              'text',...
                              'BackgroundColor',0.95*[1 1 1],...
                              'String',['Ch' num2str(i-1)],...
                              'FontSize',7,...
                              'Units','normalized',...
                              'Position',[0.005 PosY-0.01 0.2 0.08]);
                          
    AinStreamer.handles.Threshold_edt(i) = uicontrol(Threshold_bg,'Style',...
                              'edit',...
                              'String',0,...
                              'Units','normalized',...
                              'Position',[0.25 PosY 0.3 0.08]);
                          
    AinStreamer.handles.ResetValues_edt(i) = uicontrol(Threshold_bg,'Style',...
                              'edit',...
                              'String',0,...
                              'Units','normalized',...
                              'Position',[0.55 PosY 0.3 0.08]);
end

SetThresholds_bn(i) = uicontrol(Threshold_bg,'Style',...
                              'pushbutton',...
                              'String','Set',...
                              'Units','normalized',...
                              'FontSize',12,...
                              'Position',[0.25 0.01 0.6 0.1],...
                              'Callback', {@(hpb,eventdata)SetThresholds_Callback(hpb,eventdata,guidata(hpb),obj)});
                          
% % Set 0-10V default Voltage range
% ProgramAnalogModuleParam('VoltageRange', 1:8, 4*ones(8,1));

end

function Start_btn_Callback(hObject, eventdata, handles, obj)
    
    global AinStreamer;

    switch AinStreamer.CurrentWindow
        case 'Log'

            AinStreamer.Running = 0;
            if AinStreamer.Logging==0

                AinStreamer.handles.Value_txt.FontSize = 14;
                AinStreamer.handles.Value_txt.String = 'Logging...';

                flush(obj.Port)

                % Start logging
                obj.StartLogging;

                AinStreamer.Logging = 1;
            end

    otherwise % Signal or Event

        if AinStreamer.Running==0

            %Reset acquisition time
            AinStreamer.T = 0;

            flush(obj.Port)
                        
            %Set sampling period                        
            SamplingRate = str2double(AinStreamer.handles.SamplingRate_edt.String);            
            AinStreamer.SamplingRate = SamplingRate; %Arduino Timer period in ms                        
            obj.SamplingRate = SamplingRate;

            %Acquisition timer
            AinStreamer.timer = timer('Name','MyTimer',               ...
                               'Period',AinStreamer.TimerPeriod,                    ... 
                               'StartDelay',0,                 ... 
                               'TasksToExecute',inf,           ... 
                               'ExecutionMode','fixedSpacing', ...
                               'TimerFcn',{@timerCallback,AinStreamer.CurrentWindow,obj});                           
                           
            %Reset Plot
            set(AinStreamer.Signal.Plot,'XData',[],'YData',[]);

            % Send 'Select channel' command to the AM
            Channel_bg_Callback(AinStreamer.handles.Channel_bg,[],[], obj);

            % Send 'Select range' command to the AM
            Range_bg_Callback(AinStreamer.handles.Range_bg, [], [], obj);

            % Send 'Start' command to the AM
            switch AinStreamer.CurrentWindow
                case 'Signal'

                    %AinStreamer.SerialPort.write(uint8([213 61]), 'uint8');
                    disp('Here StartStreamingSignal method?')
                    obj.Port.write(uint8([213 61]), 'uint8');
                case 'Events'
                    %AinStreamer.SerialPort.write(uint8([213 65]), 'uint8');
                    disp('Here StartStreamingEvents method?')
                    obj.Port.write(uint8([213 65]), 'uint8');
            end

            AinStreamer.Running=1;

            flush(obj.Port)

            start(AinStreamer.timer);

        end
    end
end

function Stop_btn_Callback(hObject, eventdata, handles, obj)

global AinStreamer;

switch AinStreamer.CurrentWindow
    case 'Log'
        
        if AinStreamer.Logging==1
            
            flush(obj.Port)
            
            % Send 'Retrieve' command to the AM
            AinStreamer.Logging = 0;
            AinStreamer.handles.Value_txt.FontSize = 14;
            AinStreamer.handles.Value_txt.String = 'Retrieving';
            
            data = obj.RetrieveData;
            xdata = data.x;
            ydata = data.y;
            
            AinStreamer.handles.Value_txt.FontSize = 14;
            AinStreamer.handles.Value_txt.String = 'Retrieved';
            
            %clean plots
            for i=1:8
                set(AinStreamer.Log.Plot(i),'XData',[],'YData',[]);
            end
            
            for i=1:8
                set(AinStreamer.Log.Plot(i),'XData',xdata,'YData',ydata(i,:));
            end
            
            switch AinStreamer.SelectedRange
                case 1
                    AinStreamer.Log.Axis.YLim = [0 10];
                case 2
                    AinStreamer.Log.Axis.YLim = [-2.5 2.5];
                case 3
                    AinStreamer.Log.Axis.YLim = [-5 5];
                case 4
                    AinStreamer.Log.Axis.YLim = [-10 10];
            end
            
            AinStreamer.Log.Axis.XLim = [xdata(1) xdata(end)];
            
        end
        
    otherwise % Signal or Event
        stop(AinStreamer.timer);
        
        disp('Here add stop streaming methods');
        % Send 'Stop signal' and 'Stop Events' commands
        obj.Port.write(uint8([213 62]), 'uint8');
        obj.Port.write(uint8([213 66]), 'uint8');

        flush(obj.Port)

end
AinStreamer.Running=0;
end

function Win_edt_Callback(hObject, eventdata, handles, obj)
    global AinStreamer
    AinStreamer.TimeWindow = str2double(get(hObject,'String'));
end

function SamplingRate_edt_Callback(hObject, eventdata, handles, obj)

global AinStreamer

    if AinStreamer.Running

        disp('Replace here with stop streaming methods.')
        stop(AinStreamer.timer);

        % Send Stop
        obj.Port.write(uint8([213 62]), 'uint8');
        obj.Port.write(uint8([213 66]), 'uint8');
        obj.Port.write(uint8([213 69]), 'uint8');
    end

    % Set sampling period
    SamplingRate = str2double(AinStreamer.handles.SamplingRate_edt.String);
    AinStreamer.SamplingRate = SamplingRate;
    
    flush(obj.Port)

    obj.SamplingRate = SamplingRate;

    if AinStreamer.Running
        % Send 'Start' command to the AM
        disp('Replace here with start streaming method')
        switch AinStreamer.CurrentWindow
            
            case 'Signal'
                obj.Port.write(uint8([213 61]), 'uint8');
            case 'Events'
                obj.Port.write(uint8([213 65]), 'uint8');
        end
        start(AinStreamer.timer);
    end
end

function timerCallback(~,~,Tab,obj)

    global AinStreamer;
         
    ts = tic;
%     if AnalogModuleStreamer.SerialPort.bytesAvailable>8
%         AnalogModuleStreamer.handles.Message_txt.String =  'Too fast...';
%     else
%         AnalogModuleStreamer.handles.Message_txt.String =  '';
%     end
    
    % Read
    switch Tab
        
        case 'Signal'
            
            if obj.Port.bytesAvailable>=4

                % Increase time only if there is a byte available
                AinStreamer.T = AinStreamer.T + 1/AinStreamer.SamplingRate;

                a = obj.ScaleValue('toVolts',obj.Port.read(1, 'uint32'),obj.ValidRanges(AinStreamer.SelectedRange));

                xdata = [AinStreamer.Signal.Plot.XData AinStreamer.T];
                ydata = [AinStreamer.Signal.Plot.YData a];

                set(AinStreamer.Signal.Plot,'XData',xdata,'YData',ydata)
                AinStreamer.Signal.Axis.XLim = [0 xdata(end)];

                % Constant-size window
                if AinStreamer.T>=AinStreamer.TimeWindow

                    xdata_win = xdata(xdata>AinStreamer.T-AinStreamer.TimeWindow);
                    ydata_win = ydata(xdata>AinStreamer.T-AinStreamer.TimeWindow);
                    set(AinStreamer.Signal.Plot,'XData',xdata_win,'YData',ydata_win)
                    AinStreamer.Signal.Axis.XLim = [AinStreamer.T-AinStreamer.TimeWindow AinStreamer.T];
                end

%                 switch AinStreamer.SelectedRange
%                     case 4
%                         AinStreamer.Signal.Axis.YLim = [0 10];
%                     case 3
%                         AinStreamer.Signal.Axis.YLim = [-2.5 2.5];
%                     case 2
%                         AinStreamer.Signal.Axis.YLim = [-5 5];
%                     case 1
%                         AinStreamer.Signal.Axis.YLim = [-10 10];
%                 end

                drawnow
                AinStreamer.handles.Value_txt.FontSize = 40;
                AinStreamer.handles.Value_txt.String = num2str(a,'%2.4f');
            end
            
        case 'Events'

            if obj.Port.bytesAvailable>0

                % Increase time only if there is a byte available
                AinStreamer.T = AinStreamer.T + 1/AinStreamer.SamplingRate;

                % Read Threshold Events
                a = double(obj.Port.read(1, 'uint8'));

                Events = dec2bin(a,8);

                xdata = [AinStreamer.Events.Plot(1).XData AinStreamer.T AinStreamer.T nan];

                for i=1:8

                    if Events(i)=='1'
                        ydata = [AinStreamer.Events.Plot(i).YData [(8-i)*2 (8-i)*2+1] nan];
                    else
                        ydata = [AinStreamer.Events.Plot(i).YData nan nan nan];
                    end 

                    set(AinStreamer.Events.Plot(i),'XData',xdata,'YData',ydata);
                    AinStreamer.Events.Axis.XLim = [0 xdata(end-1)];

                    % Constant-size window
                    if AinStreamer.T>=AinStreamer.TimeWindow
                        AinStreamer.Events.Axis.XLim = [AinStreamer.T-AinStreamer.TimeWindow AinStreamer.T];
                    end

                end
                drawnow
            end
        end
end

function Channel_bg_Callback(hObject, eventdata, handles, obj)

global AinStreamer

    %Change channel
    % Select ADC channel
    switch hObject.SelectedObject.String
        case 'Channel 0'
            AinStreamer.SelectedChannel = 0;
        case 'Channel 1'
            AinStreamer.SelectedChannel = 1;
        case 'Channel 2'
            AinStreamer.SelectedChannel = 2;
        case 'Channel 3'
            AinStreamer.SelectedChannel = 3;
        case 'Channel 4'
            AinStreamer.SelectedChannel = 4;
        case 'Channel 5'
            AinStreamer.SelectedChannel = 5;
        case 'Channel 6'
            AinStreamer.SelectedChannel = 6;
        case 'Channel 7'
            AinStreamer.SelectedChannel = 7;
        otherwise
    end

    % stop timer
    if isfield(AinStreamer,'timer')
        stop(AinStreamer.timer);
    end

    %Stop streaming
    disp('Start/Stop streaming methods')
    switch AinStreamer.CurrentWindow
        case 'Signal'
            obj.Port.write(uint8([213 62]), 'uint8');
        case 'Events'
            obj.Port.write(uint8([213 66]), 'uint8');
    end

    % Send 'Select channel' command to the AM
    disp('Select streaming channel method')
    obj.Port.write(uint8([213 63 AinStreamer.SelectedChannel]), 'uint8');

    % if it was running, start again
    if AinStreamer.Running
        disp('Start/Stop streaming methods')
        switch AinStreamer.CurrentWindow
            case 'Signal'
                obj.Port.write(uint8([213 61]), 'uint8');
            case 'Events'
                obj.Port.write(uint8([213 65]), 'uint8');
        end

        start(AinStreamer.timer);
    end

    %Reset Plot
    set(AinStreamer.Signal.Plot,'XData',[],'YData',[]);

    % --- Executes when selected object is changed in range_btngroup.
end
    
function Range_bg_Callback(hObject, eventdata, handles, obj)

    % Select ADC Range
    global AinStreamer

    switch hObject.SelectedObject.String
        case '0V - 10V'
            AinStreamer.SelectedRange = 4;
        case '-2.5V - 2.5V'
            AinStreamer.SelectedRange = 3;
        case '-5V - 5V'
            AinStreamer.SelectedRange = 2;
        case '-10V - 10V'
            AinStreamer.SelectedRange = 1;
        otherwise            
    end

    % stop timer
    if isfield(AinStreamer,'timer')
        stop(AinStreamer.timer);
    end

    %Stop streaming
    disp('start/stop method')
    switch AinStreamer.CurrentWindow
        case 'Signal'
            obj.Port.write(uint8([213 62]), 'uint8');
        case 'Events'
            obj.Port.write(uint8([213 66]), 'uint8');
    end

    flush(obj.Port)

    % Set Voltage range
    disp('add faster way')
    obj.VoltageRange = {1, obj.ValidRanges{1,AinStreamer.SelectedRange};...
                      2, obj.ValidRanges{1,AinStreamer.SelectedRange};...
                      3, obj.ValidRanges{1,AinStreamer.SelectedRange};...
                      4, obj.ValidRanges{1,AinStreamer.SelectedRange};...
                      5, obj.ValidRanges{1,AinStreamer.SelectedRange};...
                      6, obj.ValidRanges{1,AinStreamer.SelectedRange};...
                      7, obj.ValidRanges{1,AinStreamer.SelectedRange};...
                      8, obj.ValidRanges{1,AinStreamer.SelectedRange}};

    % if it was running, start again
    if AinStreamer.Running
        disp('start/stop method')
        switch AinStreamer.CurrentWindow
            case 'Signal'
                obj.Port.write(uint8([213 61]), 'uint8');
            case 'Events'
                obj.Port.write(uint8([213 65]), 'uint8');
        end

        start(AinStreamer.timer);
    end

    %Reset Plot
    set(AinStreamer.Signal.Plot,'XData',[],'YData',[]);
end

function TabChange_Callback(hObject, eventdata, handles, obj)
    
global AinStreamer
AinStreamer.CurrentWindow = hObject.SelectedTab.Title;

    if AinStreamer.Running

        switch AinStreamer.CurrentWindow
        
            case 'Signal'
            
            stop(AinStreamer.timer);
             
            flush(obj.Port)
            
            %Stop sending events
            disp('start/stop')
            obj.Port.write(uint8([213 66]), 'uint8');
            
            %Reset Plot
            set(AinStreamer.Signal.Plot,'XData',[],'YData',[]);
            %Acquisition timer
            AinStreamer.timer = timer('Name','MyTimer',               ...
                'Period',AinStreamer.TimerPeriod,                    ...
                'StartDelay',0,                 ...
                'TasksToExecute',inf,           ...
                'ExecutionMode','fixedSpacing', ...
                'TimerFcn',{@timerCallback,'Signal',obj});
            
            % Start sending signal
            disp('start/stop')
            obj.Port.write(uint8([213 61]), 'uint8');
           
            start(AinStreamer.timer);
            AinStreamer.Running=1;
            
        case 'Events'
            
            % Stop reading
            stop(AinStreamer.timer);
            
            flush(obj.Port)

            %Stop sending signal
            disp('stop')
            obj.Port.write(uint8([213 62]), 'uint8');
            
            SetThresholds_Callback([],[])
            
            %Reset Plot
            set(AinStreamer.Events.Plot,'XData',[],'YData',[]);
                AinStreamer.timer = timer('Name','MyTimer',               ...
                'Period',AinStreamer.TimerPeriod,                    ...
                'StartDelay',0,                 ...
                'TasksToExecute',inf,           ...
                'ExecutionMode','fixedSpacing', ...
                'TimerFcn',{@timerCallback,'Events',obj});

            
            %Start sending events
            disp('stop')
            obj.Port.write(uint8([213 65]), 'uint8');
            
            start(AinStreamer.timer);
            AinStreamer.Running=1;
        end
    end
end

function SetThresholds_Callback(~,~,~,obj)

    global AinStreamer
    
    for i=1:8
        AinStreamer.CurrentThresholds(i) = str2num(AinStreamer.handles.Threshold_edt(i).String);
        AinStreamer.CurrentResetValues(i) = str2num(AinStreamer.handles.ResetValues_edt(i).String);
    end

    %Send Thresholds
    %flush(obj.Port)
    obj.Thresholds = [(1:8)' AinStreamer.CurrentThresholds']; %Thresholds in Volts
    
    %flush(obj.Port)
    obj.ResetValues = [(1:8)', AinStreamer.CurrentResetValues']; %Thresholds in Volts
end


function CloseReq(hObject, eventdata, handles, obj)
    delete(gcf)
    clear AinStreamer
end
