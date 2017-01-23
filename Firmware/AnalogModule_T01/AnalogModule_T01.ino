
// Analog Module firmware v1.0.0
// Federico Carnevale, October 2016
//
// ** DEPENDENCIES YOU NEED TO INSTALL FIRST **

// 1. This firmware uses the open source DueTimer library, developed by Ivan Seidel. (Thanks Ivan!!)
// Download it from here: https://github.com/ivanseidel/DueTimer
// and copy it to your /Arduino/Libraries folder.
// The DueTimer library is open source, and protected by the MIT License.

// 2. Thanks firmware uses the sdFat library, developed by Bill Greiman. (Thanks Bill!!)
// Download it from here: https://github.com/greiman/SdFat
// and copy it to your /Arduino/Libraries folder.

// ** Next, upload the firmware to Arduino Due **
// See here for driver installation and upload instructions: https://www.arduino.cc/en/Guide/ArduinoDue


#include <DueTimer.h>
#include <stdio.h>
#include <stdint.h>
#include <SPI.h>

//#include <SdFat.h>
//#include <SdFatUtil.h>

#include <ArCOM.h> // ArCOM is a serial interface wrapper developed by Sanworks, to streamline transmission of datatypes and arrays over serial

ArCOM myUSB(SerialUSB); // Creates an ArCOM object called myUSB, wrapping SerialUSB

// Define macros for compressing sequential bytes read from the serial port into long and short ints
#define makeUnsignedLong(msb, byte2, byte3, lsb) ((msb << 24) | (byte2 << 16) | (byte3 << 8) | (lsb))
#define makeUnsignedShort(msb, lsb) ((msb << 8) | (lsb))

const uint32_t SAMPLE_INTERVAL_US = 250000;
#define CSV_DELIM ','

byte FirmwareVersion = 1;

// Variables that define other hardware pins
byte adcChipSelectPin = 21; // set pin 8 as the chip select for the ADC:
//byte SDChipSelectPin = 14; // set pin 4 as the chip select for the SD

// Variables for SPI bus
SPISettings ADCSettings(1000000, MSBFIRST, SPI_MODE2);

// Relavant bitmasks for data value and channel address
byte adcValueMask_byte1 = 0b00111111;
byte adcValueMask_byte2 = 0b11111111;
byte adcAddressMask = 0b11100000;

// Default values for ADC

// All channels active by default
byte ActiveChannelsByte = 255; //all channels
int ActiveChannelsList[] = {0,1,2,3,4,5,6,7};
int nActiveChannels = 8;

// Sets control register (8 single-ended inputs, straight binary, internal reference, no sequence)
byte adcControlRegister_byte1 = 0b10000000; 
byte adcControlRegister_byte2 = 0b00110000;

byte adcSequenceRegister_byte1 = 0b11111111;
byte adcSequenceRegister_byte2 = 0b11100000;

byte adcRangeRegister1_byte1 = 0b10111111; // Sets channels 0-3 range to 0V - 10V
byte adcRangeRegister1_byte2 = 0b11100000; // Sets channels 0-3 range to 0V - 10V
byte adcRangeRegister2_byte1 = 0b11011111;  // Sets channels 4-7 range to 0V - 10V
byte adcRangeRegister2_byte2 = 0b11100000;  // Sets channels 4-7 range to 0V - 10V
  
  
// Variables used in programming
byte OpMenuByte = 213; // This byte must be the first byte in any serial transmission. Reduces the probability of interference from port-scanning software

// Actions
boolean StreamSignalToUSB = 0; // Stream one channel to AnalogStreamer
boolean StreamEventsToUSB = 0; // Stream event detection to AnalogStreamer
boolean LoggingDataToSD = 0; // Logs active channels to SD card
boolean SendingEventsToBpod = 0; // Send threshold crossing by serial port

byte ChannelToStream = 0;
byte SelectedADCRange = 0;

byte BrokenBytes[4] = {0}; // Used to store sequential bytes when converting bytes to short and long ints
byte inByte; byte inByte2; byte inByte3; byte inByte4; byte CommandByte; byte BpodCommandByte;

