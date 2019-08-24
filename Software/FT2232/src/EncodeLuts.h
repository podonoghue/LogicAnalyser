/*
 * EncodeLuts.h
 *
 *  Created on: 13 Jul 2019
 *      Author: podonoghue
 */

#ifndef SOURCES_ENCODELUTS_H_
#define SOURCES_ENCODELUTS_H_

#include <stdint.h>
#include <string.h>
#include <math.h>
#include <assert.h>

#include "stringFormatter.h"
#include "Lfsr16.h"

namespace Analyser {
//==============================================================
//
constexpr uint8_t C_RECEIVE_MODE  = 0b00000000;
constexpr uint8_t C_TRANSMIT_MODE = 0b10000000;
constexpr uint8_t C_TX_BITNUM     = 7;

constexpr uint8_t C_NOP           = 0b00000000 | C_RECEIVE_MODE;

constexpr uint8_t C_LUT_CONFIG    = 0b00000001 | C_RECEIVE_MODE;
constexpr uint8_t C_WR_CONTROL    = 0b00000010 | C_RECEIVE_MODE;
constexpr uint8_t C_WR_PRETRIG    = 0b00000011 | C_RECEIVE_MODE;
constexpr uint8_t C_WR_CAPTURE    = 0b00000100 | C_RECEIVE_MODE;

constexpr uint8_t C_RD_VERSION    = 0b00000000 | C_TRANSMIT_MODE;
constexpr uint8_t C_RD_BUFFER     = 0b00000001 | C_TRANSMIT_MODE;
constexpr uint8_t C_RD_STATUS     = 0b00000010 | C_TRANSMIT_MODE;

//==============================================================
//
constexpr uint8_t C_CONTROL_START_ACQ     = 0b00000001;
constexpr uint8_t C_CONTROL_CLEAR         = 0b00000010;

constexpr uint8_t C_CONTROL_DIV_MASK      = 0b00001100;
constexpr uint8_t C_CONTROL_DIV_OFFSET    = 2;
constexpr uint8_t C_CONTROL_DIV1          = 0b00000000;
constexpr uint8_t C_CONTROL_DIV2          = 0b00000100;
constexpr uint8_t C_CONTROL_DIV5          = 0b00001000;
constexpr uint8_t C_CONTROL_DIV10         = 0b00001100;

constexpr uint8_t C_CONTROL_DIVx_MASK     = 0b00110000;
constexpr uint8_t C_CONTROL_DIVx_OFFSET   = 4;
constexpr uint8_t C_CONTROL_DIVx1         = 0b00000000;
constexpr uint8_t C_CONTROL_DIVx10        = 0b00010000;
constexpr uint8_t C_CONTROL_DIVx100       = 0b00100000;
constexpr uint8_t C_CONTROL_DIVx1000      = 0b00110000;

enum SampleRate {
   SampleRate_10ns  = C_CONTROL_DIVx1    | C_CONTROL_DIV1,
   SampleRate_20ns  = C_CONTROL_DIVx1    | C_CONTROL_DIV2,
   SampleRate_50ns  = C_CONTROL_DIVx1    | C_CONTROL_DIV5,
   SampleRate_100ns = C_CONTROL_DIVx10   | C_CONTROL_DIV1,
   SampleRate_200ns = C_CONTROL_DIVx10   | C_CONTROL_DIV2,
   SampleRate_500ns = C_CONTROL_DIVx10   | C_CONTROL_DIV5,
   SampleRate_1us   = C_CONTROL_DIVx100  | C_CONTROL_DIV1,
   SampleRate_2us   = C_CONTROL_DIVx100  | C_CONTROL_DIV2,
   SampleRate_5us   = C_CONTROL_DIVx100  | C_CONTROL_DIV5,
   SampleRate_10us  = C_CONTROL_DIVx1000 | C_CONTROL_DIV1,
   SampleRate_20us  = C_CONTROL_DIVx1000 | C_CONTROL_DIV2,
   SampleRate_50us  = C_CONTROL_DIVx1000 | C_CONTROL_DIV5,
   SampleRate_100us = C_CONTROL_DIVx1000 | C_CONTROL_DIV10,
};

static constexpr unsigned getSamplePeriodIn_nanoseconds(SampleRate sampleRate) {
   switch (sampleRate) {
      case SampleRate_10ns  : return 10;
      case SampleRate_20ns  : return 20;
      case SampleRate_50ns  : return 50;
      case SampleRate_100ns : return 100;
      case SampleRate_200ns : return 200;
      case SampleRate_500ns : return 500;
      case SampleRate_1us   : return 1000;
      case SampleRate_2us   : return 2000;
      case SampleRate_5us   : return 5000;
      case SampleRate_10us  : return 10000;
      case SampleRate_20us  : return 20000;
      case SampleRate_50us  : return 50000;
      case SampleRate_100us : return 100000;
   }
   return 1;
}

//==============================================================
//
constexpr uint8_t C_STATUS_STATE_MASK      = 0b00000111;
constexpr uint8_t C_STATUS_STATE_OFFSET    = 0;
constexpr uint8_t C_STATUS_STATE_IDLE      = 0b00000000;
constexpr uint8_t C_STATUS_STATE_PRETRIG   = 0b00000001;
constexpr uint8_t C_STATUS_STATE_ARMED     = 0b00000010;
constexpr uint8_t C_STATUS_STATE_RUN       = 0b00000011;
constexpr uint8_t C_STATUS_STATE_DONE      = 0b00000100;

/**
 * Used to encode the operation to combine trigger patterns
 */
class Operation {

private:
   unsigned operation;

public:
   static constexpr unsigned And = 0;   //!< True when all patterns match
   static constexpr unsigned Or  = 1;   //!< True when any patterns match

