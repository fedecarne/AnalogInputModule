
// Analog Module firmware v4.0.0
// Federico Carnevale, October 2016

// ** DEPENDENCIES YOU NEED TO INSTALL FIRST **

// IMPORTANT: Requires the SDFat-Beta library from:
// https://github.com/greiman/SdFat-beta/tree/master/SdFat

#include "ArCOM.h"
#include "AD7327.h"
#include <SPI.h>
#include <SdFat.h>
SdFatSdioEX SD;

#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256

// Define macros for compressing sequential bytes read from the serial port into long and short ints
#define makeUnsignedLong(msb, byte2, byte3, lsb) ((msb << 24) | (byte2 << 16) | (byte3 << 8) | (lsb))
#define makeUnsignedShort(msb, lsb) ((msb << 8) | (lsb))
#define CSV_DELIM ','

#define FirmwareVersion 1

// Module setup
char moduleName[] = "AnlgLoopIn"; // Name of module for manual override UI and state machine assembler


AD7327 AD(39); // ADC ChipSelect
byte adcChipSelectPin = 39; //DISCARD

ArCOM USBCOM(SerialUSB); // Creates an ArCOM object called USBCOM, wrapping SerialUSB
ArCOM Serial1COM(Serial3); // Creates an ArCOM object called Serial1COM
ArCOM Serial2COM(Serial2); 

// Variables that define other hardware pins
byte DebugPin = 18; // Teensy LED

// System objects
SPISettings ADCSettings(300000, MSBFIRST, SPI_MODE2);
IntervalTimer hardwareTimer; // Hardware timer to ensure even sampling
File DataFile; // File on microSD card, to store waveform data

// Op menu variable
byte opCode = 0; // Serial inputs access an op menu. The op code byte stores the intended operation.
byte opSource = 0; // 0 = op from USB, 1 = op from UART1, 2 = op from UART2. More op code menu options are exposed for USB.
boolean newOpCode = 0; // true if an opCode was read from one of the ports
byte OpMenuByte = 213; // This byte must be the first byte in any serial transmission. Reduces the probability of interference from port-scanning software

// Relavant bitmasks for data value and channel address
byte adcValueMask_byte1 = 0b00011111;
byte adcValueMask_byte2 = 0b11111111;
byte adcAddressMask = 0b11100000;

// All channels active by default
byte ActiveChannelsByte = 255; //all channels
int ActiveChannelsList[] = {0,1,2,3,4,5,6,7};
int nActiveChannels = 8;

// Actions
boolean StreamSignalToUSB = 0; // Stream one channel to AnalogStreamer
boolean StreamEventsToUSB = 0; // Stream event detection to AnalogStreamer
boolean LoggingDataToSD = 0; // Logs active channels to SD card
boolean SendingEventsToBpod = 0; // Send threshold crossing by serial port
boolean SendingDataToSerial = 0; // Send adc reads through serial port

byte ChannelToStream = 0;
byte SelectedADCRange = 0;

byte BrokenBytes[4] = {0}; // Used to store sequential bytes when converting bytes to short and long ints
byte inByte; byte inByte2; byte inByte3; byte inByte4; byte CommandByte; byte BpodCommandByte;

// Threshold crossing events
boolean triggered[] = {0,0,0,0,0,0,0,0};
unsigned long ThresholdValue[] = {0,0,0,0,0,0,0,0};
unsigned long ResetValue[] = {0,0,0,0,0,0,0,0};

// SD variables
uint8_t buf[1];
uint8_t buf2[2];
uint8_t buf4[4];

unsigned long SystemTime = 0;
 
// Other variables
int ConnectedToApp = 0; // 0 if disconnected, 1 if connected
void handler(void);
uint16_t adcDigitalValue = 0;

// Error messages stored in flash.
#define error(msg) sd.errorHalt(F(msg))

void setup() {
    
  pinMode(adcChipSelectPin, OUTPUT); //DISCARD
  digitalWrite(adcChipSelectPin, HIGH); //DISCARD

  pinMode(DebugPin, OUTPUT);
  digitalWrite(DebugPin, HIGH);
  
  SerialUSB.begin(115200); // Initialize Serial USB interface at 115.2kbps
  Serial2.begin(1312500); // Initialize UART serial port to talk to bpod
  Serial3.begin(1312500); // Initialize UART serial port to talk to bpod
  
  SPI.begin(); 
  SD.begin(); // Initialize microSD card

  hardwareTimer.begin(handler, 1000); // hardwareTimer is an interval timer object - Teensy 3.6's hardware timer
}

