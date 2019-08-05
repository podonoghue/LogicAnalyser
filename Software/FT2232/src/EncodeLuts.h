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
      sf.write(operation.toString()).write(" ");
      for (unsigned triggerNum=0; triggerNum<MAX_TRIGGER_PATTERNS; triggerNum++) {
         sf.write("T").write(triggerNum).write("[").write(patterns[triggerNum].toString());
         sf.write(", ").write(polarities[triggerNum].toString()).write("] ");
      }
      sf.write("Count = ").write(triggerCount);
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

public:
   TriggerSetup() : lastActiveTriggerCount(0) {
   }

   TriggerSetup(TriggerStep triggers[MAX_TRIGGER_STEPS], unsigned lastActiveTriggerCount) : lastActiveTriggerCount(lastActiveTriggerCount) {
      memcpy(this->triggers, triggers, sizeof(this->triggers));
   }

   auto getTrigger(unsigned triggerNum) {
      return triggers[triggerNum];
   }

   auto getLastActiveTriggerCount() {
      return lastActiveTriggerCount;
   }

   void printTriggers() {
      for (unsigned step=0; step<MAX_TRIGGER_STEPS; step++) {
         USBDM::console.write("  -- ").writeln(triggers[step].toString());
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
   void getTriggerPatternMatcherLutValues(uint32_t lutValues[LUTS_FOR_TRIGGER_PATTERNS]) {
      unsigned lutIndex = 0;
      for(int step=MAX_TRIGGER_STEPS-1; step >=0; step-- ) {
         triggers[step].getTriggerStepPatternMatcherLutValues(lutValues+lutIndex);
         lutIndex += LUTS_PER_TRIGGER_STEP_FOR_PATTERNS;
      }
   }

   /**
    * Get the LUT values for the combiner for all trigger steps
    *
    * @param trigger
    * @param lutValues
    */
   void getTriggerCombinerLutValues(uint32_t lutValues[LUTS_FOR_TRIGGER_COMBINERS]) {
      unsigned lutIndex = 0;
      for(int step=MAX_TRIGGER_STEPS-1; step >=0; step-- ) {
         triggers[step].getTriggerStepCombinerLutValues(lutValues+lutIndex);
         lutIndex += LUTS_PER_TRIGGER_STEP_FOR_COMBINERS;
      }
   }

   /**
    * Get the LUT values for the trigger contiguous value
    *
    * @param trigger
    * @param lutValues
    */
   void getTriggerFlagLutValues(uint32_t lutValues[LUTS_FOR_TRIGGERS_FLAGS]) {
      unsigned lutIndex = 0;
      uint32_t flags = 0;
      // Process each trigger
      for(int step=0; step < MAX_TRIGGER_STEPS; step++ ) {
         if (triggers[step].isContiguous()) {
            flags |= (1<<step);
         }
      }
      lutValues[lutIndex++] = (1<<lastActiveTriggerCount);
      lutValues[lutIndex++] = flags;
   }

   /**
    * Get the LUT values for the trigger count comparators for all trigger steps
    *
    * @param trigger
    * @param lutValues
    */
   void getTriggerCountLutValues(uint32_t lutValues[LUTS_FOR_TRIGGER_COUNTS]) {

      // Clear LUTs initially
      for(int index=0; index<LUTS_FOR_TRIGGER_COUNTS; index++) {
         lutValues[index] = 0;
      }
      // Shuffle Trigger values for LUTS
      // This is basically a transpose
      for(int step=0; step < MAX_TRIGGER_STEPS; step++ ) {
         // The bits for each step appear at the this location in the SR
         uint32_t bitmask = 1<<step;
         uint32_t count   = Lfsr16::encode(getTrigger(step).getCount());
         for(int bit=0; bit<NUM_MATCH_COUNTER_BITS; bit++ ) {
            lutValues[(NUM_MATCH_COUNTER_BITS-1)-bit] |= (count&(1<<bit))?bitmask:0;
         }
      }
   }

};

/**
 * Print an array of LUTs
 *
 * @param lutValues
 * @param number
 */
void printLuts(uint32_t lutValues[], unsigned number);

}  // end namespace Analyser

#endif /* SOURCES_ENCODELUTS_H_ */
