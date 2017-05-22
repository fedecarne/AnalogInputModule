
// Analog Module firmware v4.0.0
// Federico Carnevale, October 2016

// ** DEPENDENCIES YOU NEED TO INSTALL FIRST **

// This firmware uses the sdFat library, developed by Bill Greiman. (Thanks Bill!!)
// Download it from here: https://github.com/greiman/SdFat
// and copy it to your /Arduino/Libraries folder.

#include "ArCOM.h"
#include "AD7327.h"
#include <SPI.h>
#include <SdFat.h>
SdFatSdioEX SD;

#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "AnalogIn"; // Name of module for manual override UI and state machine assembler

AD7327 AD(39); // ADC ChipSelect
byte adcChipSelectPin = 39; //DISCARD

ArCOM USBCOM(SerialUSB); // Creates an ArCOM object called USBCOM, wrapping SerialUSB
ArCOM StateMachineCOM(Serial3); // Creates an ArCOM object called StateMachineCOM
ArCOM OutputStreamCOM(Serial2);

// Variables that define other hardware pins
byte DebugPin = 18; // Teensy LED

// System objects
SPISettings ADCSettings(10000000, MSBFIRST, SPI_MODE2);
IntervalTimer hardwareTimer; // Hardware timer to ensure even sampling
File DataFile; // File on microSD card, to store waveform data

// Op menu variable
byte opCode = 0; // Serial inputs access an op menu. The op code byte stores the intended operation.
byte opSource = 0; // 0 = op from USB, 1 = op from UART1, 2 = op from UART2. More op code menu options are exposed for USB.
boolean newOpCode = 0; // true if an opCode was read from one of the ports
byte OpMenuByte = 213; // This byte must be the first byte in any serial transmission. Reduces the probability of interference from port-scanning software

// All channels active by default
const byte nPhysicalChannels = 8;
byte nActiveChannels = 8;

// Actions
boolean StreamSignalToUSB = false; // Stream one channel to AnalogStreamer
boolean StreamEventsToUSB = false; // Stream event detection to AnalogStreamer
boolean LoggingDataToSD = false; // Logs active channels to SD card
boolean SendingEventsToBpod = false; // Send threshold crossing by serial port
boolean SendingDataToSerial = false; // Send adc reads through serial port

// State variables
byte ChannelToStream = 0;
byte SelectedADCRange = 0;
boolean acquiring = false; // true if acquiring from the ADC
uint32_t samplingRate = 1000; // in Hz 

// Threshold crossing events
boolean triggered[] = {0, 0, 0, 0, 0, 0, 0, 0};
unsigned long ThresholdValue[] = {0, 0, 0, 0, 0, 0, 0, 0};
unsigned long ResetValue[] = {0, 0, 0, 0, 0, 0, 0, 0};

// SD variables
uint32_t nFullBufferReads = 0; // Number of full buffer reads in transmission
uint32_t nRemainderBytes = 0; // Number of bytes remaining after full transmissions
const uint32_t sdReadBufferSize = 1024; // in bytes
uint8_t sdReadBuffer[sdReadBufferSize*2];

// Other variables
uint16_t adcDigitalValue = 0;
uint32_t nSamplesAcquired = 0;
uint32_t maxSamplesToAcquire = 0; // 0 = infinite
byte VoltageRangeArray[nPhysicalChannels] = {0};

// Error messages stored in flash.
#define error(msg) sd.errorHalt(F(msg))

void setup() {
  pinMode(DebugPin, OUTPUT);
  digitalWrite(DebugPin, HIGH);
  Serial2.begin(1312500); 
  Serial3.begin(1312500);
  SPI.begin();
  SD.begin(); // Initialize microSD card
  hardwareTimer.begin(handler, (1/(double)samplingRate)*1000000); // hardwareTimer is an interval timer object - Teensy 3.6's hardware timer
}


void loop() {
  
}