//------------------------------------------------------------------------------
void loop() {
}

//------------------------------------------------------------------------------
void handler(void) {

  //unsigned long data[] = {0,0,0,0,0,0,0,0};
  unsigned short data[] = {0,0,0,0,0,0,0,0};
  
  if (Serial1COM.available() > 0) {
    //CommandByte = USBCOM.readByte(); 
    opCode = Serial1COM.readByte(); // Read in an op code
    opSource = 1; // UART 1
    newOpCode = true;
  } else if (Serial2COM.available() > 0) {
    opCode = Serial2COM.readByte();
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
    switch(opCode) {

      case 'O': { // Handshake (79)
        
        if (opSource == 0) {
          USBCOM.writeByte(75); // Send 'K' (as in ok)
          USBCOM.writeByte(FirmwareVersion); // Send firmware version
          ConnectedToApp = 1;
          SetDefaultADCSettings();

          StreamSignalToUSB = 0;
          StreamEventsToUSB = 0;
          LoggingDataToSD = 0;
          SendingEventsToBpod = 0;
          SendingDataToSerial = 0;
          
          SystemTime = 0;
          DataFile.close();
        }
  
      } break;
      
      case 255: // Return Bpod module info
        if (opSource == 1) { // Only returns this info if requested from state machine device
          returnModuleInfo();
      } break;
      
      case 'S': { // Start USB streaming signal
          StreamSignalToUSB = 1;
      } break;
  
      case 'X': { // Stop USB streaming signal
          StreamSignalToUSB = 0;
        } break;
  
      case 'C': { // Select Channel
  
          ChannelToStream = USBCOM.readByte(); // Read the command byte (an op code for the operation to execute)
          if (ChannelToStream > 7) {
            ChannelToStream = 0;
          }
        } break;
  
      case 'R': { // Select ADC Voltage range
            
          byte VoltageRangeArray[8];
          USBCOM.readByteArray(VoltageRangeArray, 8);
          AD.setRange(VoltageRangeArray);
          
        } break;
  
      case 'A': { // Select active channels
          
          ActiveChannelsByte = USBCOM.readByte();
  
          nActiveChannels = 0;
          int k=0;
          for (int i=0; i < 8; i++){
            if (bitRead(ActiveChannelsByte, 7-i)==1) {
              ActiveChannelsList[k] = i; // holds a list of channel numbers active (i.e. [1,3,5])
              nActiveChannels++;
              k++;
            }
          }
  
          USBCOM.writeByte(1); // Send confirm byte
      } break;
              
      case 'E': { // Start streaming events
          
        StreamEventsToUSB = 1;

        byte SequenceByte = 0b11111111;
        AD.setSequence(SequenceByte);
        
        for (int i=0; i < 8; i++){
          triggered[i] = 0;
        }
      } break;
                
      case 'Y': { // Stop  streaming events
        StreamEventsToUSB = 0;
      } break;
  
      case 'B': { // Set reset values
            
        for (int i = 0; i < 8; i++) {
          ResetValue[i] = USBCOM.readUint32();
        }
  
      } break;
  
      case 'T': { // Set thresholds
        for (int i = 0; i < 8; i++) {
          ThresholdValue[i] = USBCOM.readUint32();
        }
      } break;
  
      case 'L': { // Start logging data
        StartLogData();   
        Serial1COM.writeChar(1); // Send start logging flag to bpod 
      } break;
        
      case 'Z': { // Stop  logging data
        StopLogData();
        Serial1COM.writeChar(2); // Send start logging flag to bpod 
      } break;
  
      case 'D': { // Read SD card and send data 
        
        LoggingDataToSD = 0;
        SystemTime = 0;
        
        DataFile.close();
  
        unsigned long d0;
        DataFile = SD.open("Data.wfm", FILE_WRITE);
        DataFile.seekSet(0);
  
        while (DataFile.available() > 0) {
            d0 = readLongFromSD();
            USBCOM.writeUint32(d0);
        }
        DataFile.close();
        
      } break;
  
      case 'P': { // Change sampling frequency
        
        unsigned long samplingPeriod = USBCOM.readUint32();
        
        hardwareTimer.end();
        hardwareTimer.begin(handler, samplingPeriod);
      } break;
  
      case 'N': { // Start sending threshold crossing events to bpod
  
        for (int i=0; i < 8; i++){
          triggered[i] = 0;
        }
        SetupSequenceRead(ActiveChannelsByte);
        SendingEventsToBpod = 1;
                     
      } break;
            
      case 'M': { // Stop sending threshold crossing events to bpod
        SendingEventsToBpod = 0;
      } break;
  
      case 'H': { // Start sending adc reads to serial port
        SetupSequenceRead(ActiveChannelsByte);
        SendingDataToSerial = 1;
      } break;
  
      case 'I': { // Stop  sending adc reads to serial port
        SendingDataToSerial = 0;
      } break;
  
      case 'Q': { // Disconnect from client
        ConnectedToApp = 0;
      } break;
         
    }// end switch(opCode)
  }// end newOpCode


  // Streaming data with AnalogStreamer
  if (StreamSignalToUSB == 1) {
    USBCOM.writeUint16(readOneChannel(ChannelToStream));
  }

  // Streaming threshold crossings with AnalogStreamer
  if (StreamEventsToUSB == 1) {
      USBCOM.writeUint8(StreamThresholdCrossing());
  }
    
  if ((LoggingDataToSD == 1) || (SendingEventsToBpod==1) || (SendingDataToSerial==1))  {

    // Increase time one step
    SystemTime++;
    
    // Read active channels
    readActiveChannels(&data[0], nActiveChannels);

    if (LoggingDataToSD == 1){
      LogData(SystemTime,data);
    }
    
    if (SendingEventsToBpod == 1){
      SendThresholdCrossingEvents(data);
    } 

    if (SendingDataToSerial == 1){
      SendDataToSerial(data);
    }   
  }
      
}// End main timer loop


