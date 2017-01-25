function ValueOut = ScaleValue(Action,ValueIn,Range)

%validate input: nrows in ValueIn == n values in Range

ValueOut = nan(size(ValueIn));

for i=1:size(ValueIn,1)
    
    switch Range(i)
        case 4 %'0V - 10V'
            switch Action
                case 'toVolts'
                    ValueOut(i,:) = double(ValueIn(i,:)) * 10/16384.000 - 0.0;
                case 'toRaw'
                    ValueOut(i,:) = uint32((ValueIn(i,:)+0.0)*16384/10);
            end
        case 3 %'-2.5V - 2.5V'
            switch Action
                case 'toVolts'
                    ValueOut(i,:) = double(ValueIn(i,:)) * 5/16384.000 - 2.5;
                case 'toRaw'
                    ValueOut(i,:) = uint32((ValueIn(i,:)+2.5)*16384/5);
            end
        case 2 %'5V - 5V'
            switch Action
                case 'toVolts'
                    ValueOut(i,:) = double(ValueIn(i,:)) * 10/16384.000 - 5.0;
                case 'toRaw'
                    ValueOut(i,:) = uint32((ValueIn(i,:)+5.0)*16384/10);
            end
        case 1 %'-10V - 10V'
            switch Action
                case 'toVolts'
                    ValueOut(i,:) = double(ValueIn(i,:)) * 20/16384.000 - 10.0 - 0.022;
                case 'toRaw'
                    ValueOut(i,:) = uint32((ValueIn(i,:)+10.0)*16384.00/20);
            end
        otherwise
    end

end