   Operation() {
      operation = And;
   }

   Operation(unsigned value) : operation(value) {
   }

   Operation(const Operation &other) : operation(other.operation) {
   }

   Operation &operator=(const Operation &other) {
      operation = other.operation;
      return *this;
   }

   const char *toString() {
      switch(operation) {
         case And : return "And";
         case Or  : return "Or ";
      }
      return "Illegal";
   }

   bool operator==(const unsigned value) {
      return operation == value;
   }

   operator unsigned() {
      return operation;
   }
};

/**
 * Used to indicate or control the polarity of a trigger pattern
 */
class Polarity {

private:
   unsigned polarity;

public:
   static constexpr unsigned Normal   = 0;   //!< Pattern is true when matched
   static constexpr unsigned Inverted = 1;   //!< Pattern is true when not matched
   static constexpr unsigned Disabled = 2;   //!< Pattern is disabled

   Polarity() : polarity(Normal) {
   }

   Polarity(unsigned value) : polarity(value) {
   }

   Polarity(const Polarity &other) : polarity(other.polarity) {
   }

   Polarity &operator=(const Polarity &other) {
      polarity = other.polarity;
      return *this;
   }

   const char *toString() {
      switch(polarity) {
         case Normal:   return "Normal  ";
         case Inverted: return "Inverted";
         case Disabled: return "Disabled";
      }
      return "Illegal";
   }

   /**
    *
    * @param value
    * @param op
    *
    * @return
    */
   bool operator() (bool value, Operation op) {
      switch(polarity) {
         case Normal:   return value;
         case Inverted: return !value;
         case Disabled: return ((unsigned)op == Operation::And);
      }
      return false;
   }

   bool operator==(const unsigned value) {
      return polarity == value;
   }

