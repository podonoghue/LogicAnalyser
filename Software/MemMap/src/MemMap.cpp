/*
 * main.cpp
 *
 *  Created on: 6 Jul 2019
 *      Author: podonoghue
 */
#include <stdio.h>

int tmIndex, cmIndex;

// Number of sample inputs
const int NUM_INPUTS = 4;

// Maximum number of steps in complex trigger sequence
const int MAX_TRIGGERS = 4;

// Maximum number of conditions for each trigger step
const int MAX_CONDITIONS  = 2;

// Maximum match/duration counter for each trigger step
const int MAX_COUNT = 256;

int main() {
   for (int tIndex = 0; tIndex <= MAX_TRIGGERS-1; tIndex++) {
      tmIndex = (tIndex*MAX_CONDITIONS)*4;
      for (int cIndex = 0; cIndex <= MAX_CONDITIONS-1; cIndex++) {
         cmIndex = tmIndex+cIndex*4;
         for (int bitIndex = NUM_INPUTS-1; bitIndex >= 0; bitIndex--) {
            printf("triggers(%d).conditions(%d)(%d) => ", tIndex, cIndex, bitIndex);
            printf("memory(%d)(%d), memory(%d)(%d), memory(%d)(%d), \n", cmIndex, bitIndex, cmIndex+1, bitIndex, cmIndex+2, bitIndex);
            //            triggers(tIndex).conditions(cIndex)(bitIndex) <= triggerCond;
         }
         printf("triggers(%d).inverted(%d) => ", tIndex, cIndex);
         printf("memory(%d)(15)\n", cmIndex+3);
         //         triggers(tIndex).inverted(cIndex) <= memory(cmIndex+3)(15);
      }
      printf("triggers(%d).matchCount => ", tIndex);
      printf("memory(%d)(14 downto 0)\n", tmIndex+3);
      //      triggers(tIndex).matchCount  <= to_integer(unsigned(memory(tmIndex+3)(14 downto 0)));
      printf("triggers(%d).conjunction => ", tIndex);
      printf("memory(%d)(0)\n", tmIndex+4+3);
      //      triggers(tIndex).conjunction <= memory(tmIndex+4+3)(1);
      printf("triggers(%d).contiguous => ", tIndex);
      printf("memory(%d)(1)\n", tmIndex+4+3);
      //      triggers(tIndex).contiguous  <= memory(tmIndex+4+3)(2);
   }
   return 0;
}


