/*
----------------------------------------------------------------------------

This file is part of the Sanworks repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

// Library for programming the AD7327 ADC as installed in the Bpod analog input module
// Fede Carnevale, April 2017
// Heavily insipred by AD5745 library written by Josh Sanders

#include <Arduino.h>
#include <SPI.h>
#include "AD7327.h"

AD7327::AD7327(byte ADCChipSelect) {

  ChipSelect = ADCChipSelect;
  pinMode(ChipSelect, OUTPUT);
  digitalWrite(ChipSelect, LOW);

  SPI.begin(); // Initialize SPI interface

}

void AD7327::setSequence(byte SequenceByte) {
  
  word ControlWord = 32820;
  word SequenceWord = (0b111) << 13 | SequenceByte << 5;
  
  programADC(ControlWord,SequenceWord,0,0);
}

uint16_t AD7327::readOneChannel(byte Channel) {

  byte adcValueMask_byte1 = 0b00011111;
  byte adcValueMask_byte2 = 0b11111111;

  byte adcControlRegisterGeneric_byte1 = 0b10000000;
  byte adcChannelAddress = Channel << 2;
  
  byte adcControlRegister_byte1 = adcControlRegisterGeneric_byte1 | adcChannelAddress;
  byte adcControlRegister_byte2 = 0b00110000;

  noInterrupts(); // disable interupts to prepare to send address data to the ADC.

  SPI.beginTransaction(SPISettings(30000000, MSBFIRST, SPI_MODE2));
  digitalWrite(ChipSelect, LOW); // take the Chip Select pin low to select the ADC.
  SPI.transfer(adcControlRegister_byte1); //  write in the control register
  SPI.transfer(adcControlRegister_byte2); //  write in the control register
  digitalWrite(ChipSelect, HIGH); // take the Chip Select pin high to de-select the ADC.
  SPI.endTransaction();
  
  SPI.beginTransaction(SPISettings(30000000, MSBFIRST, SPI_MODE2));
  digitalWrite(ChipSelect, LOW); // take the Chip Select pin low to select the ADC.
  byte adcDataIn_byte1 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
  byte adcDataIn_byte2 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
  digitalWrite(ChipSelect, HIGH); // take the Chip Select pin high to de-select the ADC.
  SPI.endTransaction();

  interrupts(); // Enable interupts.

  return (int(adcDataIn_byte1 & adcValueMask_byte1)) << 8 | (adcDataIn_byte2 & adcValueMask_byte2);
  
}

void AD7327::readActiveChannels(short unsigned *pdata, byte nActiveChannels){

  byte adcValueMask_byte1 = 0b00011111;
  byte adcValueMask_byte2 = 0b11111111;
  
  noInterrupts(); // disable interupts to prepare to send address data to the ADC.
  
  for (int i=0; i < nActiveChannels; i++){
    
    SPI.beginTransaction(SPISettings(30000000, MSBFIRST, SPI_MODE2));
    digitalWrite(ChipSelect, LOW); // take the Chip Select pin low to select the ADC.
    byte adcDataIn_byte1 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
    byte adcDataIn_byte2 = SPI.transfer(0b00000000); // read conversion, also sending 0 as this doesn't matter.
    digitalWrite(ChipSelect, HIGH); // take the Chip Select pin high to de-select the ADC.
    SPI.endTransaction();

    uint16_t adcDigitalValue = (int(adcDataIn_byte1 & adcValueMask_byte1)) << 8 | (adcDataIn_byte2 & adcValueMask_byte2);
    pdata[i] = adcDigitalValue;
  }

  interrupts(); // Enable interupts.

}

void AD7327::setRange(byte VoltageRangeArray[]) {

  word Range1Data = (0b101) << 13 | VoltageRangeArray[0] << 11 | VoltageRangeArray[1] << 9 | VoltageRangeArray[2] << 7 | VoltageRangeArray[3] << 5;
  word Range2Data = (0b110) << 13 | VoltageRangeArray[4] << 11 | VoltageRangeArray[5] << 9 | VoltageRangeArray[6] << 7 | VoltageRangeArray[7] << 5;
  word ControlWord = 32816; //check here sequence!!
    
  programADC(ControlWord, 0, Range1Data, Range2Data);
  programADC(32820, 0, 0, 0);
}

void AD7327::programADC(word ControlData, word SequenceData, word Range1Data, word Range2Data) {
  
  noInterrupts(); // disable interupts to prepare to send address data to the ADC.

  if (Range1Data !=0){
    SPI.beginTransaction(SPISettings(30000000, MSBFIRST, SPI_MODE2));
    digitalWrite(ChipSelect, LOW);
    SPI.transfer(highByte(Range1Data));
    SPI.transfer(lowByte(Range1Data));
    digitalWrite(ChipSelect, HIGH);
    SPI.endTransaction();
  }

  if (Range2Data !=0){
    SPI.beginTransaction(SPISettings(30000000, MSBFIRST, SPI_MODE2));
    digitalWrite(ChipSelect, LOW);
    SPI.transfer(highByte(Range2Data));
    SPI.transfer(lowByte(Range2Data));
    digitalWrite(ChipSelect, HIGH);
    SPI.endTransaction();
  }

  if (SequenceData !=0){
    SPI.beginTransaction(SPISettings(30000000, MSBFIRST, SPI_MODE2));
    digitalWrite(ChipSelect, LOW);
    SPI.transfer(highByte(SequenceData));
    SPI.transfer(lowByte(SequenceData));
    digitalWrite(ChipSelect, HIGH);
    SPI.endTransaction();
  }

  if (ControlData !=0){
    SPI.beginTransaction(SPISettings(30000000, MSBFIRST, SPI_MODE2));
    digitalWrite(ChipSelect, LOW);
    SPI.transfer(highByte(ControlData));
    SPI.transfer(lowByte(ControlData));
    digitalWrite(ChipSelect, HIGH);
    SPI.endTransaction();
  }  
  interrupts(); // Enable interupts.
}
