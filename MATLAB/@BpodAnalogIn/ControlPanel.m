function S = ControlPanel(obj, Op, varargin)

global BpodSystem

switch Op
    case 'init'

        % this is so ending the protocol closes the control panel
        % but find another solution.
        BpodSystem.ProtocolFigures.Figure = figure('Position', [1200 500 410 300],...
                                                    'name','Analog Input Control',...
                                                    'numbertitle','off',...
                                                    'MenuBar', 'none',...
                                                    'Resize', 'off');
        
        AMControl.SamplingRate.Text = uicontrol('Style', 'text', ...
                                             'String', 'Sampling Period',...
                                             'Position', [40 20 120 20],...
                                             'FontWeight', 'normal',...
                                             'HorizontalAlignment','Right');
                                         
        AMControl.SamplingRate.Edit = uicontrol('Style', 'edit', ...
                                                  'String',10,...
                                             'Position', [170 22 30 20],...
                                             'FontWeight', 'normal',...
                                             'FontName', 'Arial',...
                                             'HorizontalAlignment','Right');
                                         
        AMControl.ActiveChannels.ButtonGroup = uibuttongroup('Visible','on',...
                                                             'title','Active Channels',...
                                                             'units', 'pixels',...
                                                             'Position',[20 60 100 210]);

        % Create three radio buttons in the button group.
        deltaY=22;
        for i=1:8
            AMControl.ActiveChannels.Channel(i) = uicontrol(AMControl.ActiveChannels.ButtonGroup,...
                                                        'Style','checkbox',...
                                                        'Value',1,...
                                                        'String',['Ch' num2str(i)],...
                                                        'Position',[20 185-i*deltaY 60 20]);
        end
        
        AMControl.VoltageRange.ButtonGroup = uibuttongroup('Visible','on',...
                                                           'title','Voltage Range',...             
                                                           'units', 'pixels',...
                                                           'Position',[140 60 120 210]);

        % Create three radio buttons in the button group.
        deltaY=22;
        for i=1:8
            AMControl.VoltageRange.Channel(i) = uicontrol(AMControl.VoltageRange.ButtonGroup,...
                                                        'Style','popupmenu',...
                                                        'String',{'-10V,10V','-5V,+5V','-2.5V,2.5V','0V,10V'},...
                                                        'Position',[20 185-i*deltaY 80 20]);
        end
        
        AMControl.Thresholds.ButtonGroup = uibuttongroup('Visible','on',...
                                                           'title','Thresholds',...             
                                                           'units', 'pixels',...
                                                           'Position',[270 60 130 210]);

        % Create three radio buttons in the button group.
        deltaY=22;
        for i=1:8
            AMControl.Thresholds.Channel(i) = uicontrol(AMControl.Thresholds.ButtonGroup,...
                                                        'Style','edit',...
                                                        'String','0',...
                                                        'Position',[20 185-i*deltaY 40 20]);
            AMControl.ResetValues.Channel(i) = uicontrol(AMControl.Thresholds.ButtonGroup,...
                                                        'Style','edit',...
                                                        'String','0',...
                                                        'Position',[70 185-i*deltaY 40 20]);
        end                                         
    
        S = AMControl;
        
    case 'retrieve'
        
        AMControl = varargin{1};
        
        S.ActiveChannels = find(cell2mat(get( AMControl.ActiveChannels.Channel, 'Value')))';
        vranges = {};
        for i=1:4
            vranges{i,1}=[find([AMControl.VoltageRange.Channel.Value]==i)];
            vranges(i,2)=obj.ValidRanges(1,i);
        end
        S.VoltageRange = vranges;
        S.Thresholds = str2num(char(get( AMControl.Thresholds.Channel, 'String')));
        S.ResetValues = str2num(char(get( AMControl.ResetValues.Channel, 'String')));
        S.SamplingRate = str2double(AMControl.SamplingRate.Edit.String);
        
end

