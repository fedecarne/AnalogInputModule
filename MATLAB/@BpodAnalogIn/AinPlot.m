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
        
%        set(AxesHandle,'GridColor', [1 1 1]);
        set(AxesHandle,'Color', 'k');
        set(AxesHandle,'FontSize', 14);
%        YAx = get(AxesHandle, 'YAxis');
%        set(YAx,'TickLabelFormat', '%,2.2f');
        Xlab = get(AxesHandle, 'XLabel');
        set(Xlab,'String', 'Time (s)', 'FontSize', 12);
        grid(AxesHandle,'on');
        Cmp = [0 0 1; 0 1 0; 1 0 0; 0 0.5 0; 1 1 0; 1 0.25 1; 0 1 1; 1 0.4 0;];
        c = colormap(Cmp(obj.nPhysicalChannels:-1:1, 1:end));
        for i=1:8
            BpodSystem.GUIHandles.ChannelPlot(i) = line(nan,nan,...
                'LineStyle','-',...
                'Marker','None',...
                'Color', c(i,:),...
                'LineWidth',2);
        end
        
        legend off
        hc = colorbar('YTick',1/16:1/8:1-1/16, 'YTickLabel',{'ch1','ch2','ch3','ch4','ch5','ch6','ch7','ch8'});
        set(hc, 'FontSize', 11);
        
    case 'update'
        data = varargin{1};
        
        if ~isempty(data)
            xdata = data.x;
            ydata = data.y;

            axes(AxesHandle);
%             for i=1:8
%                 set(BpodSystem.GUIHandles.ChannelPlot(i),'XData',nan,'YData',nan);
%             end
            for i=1:obj.nActiveChannels
                set(BpodSystem.GUIHandles.ChannelPlot(i),'XData',xdata,'YData',ydata(i,:));
            end
            set(AxesHandle, 'XLim', [xdata(1) xdata(end)]);
            
        else
            axes(AxesHandle);
            for i=1:8
                set(BpodSystem.GUIHandles.ChannelPlot(i),'XData',nan,'YData',nan);
            end
        end
end






end
