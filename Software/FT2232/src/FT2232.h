/*
 * FT2232.h
 *
 *  Created on: 4 Aug 2019
 *      Author: podonoghue
 */

#ifndef FT2232_H_
#define FT2232_H_

#include "ftd2xx.h"

bool transmitData(FT_HANDLE ftHandle, uint8_t data[], unsigned dataSize);

FT_HANDLE openDevice();

void closeDevice(FT_HANDLE ftHandle);

#endif /* FT2232_H_ */
