function SetAnalogModuleVersion
global AnalogModuleSystem
AnalogModuleSystem.SerialPort.write([AnalogModuleSystem.OpMenuByte 72], 'uint8');
pause(.1);
HandShakeOkByte = AnalogModuleSystem.SerialPort.read(1, 'uint8');
if HandShakeOkByte == 75
    AnalogModuleSystem.FirmwareVersion = AnalogModuleSystem.SerialPort.read(1, 'uint8');
    switch AnalogModuleSystem.FirmwareVersion
        case 0
            % Set firmware-verion specific options
    end
else
    disp('Error: Analog Module returned an incorrect handshake signature.')
end