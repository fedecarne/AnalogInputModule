function Streamer(obj)

%Initialize obj.GUIhandles
obj.GUIhandles.T=0;
obj.GUIhandles.TimeWindow = 5; % in seconds
obj.GUIhandles.TimerPeriod = 0.001;% in seconds
obj.GUIhandles.SamplingRate = 50; % in HZ
obj.GUIhandles.xpos = 0; % x-axis position for current time
obj.GUIhandles.xN = round(obj.GUIhandles.TimeWindow*obj.GUIhandles.SamplingRate); % total amount of data point in time window 
obj.GUIhandles.ydata = nan(1,obj.GUIhandles.xN);
obj.GUIhandles.SelectedChannel = 0;
obj.GUIhandles.SelectedRange = 1;
obj.GUIhandles.Running = 0;
obj.GUIhandles.Logging = 0;
obj.GUIhandles.CurrentWindow = 'Signal';

obj.GUIhandles.Figure = figure('Name','AnalogModule Streamer',...
                                     'NumberTitle','off',...
                                     'MenuBar','none',...
                                     'Color',0.95*[1 1 1],...
                                     'Position',[1090,650,820,400],...
                                     'CloseRequestFcn',{@(hpb,eventdata)CloseReq(hpb,eventdata,guidata(hpb),obj)});

set(gcf,'toolbar','figure');
a = findall(gcf);
set(findall(a,'ToolTipString','Save Figure'),'Visible','Off')
set(findall(a,'ToolTipString','Print Figure'),'Visible','Off')
set(findall(a,'ToolTipString','Open File'),'Visible','Off')
set(findall(a,'ToolTipString','New Figure'),'Visible','Off')
set(findall(a,'ToolTipString','Rotate 3D'),'Visible','Off')
set(findall(a,'ToolTipString','Edit Plot'),'Visible','Off')
set(findall(a,'ToolTipString','Insert Colorbar'),'Visible','Off')
set(findall(a,'ToolTipString','Insert Legend'),'Visible','Off')
set(findall(a,'ToolTipString','Link Plot'),'Visible','Off')
set(findall(a,'ToolTipString','Hide Plot Tools'),'Visible','Off')
set(findall(a,'ToolTipString','Show Plot Tools and Dock Figure'),'Visible','Off')
set(findall(a,'ToolTipString','Brush/Select Data'),'Visible','Off')

tabgp = uitabgroup('Position',[0.01,0.1,0.7,0.9],'SelectionChangedFcn',{@(hpb,eventdata)TabChange_Callback(hpb,eventdata,guidata(hpb),obj)});
Signal_tab = uitab(tabgp,'Title','Signal','BackgroundColor',0.52*[1 1 1]);
Event_tab = uitab(tabgp,'Title','Events','BackgroundColor',0.52*[1 1 1]);
Log_tab = uitab(tabgp,'Title','Log','BackgroundColor',0.52*[1 1 1]);

%------------------------------------------------------------------------------
obj.GUIhandles.Signal.Axis = axes('parent', Signal_tab,...
                                        'Position',[.09,.1,.88,.83],...
                                        'FontSize',14,...
                                        'Color','k'); 
                                         
obj.GUIhandles.Signal.Axis.GridColor = [1 1 1];
grid(obj.GUIhandles.Signal.Axis,'on')                                                                              
                                        
obj.GUIhandles.Signal.Plot = line(nan,nan,...
                               'Parent',obj.GUIhandles.Signal.Axis,...
                               'LineStyle','-',...
                               'Marker','.',...
                               'MarkerSize',10,...
                               'Color',[1 1 0],...
                               'LineWidth',2);

%------------------------------------------------------------------------------
%Events tab
obj.GUIhandles.Events.Axis = axes('parent', Event_tab,...
                                'Position',[.09,.1,.88,.83],...
                                'FontSize',14,...
                                'Color','k'); 
                                         