boolean triggered[] = {0,0,0,0,0,0,0,0};
unsigned long ThresholdValue[] = {0,0,0,0,0,0,0,0};
unsigned long ResetValue[] = {0,0,0,0,0,0,0,0};


// SD variables
uint8_t buf[1];
uint8_t buf2[2];
uint8_t buf4[4];

#define FILE_BASE_NAME "Data2"
unsigned long SystemTime = 0;

//SdFat sd;
//SdFile DataFile;

char fileName[13] = FILE_BASE_NAME "00.csv";
 
// Other variables
int ConnectedToApp = 0; // 0 if disconnected, 1 if connected
void handler(void);
int adcDigitalValue = 0;

unsigned long LoggedData[8000];

// Error messages stored in flash.
#define error(msg) sd.errorHalt(F(msg))

void setup() {

  pinMode(13, OUTPUT);  
  pinMode(adcChipSelectPin, OUTPUT);
  digitalWrite(adcChipSelectPin, HIGH);
  
  //pinMode(SDChipSelectPin, OUTPUT); // microSD setup
  
  SerialUSB.begin(115200); // Initialize Serial USB interface at 115.2kbps
  Serial1.begin(1312500); // Initialize UART serial port to talk to bpod
  
  SPI.begin();

  SetDefaultADCSettings();
  
  // Initialize the SD card at SPI_HALF_SPEED to avoid bus errors with
  // breadboards.  use SPI_FULL_SPEED for better performance.
//  if (!sd.begin(SDChipSelectPin, SPI_HALF_SPEED)) { 
//  //if (!sd.begin(SDChipSelectPin, SPI_FULL_SPEED)) {
//    sd.initErrorHalt();
//  }
   
  Timer3.attachInterrupt(handler);
  Timer3.start(SAMPLE_INTERVAL_US); // Calls handler precisely every 50us

}

//------------------------------------------------------------------------------
void loop() {
}