void handler(void) {
  if (StateMachineCOM.available() > 0) {
    opCode = StateMachineCOM.readByte(); // Read in an op code
    opSource = 1; // UART 1
    newOpCode = true;
  } else if (OutputStreamCOM.available() > 0) {
    opCode = OutputStreamCOM.readByte();
    opSource = 2; // UART 2
    newOpCode = true;
  } else if (USBCOM.available() > 0) {
    if (USBCOM.readByte() == OpMenuByte) {
      opCode = USBCOM.readByte();
      opSource = 0; // USB
    };
    newOpCode = true;
  }

  if (newOpCode) { // If an op byte arrived from one of the serial interfaces
    newOpCode = false;
    switch (opCode) {
      case 'O': {
          if (opSource == 0) {
            USBCOM.writeByte(161); // Send acknowledgement byte
            USBCOM.writeUint32(FirmwareVersion); // Send firmware version
            StreamSignalToUSB = false;
            StreamEventsToUSB = false;
            LoggingDataToSD = false;
            SendingEventsToBpod = false;
            SendingDataToSerial = false;
            DataFile.close();
          }
        } break;

      case 255: // Return Bpod module info
        if (opSource == 1) { // Only returns this info if requested from state machine device
          returnModuleInfo();
        } break;

      case 'S': { // Start USB streaming signal
          StreamSignalToUSB = true;
        } break;

      case 'X': { // Stop USB streaming signal
          StreamSignalToUSB = false;
        } break;

      case 'C': { // Select Channel
          ChannelToStream = USBCOM.readByte(); // Read the command byte (an op code for the operation to execute)
          if (ChannelToStream > 7) {
            ChannelToStream = 0;
          }
        } break;

      case 'R': { // Select ADC Voltage range
          USBCOM.readByteArray(VoltageRangeArray, nActiveChannels);
          for (int i = 0; i > nPhysicalChannels; i++) {
            AD.setRange(i, VoltageRangeArray[i]);
          }
        } break;

      case 'A': { // Set number of active channels
          nActiveChannels = USBCOM.readByte();
          USBCOM.writeByte(1); // Send confirm byte
        } break;

      case 'E': { // Start streaming events
          StreamEventsToUSB = true;
          for (int i = 0; i < nPhysicalChannels; i++) {
            triggered[i] = 0;
          }
        } break;

      case 'Y': { // Stop  streaming events
          StreamEventsToUSB = false;
          stopAcquiringIfNotActive();
        } break;

      case 'B': { // Set reset values
          for (int i = 0; i < nPhysicalChannels; i++) {
            ResetValue[i] = USBCOM.readUint32();
          }
        } break;

      case 'T': { // Set thresholds
          for (int i = 0; i < nPhysicalChannels; i++) {
            ThresholdValue[i] = USBCOM.readUint32();
          }
        } break;

      case 'L': { // Start logging data
          //StateMachineCOM.writeChar(1); // Uncomment to send start logging flag to bpod for diagnostics (NOTE: may be confused with a threshold event if streaming events)
          StartLogData();
        } break;

      case 'Z': { // Stop  logging data
          StopLogData();
          stopAcquiringIfNotActive();
        } break;

      case 'D': { // Read SD card and send data

          LoggingDataToSD = false;
          DataFile.close();
          unsigned long d0;
          DataFile = SD.open("Data.wfm", FILE_WRITE);
          DataFile.seekSet(0);
          if (nSamplesAcquired*2 > sdReadBufferSize) {
            nFullBufferReads = (unsigned long)(floor(((double)nSamplesAcquired)*double(nActiveChannels)*2 / (double)sdReadBufferSize));
          } else {
            nFullBufferReads = 0;
          }
          USBCOM.writeUint32(nSamplesAcquired);     
          for (int i = 0; i < nFullBufferReads; i++) { // Full buffer transfers; skipped if nFullBufferReads = 0
            DataFile.read(sdReadBuffer, sdReadBufferSize);
            USBCOM.writeByteArray(sdReadBuffer, sdReadBufferSize);
          }
          nRemainderBytes = (nSamplesAcquired*nActiveChannels*2)-(nFullBufferReads*sdReadBufferSize);
          if (nRemainderBytes > 0) {
            DataFile.read(sdReadBuffer, nRemainderBytes);
            USBCOM.writeByteArray(sdReadBuffer, nRemainderBytes);     
          }
          DataFile.close();
        } break;

      case 'P': { // Change sampling frequency
          samplingRate = USBCOM.readUint32();
          hardwareTimer.end();
          hardwareTimer.begin(handler, (1/(double)samplingRate)*1000000);
        } break;

      case 'N': { // Start sending threshold crossing events to bpod
          for (int i = 0; i < nPhysicalChannels; i++) {
            triggered[i] = 0;
          }
          SendingEventsToBpod = true;
          acquiring = true;
        } break;

      case 'M': { // Stop sending threshold crossing events to bpod
          SendingEventsToBpod = false;
          stopAcquiringIfNotActive();
        } break;

      case 'H': { // Start sending adc reads to serial port
          SendingDataToSerial = true;
          acquiring = true;
        } break;

      case 'I': { // Stop  sending adc reads to serial port
          SendingDataToSerial = false;
          stopAcquiringIfNotActive();
        } break;

      case 'W': {
        maxSamplesToAcquire = USBCOM.readUint32();
        USBCOM.writeByte(1);
      } break;
    }// end switch(opCode)
  }// end newOpCode

  if (acquiring) {
    AD.readADC(); // Reads all active channels and stores the result in a buffer in the AD object: AD.analogData[]
  }

  // Streaming data with AnalogStreamer
  if (StreamSignalToUSB) {
    USBCOM.writeUint16(AD.analogData.uint16[ChannelToStream]);
  }

  // Streaming threshold crossings with AnalogStreamer
  if (StreamEventsToUSB) {
    USBCOM.writeUint8(StreamThresholdCrossing());
  }
  
  if (LoggingDataToSD) {
    LogData();
  }
  if (SendingEventsToBpod) {
    SendThresholdCrossingEvents();
  }
  if (SendingDataToSerial) {
    SendDataToSerial();
  }
} // End main timer loop

