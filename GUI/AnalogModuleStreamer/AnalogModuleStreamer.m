function AnalogModuleStreamer()

global AnalogModuleStreamer
global AnalogModuleSystem

conn = AnalogModule;

switch conn
    case 0
        return
    case 1
end
    
AnalogModuleStreamer.SerialPort = AnalogModuleSystem.SerialPort;

%Initialize AnalogModuleStreamer object
AnalogModuleStreamer.T=0;
AnalogModuleStreamer.TimeWindow = 5; % in seconds
AnalogModuleStreamer.TimerPeriod = 0.01;% in seconds
AnalogModuleStreamer.SamplingPeriod = 250; % hardware timer interval in us
AnalogModuleStreamer.SelectedChannel = 0;
AnalogModuleStreamer.SelectedRange = 1;
AnalogModuleStreamer.Running = 0;
AnalogModuleStreamer.Logging = 0;
AnalogModuleStreamer.CurrentWindow = 'Signal';


AnalogModuleStreamer.Figure = figure('Name','AnalogModule Streamer',...
                                     'NumberTitle','off',...
                                     'MenuBar','none',...
                                     'Color',0.95*[1 1 1],...
                                     'Position',[1090,650,820,400],...
                                     'CloseRequestFcn',{@CloseReq});

tabgp = uitabgroup('Position',[0.01,0.1,0.7,0.9],'SelectionChangedFcn',{@TabChange_Callback});
Signal_tab = uitab(tabgp,'Title','Signal','BackgroundColor',0.52*[1 1 1]);
Event_tab = uitab(tabgp,'Title','Events','BackgroundColor',0.52*[1 1 1]);
Log_tab = uitab(tabgp,'Title','Log','BackgroundColor',0.52*[1 1 1]);

%------------------------------------------------------------------------------
AnalogModuleStreamer.Signal.Axis = axes('parent', Signal_tab,...
                                            'Position',[.09,.1,.88,.83],...
                                            'FontSize',14,...
                                            'Color','k'); 
                                         
AnalogModuleStreamer.Signal.Axis.GridColor = [1 1 1];
grid(AnalogModuleStreamer.Signal.Axis,'on')                                                                              
                                        
AnalogModuleStreamer.Signal.Plot = line(nan,nan,...
                                   'Parent',AnalogModuleStreamer.Signal.Axis,...
                                   'LineStyle','-',...
                                   'Marker','.',...
                                   'MarkerSize',10,...
                                   'Color',[1 1 0],...
                                   'LineWidth',2);
                               
%------------------------------------------------------------------------------
%Events tab
AnalogModuleStreamer.Events.Axis = axes('parent', Event_tab,...
                                            'Position',[.09,.1,.88,.83],...
                                            'FontSize',14,...
                                            'Color','k'); 
                                         
AnalogModuleStreamer.Events.Axis.GridColor = [1 1 1];
grid(AnalogModuleStreamer.Events.Axis,'on'); 
AnalogModuleStreamer.Events.Axis.YLim = [-1 16];
AnalogModuleStreamer.Events.Axis.YTick = 0.5:2:14.5;
AnalogModuleStreamer.Events.Axis.YTickLabel = {'Ch0','Ch1','Ch2','Ch3','Ch4','Ch5','Ch6','Ch7'};
             
c = colormap(lines(8));
for i=1:8
    AnalogModuleStreamer.Events.Plot(i) = line(nan,nan,...
                                   'Parent',AnalogModuleStreamer.Events.Axis,...
                                   'LineStyle','-',...
                                   'Color', c(i,:),...
                                   'LineWidth',2);

end



%------------------------------------------------------------------------------
%Log tab
AnalogModuleStreamer.Log.Axis = axes('parent', Log_tab,...
                                            'Position',[.09,.1,.88,.83],...
                                            'FontSize',14,...
                                            'Color','k'); 
                                         
AnalogModuleStreamer.Log.Axis.GridColor = [1 1 1];
grid(AnalogModuleStreamer.Log.Axis,'on');                                                                           
             
c = colormap(parula(8));
for i=1:8
    AnalogModuleStreamer.Log.Plot(i) = line(nan,nan,...
                                   'Parent',AnalogModuleStreamer.Log.Axis,...
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
                      'FontSize',12,'Callback', {@Start_btn_Callback});

