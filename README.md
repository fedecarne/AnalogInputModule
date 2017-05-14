This is the repo of the Analog Input Module for Bpod.

This repository contains:

-Firmware for Arduino
-Software API for MATLAB
-Design files for the circuit board
-Design files for the enclosure

Requirements:

- ArCOM (https://github.com/sanworks/ArCOM)

Features:

- Arduino-compatible 180MHz ARM Cortex M4 processor (Teensy 3.6)
- 8 x 12 bit Analog inputs (based on Analog Devices AD7327BRUZ)
- Sampling rate: up to 100kHz (1 channel)
- Voltage range settings: -10V:10V, -5V:5V, -2.5V:2.5V, 0V:10V
- 8GB microSD memory for data storage and retrieval
- 2 UART connections to communicate threshold-crossing events to state machine
- Online streaming of digitalized signal through USB or UART
- MATLAB API for easy configuration and usage during behavioral experiments

To get started:
1. Add this folder 'MATLAB' to the MATLAB path.

2. Create your BpodAnalogIn object (you might need to specify the serial port)

	Ain = BpodAnalogIn('COM14');

3. Run Analog Streamer:

	Ain.Streamer

Check the [documentation](https://sites.google.com/site/bpodanaloginmodule/analog-input-module).

