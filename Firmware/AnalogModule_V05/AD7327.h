/*
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Sound Beach, New York, USA

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

// Library for programming the AD7327 DAC as installed in the Bpod analog output module
// Josh Sanders, March 2017

#ifndef AD7327_h
#define AD7327_h
#include "Arduino.h"
#include <SPI.h>

class AD7327
{
public:
  // Constructor
  AD7327(byte ChipSelect);
  void setSequence(byte SequenceByte);
  void setRange(byte VoltageRangeArray[]);
  uint16_t readOneChannel(byte Channel);
  void readActiveChannels(uint16_t *pdata, byte nActiveChannels);
  void programADC(word ControlData, word SequenceData, word Range1Data, word Range2Data);
private:
  byte ChipSelect;
  byte rangeIndex = 3; // rangeIndex 0 = '0V:5V', 1 = '0V:10V', 2 = '0V:12V', 3 = '-5V:5V', 4 = '-10V:10V', 5 = '-12V:12V'
};
#endif