Stop_btn = uicontrol('Style', 'pushbutton',...
                     'String', 'Stop',...
                     'Units','normalized','Position', [0.86 0.07 0.1 0.06],...
                     'FontSize',12,'Callback', {@Stop_btn_Callback});

                 
AnalogModuleStreamer.handles.Channel_bg = uibuttongroup('Title','Channel',...
                           'BackgroundColor',0.95*[1 1 1],...
                           'Position',[0.72 0.35 0.11 0.35],...
                           'SelectionChangedFcn',{@Channel_bg_Callback});
       
PosY = 0.95;
for i=1:8
    PosY = PosY -0.11;
    Channel_bn(i) = uicontrol(AnalogModuleStreamer.handles.Channel_bg,'Style',...
                              'radiobutton',...
                              'BackgroundColor',0.95*[1 1 1],...
                              'String',['Channel ' num2str(i-1)],...
                              'Units','normalized',...
                              'Position',[0.07 PosY 0.9 0.12]);
end

AnalogModuleStreamer.handles.Range_bg = uibuttongroup('Title','Range',...
    'Position',[0.72 0.15 0.11 0.2],...
    'BackgroundColor',0.95*[1 1 1],...
    'SelectionChangedFcn',{@Range_bg_Callback});
   
Range_str = {'0V - 10V', '-2.5V - 2.5V', '-5V - 5V', '-10V - 10V'};

PosY = 0.97;
for i=1:4
    PosY = PosY -0.21;
    Range_bn(i) = uicontrol(AnalogModuleStreamer.handles.Range_bg,'Style',...
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
                    'FontSize',10,'Callback', {@Win_edt_Callback});
                 
SamplingPeriod_txt = uicontrol('Style', 'text',...
                    'String', 'SampPeriod (ms)',...
                    'Units','normalized',...
                    'Position', [0.02 0.01 0.13 0.06],...
                    'BackgroundColor',0.95*[1 1 1],...
                    'FontSize',10);
                
AnalogModuleStreamer.handles.SamplingPeriod_edt = uicontrol('Style', 'edit',...
                    'String', '250',...
                    'Units','normalized',...
                    'Position', [0.15 0.025 0.04 0.045],...
                    'FontSize',10,'Callback', {@SamplingPeriod_edt_Callback});
                
AnalogModuleStreamer.handles.Message_txt = uicontrol('Style', 'text',...
                    'String', '',...
                    'HorizontalAlignment','left',...
                    'ForegroundColor', 'red',...
                    'Units','normalized',...
                    'Position', [0.23 0.01 0.23 0.06],...
                    'BackgroundColor',0.95*[1 1 1],...
                    'FontSize',10);
                 
                
AnalogModuleStreamer.handles.Value_txt = uicontrol('Style', 'text',...
                     'String', '-.-',...
                     'Units','normalized',...
                     'Position', [0.72 0.76 0.27 0.19],...
                     'ForegroundColor',[1 1 0],...    
                     'BackgroundColor',[0 0 0],...
                     'FontSize',40);
                 
                 


Threshold_bg = uibuttongroup('Title','Thresholds',...
                             'BackgroundColor',0.95*[1 1 1],...
                             'Position',[0.84 0.15 0.15 0.55],...
                             'SelectionChangedFcn',{@Threshold_bg_Callback});
       
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
                          
    AnalogModuleStreamer.handles.Threshold_edt(i) = uicontrol(Threshold_bg,'Style',...
                              'edit',...
                              'String',0,...
                              'Units','normalized',...
                              'Position',[0.25 PosY 0.3 0.08]);
                          
    AnalogModuleStreamer.handles.ResetValues_edt(i) = uicontrol(Threshold_bg,'Style',...
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
                              'Callback', {@SetThresholds_Callback});
                          
% Set 0-10V default Voltage range
ProgramAnalogModuleParam('VoltageRange', 1:8, 4*ones(8,1));
                          
                          
                          
                 
function Start_btn_Callback(hObject, eventdata, handles)
global AnalogModuleStreamer;