//------------------------------------------------------------------------------
void handler(void) {

  const uint8_t BASE_NAME_SIZE = sizeof(FILE_BASE_NAME) - 1;
  unsigned long data[] = {0,0,0,0,0,0,0,0};
  
  if (Serial1.available()) { // If bytes are available through  UART

    BpodCommandByte = Serial1.read();
      switch (BpodCommandByte) {
      
       case 9: { // Start logging data

            //Best would be to have a function to open the file firs
            // then control logging through this commands
            // as opposed to this implementation
            // which opens the file every time and might add delays.
           //StartLogData(); 
          } break;
      
        case 10: { // Stop logging data
      
          //  StopLogData();
          } break;
      }
  }
 
  
  if (myUSB.available()) { // If bytes are available through USB
    
    CommandByte = myUSB.readByte(); // Read a byte
    if (CommandByte == OpMenuByte) { // The first byte must be 213. Now, read the actual command byte. (Reduces interference from port scanning applications)
      CommandByte = myUSB.readByte(); // Read the command byte (an op code for the operation to execute)
      switch (CommandByte) {

        case 72: { // Handshake
            myUSB.writeByte(75); // Send 'K' (as in ok)
            myUSB.writeByte(FirmwareVersion); // Send the firmware version
            ConnectedToApp = 1;
            SetDefaultADCSettings();


            // This initializes values when connecting through bpod
            LoggingDataToSD = 0;
            SendingEventsToBpod = 0;
            SystemTime = 0;
//            DataFile.close();
            
          } break;

        case 73: { // Program the module - total program (can be faster than item-wise, if many parameters have changed)
            /*
              // Whatever programming to load
              for (int x = 0; x < 4; x++) { // Read timing parameters (4 byte integers)
                Phase1Duration[x] = SerialReadLong();
                InterPhaseInterval[x] = SerialReadLong();
                Phase2Duration[x] = SerialReadLong();
                InterPulseInterval[x] = SerialReadLong();
                BurstDuration[x] = SerialReadLong();
                BurstInterval[x] = SerialReadLong();
                PulseTrainDuration[x] = SerialReadLong();
                PulseTrainDelay[x] = SerialReadLong();
              }
              TriggerMode[0] = SerialReadByte(); // Read bytes that set interpretation of trigger channel voltage
              TriggerMode[1] = SerialReadByte();
              SerialUSB.write(1); // Send confirm byte

              //Update ADC settngs
              dacWrite(DACValues);
              } break;

              case 74: { // Program one parameter
              inByte2 = SerialReadByte();
              inByte3 = SerialReadByte(); // inByte3 = channel (1-4)
              inByte3 = inByte3 - 1; // Convert channel for zero-indexing
              switch (inByte2) {
                case 1: {IsBiphasic[inByte3] = SerialReadByte();} break;
                case 2: {Phase1Voltage[inByte3] = SerialReadShort();} break;
                case 3: {Phase2Voltage[inByte3] = SerialReadShort();} break;
                case 4: {Phase1Duration[inByte3] = SerialReadLong();} break;
                case 5: {InterPhaseInterval[inByte3] = SerialReadLong();} break;
                case 6: {Phase2Duration[inByte3] = SerialReadLong();} break;
                case 7: {InterPulseInterval[inByte3] = SerialReadLong();} break;
                case 8: {BurstDuration[inByte3] = SerialReadLong();} break;
                case 9: {BurstInterval[inByte3] = SerialReadLong();} break;
                case 10: {PulseTrainDuration[inByte3] = SerialReadLong();} break;
                case 11: {PulseTrainDelay[inByte3] = SerialReadLong();} break;
                case 12: {inByte4 = SerialReadByte(); TriggerAddress[0][inByte3] = inByte4;} break;
                case 13: {inByte4 = SerialReadByte(); TriggerAddress[1][inByte3] = inByte4;} break;
                case 14: {CustomTrainID[inByte3] = SerialReadByte();} break;
                case 15: {CustomTrainTarget[inByte3] = SerialReadByte();} break;
                case 16: {CustomTrainLoop[inByte3] = SerialReadByte();} break;
                case 17: {RestingVoltage[inByte3] = SerialReadShort();} break;
                case 128: {TriggerMode[inByte3] = SerialReadByte();} break;
              }
            */
            myUSB.writeByte(1); // Send confirm byte
          } break;

        case 61: { // Start streaming signal
            StreamSignalToUSB = 1;
          } break;

        case 62: { // Stop streaming signal
            StreamSignalToUSB = 0;
          } break;

        case 63: { // Select Channel

            ChannelToStream = myUSB.readByte(); // Read the command byte (an op code for the operation to execute)
            if (ChannelToStream > 7) {
              ChannelToStream = 0;
            }

          } break;

        case 83: { // Select ADC Voltage range

            byte VoltageRangeByte1 = myUSB.readByte();
            byte VoltageRangeByte2 = myUSB.readByte(); 

            SetVoltageRange(VoltageRangeByte1,VoltageRangeByte2);

          } break;

        case 82: { // Select active channels
            
            ActiveChannelsByte = myUSB.readByte();

            nActiveChannels = 0;
            int k=0;
            for (int i=0; i < 8; i++){
              if (bitRead(ActiveChannelsByte, 7-i)==1) {
                ActiveChannelsList[k] = i; // holds a list of channel numbers active (i.e. [1,3,5])
                nActiveChannels++;
                k++;
              }
            }
                      
          } break;
            
          case 65: { // Start streaming events
            
            StreamEventsToUSB = 1;

            adcControlRegister_byte1 = 0b10000000;
            adcControlRegister_byte2 = 0b00100100; // Sets control register for sequence
            adcSequenceRegister_byte1 = 0b11111111;
            adcSequenceRegister_byte2 = 0b11100000;

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
             
            for (int i=0; i < 8; i++){
              triggered[i] = 0;
            }

          } break;
              
          case 66: { // Stop  streaming events
            StreamEventsToUSB = 0;
          } break;

          case 64: { // Set reset values
            
            for (int i = 0; i < 8; i++) {
              ResetValue[i] = myUSB.readUint32();
            }
            
          } break;

          case 67: { // Set thresholds
            
            for (int i = 0; i < 8; i++) {
              ThresholdValue[i] = myUSB.readUint32();
            }
            
          } break;

          case 68: { // Start logging data

            SystemTime = 0;
            StartLogData(); 
                       
          } break;
          
          case 69: { // Stop  logging data

//            StopLogData();

          } break;

          case 70: { // Read SD card and send data 
            
            LoggingDataToSD = 0;

            for (int i=0; i < SystemTime; i++){
              myUSB.writeUint32(i+1);
              for (int j=0; j < nActiveChannels; j++){
                myUSB.writeUint32(LoggedData[(i-1)*nActiveChannels+j]);
              }
            }   
          } break;

          case 75: { // Change sampling period
            
            byte samplingPeriod = myUSB.readByte(); // 
            Timer3.stop();
            Timer3.setPeriod((unsigned long)samplingPeriod*1000);
            Timer3.start();
            
          } break;


          case 76: { // Start sending threshold crossing events to bpod

            for (int i=0; i < 8; i++){
              triggered[i] = 0;
            }
            SetupSequenceRead(ActiveChannelsByte);
            SendingEventsToBpod = 1;
                       
          } break;
          
          case 77: { // Stop sending threshold crossing events to bpod
            
            SendingEventsToBpod = 0;

          } break;

        case 81: { // Disconnect from client
            
              ConnectedToApp = 0;

          } break;

        case 85: { // Return the currently loaded parameter file from the microSD card
            /*
              settingsFile.rewind();
              for (int i = 0; i < 178; i++) {
              settingsFile.read(buf, sizeof(buf));
              SerialUSB.write(buf[0]);
              }
            */
          } break;

        case 90: { // Save, load or delete the current microSD settings file
            /*
              byte confirmBit = 1;
              while (SerialUSB.available()==0){}
              settingsOp = SerialUSB.read();
              while (SerialUSB.available()==0){}
              settingsFileNameLength = SerialUSB.read();
              currentSettingsFileName = "";
              for (int i = 0; i < settingsFileNameLength; i++) {
              while (SerialUSB.available()==0){}
              currentSettingsFileName = currentSettingsFileName + (char)SerialUSB.read();
              }
              settingsFile.close();
              currentSettingsFileName.toCharArray(currentSettingsFileNameChar, settingsFileNameLength+1);
              if (settingsOp == 1) { // Save
              SaveCurrentProgram2SD();
              } else if (settingsOp == 2) { // Load
              settingsFile.open(currentSettingsFileNameChar, O_READ);
              validProgram = RestoreParametersFromSD();
              if (validProgram != 252) { // If load failed, load defaults and report error
                LoadDefaultParameters();
                settingsFile.close();
                currentSettingsFileName = "defaultSettings.pps";
                currentSettingsFileName.toCharArray(currentSettingsFileNameChar, sizeof(currentSettingsFileName));
                settingsFile.open(currentSettingsFileNameChar, O_READ);
                confirmBit = 0;
              } else {
                // Return parameters from file to update client
                  for (int x = 0; x < 4; x++) {
                    SerialWriteLong(Phase1Duration[x]);
                    SerialWriteLong(InterPhaseInterval[x]);
                    SerialWriteLong(Phase2Duration[x]);
                    SerialWriteLong(InterPulseInterval[x]);
                    SerialWriteLong(BurstDuration[x]);
                    SerialWriteLong(BurstInterval[x]);
                    SerialWriteLong(PulseTrainDuration[x]);
                    SerialWriteLong(PulseTrainDelay[x]);
                  }
                  for (int x = 0; x < 4; x++) {
                    SerialWriteShort(Phase1Voltage[x]);
                    SerialWriteShort(Phase2Voltage[x]);
                    SerialWriteShort(RestingVoltage[x]);
                  }
                  for (int x = 0; x < 4; x++) {
                    SerialUSB.write(IsBiphasic[x]);
                    SerialUSB.write(CustomTrainID[x]);
                    SerialUSB.write(CustomTrainTarget[x]);
                    SerialUSB.write(CustomTrainLoop[x]);
                  }
                 for (int x = 0; x < 2; x++) { // Read 8 trigger address bytes
                   for (int y = 0; y < 4; y++) {
                    SerialUSB.write(TriggerAddress[x][y]);
                   }
                 }
                 SerialUSB.write(TriggerMode[0]);
                 SerialUSB.write(TriggerMode[1]);
               }
            	} else if (settingsOp == 3) { // Delete
              	sd.remove(currentSettingsFileNameChar);
            	}
              settingsFile.rewind();
            */
          } break;
      }// end command switch
    }// end SerialUSB available
  }//end command byte



  // Streaming data with AnalogStreamer
  if (StreamSignalToUSB == 1) {
    digitalWrite(13,!digitalRead(13));
    myUSB.writeInt32(readOneChannel(ChannelToStream));
  }

  // Streaming threshold crossings with AnalogStreamer
  if (StreamEventsToUSB == 1) {
      myUSB.writeUint8(StreamThresholdCrossing());
  } 

    
  if ((LoggingDataToSD == 1) || (SendingEventsToBpod==1))  {

    digitalWrite(13,!digitalRead(13));
    
    // Increase time one step
    SystemTime++;
    
    // Read active channels
    readActiveChannels(&data[0]);

    if (LoggingDataToSD == 1){
      LogData(SystemTime,data);
    }
    if (SendingEventsToBpod == 1){
      SendThresholdCrossingEvents(data);
    } 
  }
      
}// End main loop


