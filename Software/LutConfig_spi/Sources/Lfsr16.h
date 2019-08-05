/*
 * Lfsr16.h
 *
 *  Created on: 16 Jul 2019
 *      Author: podonoghue
 */

#ifndef SOURCES_LFSR16_H_
#define SOURCES_LFSR16_H_

#include <stdint.h>
#include <assert.h>

class Lfsr16 {
public:
   /**
    * Calculate next value in LFSR sequence
    * @param start_state
    * @return
    *
    * See https://en.wikipedia.org/wiki/Linear-feedback_shift_register
    */
   static uint16_t calcNextValue(uint16_t start_state) {

      assert(start_state != 0);

       uint16_t lfsr = start_state;

   #ifndef LEFT
           unsigned lsb = lfsr & 1u;  /* Get LSB (i.e., the output bit). */
           lfsr >>= 1;                /* Shift register */
           if (lsb)                   /* If the output bit is 1, */
               lfsr ^= 0xB400u;       /*  apply toggle mask. */
   #else
           unsigned msb = (int16_t) lfsr < 0;   /* Get MSB (i.e., the output bit). */
           lfsr <<= 1;                          /* Shift register */
           if (msb)                             /* If the output bit is 1, */
               lfsr ^= 0x002Du;                 /*  apply toggle mask. */
   #endif
       return lfsr;
   }

   /**
    * Finds the period of the LFSR
    *
    * @return period.
    */
   static unsigned findPeriod(void) {

       uint16_t start_state = 0x0001;

       uint16_t lfsr = start_state;
       unsigned period = 0;
       do {
          lfsr = calcNextValue(lfsr);
           ++period;
       }
       while (lfsr != start_state);

       return period;
   }

   /**
    * Find LFSR state corresponding to the given value
    * Note: 0 is considered invalid.
    *
    * @param value [1..65535]
    *
    * @return encoded value [1..65535]
    */
   static uint16_t encode(uint16_t value) {
      uint16_t lfsr = 1;
      while (value-->1) {
         lfsr = calcNextValue(lfsr);
      }
      return lfsr;
   }

};

#endif /* SOURCES_LFSR16_H_ */