   operator unsigned() {
      return polarity;
   }
};

/// Number of sample inputs
static constexpr int SAMPLE_WIDTH = 16;

//====================================================================
// Trigger Steps

/// Maximum number of patterns for each trigger step (either 2 or 4)
static constexpr int MAX_TRIGGER_PATTERNS = 2;

/// Maximum number of steps in complex trigger sequence
static constexpr int MAX_TRIGGER_STEPS = 16;

/// Number of bits for counter for each trigger step
static constexpr int NUM_MATCH_COUNTER_BITS = 16;

/// Number of trigger flags (shared across all steps)
static constexpr int NUM_TRIGGER_FLAGS = 2;

//================================================================
// PatternMatchers match an input sample against a pattern
// Each trigger step contains multiple PatternMatchers
// PatternMatchers are complicated because each LUT implements
// 2 bits of 2 separate PatternMatchers with shared inputs

/// Number of partial PatternMatchers implemented in a PatternMatcher LUT
static constexpr int PARTIAL_PATTERN_MATCHERS_PER_LUT = 2;

/// Number of bits implemented in a PatternMatcher LUT
static constexpr int PATTERN_MATCHER_BITS_PER_LUT     = 2;

//================================================================
// Trigger combiners
// Combine the outputs of PatternMatchers
// Each combiner LUT can handle 4 pattern matchers
static constexpr int COMBINERS_PER_LUT = 4;

//================================================================
// CountMatchers match a count in a trigger step
// Each LUT (shift-register) implements one bit from each of the count comparisons

// Number of bits in a step trigger counter
//static constexpr int NUM_TRIGGER_COUNTER_BITS   = 16;

/// Number of bits implemented in a CountMatcher LUT
//static constexpr int COUNT_MATCHERS     = 4;

//====================================================================

/// Number of LUTS for configuration information
static constexpr int NUM_CONFIG_WORDS = 4;

///============================================================================================
/// Number of LUTS per trigger step used for pattern matchers
static constexpr int LUTS_PER_TRIGGER_STEP_FOR_PATTERNS = (MAX_TRIGGER_PATTERNS*SAMPLE_WIDTH)/(PATTERN_MATCHER_BITS_PER_LUT*PARTIAL_PATTERN_MATCHERS_PER_LUT);

/// Number of LUTS per trigger step used for trigger pattern combiners
static constexpr int LUTS_PER_TRIGGER_STEP_FOR_COMBINERS = 1;

/// Each configuration word occupies a LUT
static constexpr int LUTS_FOR_CONFIG = 0;//NUM_CONFIG_WORDS/1;

/// Number of LUTS for triggers used for pattern matchers
static constexpr int LUTS_FOR_TRIGGER_PATTERNS = MAX_TRIGGER_STEPS*LUTS_PER_TRIGGER_STEP_FOR_PATTERNS;

/// Number of LUTS for triggers used for counter matchers ( 1 per counter bit)
static constexpr int LUTS_FOR_TRIGGER_COUNTS = NUM_MATCH_COUNTER_BITS;

/// Number of LUTS for trigger combiners for each trigger step
static constexpr int LUTS_FOR_TRIGGER_COMBINERS = MAX_TRIGGER_STEPS;

/// Number of LUTS trigger flags (A flag can handle up to 32 steps)
static constexpr int LUTS_FOR_TRIGGERS_FLAGS = NUM_TRIGGER_FLAGS*ceil(MAX_TRIGGER_STEPS/16.0);

static constexpr int TOTAL_TRIGGER_LUTS =
      LUTS_FOR_TRIGGER_PATTERNS+
      LUTS_FOR_TRIGGER_COMBINERS+
      LUTS_FOR_TRIGGER_COUNTS+
      LUTS_FOR_TRIGGERS_FLAGS;

//===============================================
// Offsets to LUT sections

// Start of Trigger LUTs
static constexpr int START_CONFIG_LUTS             = 0;

// Start of Trigger LUTs
static constexpr int START_TRIGGER_PATTERN_LUTS    = START_CONFIG_LUTS+LUTS_FOR_CONFIG;

// Start of Trigger Combiner LUTs
static constexpr int START_TRIGGER_COMBINER_LUTS   = START_TRIGGER_PATTERN_LUTS+LUTS_FOR_TRIGGER_PATTERNS;

// Start of Trigger Flag LUTs
static constexpr int START_TRIGGER_COUNT_LUTS      = START_TRIGGER_COMBINER_LUTS+LUTS_FOR_TRIGGER_COMBINERS;

// Start of Trigger Count Matcher LUTs
static constexpr int START_TRIGGER_FLAG_LUTS       = START_TRIGGER_COUNT_LUTS+LUTS_FOR_TRIGGER_COUNTS;

///=========================================================================
/// Uses to represent a trigger bit encoding e.g. 'X','H','L','R','F','C'
typedef char PinTriggerEncoding;

/**
 * Compares the sample data to a particular trigger pattern.
 * The pattern is encoded as a string of "XHLRFC" values
 */
class TriggerPattern {
private:
   PinTriggerEncoding triggerValue[SAMPLE_WIDTH+1];

public:
   TriggerPattern() {
      memset(triggerValue, 0, SAMPLE_WIDTH+1);
   }

