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

#include "hardware.h"
#include "stringFormatter.h"

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
         case And : return "And  ";
         case Or  : return "Or";
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
 * Used to indicate or control the polarity of trigger patterns
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
static constexpr int SAMPLE_WIDTH = 2;

//====================================================================
// Trigger Steps

/// Maximum number of patterns for each trigger step (either 2 or 4)
static constexpr int MAX_TRIGGER_PATTERNS = 2;

/// Maximum number of steps in complex trigger sequence
static constexpr int MAX_TRIGGER_STEPS = 4;

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
// CountMatchers are complicated because each LUT implements
// 4 bits of 2 separate count matchers with shared inputs

/// Number of partial CountMatchers implemented in a Comparator LUT
static constexpr int PARTIAL_COUNT_MATCHERS_PER_LUT = 2;

/// Number of bits implemented in a CountMatcher LUT
static constexpr int COUNT_MATCHER_BITS_PER_LUT     = 4;

//====================================================================

/// Number of LUTS for configuration information
static constexpr int NUM_CONFIG_WORDS = 4;

///============================================================================================
/// Number of LUTS per trigger step used for pattern matchers
static constexpr int LUTS_PER_TRIGGER_STEP_FOR_PATTERNS = (MAX_TRIGGER_PATTERNS*SAMPLE_WIDTH)/(PATTERN_MATCHER_BITS_PER_LUT*PARTIAL_PATTERN_MATCHERS_PER_LUT);

/// Number of LUTS per trigger step used for counter matchers
static constexpr int LUTS_PER_TRIGGER_STEP_FOR_COUNTS = (NUM_MATCH_COUNTER_BITS)/(COUNT_MATCHER_BITS_PER_LUT*PARTIAL_COUNT_MATCHERS_PER_LUT);

/// Number of LUTS per trigger step used for trigger pattern combiners
static constexpr int LUTS_PER_TRIGGER_STEP_FOR_COMBINERS = 1;

// todo fix this
/// Each configuration word occupies a LUT
static constexpr int LUTS_FOR_CONFIG = 0;//NUM_CONFIG_WORDS/1;

/// Number of LUTS for triggers used for pattern matchers
static constexpr int LUTS_FOR_TRIGGER_PATTERNS = MAX_TRIGGER_STEPS*LUTS_PER_TRIGGER_STEP_FOR_PATTERNS;

/// Number of LUTS for triggers used for counter matchers
static constexpr int LUTS_FOR_TRIGGER_COUNTS = MAX_TRIGGER_STEPS*LUTS_PER_TRIGGER_STEP_FOR_COUNTS;

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

// Start of Trigger Count Satcher LUTs
static constexpr int START_TRIGGER_FLAG_LUTS       = START_TRIGGER_COUNT_LUTS+LUTS_FOR_TRIGGER_COUNTS;

///=========================================================================
/// Uses to represent a trigger bit encoding e.g. 'X','H','L','R','F','C'
typedef char PinTriggerEncoding;

/**
 * Compares the sample data to a particular trigger pattern.
 * The pattern is encoded as a string of "XHLRFC" values
 */
struct TriggerPattern {
   PinTriggerEncoding triggerValue[SAMPLE_WIDTH+1];

   TriggerPattern() {
      memset(triggerValue, 0, SAMPLE_WIDTH+1);
   }

   TriggerPattern(const char *triggerString) {
      memcpy(triggerValue, triggerString, SAMPLE_WIDTH+1);
   }

   TriggerPattern &operator=(const char *&triggerString) {
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
friend void getTriggerStepCombinerLutValues(TriggerStep &trigger, uint32_t lutValues[LUTS_PER_TRIGGER_STEP_FOR_PATTERNS]);
friend void getTriggerStepPatternMatcherLutValues(TriggerStep &trigger, uint32_t lutValues[LUTS_PER_TRIGGER_STEP_FOR_PATTERNS]);
friend void getTriggerStepPairCountLutValues(TriggerStep t1, TriggerStep t0, uint32_t lutValues[2*LUTS_PER_TRIGGER_STEP_FOR_COUNTS]);

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
         const unsigned        count) : patterns({trigger0, trigger1}), polarities({polarity0, polarity1}), operation(op), contiguous(contiguous), triggerCount(count) {
   }

   TriggerStep(
         const char        *trigger0,
         const char        *trigger1,
         const Polarity     polarity0,
         const Polarity     polarity1,
         const Operation    op,
         const bool         contiguous,
         const unsigned     count) : patterns({trigger0, trigger1}), polarities({polarity0, polarity1}), operation(op), contiguous(contiguous), triggerCount(count) {
   }

   const char *toString() {
      static USBDM::StringFormatter_T<200> sf;
      sf.clear();
      sf.write(operation.toString()).write(" ");
      for (unsigned triggerNum=0; triggerNum<MAX_TRIGGER_PATTERNS; triggerNum++) {
         sf.write("T").write(triggerNum).write("[").write(patterns[triggerNum].triggerValue);
         sf.write(", ").write(polarities[triggerNum].toString()).write("] ");
      }
      sf.write("Count = ").write(triggerCount);
      return sf.toString();
   }

   bool isContiguous() {
      return contiguous;
   }
};

struct TriggerSetup {
   // Configuration for each trigger
   TriggerStep triggers[MAX_TRIGGER_STEPS];

   // Number of last active trigger
   unsigned lastActiveTriggerCount;

   TriggerSetup() : lastActiveTriggerCount(0) {
   }

   TriggerSetup(TriggerStep triggers[MAX_TRIGGER_STEPS], unsigned lastActiveTriggerCount) : lastActiveTriggerCount(lastActiveTriggerCount) {
      memcpy(this->triggers, triggers, sizeof(this->triggers));
   }

};

/**
 * Get the LUT values for the pattern matchers for all trigger steps
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerPatternMatcherLutValues(TriggerSetup setup, uint32_t lutValues[LUTS_FOR_TRIGGER_PATTERNS]);

/**
 * Get the LUT values for the combiner for all trigger steps
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerCombinerLutValues(TriggerSetup setup, uint32_t lutValues[LUTS_FOR_TRIGGER_COMBINERS]);

/**
 * Get the LUT values for the trigger count comparators for all trigger steps
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerCountLutValues(TriggerSetup setup, uint32_t lutValues[LUTS_FOR_TRIGGER_COUNTS]);

/**
 * Get the LUT values for the trigger contiguous value
 *
 * @param trigger
 * @param lutValues
 */
void getTriggerFlagLutValues(TriggerSetup setup, uint32_t lutValues[LUTS_FOR_TRIGGERS_FLAGS]);
/**
 * Print an array of LUTs
 *
 * @param lutValues
 * @param number
 */
void printLuts(uint32_t lutValues[], unsigned number);

}  // end namespace Analyser

#endif /* SOURCES_ENCODELUTS_H_ */