switch AnalogModuleStreamer.CurrentWindow
    case 'Log'
            
        AnalogModuleStreamer.Running = 0;
        if AnalogModuleStreamer.Logging==0

            AnalogModuleStreamer.handles.Value_txt.FontSize = 14;
            AnalogModuleStreamer.handles.Value_txt.String = 'Logging...';
            
            while AnalogModuleStreamer.SerialPort.bytesAvailable>0
                AnalogModuleStreamer.SerialPort.read(1, 'uint8');
            end
            
            % Start logging
            StartLogging;
            
            AnalogModuleStreamer.Logging = 1;
        end
        
    otherwise % Signal or Event
        
        if AnalogModuleStreamer.Running==0

            %Reset acquisition time
            AnalogModuleStreamer.T = 0;
            
            %Set sampling period
            SamplingPeriod = str2double(AnalogModuleStreamer.handles.SamplingPeriod_edt.String);            
            AnalogModuleStreamer.SamplingPeriod = SamplingPeriod; %Arduino Timer period in ms            
            ProgramAnalogModuleParam('SamplingPeriod', SamplingPeriod);

            %Acquisition timer
            AnalogModuleStreamer.timer = timer('Name','MyTimer',               ...
                               'Period',AnalogModuleStreamer.TimerPeriod,                    ... 
                               'StartDelay',0,                 ... 
                               'TasksToExecute',inf,           ... 
                               'ExecutionMode','fixedSpacing', ...
                               'TimerFcn',{@timerCallback,AnalogModuleStreamer.CurrentWindow});

            %Reset Plot
            set(AnalogModuleStreamer.Signal.Plot,'XData',[],'YData',[]);

            % Send 'Select channel' command to the AM
            Channel_bg_Callback(AnalogModuleStreamer.handles.Channel_bg,[],[]);
            
            % Send 'Select range' command to the AM
            Range_bg_Callback(AnalogModuleStreamer.handles.Range_bg, [], []);

            % Send 'Start' command to the AM
            switch AnalogModuleStreamer.CurrentWindow
                case 'Signal'
                    AnalogModuleStreamer.SerialPort.write(uint8([213 61]), 'uint8');
                case 'Events'
                    AnalogModuleStreamer.SerialPort.write(uint8([213 65]), 'uint8');
            end

            AnalogModuleStreamer.Running=1;
            while AnalogModuleStreamer.SerialPort.bytesAvailable>0
                AnalogModuleStreamer.SerialPort.read(1, 'uint8');
            end
            start(AnalogModuleStreamer.timer);

        end
end

function Stop_btn_Callback(hObject, eventdata, handles)

global AnalogModuleStreamer;

switch AnalogModuleStreamer.CurrentWindow
    case 'Log'
        
        if AnalogModuleStreamer.Logging==1
            
            while AnalogModuleStreamer.SerialPort.bytesAvailable>0
                AnalogModuleStreamer.SerialPort.read(1, 'uint8');
            end
            
            % Send 'Retrieve' command to the AM
            AnalogModuleStreamer.Logging = 0;
            
            AnalogModuleStreamer.handles.Value_txt.FontSize = 14;
            AnalogModuleStreamer.handles.Value_txt.String = 'Retrieving';
            
            data = RetrieveData;
            xdata = data.x;
            ydata = data.y;
            
            AnalogModuleStreamer.handles.Value_txt.FontSize = 14;
            AnalogModuleStreamer.handles.Value_txt.String = 'Retrieved';
                    
            %clean plots        
            for i=1:8
                set(AnalogModuleStreamer.Log.Plot(i),'XData',[],'YData',[]);
            end

            for i=1:8
                set(AnalogModuleStreamer.Log.Plot(i),'XData',xdata,'YData',ydata(i,:));
            end
            
            switch AnalogModuleStreamer.SelectedRange
                case 1
                    AnalogModuleStreamer.Log.Axis.YLim = [0 10];
                case 2
                    AnalogModuleStreamer.Log.Axis.YLim = [-2.5 2.5];
                case 3
                    AnalogModuleStreamer.Log.Axis.YLim = [-5 5];
                case 4
                    AnalogModuleStreamer.Log.Axis.YLim = [-10 10];
            end
            try
                AnalogModuleStreamer.Log.Axis.XLim = [xdata(1) xdata(end)];
            catch
                disp();
            end
    
        end
        
    otherwise % Signal or Event
        stop(AnalogModuleStreamer.timer);

        % Send 'Stop signal' and 'Stop Events' commands
        AnalogModuleStreamer.SerialPort.write(uint8([213 62]), 'uint8');
        AnalogModuleStreamer.SerialPort.write(uint8([213 66]), 'uint8');
        while AnalogModuleStreamer.SerialPort.bytesAvailable>0
            AnalogModuleStreamer.SerialPort.read(1, 'uint8');
        end
