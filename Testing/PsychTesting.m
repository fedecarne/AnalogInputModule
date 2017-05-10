Ain.SamplingRate = 3000;

WaveGen.play(1,1);
Ain.StartLogging;
pause(1) % stop logging before waveform finishes
data = Ain.RetrieveData;

xdata = data.x;
ydata = data.y;

size(ydata)
Ain.SamplingRate*1