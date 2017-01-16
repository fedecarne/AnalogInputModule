function ScaledTime = ScaleTime(RawTime)
global AnalogModuleSystem

ScaledTime = (RawTime-1)*AnalogModuleSystem.SamplingPeriod*10^-3;