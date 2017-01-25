This is the repo of the Analog Input Module for Bpod.

This repository contains:

-Firmware for Arduino
-Software APIs for MATLAB
-Design files for the circuit board
-Design files for the enclosure

Requirements:

- ArCOM (https://github.com/sanworks/ArCOM)

Features:

- 8 input channels (12-bit)
- 1kHz+ sampling
- Input range: -10 to +10V (software selectable to +/- 5 or +/-2.5V ranges)
- 2 UART serial interfaces connect the module to:
  - The state machine
  - Open systems to connect brain function with behavior
- The analog output module (direct interface for closed loop applications)
- I2C interface supported with the I2C module (see below) ...
- Powered by Arduino Due

To get started:
1. Add this folder ('MATLAB') to the MATLAB path. Subfolders not necessary.

2. Run 'AnalogModule'. 