void SetDefaultADCSettings(){

  word ControlData = 12416;
  word SequenceData = 65504;
  word Range1Data = 49120;
  word Range2Data = 57312;
 
  AD.programADC(ControlData, SequenceData, Range1Data, Range2Data);
}
  
//Function to read one channel of the ADC, accepts the channel to be read.
int16_t readOneChannel(int channel) {

  return AD.readOneChannel(channel);
}

// Function to read all active channels, accepts pointer to an array 
//void readActiveChannels(long unsigned *pdata){
void readActiveChannels(short unsigned *pdata, byte nActiveChannels){

  AD.readActiveChannels(pdata,nActiveChannels);
  
}

// Detect thresholds in active channels and send events to Bpod
//void SendThresholdCrossingEvents(unsigned long data[]){
void SendThresholdCrossingEvents(unsigned short data[]){
  
  // nActiveChannels has the number of active channels
  // ActiveChannelsList has a list of channel numbers (0-7) that are active (sorted in ascenting order)

  for (int i=0; i < nActiveChannels; i++){
    
    if (triggered[ActiveChannelsList[i]]==0){
      if (data[i]>ThresholdValue[ActiveChannelsList[i]]){

        Serial1COM.writeByte(ActiveChannelsList[i]+1);
        triggered[ActiveChannelsList[i]] = 1;
      }
    } else{
      //if (data[i]<ThresholdValue[ActiveChannelsList[i]]){
      if (data[i]<ResetValue[ActiveChannelsList[i]]){

        triggered[ActiveChannelsList[i]] = 0;
      }
    }
  }
}

// Send data to serial port
//void SendDataToSerial(unsigned long data[]){
void SendDataToSerial(unsigned short data[]){
  Serial1COM.writeByte('R');
  Serial1COM.writeUint16Array(data, nActiveChannels);
}


// Log data
//void LogData(unsigned long SystemTime, unsigned long data[]){
void LogData(unsigned long SystemTime, unsigned short data[]){
  
  //Write System Time to SD
  breakLong(SystemTime); 
  writeLong2SD(); //Log time from logging start
  
  //Write data to SD
  for (int i = 0; i < nActiveChannels; i++) {
    breakLong(data[i]); 
    writeLong2SD();   
  }
}

// Log data
void StartLogData() {
  
    LoggingDataToSD = 1;
    
//            //Find an unused file name.
//            while (sd.exists(fileName)) {
//              if (fileName[BASE_NAME_SIZE + 1] != '9') {
//                fileName[BASE_NAME_SIZE + 1]++;
//              } else if (fileName[BASE_NAME_SIZE] != '9') {
//                fileName[BASE_NAME_SIZE + 1] = '0';
//                fileName[BASE_NAME_SIZE]++;
//              } else {
//                error("Can't create file name");
//              }
//            }

    SD.remove("Data.wfm");
    DataFile = SD.open("Data.wfm", FILE_WRITE);

    SetupSequenceRead(ActiveChannelsByte);
}

