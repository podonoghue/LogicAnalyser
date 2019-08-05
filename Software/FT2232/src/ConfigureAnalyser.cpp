/*
 ============================================================================
 * @file    TestAnalyser.cpp
 *
 *  Created on: 10/1/2016
 *      Author: podonoghue
 ============================================================================
 */
#include <stdio.h>
#include <string.h>
#include "console.h"
#include "MyException.h"

#include "Lfsr16.h"

#include "EncodeLuts.h"
#include "FT2232.h"

using namespace Analyser;

TriggerStep triggersdontcare[MAX_TRIGGER_STEPS] = {
      // Pattern 0 Pattern 1      Polarity 0          Polarity 1          Count
      {   "XX",     "XX",    Polarity::Normal,   Polarity::Normal,  Operation::And, false, 1},
      {   "XX",     "XX",    Polarity::Normal,   Polarity::Normal,  Operation::And, false, 2},
      {   "XX",     "XX",    Polarity::Normal,   Polarity::Normal,  Operation::And, false, 3},
      {   "XX",     "XX",    Polarity::Normal,   Polarity::Normal,  Operation::And, false, 4},
};

TriggerStep triggers1[MAX_TRIGGER_STEPS] = {
      // Pattern 0 Pattern 1      Polarity 0          Polarity 1          Count
      {   "XX",     "XX",    Polarity::Normal,   Polarity::Disabled,  Operation::And, false, 4},
      {   "X0",     "X0",    Polarity::Normal,   Polarity::Disabled,  Operation::And, false, 3},
      {   "X1",     "X1",    Polarity::Normal,   Polarity::Disabled,  Operation::And, false, 2},
      {   "XC",     "XC",    Polarity::Normal,   Polarity::Disabled,  Operation::And, false, 7},
};

TriggerStep triggers2[MAX_TRIGGER_STEPS] = {
      // Pattern 0 Pattern 1      Polarity 0          Polarity 1          Count
      {   "XX",     "XX",    Polarity::Disabled,   Polarity::Normal,  Operation::And, false, 100},
      {   "X0",     "X1",    Polarity::Disabled,   Polarity::Normal,  Operation::And, false, 100},
      {   "X1",     "X0",    Polarity::Disabled,   Polarity::Normal,  Operation::And, false, 100},
      {   "XC",     "XF",    Polarity::Disabled,   Polarity::Normal,  Operation::And, false, 100},
};

TriggerStep triggers3[MAX_TRIGGER_STEPS] = {
      // Pattern 0 Pattern 1      Polarity 0          Polarity 1          Count
      {   "XX",     "XX",    Polarity::Normal,     Polarity::Normal,  Operation::And, false, 100},
      {   "X0",     "1X",    Polarity::Normal,     Polarity::Normal,  Operation::And, false, 100},
      {   "X1",     "0X",    Polarity::Normal,     Polarity::Normal,  Operation::And, false, 100},
      {   "XC",     "FX",    Polarity::Normal,     Polarity::Normal,  Operation::And, false, 100},
};

TriggerStep triggers4[MAX_TRIGGER_STEPS] = {
      // Pattern 0 Pattern 1      Polarity 0          Polarity 1          Count
      {   "XX",     "XX",    Polarity::Normal,     Polarity::Normal,  Operation::Or, false, 100},
      {   "X0",     "1X",    Polarity::Normal,     Polarity::Normal,  Operation::Or, false, 100},
      {   "X1",     "0X",    Polarity::Normal,     Polarity::Normal,  Operation::Or, false, 100},
      {   "XC",     "FX",    Polarity::Normal,     Polarity::Normal,  Operation::Or, false, 100},
};

class PrintLuts {

   /**
    * Print an array of LUTs
    *
    * @param lutValues
    * @param number
    */
   static void printLutsAsVhdlArrayPreamble(unsigned number) {
      using namespace USBDM;
      constexpr unsigned PREAMBLE = 2;

      console.writeln();
      console.write("   constant SIM_SAMPLE_WIDTH           : natural := ").write(SAMPLE_WIDTH).writeln(";");
      console.write("   constant SIM_MAX_TRIGGER_STEPS      : natural := ").write(MAX_TRIGGER_STEPS).writeln(";");
      console.write("   constant SIM_MAX_TRIGGER_PATTERNS   : natural := ").write(MAX_TRIGGER_PATTERNS).writeln(";");
      console.write("   constant SIM_NUM_TRIGGER_FLAGS      : natural := ").write(NUM_TRIGGER_FLAGS).writeln(";");
      console.write("   constant SIM_NUM_MATCH_COUNTER_BITS : natural := ").write(NUM_MATCH_COUNTER_BITS).writeln(";");

      console.writeln();
      console.write("   type StimulusArray is array (0 to ").write((4*number-1)+PREAMBLE).writeln(") of DataBusType;");
      console.writeln("   variable stimulus : StimulusArray := (");
      console.writeln("      -- Preamble ");
      console.write("      C_LUT_CONFIG, ").write("\"").write(number, Radix_2).write("\", -- ").write(4*number).write(" bytes (").write(number).writeln(" LUTs)");
   }