void SetDefaultADCSettings(){

  noInterrupts(); // disable interupts to prepare to send address data to the ADC.

  SPI.beginTransaction(ADCSettings);
  digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
  SPI.transfer(adcRangeRegister1_byte1); //  write in the range register 1
  SPI.transfer(adcRangeRegister1_byte2); //  write in the range register 1
  digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
  SPI.endTransaction();

  SPI.beginTransaction(ADCSettings);
  digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
  SPI.transfer(adcRangeRegister2_byte1); //  write in the range register 2
  SPI.transfer(adcRangeRegister2_byte2); //  write in the range register 2
  digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
  SPI.endTransaction();

  SPI.beginTransaction(ADCSettings);
  digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
  SPI.transfer(adcSequenceRegister_byte1); //  write in the sequence register
  SPI.transfer(adcSequenceRegister_byte2); //  write in the sequence register
  digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
  SPI.endTransaction();

  SPI.beginTransaction(ADCSettings);
  digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
  SPI.transfer(adcControlRegister_byte1); //  write in the range control register
  SPI.transfer(adcControlRegister_byte2); //  write in the range control register
  digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
  SPI.endTransaction();

  interrupts(); // Enable interupts.
}
  
//Function to read one channel of the ADC, accepts the channel to be read.
unsigned long readOneChannel(int channel) {

  byte adcControlRegisterGeneric_byte1 = 0b10000000;
  byte adcChannelAddress = channel << 2;
  
  adcControlRegister_byte1 = adcControlRegisterGeneric_byte1 | adcChannelAddress;
  adcControlRegister_byte2 = 0b00110000;      // Sets control register (8 single-ended inputs, straight binary, internal reference, no sequence)

  noInterrupts(); // disable interupts to prepare to send address data to the ADC.

  SPI.beginTransaction(ADCSettings);
  digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
  SPI.transfer(adcControlRegister_byte1); //  write in the control register
  SPI.transfer(adcControlRegister_byte2); //  write in the control register
  digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
  SPI.endTransaction();

  SPI.beginTransaction(ADCSettings);
  digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
  byte adcDataIn_byte1 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
  byte adcDataIn_byte2 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
  digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
  SPI.endTransaction();

  interrupts(); // Enable interupts.

  unsigned long adcDigitalValue = (int(adcDataIn_byte1 & adcValueMask_byte1)) << 8 | (adcDataIn_byte2 & adcValueMask_byte2);

  //int adcAddress =  (adcDataIn_byte1 & adcAddressMask)>>5;
  
return adcDigitalValue;
}