end
AnalogModuleStreamer.Running=0;


function Win_edt_Callback(hObject, eventdata, handles)
global AnalogModuleStreamer
AnalogModuleStreamer.TimeWindow = str2double(get(hObject,'String'));

function SamplingPeriod_edt_Callback(hObject, eventdata, handles)
global AnalogModuleStreamer
    
if AnalogModuleStreamer.Running

    stop(AnalogModuleStreamer.timer);

    % Send Stop
    AnalogModuleStreamer.SerialPort.write(uint8([213 62]), 'uint8');
    AnalogModuleStreamer.SerialPort.write(uint8([213 66]), 'uint8');
    AnalogModuleStreamer.SerialPort.write(uint8([213 69]), 'uint8');

end

% Set sampling period
SamplingPeriod = str2double(AnalogModuleStreamer.handles.SamplingPeriod_edt.String);
AnalogModuleStreamer.SamplingPeriod = SamplingPeriod; %Arduino Timer period in ms
ProgramAnalogModuleParam('SamplingPeriod', SamplingPeriod);

if AnalogModuleStreamer.Running
    % Send 'Start' command to the AM
    switch AnalogModuleStreamer.CurrentWindow
        case 'Signal'
            AnalogModuleStreamer.SerialPort.write(uint8([213 61]), 'uint8');
        case 'Events'
            AnalogModuleStreamer.SerialPort.write(uint8([213 65]), 'uint8');
    end
    start(AnalogModuleStreamer.timer);
end


function [] = timerCallback(~,~,Tab)

    global AnalogModuleStreamer;
         
    ts = tic;
    if AnalogModuleStreamer.SerialPort.bytesAvailable>8
        AnalogModuleStreamer.handles.Message_txt.String =  'Too fast...';
    else
        AnalogModuleStreamer.handles.Message_txt.String =  '';
    end
    
    % Read
    switch Tab
        case 'Signal'
            
            if AnalogModuleStreamer.SerialPort.bytesAvailable>=4
                
                % Increase time only if there is a byte available
                AnalogModuleStreamer.T = AnalogModuleStreamer.T+AnalogModuleStreamer.SamplingPeriod/1000;
                
                a = ScaleValue('toVolts',AnalogModuleStreamer.SerialPort.read(1, 'uint32'),AnalogModuleStreamer.SelectedRange);

                xdata = [AnalogModuleStreamer.Signal.Plot.XData AnalogModuleStreamer.T];
                ydata = [AnalogModuleStreamer.Signal.Plot.YData a];
                set(AnalogModuleStreamer.Signal.Plot,'XData',xdata,'YData',ydata)
                AnalogModuleStreamer.Signal.Axis.XLim = [0 xdata(end)];
                
                % Constant-size window
                if AnalogModuleStreamer.T>=AnalogModuleStreamer.TimeWindow
                    xdata_win = xdata(xdata>AnalogModuleStreamer.T-AnalogModuleStreamer.TimeWindow);
                    ydata_win = ydata(xdata>AnalogModuleStreamer.T-AnalogModuleStreamer.TimeWindow);
                    set(AnalogModuleStreamer.Signal.Plot,'XData',xdata_win,'YData',ydata_win)
                    AnalogModuleStreamer.Signal.Axis.XLim = [AnalogModuleStreamer.T-AnalogModuleStreamer.TimeWindow AnalogModuleStreamer.T];
                end
                
                switch AnalogModuleStreamer.SelectedRange
                    case 4
                        AnalogModuleStreamer.Signal.Axis.YLim = [0 10];
                    case 3
                        AnalogModuleStreamer.Signal.Axis.YLim = [-2.5 2.5];
                    case 2
                        AnalogModuleStreamer.Signal.Axis.YLim = [-5 5];
                    case 1
                        AnalogModuleStreamer.Signal.Axis.YLim = [-10 10];
                end
                
                drawnow
                AnalogModuleStreamer.handles.Value_txt.FontSize = 40;
                AnalogModuleStreamer.handles.Value_txt.String = num2str(a,'%2.4f');
            end
            
        case 'Events'
            
            if AnalogModuleStreamer.SerialPort.bytesAvailable>0
                
                % Increase time only if there is a byte available
                AnalogModuleStreamer.T = AnalogModuleStreamer.T+AnalogModuleStreamer.SamplingPeriod/1000;

                % Read Threshold Events
                a = double(AnalogModuleStreamer.SerialPort.read(1, 'uint8'));
            
                Events = dec2bin(a,8);
            
                xdata = [AnalogModuleStreamer.Events.Plot(1).XData AnalogModuleStreamer.T AnalogModuleStreamer.T nan];
            
                for i=1:8

                    if Events(i)=='1'
                        ydata = [AnalogModuleStreamer.Events.Plot(i).YData [(8-i)*2 (8-i)*2+1] nan];
                    else
                        ydata = [AnalogModuleStreamer.Events.Plot(i).YData nan nan nan];
                    end 
                    set(AnalogModuleStreamer.Events.Plot(i),'XData',xdata,'YData',ydata);
                    AnalogModuleStreamer.Events.Axis.XLim = [0 xdata(end-1)];

                    % Constant-size window
                    if AnalogModuleStreamer.T>=AnalogModuleStreamer.TimeWindow
                        AnalogModuleStreamer.Events.Axis.XLim = [AnalogModuleStreamer.T-AnalogModuleStreamer.TimeWindow AnalogModuleStreamer.T];
                    end

                end
                drawnow
            end
    end
