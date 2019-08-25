//============================================================================
// Name        : FT2232.cpp
// Author      : pgo
// This program can be used to read and program the flash associated with
// a FT2232 device.
//============================================================================
#include <stdio.h>
#include <stdint.h>
#include <windows.h>
#include <assert.h>
#include "ftd2xx.h"

#include "MyException.h"
#include "FT2232.h"

/**
 * Open FT2232 device
 */
FT2232::FT2232(bool verbose) {

   FT_STATUS ftStatus;
   long unsigned numDevs;
   handle = nullptr;

   // Create the device information list
   ftStatus = FT_CreateDeviceInfoList(&numDevs);
   if (ftStatus == FT_OK) {
      if (verbose) {
         printf("Number of devices found: %ld\n", numDevs);
      }
   } else {
      printf("FT_CreateDeviceInfoList failed\n");
      throw MyException("FT_CreateDeviceInfoList failed");
   }

   FT_DEVICE_LIST_INFO_NODE *devInfo;

   if (numDevs > 0) {
      // Allocate storage for list based on numDevs
      devInfo = (FT_DEVICE_LIST_INFO_NODE*)malloc(sizeof(FT_DEVICE_LIST_INFO_NODE)*numDevs);
      // Get the device information list
      ftStatus = FT_GetDeviceInfoList(devInfo, &numDevs);
      if (verbose) {
         if (ftStatus == FT_OK) {
            for (unsigned i = 0; i < numDevs; i++) {
               printf("Dev %d:\n",i);
               printf(" Flags          = 0x%lx\n",    devInfo[i].Flags);
               printf(" Type           = 0x%lx\n",    devInfo[i].Type);
               printf(" ID             = 0x%lx\n",    devInfo[i].ID);
               printf(" LocId          = 0x%lx\n",    devInfo[i].LocId);
               printf(" SerialNumber   = '%s'\n",     devInfo[i].SerialNumber);
               printf(" Description    = '%s'\n",     devInfo[i].Description);
               printf(" handle       = 0x%p\n",       devInfo[i].ftHandle);
            }
         }
      }
   }

   ftStatus = FT_OpenEx((char*)"Fast Logic Analyser A",FT_OPEN_BY_DESCRIPTION, &handle);
   if (ftStatus == FT_OK) {
      if (verbose) {
         printf("FT_OpenEx() OK\n");
      }
   } else {
      printf("FT_OpenEx() failed\n");
      throw MyException("FT_OpenEx() failed");
   }

   ftStatus = FT_SetTimeouts(handle, 1000, 1000); // read, write timeouts in ms
   if (ftStatus != FT_OK) {
      printf("FT_SetTimeouts() failed\n");
      throw MyException("FT_SetTimeouts() failed");
   }

   purge();

   return;
}

/**
 * Close FT2232 device
 *
 * @param handle Device handles
 */
FT2232::~FT2232() {
   try {
      FT_Close(handle);
   } catch (std::exception &) {
      // Ignore
   }
}

/**
 * Send data to FPGA through FT2232
 *
 * @param handle   Device handle
 * @param data       Data to send
 * @param dataSize   Size of data in bytes
 *
 * @return true  => OK
 * @return false => Failed
 */
void FT2232::transmitData(const uint8_t data[], unsigned dataSize) {
   FT_STATUS ftStatus;
   //   unsigned long rxQueueBytes, txQueueBytes, status;
   //   ftStatus = FT_GetStatus(handle,&rxQueueBytes, &txQueueBytes, &status);
   //   if (ftStatus != FT_OK) {
   //      printf("FT_GetStatus() failed\n");
   //      return false;
   //   }
   unsigned bytesRemaining    = dataSize;
   unsigned long bytesWritten = 0;
   unsigned long offset       = 0;
//   unsigned col = 0;

   while(bytesRemaining > 0) {
      ftStatus = FT_Write(handle, (LPVOID)(data+offset), bytesRemaining, &bytesWritten);
      if (ftStatus == FT_OK) {
         if (bytesWritten > 0) {
//            printf(".");
//            if (col++==60) {
//               col = 0;
//               printf("\n");
//            }
//            printf("bytesWritten = %ld\n", bytesWritten);
            offset         += bytesWritten;
            bytesRemaining -= bytesWritten;
         }
         else {
            fprintf(stderr, "\nFT_Write() Timeout\n");
            throw MyException("FT_Write() Timeout");
         }
         fflush(stdout);
         //         printf("FT_Write() OK\n");
      }
      else {
         fprintf(stderr, "\nFT_Write() failed\n");
         throw MyException("FT_Write() failed");
      }
   }
}

/**
 * Send data to FPGA through FT2232
 *
 * @param handle   Device handle
 * @param data       Data to send
 * @param dataSize   Size of data in bytes
 *
 * @return true  => OK
 * @return false => Failed
 */
void FT2232::receiveData(uint8_t data[], unsigned dataSize) {
   FT_STATUS ftStatus;

   //   unsigned long rxQueueBytes, txQueueBytes, status;
   //   ftStatus = FT_GetStatus(handle,&rxQueueBytes, &txQueueBytes, &status);
   //   if (ftStatus != FT_OK) {
   //      printf("FT_GetStatus() failed\n");
   //      return false;
   //   }
   unsigned bytesRemaining    = dataSize;
   unsigned long bytesRead = 0;
   unsigned long offset       = 0;
//   unsigned col = 0;

   while(bytesRemaining > 0) {
      ftStatus = FT_Read(handle, (LPVOID)(data+offset), bytesRemaining, &bytesRead);
      if (ftStatus == FT_OK) {
         if (bytesRead > 0) {
//            printf(".");
//            if (col++==60) {
//               col = 0;
//               printf("\n");
//            }
//            printf("bytesReceived = %ld\n", bytesRead);
            offset         += bytesRead;
            bytesRemaining -= bytesRead;
         }
         else {
            fprintf(stderr, "\nFT_Read() Timeout\n");
            throw MyException("FT_Read() Timeout");
         }
         fflush(stdout);
         //         printf("FT_Write() OK\n");
      }
      else {
         fprintf(stderr, "\nFT_Read() failed\n");
         throw MyException("FT_Read() failed");
      }
   }
}