// Setting up chip for sequence read
void SetupSequenceRead(byte ActiveChannelsByte) {

    byte adcControlRegister_byte1 = 0b10000000;
    byte adcControlRegister_byte2 = 0b00110100; // Sets control register for sequence

    word adcSequenceRegister = (0b111 << 13) | ActiveChannelsByte<<5;
    byte adcSequenceRegister_byte1 = highByte(adcSequenceRegister);
    byte adcSequenceRegister_byte2 = lowByte(adcSequenceRegister);

    noInterrupts(); // disable interupts to prepare to send address data to the ADC.
  
    SPI.beginTransaction(ADCSettings);
    digitalWrite(adcChipSelectPin,LOW); // take the Chip Select pin low to select the ADC.
    SPI.transfer(adcSequenceRegister_byte1); //  write in the sequence register
    SPI.transfer(adcSequenceRegister_byte2); //  write in the sequence register
    digitalWrite(adcChipSelectPin,HIGH); // take the Chip Select pin high to de-select the ADC.
    SPI.endTransaction();
  
    SPI.beginTransaction(ADCSettings);
    digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
    SPI.transfer(adcControlRegister_byte1); //  write in the control register
    SPI.transfer(adcControlRegister_byte2); //  write in the control register
    digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
    SPI.endTransaction();

    interrupts(); // Enable interupts.
}

void StopLogData() {
  
  LoggingDataToSD = 0;
  Serial1COM.writeByte(10); // Send stop logging flag to bpod

  // Close logging file
  DataFile.close();
  
}

//Function to detect thresholds read all channels of the ADC in sequence
byte StreamThresholdCrossing() {

  byte ThresholdCrossed = 0;
  
  noInterrupts(); // disable interupts to prepare to send address data to the ADC.

  for (int i=0; i < 8; i++){
    
    SPI.beginTransaction(ADCSettings);
    digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
    byte adcDataIn_byte1 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
    byte adcDataIn_byte2 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
    digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
    SPI.endTransaction();

    adcDigitalValue = (int(adcDataIn_byte1 & adcValueMask_byte1)) << 8 | (adcDataIn_byte2 & adcValueMask_byte2);

    if (triggered[i]==0){
      if (adcDigitalValue>ThresholdValue[i]){
        ThresholdCrossed = ThresholdCrossed | 1<<i;
        triggered[i] = 1;
      }else{
          ThresholdCrossed = ThresholdCrossed | 0<<i; 
      }
    }else{
      ThresholdCrossed = ThresholdCrossed | 0<<i;
      
      if (adcDigitalValue<ResetValue[i]){
        triggered[i] = 0;
      } 
    }
  }

  interrupts(); // Enable interupts. 
    
  return ThresholdCrossed; // Returns the value from the function
}

void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeUint32(sizeof(moduleName)-1); // Length of module name
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(0);
}


void breakLong(unsigned long LongInt2Break) {
  //BrokenBytes is a global array for the output of long int break operations
  BrokenBytes[3] = (byte)(LongInt2Break >> 24);
  BrokenBytes[2] = (byte)(LongInt2Break >> 16);
  BrokenBytes[1] = (byte)(LongInt2Break >> 8);
  BrokenBytes[0] = (byte)LongInt2Break;
}

void breakShort(word Value2Break) {
  //BrokenBytes is a global array for the output of long int break operations
  BrokenBytes[1] = (byte)(Value2Break >> 8);
  BrokenBytes[0] = (byte)Value2Break;
}

void writeLong2SD() {
DataFile.write(BrokenBytes[0]);
DataFile.write(BrokenBytes[1]);
DataFile.write(BrokenBytes[2]);
DataFile.write(BrokenBytes[3]);
}
void writeShort2SD() {
DataFile.write(BrokenBytes[0]);
DataFile.write(BrokenBytes[1]);
}

unsigned long readLongFromSD() {
unsigned long myLongInt = 0;
DataFile.read(buf4, sizeof(buf4));
myLongInt = makeUnsignedLong(buf4[3], buf4[2], buf4[1], buf4[0]);
return myLongInt;
}
word readShortFromSD() {
word myWord = 0;
DataFile.read(buf2, sizeof(buf2));
myWord = makeUnsignedShort(buf2[1], buf2[0]);
return myWord;
}

byte readByteFromSD() {
byte myByte = 0;
DataFile.read(buf, sizeof(buf));
myByte = buf[0];
return myByte;
}
 