%          toc(ts) %time that takes to read and plot (deteremines max online streaming freq)
    


% --- Executes when selected object is changed in channel_btngroup.
function Channel_bg_Callback(hObject, eventdata, handles)
% hObject    handle to the selected object in channel_btngroup 
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global AnalogModuleStreamer

%Change channel
% Select ADC channel
switch hObject.SelectedObject.String
    case 'Channel 0'
        AnalogModuleStreamer.SelectedChannel = 0;
    case 'Channel 1'
        AnalogModuleStreamer.SelectedChannel = 1;
    case 'Channel 2'
        AnalogModuleStreamer.SelectedChannel = 2;
    case 'Channel 3'
        AnalogModuleStreamer.SelectedChannel = 3;
    case 'Channel 4'
        AnalogModuleStreamer.SelectedChannel = 4;
    case 'Channel 5'
        AnalogModuleStreamer.SelectedChannel = 5;
    case 'Channel 6'
        AnalogModuleStreamer.SelectedChannel = 6;
    case 'Channel 7'
        AnalogModuleStreamer.SelectedChannel = 7;
    otherwise
end

% stop timer
if isfield(AnalogModuleStreamer,'timer')
    stop(AnalogModuleStreamer.timer);
end
            
%Stop streaming
switch AnalogModuleStreamer.CurrentWindow
    case 'Signal'
        AnalogModuleStreamer.SerialPort.write(uint8([213 62]), 'uint8');
    case 'Events'
        AnalogModuleStreamer.SerialPort.write(uint8([213 66]), 'uint8');
end

% Send 'Select channel' command to the AM
AnalogModuleStreamer.SerialPort.write(uint8([213 63 AnalogModuleStreamer.SelectedChannel]), 'uint8');

% if it was running, start again
if AnalogModuleStreamer.Running
    switch AnalogModuleStreamer.CurrentWindow
        case 'Signal'
            AnalogModuleStreamer.SerialPort.write(uint8([213 61]), 'uint8');
        case 'Events'
            AnalogModuleStreamer.SerialPort.write(uint8([213 65]), 'uint8');
    end
    
    start(AnalogModuleStreamer.timer);
end

%Reset Plot
set(AnalogModuleStreamer.Signal.Plot,'XData',[],'YData',[]);

% --- Executes when selected object is changed in range_btngroup.
function Range_bg_Callback(hObject, eventdata, handles)

% Select ADC Range
global AnalogModuleStreamer
global AnalogModuleSystem

switch hObject.SelectedObject.String
    case '0V - 10V'
        AnalogModuleStreamer.SelectedRange = 4;
    case '-2.5V - 2.5V'
        AnalogModuleStreamer.SelectedRange = 3;
    case '-5V - 5V'
        AnalogModuleStreamer.SelectedRange = 2;
    case '-10V - 10V'
        AnalogModuleStreamer.SelectedRange = 1;
    otherwise            
end

% stop timer
if isfield(AnalogModuleStreamer,'timer')
    stop(AnalogModuleStreamer.timer);
end
            