   /**
    * Print an array of LUTs
    *
    * @param lutValues
    * @param number
    */
   static void printLutsAsVhdlArray(uint32_t lutValues[], unsigned number, const char *title, bool end) {
      using namespace USBDM;

      console.write("      -- ").write(title).write(" (").write(number).writeln(" LUTs)");

      console.setPadding(Padding_LeadingZeroes).setWidth(8);
      for(unsigned index=0; index<number; index++) {
         console.write("      ");
         console.write("\"").write((lutValues[index]>>24)&0xFF, Radix_2).write("\", ");
         console.write("\"").write((lutValues[index]>>16)&0xFF, Radix_2).write("\", ");
         console.write("\"").write((lutValues[index]>>8)&0xFF,  Radix_2).write("\", ");
         console.write("\"").write((lutValues[index]>>0)&0xFF,  Radix_2).write("\"");
         if ((index!=(number-1)) || !end) {
            console.write(",");
         }
         console.writeln();
      }
      console.resetFormat();
   }

   /**
    * Print an array of LUTs
    *
    * @param lutValues
    * @param number
    */
   static void printLutsAsVhdlArrayPostamble() {
      using namespace USBDM;
      console.writeln("   );");
   }

public:

   static void printLutsForSimulation() {
      uint32_t lutValues[TOTAL_TRIGGER_LUTS] = {0};

      TriggerSetup setup = {triggers1, 3};

      setup.printTriggers();

      printLutsAsVhdlArrayPreamble(TOTAL_TRIGGER_LUTS);
      setup.getTriggerPatternMatcherLutValues(lutValues);
      printLutsAsVhdlArray(lutValues, LUTS_FOR_TRIGGER_PATTERNS, "PatternMatcher LUT values", false);
      setup.getTriggerCombinerLutValues(lutValues);
      printLutsAsVhdlArray(lutValues, LUTS_FOR_TRIGGER_COMBINERS, "Combiner LUT values", false);
      setup.getTriggerCountLutValues(lutValues);
      printLutsAsVhdlArray(lutValues, LUTS_FOR_TRIGGER_COUNTS, "Count LUT values", false);
      setup.getTriggerFlagLutValues(lutValues);
      printLutsAsVhdlArray(lutValues, LUTS_FOR_TRIGGERS_FLAGS, "Flag LUT values", true);
      printLutsAsVhdlArrayPostamble();
      USBDM::console.flushOutput();
   }
};

void loadLuts() {

   uint32_t lutValues[TOTAL_TRIGGER_LUTS] = {0};

   TriggerSetup setup = {triggers1, 4};

   setup.printTriggers();

//   USBDM::console.write("Trigger Counts LUTs");

   FT2232 ft2232;

   setup.getTriggerPatternMatcherLutValues(lutValues+START_TRIGGER_PATTERN_LUTS);
   setup.getTriggerCombinerLutValues(lutValues+START_TRIGGER_COMBINER_LUTS);
   setup.getTriggerCountLutValues(lutValues+START_TRIGGER_COUNT_LUTS);
   setup.getTriggerFlagLutValues(lutValues+START_TRIGGER_FLAG_LUTS);
   printLuts(lutValues, TOTAL_TRIGGER_LUTS);
   uint8_t *convertedData = setup.formatData(TOTAL_TRIGGER_LUTS, lutValues);

   for(;;) {
      ft2232.transmitData(convertedData, 4*TOTAL_TRIGGER_LUTS);
      puts("Again?");
      getchar();
   }

}

void testLfsr16() {
   USBDM::console.write("Period = ").writeln(Lfsr16::findPeriod());

   USBDM::console.setWidth(4).setPadding(USBDM::Padding_LeadingZeroes);
   USBDM::console.write("Next(").write(0xACE1, USBDM::Radix_16).write(") => ").writeln(Lfsr16::calcNextValue(0xACE1), USBDM::Radix_16);
   for (uint32_t value=0; value<=65525; value++) {
      USBDM::console.write("Encode(").write(value, USBDM::Radix_16).write(") => ").writeln(Lfsr16::encode(value), USBDM::Radix_16);
   }
}

int main() {

   try {
//   PrintLuts::printLutsForSimulation();
   loadLuts();
   }
   catch (std::exception &e) {
      fprintf(stdout, "Error: %s\n", e.what());
      fflush(stderr);
   }
   catch (std::exception *e) {
      fprintf(stdout, "Error: %s\n", e->what());
      fflush(stderr);
   }

   return 0;

}