// Function to read all active channels, accepts pointer to an array 
void readActiveChannels(long unsigned *pdata){
  // ActiveChannelsByte:  has a 1 in every channel that is active

  noInterrupts(); // disable interupts to prepare to send address data to the ADC.
  
  for (int i=0; i < nActiveChannels; i++){
    
    SPI.beginTransaction(ADCSettings);
    
    digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
    
    byte adcDataIn_byte1 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
    byte adcDataIn_byte2 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
    
    digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
    
    SPI.endTransaction();

    int adcDigitalValue = (int(adcDataIn_byte1 & adcValueMask_byte1)) << 8 | (adcDataIn_byte2 & adcValueMask_byte2);
    pdata[i] = adcDigitalValue;
  }

  interrupts(); // Enable interupts.
}

// Detect thresholds in active channels and send events to Bpod
void SendThresholdCrossingEvents(unsigned long data[]){
  
  // nActiveChannels has the number of active channels
  // ActiveChannelsList has a list of channel numbers (0-7) that are active (sorted in ascenting order)

  for (int i=0; i < nActiveChannels; i++){
    
    if (triggered[ActiveChannelsList[i]]==0){
      if (data[i]>ThresholdValue[ActiveChannelsList[i]]){


        if (i==7){
          digitalWrite(13, HIGH); 
        }
        
        Serial1.write(ActiveChannelsList[i]+1);
        triggered[ActiveChannelsList[i]] = 1;
      }
    } else{
      //if (data[i]<ThresholdValue[ActiveChannelsList[i]]){
      if (data[i]<ResetValue[ActiveChannelsList[i]]){


        if (i==7){
          digitalWrite(13, LOW); 
        }


        triggered[ActiveChannelsList[i]] = 0;
      }
    }
  }
}

