/*
 * FT2232.h
 *
 *  Created on: 4 Aug 2019
 *      Author: podonoghue
 */

#ifndef FT2232_H_
#define FT2232_H_

#include "ftd2xx.h"

class FT2232 {

private:
   FT_HANDLE handle = nullptr;

public:

/**
 * Construct FT2232 device
 * This open the device
 *
 * @return Device handle
 */
FT2232(bool verbose = false);

/**
 * Send data to FPGA through FT2232
 *
 * @param ftHandle   Device handle
 * @param data       Data to send
 * @param dataSize   Size of data in bytes
 *
 * @return true  => OK
 * @return false => Failed
 */
void transmitData(const uint8_t data[], unsigned dataSize);

/**
 * Receive data from FPGA through FT2232
 *
 * @param ftHandle   Device handle
 * @param data       Data to send
 * @param dataSize   Size of data in bytes
 *
 * @return true  => OK
 * @return false => Failed
 */
void receiveData(uint8_t data[], unsigned dataSize);

/**
 * Purge receive data buffer
 */
void purgeRx() {
   FT_Purge(handle, FT_PURGE_RX);
}

/**
 * Purge transmit data buffer
 */
void purgeTx() {
   FT_Purge(handle, FT_PURGE_TX);
}

/**
 * Purge receive and transmit data buffer
 */
void purge() {
   FT_Purge(handle, FT_PURGE_RX|FT_PURGE_TX);
}

/**
 * Destruct FT2232 device
 * This closes the device
 *
 * @param ftHandle Device handles
 */
~FT2232();

};

#endif /* FT2232_H_ */