%Stop streaming
switch AnalogModuleStreamer.CurrentWindow
    case 'Signal'
        AnalogModuleStreamer.SerialPort.write(uint8([213 62]), 'uint8');
    case 'Events'
        AnalogModuleStreamer.SerialPort.write(uint8([213 66]), 'uint8');
end

% Set Voltage range
ProgramAnalogModuleParam('VoltageRange', 1:8, AnalogModuleStreamer.SelectedRange*ones(8,1));

% if it was running, start again
if AnalogModuleStreamer.Running
    switch AnalogModuleStreamer.CurrentWindow
        case 'Signal'
            AnalogModuleStreamer.SerialPort.write(uint8([213 61]), 'uint8');
        case 'Events'
            AnalogModuleStreamer.SerialPort.write(uint8([213 65]), 'uint8');
    end

    start(AnalogModuleStreamer.timer);
end

%Reset Plot
set(AnalogModuleStreamer.Signal.Plot,'XData',[],'YData',[]);
 
function TabChange_Callback(hObject,~)
global AnalogModuleStreamer
AnalogModuleStreamer.CurrentWindow = hObject.SelectedTab.Title;

if AnalogModuleStreamer.Running

    switch AnalogModuleStreamer.CurrentWindow
        case 'Signal'
            
            stop(AnalogModuleStreamer.timer);
 
            while AnalogModuleStreamer.SerialPort.bytesAvailable>0
                AnalogModuleStreamer.SerialPort.read(1, 'uint8');
            end
            
            %Stop sending events
            AnalogModuleStreamer.SerialPort.write(uint8([213 66]), 'uint8');
            
            %Reset Plot
            set(AnalogModuleStreamer.Signal.Plot,'XData',[],'YData',[]);
            %Acquisition timer
            AnalogModuleStreamer.timer = timer('Name','MyTimer',               ...
                'Period',AnalogModuleStreamer.TimerPeriod,                    ...
                'StartDelay',0,                 ...
                'TasksToExecute',inf,           ...
                'ExecutionMode','fixedSpacing', ...
                'TimerFcn',{@timerCallback,'Signal'});
            
            % Start sending signal
            AnalogModuleStreamer.SerialPort.write(uint8([213 61]), 'uint8');
           
            start(AnalogModuleStreamer.timer);
            AnalogModuleStreamer.Running=1;
        case 'Events'
            
            % Stop reading
            stop(AnalogModuleStreamer.timer);
            
            while AnalogModuleStreamer.SerialPort.bytesAvailable>0
                AnalogModuleStreamer.SerialPort.read(1, 'uint8');
            end

            %Stop sending signal
            AnalogModuleStreamer.SerialPort.write(uint8([213 62]), 'uint8');
            
            SetThresholds_Callback([],[])
            
            %Reset Plot
            set(AnalogModuleStreamer.Events.Plot,'XData',[],'YData',[]);
                AnalogModuleStreamer.timer = timer('Name','MyTimer',               ...
                'Period',AnalogModuleStreamer.TimerPeriod,                    ...
                'StartDelay',0,                 ...
                'TasksToExecute',inf,           ...
                'ExecutionMode','fixedSpacing', ...
                'TimerFcn',{@timerCallback,'Events'});

            
            %Start sending events
            AnalogModuleStreamer.SerialPort.write(uint8([213 65]), 'uint8');
            
            start(AnalogModuleStreamer.timer);
            AnalogModuleStreamer.Running=1;
    end
end

function SetThresholds_Callback(~,~)
global AnalogModuleStreamer


for i=1:8
    AnalogModuleStreamer.CurrentThresholds(i) = str2num(AnalogModuleStreamer.handles.Threshold_edt(i).String);
    AnalogModuleStreamer.CurrentResetValues(i) = str2num(AnalogModuleStreamer.handles.ResetValues_edt(i).String);
end

%Send Thresholds
ProgramAnalogModuleParam('Thresholds',1:8,AnalogModuleStreamer.CurrentThresholds'); %Thresholds in Volts
ProgramAnalogModuleParam('ResetValues',1:8,AnalogModuleStreamer.CurrentResetValues'); %Thresholds in Volts


                       
function CloseReq(src,callbackdata)
% Close request function 
try    
    %EndAnalogModule
    delete(gcf)
    instrreset
catch
    disp('Could not disconnect Analog Module')
    delete(gcf)    
end

    
    
