/*
 * CalculateLuts.cpp
 *
 *  Created on: 7 Jul 2019
 *      Author: podonoghue
 */
#include <stdio.h>
#include <string.h>

#include "console.h"

#include "EncodeLuts.h"

#include "Lfsr16.h"

namespace Analyser {

const uint16_t TriggerStep::lutEncoding[] = {
      0b1111111111111111,  // XX
      0b1010101010101010,  // XH
      0b0101010101010101,  // XL
      0b0010001000100010,  // XR
      0b0100010001000100,  // XF
      0b0110011001100110,  // XC
      0b1111000011110000,  // HX
      0b1010000010100000,  // HH
      0b0101000001010000,  // HL
      0b0010000000100000,  // HR
      0b0100000001000000,  // HF
      0b0110000001100000,  // HC
      0b0000111100001111,  // LX
      0b0000101000001010,  // LH
      0b0000010100000101,  // LL
      0b0000001000000010,  // LR
      0b0000010000000100,  // LF
      0b0000011000000110,  // LC
      0b0000000011110000,  // RX
      0b0000000010100000,  // RH
      0b0000000001010000,  // RL
      0b0000000000100000,  // RR
      0b0000000001000000,  // RF
      0b0000000001100000,  // RC
      0b0000111100000000,  // FX
      0b0000101000000000,  // FH
      0b0000010100000000,  // FL
      0b0000001000000000,  // FR
      0b0000010000000000,  // FF
      0b0000011000000000,  // FC
      0b0000111111110000,  // CX
      0b0000101010100000,  // CH
      0b0000010101010000,  // CL
      0b0000001000100000,  // CR
      0b0000010001000000,  // CF
      0b0000011001100000,  // CC
};

/**
 * Print an array of LUTs
 *
 * @param lutValues
 * @param number
 */
void printLuts(uint32_t lutValues[], unsigned number) {
   using namespace USBDM;

   bool doOpen = true;
   unsigned printNum = 0;
   if (number>LUTS_PER_TRIGGER_STEP_FOR_PATTERNS) {
      console.write("\n");
   }
   for(unsigned index=0; index<number; index++) {
      if (doOpen) {
         console.write("[");
         doOpen = false;
      }
      console.setPadding(Padding_LeadingZeroes).
            setWidth(2).write(index, Radix_16).write(":0x").setWidth(32).write(lutValues[index], Radix_2);
      if (++printNum == LUTS_PER_TRIGGER_STEP_FOR_PATTERNS) {
         printNum = 0;
         console.write("]\n");
         doOpen = true;
      }
//      else if ((printNum % LUTS_PER_COMPARATOR) ==0) {
//         USBDM::console.write("|");
//      }
      else {
         console.write(", ");
      }
   }
   if (printNum != 0) {
      console.write("]\n");
   }
   console.resetFormat();
}

/*
 * This encodes the trigger value for 1 TriggerStep (2 comparators)
 * Example layout (MAX_TRIGGER_PATTERNS=2, SAMPLE_WIDTH=32)
 *    33         1 1
 *    10         6 5          0
 *   +-------------------------+
 *   |  T1(31:30) |  T0(31:30) | lutValues[7]
 *   +-------------------------+
 *   |  T1(29:28) |  T0(29:28) | lutValues[6]
 *   +-------------------------+
 *   |            |            |
 *   +-------------------------+
 *   |   T1(5:4)  |   T0(5:4)  | lutValues[2]
 *   +-------------------------+
 *   |   T1(3:2)  |   T0(3:2)  | lutValues[1]
 *   +-------------------------+
 *   |   T1(1:0)  |   T0(1:0)  | lutValues[0]
 *   +-------------------------+
 */
void testTriggerToLuts(
      const char *triggerB,
      const char *triggerA,
      uint32_t lutValues[LUTS_PER_TRIGGER_STEP_FOR_PATTERNS]) {

   TriggerStep trigger = {
         triggerB,
         triggerA,
         Polarity::Normal,
         Polarity::Normal,
         Operation::And,
         false,
         100,
   };
   USBDM::console.write("Tb='").write(triggerB).write("', Ta='").write(triggerA).write("' => ");
   trigger.getTriggerStepPatternMatcherLutValues(lutValues);
   printLuts(lutValues, LUTS_PER_TRIGGER_STEP_FOR_PATTERNS);
}

void encodeTriggerToStep(
      const char *triggerB,
      const char *triggerA,
	  const unsigned count,
      TriggerStep &triggerStep) {

   TriggerStep trgrStep = {
         triggerB,
         triggerA,
         Polarity::Normal,
         Polarity::Normal,
         Operation::And,
         false,
         count,
   };
   triggerStep = trgrStep;
}

void testTrigger() {
   //   testLutEncoding();
   uint32_t lutValues[LUTS_PER_TRIGGER_STEP_FOR_PATTERNS];
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXX1", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXX1", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXX0", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXX0", lutValues);
   USBDM::console.writeln();
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXH", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXL", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXR", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXF", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXC", "XXXXXXXXXXXXXXXX", lutValues);
   USBDM::console.writeln();
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXHX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXLX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXRX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXFX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXCX", "XXXXXXXXXXXXXXXX", lutValues);
   USBDM::console.writeln();
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXH", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXL", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXR", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXF", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXC", "XXXXXXXXXXXXXXXX", lutValues);
   USBDM::console.writeln();
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXX0", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXX0X", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXX0XX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXX0XXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXX0XXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXX0XXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXX0XXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXX0XXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXX0XXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXX0XXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXX0XXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXX0XXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXX0XXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XX0XXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "X0XXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "0XXXXXXXXXXXXXXX", lutValues);
}

}  // end namespace Analyser