obj.GUIhandles.Events.Axis.GridColor = [1 1 1];
grid(obj.GUIhandles.Events.Axis,'on'); 
obj.GUIhandles.Events.Axis.YLim = [-1 16];
obj.GUIhandles.Events.Axis.YTick = 0.5:2:14.5;
obj.GUIhandles.Events.Axis.YTickLabel = {'Ch0','Ch1','Ch2','Ch3','Ch4','Ch5','Ch6','Ch7'};
             
c = colormap(lines(8));
for i=1:8
    obj.GUIhandles.Events.Plot(i) = line(nan,nan,...
                                       'Parent',obj.GUIhandles.Events.Axis,...
                                       'LineStyle','-',...
                                       'Color', c(i,:),...
                                       'LineWidth',2);

end

%------------------------------------------------------------------------------
%Log tab
obj.GUIhandles.Log.Axis = axes('parent', Log_tab,...
                            'Position',[.09,.1,.88,.83],...
                            'FontSize',14,...
                            'Color','k'); 
                                         
obj.GUIhandles.Log.Axis.GridColor = [1 1 1];
grid(obj.GUIhandles.Log.Axis,'on');                                                                           
             
c = colormap(parula(8));
for i=1:8
    obj.GUIhandles.Log.Plot(i) = line(nan,nan,...
                                   'Parent',obj.GUIhandles.Log.Axis,...
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
                 
obj.GUIhandles.Channel_bg = uibuttongroup('Title','Channel',...
                           'BackgroundColor',0.95*[1 1 1],...
                           'Position',[0.72 0.35 0.11 0.35],...
                           'SelectionChangedFcn',{@(hpb,eventdata)Channel_bg_Callback(hpb,eventdata,guidata(hpb),obj)});
       
PosY = 0.95;
for i=1:8
    PosY = PosY -0.11;
    Channel_bn(i) = uicontrol(obj.GUIhandles.Channel_bg,'Style',...
                              'radiobutton',...
                              'BackgroundColor',0.95*[1 1 1],...
                              'String',['Channel ' num2str(i)],...
                              'Units','normalized',...
                              'Position',[0.07 PosY 0.9 0.12]);
end

obj.GUIhandles.Range_bg = uibuttongroup('Title','Range',...
                                            'Position',[0.72 0.15 0.11 0.2],...
                                            'BackgroundColor',0.95*[1 1 1],...
                                            'SelectionChangedFcn',{@(hpb,eventdata)Range_bg_Callback(hpb,eventdata,guidata(hpb),obj)});
   
Range_str = obj.ValidRanges;

PosY = 0.97;
for i=1:4
    PosY = PosY -0.21;
    Range_bn(i) = uicontrol(obj.GUIhandles.Range_bg,'Style',...
                          'radiobutton',...
                          'BackgroundColor',0.95*[1 1 1],...
                          'String',Range_str{i},...
                          'FontSize',7,...
                          'Units','normalized',...
                          'Position',[0.07 PosY 0.9 0.12]);
end

Win_txt = uicontrol('Style', 'text',...
                    'String', 'Time Win',...
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
                    'String', 'Sampling Rate(Hz)',...
                    'Units','normalized',...
                    'Position', [0.02 0.01 0.15 0.06],...
                    'BackgroundColor',0.95*[1 1 1],...
                    'FontSize',10);
                
obj.GUIhandles.SamplingRate_edt = uicontrol('Style', 'edit',...
                    'String', num2str(obj.GUIhandles.SamplingRate),...
                    'Units','normalized',...
                    'Position', [0.17 0.025 0.06 0.05],...
                    'FontSize',10,'Callback', {@(hpb,eventdata)SamplingRate_edt_Callback(hpb,eventdata,guidata(hpb),obj)});
                
obj.GUIhandles.Message_txt = uicontrol('Style', 'text',...
                    'String', '',...
                    'HorizontalAlignment','left',...
                    'ForegroundColor', 'red',...
                    'Units','normalized',...
                    'Position', [0.23 0.01 0.23 0.06],...
                    'BackgroundColor',0.95*[1 1 1],...
                    'FontSize',10);
                 
obj.GUIhandles.Value_txt = uicontrol('Style', 'text',...
                     'String', {[];'-.-';[]},...
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
                              'String',['Ch' num2str(i)],...
                              'FontSize',7,...
                              'Units','normalized',...
                              'Position',[0.005 PosY-0.01 0.2 0.08]);
                          
    obj.GUIhandles.Threshold_edt(i) = uicontrol(Threshold_bg,'Style',...
                              'edit',...
                              'String',0,...
                              'Units','normalized',...
                              'Position',[0.25 PosY 0.3 0.08]);
                          
    obj.GUIhandles.ResetValues_edt(i) = uicontrol(Threshold_bg,'Style',...
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
                          
%Set 0-10V default Voltage range
flush(obj.Port)
obj.VoltageRange(1:8) = repmat({'-10V:10V'},1,8);
obj.SamplingRate = obj.GUIhandles.SamplingRate;
obj.ActiveChannels = 1:8;
obj.StreamChannel = 1;
end

function Start_btn_Callback(hObject, eventdata, handles, obj)

    switch obj.GUIhandles.CurrentWindow
        case 'Log'

            obj.GUIhandles.Running = 0;
            if obj.GUIhandles.Logging==0

                obj.GUIhandles.Value_txt.FontSize = 14;
                obj.GUIhandles.Value_txt.String = {'','Logging...'};

                flush(obj.Port)

                % Start logging
                obj.StartLogging;
                obj.GUIhandles.Logging = 1;
            end

    otherwise % Signal or Event

        if obj.GUIhandles.Running==0

            %Reset acquisition time
            obj.GUIhandles.T = 0;

            flush(obj.Port)
                        
            %Set sampling period                        
            SamplingRate = str2double(obj.GUIhandles.SamplingRate_edt.String);            
            obj.GUIhandles.SamplingRate = SamplingRate;
            
            %obj.SamplingRate = SamplingRate;

            %Acquisition timer
            obj.GUIhandles.timer = timer('Name','MyTimer',               ...
                               'Period',obj.GUIhandles.TimerPeriod,                    ... 
                               'StartDelay',0,                 ... 
                               'TasksToExecute',inf,           ... 
                               'ExecutionMode','fixedSpacing', ...
                               'TimerFcn',{@timerCallback,obj.GUIhandles.CurrentWindow,obj});                           
                           
            %Reset Plot
            set(obj.GUIhandles.Signal.Plot,'XData',[],'YData',[]);

            % Send 'Start' command to the AM
            switch obj.GUIhandles.CurrentWindow
                case 'Signal'
                    obj.StartUSBstreaming('Signal');
                case 'Events'
                    obj.StartUSBstreaming('Events');
            end

            obj.GUIhandles.Running=1;
            start(obj.GUIhandles.timer);
        end
    end
end

function Stop_btn_Callback(hObject, eventdata, handles, obj)

switch obj.GUIhandles.CurrentWindow
    case 'Log'
        
        if obj.GUIhandles.Logging==1
            
            flush(obj.Port)
            
            % Send 'Retrieve' command to the AM
            obj.GUIhandles.Logging = 0;
            obj.GUIhandles.Value_txt.FontSize = 14;
            obj.GUIhandles.Value_txt.String = {'','Retrieving...'};
            
            data = obj.RetrieveData;
            xdata = data.x;
            ydata = data.y;
            
            obj.GUIhandles.Value_txt.FontSize = 14;
            obj.GUIhandles.Value_txt.String = {'','Done!'};
            
            %clean plots
            for i=1:8
                set(obj.GUIhandles.Log.Plot(i),'XData',[],'YData',[]);
            end
            
            for i=1:8
                set(obj.GUIhandles.Log.Plot(i),'XData',xdata,'YData',ydata(i,:));
            end
            
            switch obj.GUIhandles.SelectedRange
                case 1
                    obj.GUIhandles.Log.Axis.YLim = [-10 10];
                case 2
                    obj.GUIhandles.Log.Axis.YLim = [-5 5];
                case 3
                    obj.GUIhandles.Log.Axis.YLim = [-2.5 2.5];
                case 4
                    obj.GUIhandles.Log.Axis.YLim = [0 10];
            end
            
            obj.GUIhandles.Log.Axis.XLim = [xdata(1) xdata(end)];
            
        end
        
    otherwise % Signal or Event
        
        stop(obj.GUIhandles.timer);

        % Send 'Stop signal' and 'Stop Events' commands
        obj.StopUSBstreaming;

        flush(obj.Port)

end
obj.GUIhandles.Running=0;
end

function Win_edt_Callback(hObject, eventdata, handles, obj)

    tw = str2double(get(hObject,'String'));
    if ~isnan(tw) && ~tw==0
        obj.GUIhandles.TimeWindow = str2double(get(hObject,'String'));
        obj.GUIhandles.xpos = 0;
        obj.GUIhandles.xN = round(obj.GUIhandles.TimeWindow*obj.GUIhandles.SamplingRate);
        obj.GUIhandles.ydata = nan(1,obj.GUIhandles.xN);
    else
        hObject.String = num2str(obj.GUIhandles.TimeWindow);
    end

end

function SamplingRate_edt_Callback(hObject, eventdata, handles, obj)

    sr = str2double(get(hObject,'String'));
    if ~isnan(sr) && ~sr==0    
        
        if obj.GUIhandles.Running

                stop(obj.GUIhandles.timer);

                % Send Stop
                obj.StopUSBstreaming;
            end

        % Set sampling period
        SamplingRate = sr;
        obj.GUIhandles.SamplingRate = SamplingRate;
    
        flush(obj.Port)

        obj.SamplingRate = SamplingRate;

        % plotting properties
        obj.GUIhandles.xpos = 0;
        obj.GUIhandles.xN = round(obj.GUIhandles.TimeWindow*obj.GUIhandles.SamplingRate);
        obj.GUIhandles.ydata = nan(1,obj.GUIhandles.xN);

        if obj.GUIhandles.Running

            % Send 'Start' command to the AM
            switch obj.GUIhandles.CurrentWindow
                case 'Signal'
                    obj.StartUSBstreaming('Signal');
                case 'Events'
                    obj.StartUSBstreaming('Events');
            end

            start(obj.GUIhandles.timer);
        end
    else
        hObject.String = num2str(obj.SamplingRate);
    end
end

function timerCallback(~,~,Tab,obj)

    ts = tic;
    if obj.Port.bytesAvailable>8
        obj.GUIhandles.Message_txt.String =  'Too fast...';
    else
        obj.GUIhandles.Message_txt.String =  '';
    end
    
    % Read
    switch Tab
        
        case 'Signal'
            
            if obj.Port.bytesAvailable>=4
                
                % Increase time only if there is a byte available
                obj.GUIhandles.T = obj.GUIhandles.T + 1/obj.GUIhandles.SamplingRate;
                
                % Read new byte
                a = obj.ScaleValue('toVolts',obj.Port.read(1, 'uint16'),obj.ValidRanges(obj.GUIhandles.SelectedRange));
                
                % Sweep like osciloscope
                xdata = 1:obj.GUIhandles.xN;
                obj.GUIhandles.xpos = mod(obj.GUIhandles.xpos,obj.GUIhandles.xN)+1;
                obj.GUIhandles.ydata(1,obj.GUIhandles.xpos) = a;
                obj.GUIhandles.ydata(1,mod(obj.GUIhandles.xpos+(0:round(obj.GUIhandles.xN*0.1)),obj.GUIhandles.xN)+1) = nan;
                
                set(obj.GUIhandles.Signal.Plot,'XData',xdata,'YData',obj.GUIhandles.ydata)
                obj.GUIhandles.Signal.Axis.XLim = [0 obj.GUIhandles.xN];
                
                switch obj.GUIhandles.SelectedRange
                    case 4
                        obj.GUIhandles.Signal.Axis.YLim = [0 10];
                    case 3
                        obj.GUIhandles.Signal.Axis.YLim = [-2.5 2.5];
                    case 2
                        obj.GUIhandles.Signal.Axis.YLim = [-5 5];
                    case 1
                        obj.GUIhandles.Signal.Axis.YLim = [-10 10];
                end
                
                drawnow
                obj.GUIhandles.Value_txt.FontSize = 40;
                obj.GUIhandles.Value_txt.String = num2str(a,'%2.4f');
            end
            
        case 'Events'
            
            if obj.Port.bytesAvailable>0
                
                % Increase time only if there is a byte available
                obj.GUIhandles.T = obj.GUIhandles.T + 1/obj.GUIhandles.SamplingRate;
                
                % Read Threshold Events
                a = double(obj.Port.read(1, 'uint8'));
                
                Events = dec2bin(a,8);
                
                xdata = [obj.GUIhandles.Events.Plot(1).XData obj.GUIhandles.T obj.GUIhandles.T nan];
                
                for i=1:8
                    
                    if Events(i)=='1'
                        ydata = [obj.GUIhandles.Events.Plot(i).YData [(8-i)*2 (8-i)*2+1] nan];
                    else
                        ydata = [obj.GUIhandles.Events.Plot(i).YData nan nan nan];
                    end
                    
                    set(obj.GUIhandles.Events.Plot(i),'XData',xdata,'YData',ydata);
                    obj.GUIhandles.Events.Axis.XLim = [0 xdata(end-1)];
                    
                    % Constant-size window
                    if obj.GUIhandles.T>=obj.GUIhandles.TimeWindow
                        obj.GUIhandles.Events.Axis.XLim = [obj.GUIhandles.T-obj.GUIhandles.TimeWindow obj.GUIhandles.T];
                    end
                    
                end
                drawnow
            end
    end
end

function Channel_bg_Callback(hObject, eventdata, handles, obj)

    %Change channel
    % Select ADC channel
    switch hObject.SelectedObject.String
        case 'Channel 1'
            obj.GUIhandles.SelectedChannel = 1;
        case 'Channel 2'
            obj.GUIhandles.SelectedChannel = 2;
        case 'Channel 3'
            obj.GUIhandles.SelectedChannel = 3;
        case 'Channel 4'
            obj.GUIhandles.SelectedChannel = 4;
        case 'Channel 5'
            obj.GUIhandles.SelectedChannel = 5;
        case 'Channel 6'
            obj.GUIhandles.SelectedChannel = 6;
        case 'Channel 7'
            obj.GUIhandles.SelectedChannel = 7;
        case 'Channel 8'
            obj.GUIhandles.SelectedChannel = 8;
        otherwise
    end

    % stop timer
    if isfield(obj.GUIhandles,'timer')
        stop(obj.GUIhandles.timer);
    end

    %Stop streaming
    switch obj.GUIhandles.CurrentWindow
        case 'Signal'
            obj.StopUSBstreaming('Signal');
        case 'Events'
            obj.StopUSBstreaming('Events');
    end

    % Send 'Select channel' command to the AM
    obj.StreamChannel = obj.GUIhandles.SelectedChannel;
    
    % if it was running, start again
    if obj.GUIhandles.Running

        flush(obj.Port)
        start(obj.GUIhandles.timer);
        switch obj.GUIhandles.CurrentWindow
            case 'Signal'
                obj.StartUSBstreaming('Signal');
            case 'Events'
                obj.StartUSBstreaming('Events');
        end

        
    end

    %Reset Plot
    set(obj.GUIhandles.Signal.Plot,'XData',[],'YData',[]);
end
    
function Range_bg_Callback(hObject, eventdata, handles, obj)

    obj.GUIhandles.SelectedRange = find(strcmp(hObject.SelectedObject.String,obj.ValidRanges));

    % stop timer
    if isfield(obj.GUIhandles,'timer')
        stop(obj.GUIhandles.timer);
    end

    %Stop streaming
    switch obj.GUIhandles.CurrentWindow
        case 'Signal'
            obj.StopUSBstreaming('Signal');
        case 'Events'
            obj.StopUSBstreaming('Events');
    end

    flush(obj.Port)

    % Set Voltage range
    obj.VoltageRange(1:8) = repmat(obj.ValidRanges(1,obj.GUIhandles.SelectedRange),1,8);
    
    % if it was running, start again
    if obj.GUIhandles.Running
        
        switch obj.GUIhandles.CurrentWindow
            case 'Signal'
                obj.StartUSBstreaming('Signal');
            case 'Events'
                obj.StartUSBstreaming('Events');
        end

        start(obj.GUIhandles.timer);
    end

    %Reset Plot
    set(obj.GUIhandles.Signal.Plot,'XData',[],'YData',[]);
end

function TabChange_Callback(hObject, eventdata, handles, obj)
    
obj.GUIhandles.CurrentWindow = hObject.SelectedTab.Title;

    if obj.GUIhandles.Running

        switch obj.GUIhandles.CurrentWindow
        
            case 'Signal'
            
                stop(obj.GUIhandles.timer);

                %Stop sending events
                obj.StopUSBstreaming('Events');

                %Reset Plot
                set(obj.GUIhandles.Signal.Plot,'XData',[],'YData',[]);
                
                
                %Acquisition timer
                obj.GUIhandles.timer = timer('Name','MyTimer',               ...
                                   'Period',obj.GUIhandles.TimerPeriod,                    ... 
                                   'StartDelay',0,                 ... 
                                   'TasksToExecute',inf,           ... 
                                   'ExecutionMode','fixedSpacing', ...
                                   'TimerFcn',{@timerCallback,obj.GUIhandles.CurrentWindow,obj}); 
                           
                % Start sending signal
                obj.StartUSBstreaming('Signal');

                flush(obj.Port)
                start(obj.GUIhandles.timer);
                obj.GUIhandles.Running=1;
            
            case 'Events'

                % Stop reading
                stop(obj.GUIhandles.timer);

                %Stop sending signal
                obj.StopUSBstreaming('Signal');

                %SetThresholds_Callback([],[],[], obj);

                %Reset Plot
                set(obj.GUIhandles.Events.Plot,'XData',[],'YData',[]);
                
                %Acquisition timer
                obj.GUIhandles.timer = timer('Name','MyTimer',               ...
                                   'Period',obj.GUIhandles.TimerPeriod,                    ... 
                                   'StartDelay',0,                 ... 
                                   'TasksToExecute',inf,           ... 
                                   'ExecutionMode','fixedSpacing', ...
                                   'TimerFcn',{@timerCallback,obj.GUIhandles.CurrentWindow,obj});

                %Start sending events
                obj.StartUSBstreaming('Events');

                flush(obj.Port);
                start(obj.GUIhandles.timer);
                obj.GUIhandles.Running=1;

            case 'Log'
                
                stop(obj.GUIhandles.timer);
                
                %Stop sending events
                obj.StopUSBstreaming();
                
                %Reset Plot
                set(obj.GUIhandles.Signal.Plot,'XData',[],'YData',[]);
        end
    end
end

function SetThresholds_Callback(~,~,~,obj)
    
    for i=1:8
        obj.GUIhandles.CurrentThresholds(i) = str2num(obj.GUIhandles.Threshold_edt(i).String);
        obj.GUIhandles.CurrentResetValues(i) = str2num(obj.GUIhandles.ResetValues_edt(i).String);
    end

    % stop timer
    if isfield(obj.GUIhandles,'timer')
        stop(obj.GUIhandles.timer);
    end

    %Stop streaming
    obj.StopUSBstreaming();

    flush(obj.Port)
    
    %Send Thresholds
    obj.Thresholds = [(1:8)' obj.GUIhandles.CurrentThresholds']; %Thresholds in Volts

    obj.ResetValues = [(1:8)', obj.GUIhandles.CurrentResetValues']; %Thresholds in Volts
    
    % if it was running, start again
    if obj.GUIhandles.Running
        
        switch obj.GUIhandles.CurrentWindow
            case 'Signal'
                obj.StartUSBstreaming('Signal');
            case 'Events'
                obj.StartUSBstreaming('Events');
        end

        start(obj.GUIhandles.timer);
    end
    
    
end

function CloseReq(hObject, eventdata, handles, obj)
    flush(obj.Port);
    delete(gcf)
    clear obj.GUIhandles
end
