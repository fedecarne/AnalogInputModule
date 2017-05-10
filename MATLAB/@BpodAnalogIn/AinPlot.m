function AinPlot(obj, AxesHandle, Action, varargin)

%%
% Plug in to plot analog signals acquired with the Analog Module
% Action = specific action for plot, "init" - initialize OR "update" -  update plot
%Example usage:
%Varargins:


%% Code Starts Here
global BpodSystem

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
            for i=1:8
                set(BpodSystem.GUIHandles.ChannelPlot(i),'XData',nan,'YData',nan);
            end
            for i=1:size(obj.ActiveChannels,2)
                chn = obj.ActiveChannels(i);
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






end
