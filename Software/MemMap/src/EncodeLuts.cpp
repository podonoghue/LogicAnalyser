/*
 * CalculateLuts.cpp
 *
 *  Created on: 7 Jul 2019
 *      Author: podonoghue
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

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
//=========================================================================
// Uses to represent a trigger bit encoding e.g. 'X','H','L','R','F','C'
typedef char PinTriggerEncoding;

//================================================================
// Number of sample inputs
static constexpr int SAMPLE_WIDTH = 16;

//================================================================
// Comparators are complicated because each LUT implements
// 2 bits of 2 separate comparators

// Number of partial Comparators implemented in a Comparator LUT
static constexpr int PARTIAL_COMPARATORS_PER_LUT = 2;

// Number of bits implemented in a Comparator LUT
static constexpr int COMPARATOR_BITS_PER_LUT     = 2;

//====================================================================
// Maximum number of conditions for each trigger step (either 2 or 4)
static constexpr int MAX_TRIGGER_CONDITIONS = 2;

// Maximum number of steps in complex trigger sequence
static constexpr int MAX_TRIGGER_STEPS = 16;

//============================================================================================
// Number of LUTS per trigger comparator (each comparator actually implements 2 comparators)
static constexpr int LUTS_PER_COMPARATOR = SAMPLE_WIDTH/COMPARATOR_BITS_PER_LUT/PARTIAL_COMPARATORS_PER_LUT;

//============================================================================================
// Number of LUTS per trigger step
static constexpr int LUTS_PER_TRIGGER_STEP = MAX_TRIGGER_CONDITIONS*LUTS_PER_COMPARATOR;

//============================================================================================
// Number of bits for counter for each trigger step
static constexpr int  MATCH_COUNTER_BITS = 16;

//============================================================================================
// Number of LUTS for triggers
static constexpr int LUTS_FOR_TRIGGERS = MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS*LUTS_PER_COMPARATOR;

//============================================================================================
// Number of LUTS for triggers
static constexpr int LUTS_FOR_COMBINERS = 1*(MAX_TRIGGER_STEPS*MAX_TRIGGER_CONDITIONS/4);

//============================================================================================
// Number of LUTS for Trigger Counter match values (Each trigger matcher implements 2 partial matchers each 4-bits wide)
static constexpr int LUTS_FOR_TRIGGER_COUNTS =1*((MAX_TRIGGER_STEPS/2) * (MATCH_COUNTER_BITS/4));

//============================================================================================
// Number of LUTS trigger flags
static constexpr int NUM_TRIGGER_FLAGS = 2;

// Number of LUTS trigger flags (A flag can handle up to 16 steps)
static constexpr int LUTS_FOR_TRIGGERS_FLAGS = NUM_TRIGGER_FLAGS*ceil(MAX_TRIGGER_STEPS/16.0);

//===============================================
// Offsets to LUT sections

// Start of Trigger LUTs
static constexpr int START_TRIGGER_LUTS          = 0;

// Start of Trigger Combiner LUTs
static constexpr int START_TRIGGER_COMBINER_LUTS = START_TRIGGER_LUTS+LUTS_FOR_TRIGGERS;

// Start of Trigger Flag LUTs
static constexpr int START_TRIGGER_COUNTS = START_TRIGGER_COMBINER_LUTS+LUTS_FOR_COMBINERS;

// Start of Trigger Count Satcher LUTs
static constexpr int START_TRIGGER_FLAG_LUTS = START_TRIGGER_COUNTS+LUTS_FOR_TRIGGER_COUNTS;


/**
 * Compares the sample data to a particular trigger pattern.
 * The pattern is encoded as a string of "XHLRFC" values
 */
struct TriggerComparator {
   PinTriggerEncoding triggerValue[SAMPLE_WIDTH+1];

   TriggerComparator() {
      memset(triggerValue, 0, SAMPLE_WIDTH+1);   }

   TriggerComparator(const char *triggerString) {
      memcpy(triggerValue, triggerString, SAMPLE_WIDTH+1);
   }

   TriggerComparator &operator=(const char *&triggerString) {
      memcpy(triggerValue, triggerString, SAMPLE_WIDTH+1);
      return *this;
   }
   PinTriggerEncoding operator[](unsigned index) {
      return triggerValue[(SAMPLE_WIDTH-1)-index];
   }
};

/**
 * Represents a Step in the trigger sequence
 */
struct TriggerStep {
   TriggerComparator triggerValues[MAX_TRIGGER_CONDITIONS];
   unsigned          triggerCount;

   TriggerStep() : triggerCount(0) {
      for (int index=0; index<MAX_TRIGGER_CONDITIONS; index++) {
         triggerValues[index] = TriggerComparator();
      }
   }

   TriggerStep(
         const TriggerComparator &triggerA,
         const TriggerComparator &triggerB,
         unsigned count) : triggerCount(count) {
      triggerValues[0] = triggerA;
      triggerValues[1] = triggerB;
   }