   /**
    * Construct a pattern from a string
    * If the pattern is shorter than SAMPLE_WIDTH then it
    * is padded with 'X' on the left
    *
    * @param triggerString
    */
   TriggerPattern(const char *triggerString) {
      memset(triggerValue, 'X', SAMPLE_WIDTH);
      unsigned width  = strlen(triggerString);
      if (width>SAMPLE_WIDTH) {
         width = SAMPLE_WIDTH;
      }
      unsigned offset = SAMPLE_WIDTH-width;
      memcpy(triggerValue+offset, triggerString, width);
      triggerValue[SAMPLE_WIDTH] = '\0';
   }

   TriggerPattern &operator=(const char *&triggerString) {
      memcpy(triggerValue, triggerString, SAMPLE_WIDTH+1);
      return *this;
   }
   PinTriggerEncoding operator[](unsigned index) {
      return triggerValue[(SAMPLE_WIDTH-1)-index];
   }

   PinTriggerEncoding getBitEncoding(unsigned bitNum) {
      assert(bitNum < SAMPLE_WIDTH);
      return triggerValue[bitNum];
   }
   const char *toString() {
      return triggerValue;
   }
};

/**
 * Represents a Step in the trigger sequence
 *
 * This will contain:
 * - Trigger pattern x MAX_TRIGGER_PATTERNS
 * - Polarities for above
 * - Operation (AND/OR) used to combine pattern matches
 * - Whether pattern counting requires contiguous detection
 * - Trigger count required for final match
 */
class TriggerStep {

private:
   TriggerPattern    patterns[MAX_TRIGGER_PATTERNS];
   Polarity          polarities[MAX_TRIGGER_PATTERNS];
   Operation         operation;
   bool              contiguous;
   unsigned          triggerCount;

public:
   TriggerStep() : operation(Operation::And), contiguous(false), triggerCount(0) {
   }

   TriggerStep(
         const TriggerPattern &trigger0,
         const TriggerPattern &trigger1,
         const Polarity        polarity0,
         const Polarity        polarity1,
         const Operation       op,
         const bool            contiguous,
         const unsigned        count) :
            patterns({trigger0, trigger1}), polarities({polarity0, polarity1}), operation(op), contiguous(contiguous), triggerCount(count) {
   }

   TriggerStep(
         const char        *trigger0,
         const char        *trigger1,
         const Polarity     polarity0,
         const Polarity     polarity1,
         const Operation    op,
         const bool         contiguous,
         const unsigned     count) :
            patterns({trigger0, trigger1}), polarities({polarity0, polarity1}), operation(op), contiguous(contiguous), triggerCount(count) {
   }

