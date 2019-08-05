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
#include "FT2232.h"

/**
 * Print an array as a hex table.
 * The indexes shown are for byte offsets suitable for a memory dump.
 *
 * @param data          Array to print
 * @param size          Size of array in elements
 * @param visibleIndex  The starting index to print for the array. Should be multiple of sizeof(data[]).
 */
template <typename T>
void printArray(T *data, uint32_t size, uint32_t visibleIndex=0) {
   assert((visibleIndex%sizeof(T))==0);
   unsigned rowMask;
   unsigned offset;

   switch(sizeof(T)) {
      case 1  :
         offset = (visibleIndex/sizeof(T))&0xF;
         visibleIndex &= ~0xF;
         rowMask = 0xF;  break;
      case 2  :
         offset = (visibleIndex/sizeof(T))&0x7;
         visibleIndex &= ~0xF;
         rowMask = 0x7; break;
      default :
         offset = (visibleIndex/sizeof(T))&0x7;
         visibleIndex &= ~0x1F;
         rowMask = 0x7; break;
   }
   unsigned width = 2*sizeof(T);
   printf("   ");
   for (unsigned index=0; index<=(rowMask*sizeof(T)); index+=sizeof(T)) {
      printf("%*X", width, index);
      printf(" ");
   }
   printf("\n");
   bool needNewline = true;
   size += offset;
   for (unsigned index=0; index<size; index++) {
      if (needNewline) {
         printf("%0*X: ", width, visibleIndex+index*sizeof(T));
      }
      if (index<offset) {
         switch(sizeof(T)) {
            case 1  : printf("   ");       break;
            case 2  : printf("     ");     break;
            default : printf("         "); break;
         }
      }
      else {
         printf("%0*X ", width, data[index-offset]);
      }
      needNewline = (((index+1)&rowMask)==0);
      if (needNewline) {
         printf("\n");
      }
   }
   printf("\n");
}

FT_HANDLE openDevice() {
   FT_STATUS ftStatus;
   long unsigned numDevs;

   // Create the device information list
   ftStatus = FT_CreateDeviceInfoList(&numDevs);
   if (ftStatus == FT_OK) {
      printf("Number of devices is %ld\n",numDevs);
   } else {
      printf("FT_CreateDeviceInfoList failed\n");
      return nullptr;
   }

      FT_DEVICE_LIST_INFO_NODE *devInfo;

      if (numDevs > 0) {
         // allocate storage for list based on numDevs
         devInfo = (FT_DEVICE_LIST_INFO_NODE*)malloc(sizeof(FT_DEVICE_LIST_INFO_NODE)*numDevs);
         // get the device information list
         ftStatus = FT_GetDeviceInfoList(devInfo, &numDevs);
         if (ftStatus == FT_OK) {
            for (unsigned i = 0; i < numDevs; i++) {
               printf("Dev %d:\n",i);
               printf(" Flags          = 0x%lx\n",    devInfo[i].Flags);
               printf(" Type           = 0x%lx\n",    devInfo[i].Type);
               printf(" ID             = 0x%lx\n",    devInfo[i].ID);
               printf(" LocId          = 0x%lx\n",    devInfo[i].LocId);
               printf(" SerialNumber   = '%s'\n",     devInfo[i].SerialNumber);
               printf(" Description    = '%s'\n",     devInfo[i].Description);
               printf(" ftHandle       = 0x%p\n",     devInfo[i].ftHandle);
            }
         }
      }

   FT_HANDLE ftHandle;

   ftStatus = FT_OpenEx((char*)"Fast Logic Analyser A",FT_OPEN_BY_DESCRIPTION, &ftHandle);
   if (ftStatus == FT_OK) {
      printf("FT_OpenEx() OK\n");
   } else {
      printf("FT_OpenEx() failed\n");
      return nullptr;
   }

   ftStatus = FT_SetTimeouts(ftHandle, 10, 10); // read, write
   if (ftStatus != FT_OK) {
      printf("FT_SetTimeouts() failed\n");
      return nullptr;
   }
   return ftHandle;
}

void closeDevice(FT_HANDLE ftHandle) {
   FT_Close(ftHandle);
}

bool transmitData(FT_HANDLE ftHandle, uint8_t data[], unsigned dataSize) {
   FT_STATUS ftStatus;

   //   unsigned long rxQueueBytes, txQueueBytes, status;
   //   ftStatus = FT_GetStatus(ftHandle,&rxQueueBytes, &txQueueBytes, &status);
   //   if (ftStatus != FT_OK) {
   //      printf("FT_GetStatus() failed\n");
   //      return false;
   //   }
   unsigned bytesRemaining    = dataSize;
   unsigned long bytesWritten = 0;
   unsigned long offset       = 0;
   unsigned col = 0;

   while(bytesRemaining > 0) {
      ftStatus = FT_Write(ftHandle, data+offset, bytesRemaining, &bytesWritten);
      if (ftStatus == FT_OK) {
         if (bytesWritten > 0) {
            printf(".");
            if (col++==60) {
               col = 0;
               printf("\n");
            }
            printf("\nbytesWritten = %ld\n", bytesWritten);
            offset         += bytesWritten;
            bytesRemaining -= bytesWritten;
         }
         fflush(stdout);
         //         printf("FT_Write() OK\n");
      } else {
         fprintf(stderr, "\nFT_Write() failed\n");
         return false;
      }
   }
   return true;
}