//Log data
void LogData(unsigned long SystemTime, unsigned long data[]){
  
  //Save to RAM
  for (int i = 0; i < nActiveChannels; i++) {
    LoggedData[(SystemTime-1)*nActiveChannels+i] = data[i]; 
  }
}



// Set voltage ranges
void SetVoltageRange(byte VoltageRangeByte1,byte VoltageRangeByte2){
    
    //Before changing range, the sequence must be stopped
    adcControlRegister_byte1 = 0b10000000; // Sets control register (8 single-ended inputs, straight binary, internal reference, no sequence)
    adcControlRegister_byte2 = 0b00110000; // Sets control register (8 single-ended inputs, straight binary, internal reference, no sequence)

    adcRangeRegister1_byte1 = (0b101) << 5 | (VoltageRangeByte1) >> 3;
    adcRangeRegister1_byte2 = (VoltageRangeByte1) << 5 | 0b00000;
    adcRangeRegister2_byte1 = (0b110) << 5 | (VoltageRangeByte2) >> 3;
    adcRangeRegister2_byte2 = (VoltageRangeByte2) << 5 | 0b00000;

    noInterrupts(); // disable interupts to prepare to send address data to the ADC.

    SPI.beginTransaction(ADCSettings);
    digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
    SPI.transfer(adcControlRegister_byte1); //  write in the control register
    SPI.transfer(adcControlRegister_byte2); //  write in the control register
    digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
    SPI.endTransaction();
    
    SPI.beginTransaction(ADCSettings);
    digitalWrite(adcChipSelectPin,LOW); // take the Chip Select pin low to select the ADC.
    SPI.transfer(adcRangeRegister1_byte1); //  write in the range register 1
    SPI.transfer(adcRangeRegister1_byte2); //  write in the range register 1
    digitalWrite(adcChipSelectPin,HIGH); // take the Chip Select pin high to de-select the ADC.
    SPI.endTransaction();
    
    SPI.beginTransaction(ADCSettings);
    digitalWrite(adcChipSelectPin,LOW); // take the Chip Select pin low to select the ADC.
    SPI.transfer(adcRangeRegister2_byte1); //  write in the range register 2
    SPI.transfer(adcRangeRegister2_byte2); //  write in the range register 2
    digitalWrite(adcChipSelectPin,HIGH); // take the Chip Select pin high to de-select the ADC.
    SPI.endTransaction();

    // Restart sequence
    adcControlRegister_byte1 = 0b10000000;
    adcControlRegister_byte2 = 0b00110100; // Sets control register for sequence

    SPI.beginTransaction(ADCSettings);
    digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
    SPI.transfer(adcControlRegister_byte1); //  write in the control register
    SPI.transfer(adcControlRegister_byte2); //  write in the control register
    digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
    SPI.endTransaction();
    
    interrupts(); // Enable interupts.
            
}