   static unsigned triggerValueIndex(PinTriggerEncoding value) {
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

   const char *toString() {
      static USBDM::StringFormatter_T<200> sf;
      sf.clear();
      sf.write(operation.toString()).write("(");
      for (unsigned triggerNum=0; triggerNum<MAX_TRIGGER_PATTERNS; triggerNum++) {
         sf.write("T").write(triggerNum).write("[").write(patterns[triggerNum].toString());
         sf.write(", ").write(polarities[triggerNum].toString()).write("] ");
      }
      sf.write("), Count = ").write(triggerCount);
      return sf.toString();
   }

   auto getCount() {
      return triggerCount;
   }

   auto getPattern(unsigned patternNum) {
      assert(patternNum<MAX_TRIGGER_PATTERNS);
      return patterns[patternNum];
   }

   auto getPolarities(unsigned patternNum) {
      assert(patternNum<MAX_TRIGGER_PATTERNS);
      return polarities[patternNum];
   }

   auto getOperation() {
      return operation;
   }

   auto isContiguous() {
      return contiguous;
   }

   /**
    * Get the LUT values for the combiner in a trigger step
    *
    * @param trigger
    * @param lutValues
    */
   void getTriggerStepCombinerLutValues(uint32_t lutValues[LUTS_PER_TRIGGER_STEP_FOR_COMBINERS]) {
      uint16_t result = 0;

      for (unsigned value=0; value<(1<<MAX_TRIGGER_PATTERNS); value++) {
         bool bitValue;
         switch(getOperation()) {
            case Operation::And: bitValue = 1; break;
            case Operation::Or:  bitValue = 0; break;
         }
         for (unsigned patternNum=0; patternNum<MAX_TRIGGER_PATTERNS; patternNum++) {
            bool term = (value&(1<<patternNum));
            term = getPolarities(patternNum)(term, getOperation());
            switch(getOperation()) {
               case Operation::And: bitValue = bitValue && term; break;
               case Operation::Or:  bitValue = bitValue || term; break;
            }
         }
         result |= bitValue<<value;
      }
      lutValues[0] = result;
   }

   static const uint16_t lutEncoding[];

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
   void getTriggerStepPatternMatcherLutValues(uint32_t lutValues[LUTS_PER_TRIGGER_STEP_FOR_PATTERNS]) {

      int lutIndex = 0;

      for(int bitNum=SAMPLE_WIDTH-1; bitNum>=PATTERN_MATCHER_BITS_PER_LUT-1; bitNum-=PATTERN_MATCHER_BITS_PER_LUT) {
         for(int condition=MAX_TRIGGER_PATTERNS-1; condition>=PARTIAL_PATTERN_MATCHERS_PER_LUT-1; condition-=PARTIAL_PATTERN_MATCHERS_PER_LUT) {
            uint32_t value = 0;
            value  = getPatternMatchHalfLutValues(
                  getPattern(condition)[bitNum],
                  getPattern(condition)[bitNum-1]);
            value <<= 16;
            value |= getPatternMatchHalfLutValues(
                  getPattern(condition-1)[bitNum],
                  getPattern(condition-1)[bitNum-1]);
            lutValues[lutIndex++] = value;
         }
      }
   }

};

/**
 * Represents the entire trigger setup
 */
class TriggerSetup {
   // Configuration for each trigger
   TriggerStep triggers[MAX_TRIGGER_STEPS];

   // Number of last active trigger
   unsigned lastActiveTriggerCount;

   SampleRate sampleRate;

   unsigned   sampleSize;
   unsigned   preTriggerSize;

public:
   TriggerSetup() : lastActiveTriggerCount(0), sampleRate(SampleRate_100ns), sampleSize(100), preTriggerSize(50) {
   }

   TriggerSetup(
         TriggerStep triggers[MAX_TRIGGER_STEPS],
         unsigned    lastActiveTriggerCount,
         SampleRate  sampleRate,
         unsigned    sampleSize,
         unsigned    preTriggerSize)

      : lastActiveTriggerCount(lastActiveTriggerCount), sampleRate(sampleRate), sampleSize(sampleSize), preTriggerSize(preTriggerSize) {
      memcpy(this->triggers, triggers, sizeof(this->triggers));
   }

   void setSampleRate(SampleRate sampleRate) {
      this->sampleRate = sampleRate;
   }

   SampleRate getSampleRate() {
      return sampleRate;
   }

   void setSampleSize(unsigned sampleSize) {
      this->sampleSize = sampleSize;
   }

   unsigned getSampleSize() {
      return sampleSize;
   }

   void setPreTrigSize(unsigned preTriggerSize) {
      this->preTriggerSize = preTriggerSize;
   }

   unsigned getPreTrigSize() {
      return preTriggerSize;
   }

   auto getTrigger(unsigned triggerNum) {
      return triggers[triggerNum];
   }

   auto getLastActiveTriggerCount() {
      return lastActiveTriggerCount;
   }

   void printTriggers() {
      for (unsigned step=0; step<=lastActiveTriggerCount; step++) {
         USBDM::console.write("-- ").writeln(triggers[step].toString());
      }
   }

