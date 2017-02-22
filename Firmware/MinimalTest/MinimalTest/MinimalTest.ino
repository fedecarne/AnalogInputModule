
// Analog Module firmware v1.0.0
// Federico Carnevale, October 2016
//
// ** DEPENDENCIES YOU NEED TO INSTALL FIRST **

// IMPORTANT: Requires the SDFat-Beta library from:
// https://github.com/greiman/SdFat-beta/tree/master/SdFat

#include <ArCOM.h>
#include <SPI.h>
#include <SdFat.h>

ArCOM myUSB(SerialUSB); // Creates an ArCOM object called myUSB, wrapping SerialUSB

byte adcChipSelectPin = 36;
byte DebugPin = 37;

// System objects
SPISettings ADCSettings(100000, MSBFIRST, SPI_MODE2);
IntervalTimer hardwareTimer; // Hardware timer to ensure even sampling

// Relavant bitmasks for data value and channel address
byte adcValueMask_byte1 = 0b00111111;
byte adcValueMask_byte2 = 0b11111111;
byte adcAddressMask = 0b11100000;

// Sets control register (8 single-ended inputs, straight binary, internal reference, no sequence)
byte adcControlRegister_byte1 = 0b10000000; 
byte adcControlRegister_byte2 = 0b00110000;

byte adcSequenceRegister_byte1 = 0b11111111;
byte adcSequenceRegister_byte2 = 0b11100000;

byte adcRangeRegister1_byte1 = 0b10100000; // Sets channels 0-3 range to 0V - 10V
byte adcRangeRegister1_byte2 = 0b00000000; // Sets channels 0-3 range to 0V - 10V
byte adcRangeRegister2_byte1 = 0b11000000;  // Sets channels 4-7 range to 0V - 10V
byte adcRangeRegister2_byte2 = 0b00000000;  // Sets channels 4-7 range to 0V - 10V
  
  
// Variables used in programming
byte OpMenuByte = 213; // This byte must be the first byte in any serial transmission. Reduces the probability of interference from port-scanning software

// Actions
boolean StreamSignalToUSB = 0; // Stream one channel to AnalogStreamer
byte CommandByte;

void handler(void);


void setup() {
    
  pinMode(adcChipSelectPin, OUTPUT);
  digitalWrite(adcChipSelectPin, HIGH);

  pinMode(DebugPin, OUTPUT);
  digitalWrite(DebugPin, HIGH);
  
  SerialUSB.begin(115200); // Initialize Serial USB interface at 115.2kbps
  
  SPI.begin();
  
  hardwareTimer.begin(handler, 100); // hardwareTimer is an interval timer object - Teensy 3.6's hardware timer
}

//------------------------------------------------------------------------------
void loop() {
}

//------------------------------------------------------------------------------
void handler(void) {

  //digitalWrite(DebugPin, !digitalRead(DebugPin));
    
  if (myUSB.available()) { // If bytes are available through USB
    
    CommandByte = myUSB.readByte(); // Read a byte
    if (CommandByte == OpMenuByte) { // The first byte must be 213. Now, read the actual command byte. (Reduces interference from port scanning applications)
      CommandByte = myUSB.readByte(); // Read the command byte (an op code for the operation to execute)
      switch (CommandByte) {

        case 72: { // Handshake

            myUSB.writeByte(75); // Send 'K' (as in ok)
            myUSB.writeByte(1); // Send the firmware version
            SetDefaultADCSettings();
          
          } break;

        case 61: { // Start streaming signal
            digitalWrite(DebugPin, !digitalRead(DebugPin));
            StreamSignalToUSB = 1;
          } break;

        case 62: { // Stop streaming signal
            StreamSignalToUSB = 0;
          } break;
          
      }// end command switch
    }// end SerialUSB available
  }//end command byte



  // Streaming data with AnalogStreamer
  if (StreamSignalToUSB == 1) {
    myUSB.writeInt32(readOneChannel(0));
  }
      
}// End main loop


void SetDefaultADCSettings(){

  //noInterrupts(); // disable interupts to prepare to send address data to the ADC.

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

  //interrupts(); // Enable interupts.
}
  
//Function to read one channel of the ADC, accepts the channel to be read.
unsigned long readOneChannel(int channel) {

  byte adcControlRegisterGeneric_byte1 = 0b10000000;
  byte adcChannelAddress = channel << 2;
  
  adcControlRegister_byte1 = adcControlRegisterGeneric_byte1 | adcChannelAddress;
  adcControlRegister_byte2 = 0b00110000;      // Sets control register (8 single-ended inputs, straight binary, internal reference, no sequence)

  //noInterrupts(); // disable interupts to prepare to send address data to the ADC.
  
  SPI.beginTransaction(ADCSettings);
  digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
  SPI.transfer(adcControlRegister_byte1); //  write in the control register
  SPI.transfer(adcControlRegister_byte2); //  write in the control register
  digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
  SPI.endTransaction();

  digitalWrite(DebugPin, HIGH);

  SPI.beginTransaction(ADCSettings);
  digitalWrite(adcChipSelectPin, LOW); // take the Chip Select pin low to select the ADC.
  byte adcDataIn_byte1 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
  byte adcDataIn_byte2 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
  digitalWrite(adcChipSelectPin, HIGH); // take the Chip Select pin high to de-select the ADC.
  SPI.endTransaction();

  digitalWrite(DebugPin, LOW);
  //interrupts(); // Enable interupts.

  unsigned long adcDigitalValue = (int(adcDataIn_byte1 & adcValueMask_byte1)) << 8 | (adcDataIn_byte2 & adcValueMask_byte2);

  //int adcAddress =  (adcDataIn_byte1 & adcAddressMask)>>5;
  
  return adcDataIn_byte2;

}

