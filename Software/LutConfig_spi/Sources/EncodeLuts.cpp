/*
 * CalculateLuts.cpp
 *
 *  Created on: 7 Jul 2019
 *      Author: podonoghue
 */
#include <stdio.h>
#include <string.h>
#include "hardware.h"

#include "EncodeLuts.h"

#include "Lfsr16.h"

namespace Analyser {

static const uint16_t lutEncoding[] = {
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

unsigned triggerValueIndex(PinTriggerEncoding value) {
   switch (value) {
      default:
      case 'X' :
         return 0;
      case '1' :
      case 'H' :
         return 1;
      case '0' :
      case 'L' :
         return 2;
      case 'R' :
         return 3;
      case 'F' :
         return 4;
      case 'C' :
         return 5;
   }
}

/**
 * Get the LUT value for half a LUT pattern matcher
 * This encodes one bit of two pattern matchers
 *
 * @param triggerValue1
 * @param triggerValue0
 * @return
 */
uint16_t getPatternMatchHalfLutValues(PinTriggerEncoding triggerValue1, PinTriggerEncoding triggerValue0) {
   unsigned index = 6*triggerValueIndex(triggerValue1)+triggerValueIndex(triggerValue0);
   return lutEncoding[index];
}

/**
 * Get the LUT values for the pattern matchers in a trigger step
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerStepPatternMatcherLutValues(TriggerStep &trigger, uint32_t lutValues[LUTS_PER_TRIGGER_STEP_FOR_PATTERNS]) {

   int lutIndex = 0;

   for(int bitNum=SAMPLE_WIDTH-1; bitNum>=PATTERN_MATCHER_BITS_PER_LUT-1; bitNum-=PATTERN_MATCHER_BITS_PER_LUT) {
      for(int condition=MAX_TRIGGER_PATTERNS-1; condition>=PARTIAL_PATTERN_MATCHERS_PER_LUT-1; condition-=PARTIAL_PATTERN_MATCHERS_PER_LUT) {
         uint32_t value = 0;
         value  = getPatternMatchHalfLutValues(
               trigger.getPattern(condition)[bitNum],
               trigger.getPattern(condition)[bitNum-1]);
         value <<= 16;
         value |= getPatternMatchHalfLutValues(
               trigger.getPattern(condition-1)[bitNum],
               trigger.getPattern(condition-1)[bitNum-1]);
         lutValues[lutIndex++] = value;
      }
   }
}

/**
 * Get the LUT values for the pattern matchers for all trigger steps
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerPatternMatcherLutValues(TriggerSetup setup, uint32_t lutValues[LUTS_FOR_TRIGGER_PATTERNS]) {
   unsigned lutIndex = 0;
   for(int step=MAX_TRIGGER_STEPS-1; step >=0; step-- ) {
      getTriggerStepPatternMatcherLutValues(setup.triggers[step],  lutValues+lutIndex);
      lutIndex += LUTS_PER_TRIGGER_STEP_FOR_PATTERNS;
   }
}

/**
 * Get the LUT values for the combiner in a trigger step
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerStepCombinerLutValues(TriggerStep &trigger, uint32_t lutValues[LUTS_PER_TRIGGER_STEP_FOR_COMBINERS]) {
   uint16_t result = 0;

   for (unsigned value=0; value<(1<<MAX_TRIGGER_PATTERNS); value++) {
      bool bitValue;
      switch(trigger.getOperation()) {
         case Operation::And: bitValue = 1; break;
         case Operation::Or:  bitValue = 0; break;
      }
      for (unsigned patternNum=0; patternNum<MAX_TRIGGER_PATTERNS; patternNum++) {
         bool term = (value&(1<<patternNum));
         term = trigger.getPolarities(patternNum)(term, trigger.getOperation());
         switch(trigger.getOperation()) {
            case Operation::And: bitValue = bitValue && term; break;
            case Operation::Or:  bitValue = bitValue || term; break;
         }
      }
      result |= bitValue<<value;
   }
   lutValues[0] = result;
}

/**
 * Get the LUT values for the combiner for all trigger steps
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerCombinerLutValues(TriggerSetup setup, uint32_t lutValues[LUTS_FOR_TRIGGER_COMBINERS]) {
   unsigned lutIndex = 0;
   for(int step=MAX_TRIGGER_STEPS-1; step >=0; step-- ) {
      getTriggerStepCombinerLutValues(setup.triggers[step],  lutValues+lutIndex);
      lutIndex += LUTS_PER_TRIGGER_STEP_FOR_COMBINERS;
   }
}

///**
// * Does two steps at a time because of interleaved values in LUTs
// *
// * @param t1
// * @param t0
// * @param lutValues
// */
//void getTriggerStepPairCountLutValues(TriggerStep t1, TriggerStep t0, uint32_t lutValues[2*LUTS_PER_TRIGGER_STEP_FOR_COUNTS]) {
//   static constexpr unsigned BIT_MASK = (1U<<COUNT_MATCHER_BITS_PER_LUT)-1;
//   unsigned lutIndex=0;
//
//   for (unsigned bits=NUM_MATCH_COUNTER_BITS; bits>=COUNT_MATCHER_BITS_PER_LUT; bits -= COUNT_MATCHER_BITS_PER_LUT) {
//      unsigned partial1, partial0;
//      partial1 = t1.triggerCount>>(bits-COUNT_MATCHER_BITS_PER_LUT);
//      partial0 = t0.triggerCount>>(bits-COUNT_MATCHER_BITS_PER_LUT);
//      partial1 = partial1&BIT_MASK;
//      partial0 = partial0&BIT_MASK;
//      partial1 = 1U<<partial1;
//      partial0 = 1U<<partial0;
////      partial1 = 1U<<((t1.triggerCount>>(bits-COUNT_MATCHER_BITS_PER_LUT))&BIT_MASK);
////      partial0 = 1U<<((t0.triggerCount>>(bits-COUNT_MATCHER_BITS_PER_LUT))&BIT_MASK);
//      lutValues[lutIndex++] = (partial1<<16)|partial0;
//   }
//}
//
///**
// * Get the LUT values for the trigger count comparators for all trigger steps
// *
// * @param trigger
// * @param lutValues
// */
//void getTriggerCountLutValues(TriggerSetup setup, uint32_t lutValues[LUTS_FOR_TRIGGER_COUNTS]) {
//   unsigned lutIndex = 0;
//   // Process the Triggers in pairs
//   for(int step=MAX_TRIGGER_STEPS-1; step >= 1; step-=2 ) {
//      getTriggerStepPairCountLutValues(setup.triggers[step], setup.triggers[step-1],  lutValues+lutIndex);
//      lutIndex += 2*LUTS_PER_TRIGGER_STEP_FOR_COUNTS;
//   }
//}

/**
 * Get the LUT values for the trigger count comparators for all trigger steps
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerCountLutValues(TriggerSetup setup, uint32_t lutValues[LUTS_FOR_TRIGGER_COUNTS]) {

   // Clear LUTs initially
   for(int index=0; index<LUTS_FOR_TRIGGER_COUNTS; index++) {
      lutValues[index] = 0;
   }
   // Shuffle Trigger values for LUTS
   // This is basically a transpose
   for(int step=0; step < MAX_TRIGGER_STEPS; step++ ) {
      // The bits for each step appear at the this location in the SR
      uint32_t bitmask = 1<<step;
      uint32_t count   = Lfsr16::encode(setup.getTrigger(step).getCount());
      for(int bit=0; bit<NUM_MATCH_COUNTER_BITS; bit++ ) {
          lutValues[(NUM_MATCH_COUNTER_BITS-1)-bit] |= (count&(1<<bit))?bitmask:0;
      }
   }
}

/**
 * Get the LUT values for the trigger contiguous value
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerFlagLutValues(TriggerSetup setup, uint32_t lutValues[LUTS_FOR_TRIGGERS_FLAGS]) {
   unsigned lutIndex = 0;
   uint32_t flags = 0;
   // Process each trigger
   for(int step=0; step < MAX_TRIGGER_STEPS; step++ ) {
      if (setup.triggers[step].isContiguous()) {
         flags |= (1<<step);
      }
   }
   lutValues[lutIndex++] = (1<<setup.lastActiveTriggerCount);
   lutValues[lutIndex++] = flags;
}

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
 * This encoder the trigger value for 1 TriggerStep (step)
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
   getTriggerStepPatternMatcherLutValues(trigger, lutValues);
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