   TriggerStep(
         const char *triggerA,
         const char *triggerB,
         unsigned count) : triggerCount(count) {
      triggerValues[0] = triggerA;
      triggerValues[1] = triggerB;
   }
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
 * Get the LUT value for half a LUT comparator
 * This encodes one bit of two comparators
 *
 * @param triggerValue1
 * @param triggerValue0
 * @return
 */
uint16_t getComparatorHalfLutValues(PinTriggerEncoding triggerValue1, PinTriggerEncoding triggerValue0) {
   unsigned index = 6*triggerValueIndex(triggerValue1)+triggerValueIndex(triggerValue0);
   return lutEncoding[index];
}

/**
 * Get the LUT values for a trigger step
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerStepLutValues(TriggerStep &trigger, uint32_t lutValues[LUTS_PER_TRIGGER_STEP]) {
   int lutIndex = LUTS_PER_TRIGGER_STEP-1;
   for(int condition=MAX_TRIGGER_CONDITIONS-1; condition>=PARTIAL_COMPARATORS_PER_LUT-1; condition-=PARTIAL_COMPARATORS_PER_LUT) {
      for(int bitNum=SAMPLE_WIDTH-1; bitNum>=COMPARATOR_BITS_PER_LUT-1; bitNum-=COMPARATOR_BITS_PER_LUT) {
         lutValues[lutIndex] = getComparatorHalfLutValues(
               trigger.triggerValues[condition][bitNum],
               trigger.triggerValues[condition][bitNum-1]);
         lutValues[lutIndex] <<= 16;
         lutValues[lutIndex] |= getComparatorHalfLutValues(
               trigger.triggerValues[condition-1][bitNum],
               trigger.triggerValues[condition-1][bitNum-1]);
         lutIndex--;
      }
   }
}

/**
 * Get the LUT values for a trigger sequence
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerLutValues(TriggerStep trigger[MAX_TRIGGER_STEPS], uint32_t lutValues[LUTS_PER_TRIGGER_STEP]) {
   for (int step=0; step<MAX_TRIGGER_STEPS; step++) {
      getTriggerStepLutValues(trigger[step], lutValues+step*LUTS_PER_TRIGGER_STEP);
   }
}

/**
 * Print an array of LUTs
 *
 * @param lutValues
 * @param number
 */
void printLuts(uint32_t lutValues[], unsigned number) {
   bool doOpen = true;
   unsigned printNum = 0;
   if (number>LUTS_PER_TRIGGER_STEP) {
      printf("\n");
   }
   for(int index=number-1; index>=0; index--) {
      if (doOpen) {
         printf("[");
         doOpen = false;
      }
      printf("%2X:0x%08X", index, lutValues[index]);
      if (++printNum == LUTS_PER_TRIGGER_STEP) {
         printNum = 0;
         printf("]\n");
         doOpen = true;
      }
      else if ((printNum % LUTS_PER_COMPARATOR) ==0) {
         printf("|");
      }
      else {
         printf(", ");
      }
   }
   if (printNum != 0) {
      printf("]\n");
   }
}

/*
 * This encoder the trigger value for 1 TriggerStep (step)
 * Example layout (MAX_TRIGGER_CONDITIONS=2, SAMPLE_WIDTH=32)
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
      uint32_t lutValues[LUTS_PER_TRIGGER_STEP]) {

   TriggerStep trigger = {
         triggerB,
         triggerA,
         100,
   };
   printf("Tb='%16s', Ta='%16s' => ", triggerB, triggerA);
   getTriggerStepLutValues(trigger, lutValues);
   printLuts(lutValues, LUTS_PER_TRIGGER_STEP);
}

void encodeTriggerToStep(
      const char *triggerB,
      const char *triggerA,
      TriggerStep &triggerStep) {

   TriggerStep trgrStep = {
         triggerB,
         triggerA,
         100,
   };
   triggerStep = trgrStep;
}

void testTrigger() {
   //   testLutEncoding();
   uint32_t lutValues[LUTS_PER_TRIGGER_STEP];
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXX1", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXX1", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXX0", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXX0", lutValues);
   printf("\n");
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXH", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXL", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXR", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXF", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXC", "XXXXXXXXXXXXXXXX", lutValues);
   printf("\n");
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXHX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXLX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXRX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXFX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXCX", "XXXXXXXXXXXXXXXX", lutValues);
   printf("\n");
   testTriggerToLuts("XXXXXXXXXXXXXXXX", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXH", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXL", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXR", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXF", "XXXXXXXXXXXXXXXX", lutValues);
   testTriggerToLuts("XXXXXXXXXXXXXXXC", "XXXXXXXXXXXXXXXX", lutValues);
   printf("\n");
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

int main() {

   printf("LUTS_FOR_TRIGGERS           = %d\n", LUTS_FOR_TRIGGERS);
   printf("LUTS_FOR_COMBINERS          = %d\n", LUTS_FOR_COMBINERS);
   printf("LUTS_FOR_TRIGGER_COUNTS     = %d\n", LUTS_FOR_TRIGGER_COUNTS);
   printf("LUTS_FOR_TRIGGERS_FLAGS     = %d\n", LUTS_FOR_TRIGGERS_FLAGS);

   printf("START_TRIGGER_LUTS          = %d\n", START_TRIGGER_LUTS);
   printf("START_TRIGGER_COMBINER_LUTS = %d\n", START_TRIGGER_COMBINER_LUTS);
   printf("START_TRIGGER_COUNTS        = %d\n", START_TRIGGER_COUNTS);
   printf("START_TRIGGER_FLAG_LUTS     = %d\n", START_TRIGGER_FLAG_LUTS);



   TriggerStep trigger[MAX_TRIGGER_STEPS];
   uint32_t lutValues[LUTS_FOR_TRIGGERS];

   for (int step=MAX_TRIGGER_STEPS-1; step>=0; step--) {
      encodeTriggerToStep("XXXXXXXXXXXXXXXX", "0XXXXXXXXXXXXXXX", trigger[step]);
   }

   getTriggerLutValues(trigger, lutValues);
   printLuts(lutValues, LUTS_FOR_TRIGGERS);
   return 0;
}