// Log data
void StartLogData() {
  
    LoggingDataToSD = 1;
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

//void StopLogData() {
// 
//  LoggingDataToSD = 0;
//  Serial1.write(10); // Send stop logging flag to bpod
//
//  // Close logging file
//  DataFile.close();
//}

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

    unsigned long adcDigitalValue = (int(adcDataIn_byte1 & adcValueMask_byte1)) << 8 | (adcDataIn_byte2 & adcValueMask_byte2);

    if (triggered[i]==0){
      if (adcDigitalValue>ThresholdValue[i]){
        ThresholdCrossed = ThresholdCrossed | 1<<i;
        triggered[i] = 1;

        if (i==7){
          digitalWrite(13, HIGH); 
        }
        
        }else{
          ThresholdCrossed = ThresholdCrossed | 0<<i; 
        }
    }else{
      
      ThresholdCrossed = ThresholdCrossed | 0<<i;
      
      if (adcDigitalValue<ResetValue[i]){
        triggered[i] = 0;

        if (i==7){
          digitalWrite(13, LOW); 
        }
        
      } 
    }
  }

  interrupts(); // Enable interupts. 
    
  return ThresholdCrossed; // Returns the value from the function
}


void digitalWriteDirect(int pin, boolean val) {
  if (val) g_APinDescription[pin].pPort -> PIO_SODR = g_APinDescription[pin].ulPin;
  else    g_APinDescription[pin].pPort -> PIO_CODR = g_APinDescription[pin].ulPin;
}

byte digitalReadDirect(int pin) {
  return !!(g_APinDescription[pin].pPort -> PIO_PDSR & g_APinDescription[pin].ulPin);
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

//void writeLong2SD() {
//DataFile.write(BrokenBytes[0]);
//DataFile.write(BrokenBytes[1]);
//DataFile.write(BrokenBytes[2]);
//DataFile.write(BrokenBytes[3]);
//}

//void writeShort2SD() {
//DataFile.write(BrokenBytes[0]);
//DataFile.write(BrokenBytes[1]);
//}

//unsigned long readLongFromSD() {
//unsigned long myLongInt = 0;
//DataFile.read(buf4, sizeof(buf4));
//myLongInt = makeUnsignedLong(buf4[3], buf4[2], buf4[1], buf4[0]);
//return myLongInt;
//}

//word readShortFromSD() {
//word myWord = 0;
//DataFile.read(buf2, sizeof(buf2));
//myWord = makeUnsignedShort(buf2[1], buf2[0]);
//return myWord;
//}

//byte readByteFromSD() {
//byte myByte = 0;
//DataFile.read(buf, sizeof(buf));
//myByte = buf[0];
//return myByte;
//}
 
void Software_Reset() {
  const int RSTC_KEY = 0xA5;
  RSTC->RSTC_CR = RSTC_CR_KEY(RSTC_KEY) | RSTC_CR_PROCRST | RSTC_CR_PERRST;
  while (true);
}
