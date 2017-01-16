%{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2015 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

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
function AnalogModulePlot(AxesHandle, Action, varargin)
%%
% Plug in to plot analog signals acquired with the Analog Module
% Action = specific action for plot, "init" - initialize OR "update" -  update plot
%Example usage:
%Varargins:


%% Code Starts Here
global BpodSystem
global AnalogModuleSystem

switch Action
    case 'init'
        
        %initialize pokes plot
        axes(AxesHandle);
        
        AxesHandle.GridColor = [1 1 1];
        AxesHandle.Color = 'k';
        AxesHandle.FontSize = 14;
        AxesHandle.XLabel.String = 'Time (s)';
        grid(AxesHandle,'on');
        
        c = colormap(parula(8));
        for i=1:8
            BpodSystem.GUIHandles.ChannelPlot(i) = line(nan,nan,...
                'LineStyle','-',...
                'Marker','.',...
                'MarkerSize',10,...
                'Color', c(i,:),...
                'LineWidth',2);
        end
        
    case 'update'
        data = varargin{1};
        
        if ~isempty(data)
            xdata = data.x;
            ydata = data.y;

            axes(AxesHandle);
            %for i=1:size(ydata,1)
            for i=1:8
                set(BpodSystem.GUIHandles.ChannelPlot(i),'XData',nan,'YData',nan);
            end
            for i=1:size(AnalogModuleSystem.ActiveChannels,2)
                chn = AnalogModuleSystem.ActiveChannels(i);
                set(BpodSystem.GUIHandles.ChannelPlot(chn),'XData',xdata,'YData',ydata(i,:));
            end
            AxesHandle.XLim = [xdata(1) xdata(end)];
        else
            axes(AxesHandle);
            for i=1:8
                set(BpodSystem.GUIHandles.ChannelPlot(i),'XData',nan,'YData',nan);
            end
        end
end