// Detect thresholds in active channels and send events to Bpod
void SendThresholdCrossingEvents() {

  // nActiveChannels has the number of active channels
  for (int i = 0; i < nActiveChannels; i++) {
    if (triggered[i] == 0) {
      if (AD.analogData.uint16[i] > ThresholdValue[i]) {
        StateMachineCOM.writeByte(i + 1);
        triggered[i] = 1;
      }
    } else {
      if (AD.analogData.uint16[i] < ResetValue[i]) {
        triggered[i] = 0;
      }
    }
  }
}

// Send data to serial port
void SendDataToSerial() {
  StateMachineCOM.writeByte('R');
  StateMachineCOM.writeUint16Array(AD.analogData.uint16, nActiveChannels);
}

// Log data
void LogData() {
  //Write data to SD
  unsigned long Pos = 0;
  for (int i = 0; i < nActiveChannels; i++) {
    DataFile.write(AD.analogData.uint8[Pos]);
    DataFile.write(AD.analogData.uint8[Pos+1]);
    Pos += 2;
  }
  nSamplesAcquired++;
  if (nSamplesAcquired == maxSamplesToAcquire) {
    StopLogData();
    stopAcquiringIfNotActive();
  }
}

// Log data
void StartLogData() {
  LoggingDataToSD = true;
  acquiring = true;
  SD.remove("Data.wfm");
  DataFile = SD.open("Data.wfm", FILE_WRITE);
  nSamplesAcquired = 0;
}

void StopLogData() {

  LoggingDataToSD = false;
  StateMachineCOM.writeByte(10); // Send stop logging flag to bpod

  // Close logging file
  DataFile.close();
}

void stopAcquiringIfNotActive() {
  if (!StreamEventsToUSB && !LoggingDataToSD && !SendingEventsToBpod && !SendingDataToSerial) {
    acquiring = false;
  }
}

//Function to detect thresholds read all channels of the ADC in sequence
byte StreamThresholdCrossing() {
  byte ThresholdCrossed = 0;
  for (int i = 0; i < nPhysicalChannels; i++) {
    if (triggered[i] == 0) {
      if (AD.analogData.uint16[i] > ThresholdValue[i]) {
        ThresholdCrossed = ThresholdCrossed | 1 << i;
        triggered[i] = 1;
      } else {
        ThresholdCrossed = ThresholdCrossed | 0 << i;
      }
    } else {
      ThresholdCrossed = ThresholdCrossed | 0 << i;

      if (AD.analogData.uint16[i] < ResetValue[i]) {
        triggered[i] = 0;
      }
    }
  }
  return ThresholdCrossed; // Returns the value from the function
}

void returnModuleInfo() {
  StateMachineCOM.writeByte(65); // Acknowledge
  StateMachineCOM.writeUint32(FirmwareVersion); // 4-byte firmware version
  StateMachineCOM.writeByte(sizeof(moduleName) - 1); // Length of module name
  StateMachineCOM.writeCharArray(moduleName, sizeof(moduleName) - 1); // Module name
  StateMachineCOM.writeByte(0);
}

