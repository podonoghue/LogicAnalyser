/*
 * printArray.h
 *
 *  Created on: 3 Aug 2019
 *      Author: podonoghue
 */

#ifndef PRINTARRAY_H_
#define PRINTARRAY_H_

#include <stdint.h>
#include <assert.h>
#include <stdio.h>

/**
 * Print an array as a hex table.
 * The indexes shown are for byte offsets suitable for a memory dump.
 *
 * @param data          Array to print
 * @param size          Size of array in elements
 * @param visibleIndex The starting index to print for the array. Should be multiple of sizeof(data[]).
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
         printf("%0*lX: ", width, (long unsigned int)(visibleIndex+index*sizeof(T)));
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

#endif /* PRINTARRAY_H_ */