   /**
    * Converts data from little-endian to big-endian in-situ
    *
    * @param size Number of LUTs to convert
    * @param data Array of LUTs
    *
    * @return Converted array treated as uint8_t
    */
   uint8_t *formatData(unsigned size, uint32_t *data) {
      for(unsigned index=0; index<size; index++) {
         data[index] = __builtin_bswap32(data[index]);
      }
      return reinterpret_cast<uint8_t *>(data);
   }

   /**
    * Get the LUT values for the pattern matchers for all trigger steps
    *
    * @param trigger
    * @param lutValues
    */
   void getTriggerPatternMatcherLutValues(uint32_t *&lutValues) {
      unsigned lutIndex = 0;
      for(int step=MAX_TRIGGER_STEPS-1; step >=0; step-- ) {
         if (step>(int)this->lastActiveTriggerCount) {
            for (unsigned offset=0; offset<LUTS_PER_TRIGGER_STEP_FOR_PATTERNS; offset++) {
               lutValues[lutIndex+offset] = 0x0;
            }
         }
         else {
            triggers[step].getTriggerStepPatternMatcherLutValues(lutValues+lutIndex);
         }
         lutIndex += LUTS_PER_TRIGGER_STEP_FOR_PATTERNS;
      }
      lutValues += LUTS_FOR_TRIGGER_PATTERNS;
   }

   /**
    * Get the LUT values for the combiner for all trigger steps
    *
    * @param trigger
    * @param lutValues
    */
   void getTriggerCombinerLutValues(uint32_t *&lutValues) {
      unsigned lutIndex = 0;
      for(int step=MAX_TRIGGER_STEPS-1; step >=0; step-- ) {
         if (step>(int)this->lastActiveTriggerCount) {
            for (unsigned offset=0; offset<LUTS_PER_TRIGGER_STEP_FOR_COMBINERS; offset++) {
               lutValues[lutIndex+offset] = 0x0;
            }
         }
         else {
            triggers[step].getTriggerStepCombinerLutValues(lutValues+lutIndex);
         }
         lutIndex += LUTS_PER_TRIGGER_STEP_FOR_COMBINERS;
      }
      lutValues += LUTS_FOR_TRIGGER_COMBINERS;
   }

   /**
    * Get the LUT values for the trigger contiguous value
    *
    * @param trigger
    * @param lutValues
    */
   void getTriggerFlagLutValues(uint32_t *&lutValues) {
      uint32_t flags = 0;
      // Process each trigger
      for(int step=0; step < MAX_TRIGGER_STEPS; step++ ) {
         if (triggers[step].isContiguous()) {
            flags |= (1<<step);
         }
      }
      *lutValues++ = (1<<lastActiveTriggerCount);
      *lutValues++ = flags;
   }

   /**
    * Get the LUT values for the trigger count comparators for all trigger steps
    *
    * @param trigger
    * @param lutValues
    */
   void getTriggerCountLutValues(uint32_t *&lutValues) {

      // Clear LUTs initially
      for(int index=0; index<LUTS_FOR_TRIGGER_COUNTS; index++) {
         lutValues[index] = 0;
      }
      // Shuffle Trigger values for LUTS
      // This is basically a transpose
      for(int step=0; step <= (int)lastActiveTriggerCount; step++ ) {
         // The bits for each step appear at the this location in the SR
         uint32_t bitmask = 1<<step;
         uint32_t count   = Lfsr16::encode(getTrigger(step).getCount());
         for(int bit=0; bit<NUM_MATCH_COUNTER_BITS; bit++ ) {
            lutValues[(NUM_MATCH_COUNTER_BITS-1)-bit] |= (count&(1<<bit))?bitmask:0;
         }
      }
      lutValues += LUTS_FOR_TRIGGER_COUNTS;
   }

};

/**
 * Print an array of LUTs
 *
 * @param lutValues
 * @param number
 */
void printLuts(const char *title, uint32_t lutValues[], unsigned number);

}  // end namespace Analyser

#endif /* SOURCES_ENCODELUTS_H_ */
