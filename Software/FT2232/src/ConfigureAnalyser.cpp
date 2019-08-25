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
#include <algorithm>
#include "console.h"
#include "MyException.h"

#include "Lfsr16.h"

#include "EncodeLuts.h"
#include "FT2232.h"

using namespace Analyser;

TriggerStep trigger0x7FFFor0x7FFE[MAX_TRIGGER_STEPS] = {
      //   Pattern 0              Pattern 1            Polarity 0            Polarity 1         Operation        Contiguous  Count
      {   "0111111111111111",    "0111111111111110",   Polarity::Normal,   Polarity::Normal,    Operation::Or,   false,        1},
};

TriggerStep triggersImmediate[MAX_TRIGGER_STEPS] = {
      //   Pattern 0              Pattern 1            Polarity 0            Polarity 1         Operation        Contiguous  Count
      {   "XXXXXXXXXXXXXXXX",    "XXXXXXXXXXXXXXX",    Polarity::Normal,   Polarity::Normal,    Operation::Or,  false,        0},
};

TriggerStep triggersdontcare[MAX_TRIGGER_STEPS] = {
      //   Pattern 0              Pattern 1            Polarity 0            Polarity 1         Operation        Contiguous  Count
      {   "XXXXXXXXXXXXXXX",     "XXXXXXXXXXXXXXX",    Polarity::Normal,   Polarity::Normal,    Operation::And,  false,        1},
      {   "XXXXXXXXXXXXXXX",     "XXXXXXXXXXXXXXX",    Polarity::Normal,   Polarity::Normal,    Operation::And,  false,        2},
      {   "XXXXXXXXXXXXXXX",     "XXXXXXXXXXXXXXX",    Polarity::Normal,   Polarity::Normal,    Operation::And,  false,        3},
      {   "XXXXXXXXXXXXXXX",     "XXXXXXXXXXXXXXX",    Polarity::Normal,   Polarity::Normal,    Operation::And,  false,        4},
};

TriggerStep triggers1[MAX_TRIGGER_STEPS] = {
      //   Pattern 0              Pattern 1            Polarity 0            Polarity 1         Operation        Contiguous  Count
      {   "XXXXXXXXXXXXXXX",     "XXXXXXXXXXXXXXX",    Polarity::Normal,   Polarity::Disabled,  Operation::And,  false,        4},
      {   "XXXXXXXXXXXXXX0",     "XXXXXXXXXXXXXX0",    Polarity::Normal,   Polarity::Disabled,  Operation::And,  false,        3},
      {   "XXXXXXXXXXXXXX1",     "XXXXXXXXXXXXXX1",    Polarity::Normal,   Polarity::Disabled,  Operation::And,  false,        2},
      {   "XXXXXXXXXXXXXXC",     "XXXXXXXXXXXXXXC",    Polarity::Normal,   Polarity::Disabled,  Operation::And,  false,        7},
};

TriggerStep triggers2[MAX_TRIGGER_STEPS] = {
      //   Pattern 0              Pattern 1            Polarity 0            Polarity 1         Operation        Contiguous  Count
      {   "XXXXXXXXXXXXXXX",     "XXXXXXXXXXXXXXX",    Polarity::Disabled,   Polarity::Normal,  Operation::And,  false,      100},
      {   "XXXXXXXXXXXXXX0",     "XXXXXXXXXXXXXX1",    Polarity::Disabled,   Polarity::Normal,  Operation::And,  false,      100},
      {   "XXXXXXXXXXXXXX1",     "XXXXXXXXXXXXXX0",    Polarity::Disabled,   Polarity::Normal,  Operation::And,  false,      100},
      {   "XXXXXXXXXXXXXXC",     "XXXXXXXXXXXXXXF",    Polarity::Disabled,   Polarity::Normal,  Operation::And,  false,      100},
};

TriggerStep triggers3[MAX_TRIGGER_STEPS] = {
      //   Pattern 0              Pattern 1            Polarity 0            Polarity 1         Operation        Contiguous  Count
      {   "XXXXXXXXXXXXXXX",     "XXXXXXXXXXXXXXX",    Polarity::Normal,     Polarity::Normal,  Operation::And,  false,      100},
      {   "XXXXXXXXXXXXXX0",     "XXXXXXXXXXXXX1X",    Polarity::Normal,     Polarity::Normal,  Operation::And,  false,      100},
      {   "XXXXXXXXXXXXXX1",     "XXXXXXXXXXXXX0X",    Polarity::Normal,     Polarity::Normal,  Operation::And,  false,      100},
      {   "XXXXXXXXXXXXXXC",     "XXXXXXXXXXXXXFX",    Polarity::Normal,     Polarity::Normal,  Operation::And,  false,      100},
};

TriggerStep triggers4[MAX_TRIGGER_STEPS] = {
      //   Pattern 0              Pattern 1            Polarity 0            Polarity 1         Operation        Contiguous  Count
      {   "XXXXXXXXXXXXXXX",     "XXXXXXXXXXXXXXX",    Polarity::Normal,     Polarity::Normal,  Operation::Or,   false,      100},
      {   "XXXXXXXXXXXXXX0",     "XXXXXXXXXXXXX1X",    Polarity::Normal,     Polarity::Normal,  Operation::Or,   false,      100},
      {   "XXXXXXXXXXXXXX1",     "XXXXXXXXXXXXX0X",    Polarity::Normal,     Polarity::Normal,  Operation::Or,   false,      100},
      {   "XXXXXXXXXXXXXXC",     "XXXXXXXXXXXXXFX",    Polarity::Normal,     Polarity::Normal,  Operation::Or,   false,      100},
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

      console.writeln();
      console.write("   constant SIM_SAMPLE_WIDTH           : natural := ").write(SAMPLE_WIDTH).writeln(";");
      console.write("   constant SIM_MAX_TRIGGER_STEPS      : natural := ").write(MAX_TRIGGER_STEPS).writeln(";");
      console.write("   constant SIM_MAX_TRIGGER_PATTERNS   : natural := ").write(MAX_TRIGGER_PATTERNS).writeln(";");
      console.write("   constant SIM_NUM_TRIGGER_FLAGS      : natural := ").write(NUM_TRIGGER_FLAGS).writeln(";");
      console.write("   constant SIM_NUM_MATCH_COUNTER_BITS : natural := ").write(NUM_MATCH_COUNTER_BITS).writeln(";");

      console.write("   constant SIM_NUM_STIMULUS           : natural := ").write(4*number).writeln(";");

      console.write("   constant SIM_NUM_PATTERN_STIMULUS   : natural := ").write(4*LUTS_FOR_TRIGGER_PATTERNS).writeln(";");
      console.write("   constant SIM_NUM_COMBINER_STIMULUS  : natural := ").write(4*LUTS_FOR_TRIGGER_COMBINERS).writeln(";");
      console.write("   constant SIM_NUM_COUNT_STIMULUS     : natural := ").write(4*LUTS_FOR_TRIGGER_COUNTS).writeln(";");
      console.write("   constant SIM_NUM_FLAG_STIMULUS      : natural := ").write(4*LUTS_FOR_TRIGGERS_FLAGS).writeln(";");

      console.writeln();
      console.write("   type StimulusArray is array (0 to ").write(4*number-1).writeln(") of DataBusType;");
      console.writeln("   variable stimulus : StimulusArray := (");
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

   static void printLutsForSimulation(TriggerSetup &setup) {
      uint32_t lutValues[LUTS_FOR_TRIGGER_PATTERNS] = {0};

      uint32_t *lutValuePtr;

      setup.printTriggers();

      printLutsAsVhdlArrayPreamble(TOTAL_TRIGGER_LUTS);
      lutValuePtr = lutValues;
      setup.getTriggerPatternMatcherLutValues(lutValuePtr);
      printLutsAsVhdlArray(lutValues, LUTS_FOR_TRIGGER_PATTERNS, "PatternMatcher LUT values", false);
      lutValuePtr = lutValues;
      setup.getTriggerCombinerLutValues(lutValuePtr);
      printLutsAsVhdlArray(lutValues, LUTS_FOR_TRIGGER_COMBINERS, "Combiner LUT values", false);
      lutValuePtr = lutValues;
      setup.getTriggerCountLutValues(lutValuePtr);
      printLutsAsVhdlArray(lutValues, LUTS_FOR_TRIGGER_COUNTS, "Count LUT values", false);
      lutValuePtr = lutValues;
      setup.getTriggerFlagLutValues(lutValuePtr);
      printLutsAsVhdlArray(lutValues, LUTS_FOR_TRIGGERS_FLAGS, "Flag LUT values", true);
      printLutsAsVhdlArrayPostamble();
      USBDM::console.flushOutput();
   }
};

void writeLuts(FT2232 &ft2232, TriggerSetup &setup, bool verbose = false) {
   static constexpr unsigned MAX_VALUES = 30000;

   uint32_t  lutValues[TOTAL_TRIGGER_LUTS] = {0};
   uint32_t *lutValuePtr = lutValues;

   if (verbose) {
      PrintLuts::printLutsForSimulation(setup);
   }
   setup.getTriggerPatternMatcherLutValues(lutValuePtr);
   setup.getTriggerCombinerLutValues(lutValuePtr);
   setup.getTriggerCountLutValues(lutValuePtr);
   setup.getTriggerFlagLutValues(lutValuePtr);

   if (verbose) {
      setup.printTriggers();
      printLuts("Pattern Matchers",    lutValues+START_TRIGGER_PATTERN_LUTS, LUTS_FOR_TRIGGER_PATTERNS);
      printLuts("Trigger Combiners",   lutValues+START_TRIGGER_COMBINER_LUTS, LUTS_FOR_TRIGGER_COMBINERS);
      printLuts("Trigger Counts",      lutValues+START_TRIGGER_COUNT_LUTS, LUTS_FOR_TRIGGER_COUNTS);
      printLuts("Trigger Flags",       lutValues+START_TRIGGER_FLAG_LUTS, LUTS_FOR_TRIGGERS_FLAGS);
   }

   uint8_t *convertedData = setup.formatData(TOTAL_TRIGGER_LUTS, lutValues);

   unsigned bytesRemaining = 4*TOTAL_TRIGGER_LUTS;
   while(bytesRemaining > 0) {
      unsigned blockSize = bytesRemaining;
      if (blockSize>MAX_VALUES) {
         blockSize = MAX_VALUES;
      }
      uint8_t loadLutsCommand[] = {
            C_LUT_CONFIG,
            (uint8_t)blockSize,
            (uint8_t)(blockSize>>8),
      };
      ft2232.transmitData(loadLutsCommand, sizeof(loadLutsCommand));
      ft2232.transmitData(convertedData, blockSize);
      bytesRemaining -= blockSize;
      convertedData  += blockSize;
   }
}

void writePreTrigger(FT2232 &ft2232, uint32_t pretrigValue, bool verbose = false) {
   using namespace USBDM;

   if (verbose) {
      USBDM::console.write("PreTrigger(").write(pretrigValue).writeln(")");
   }
   const uint8_t command[] = {
         C_WR_PRETRIG,
         (uint8_t)(pretrigValue),
         (uint8_t)(pretrigValue>>8),
         (uint8_t)(pretrigValue>>16),
   };
   ft2232.transmitData(command, sizeof(command));
   console.setWidth(2).setPadding(Padding_LeadingZeroes).
         write("transmitData(C_WR_PRETRIG,").write(command[1],Radix_16).write(",").write(command[2],Radix_16).write(",").write(command[3],Radix_16).writeln(")").resetFormat();
}

void writeCaptureLength(FT2232 &ft2232, uint32_t captureLength, bool verbose = false) {
   using namespace USBDM;

   if (verbose) {
      USBDM::console.write("CaptureLength(").write(captureLength).writeln(")");
   }
   static const uint8_t command[] = {
         C_WR_CAPTURE,
         (uint8_t)(captureLength),
         (uint8_t)(captureLength>>8),
         (uint8_t)(captureLength>>16),
   };
   ft2232.transmitData(command, sizeof(command));
   console.setWidth(2).setPadding(Padding_LeadingZeroes).
         write("transmitData(C_WR_CAPTURE,").write(command[1],Radix_16).write(",").write(command[2],Radix_16).write(",").write(command[3],Radix_16).writeln(")").resetFormat();
}

const char *getControlNames(uint8_t controlValue) {
   using namespace USBDM;

   static USBDM::StringFormatter_T<100> sf;
   sf.clear();
   sf.write((controlValue & C_CONTROL_START_ACQ)?"C_CONTROL_START_ACQ|":"");
   sf.write((controlValue & C_CONTROL_CLEAR)?"C_CONTROL_CLEAR|":"");

   static const unsigned divs[]   = {1,2,5,10};
   static const unsigned div_xs[] = {1,10,10,1000};

   unsigned divisor =
         divs[((controlValue&C_CONTROL_DIV_MASK)>>C_CONTROL_DIV_OFFSET)] *
         div_xs[((controlValue&C_CONTROL_DIVx_MASK)>>C_CONTROL_DIVx_OFFSET)];

   sf.write("x").write(divisor);

   return sf.toString();
}

const char *getStatuslNames(uint8_t statusValue) {
   using namespace USBDM;

   static StringFormatter_T<100> sf;
   sf.clear();

   static const char *stateNames[]  = {
         "C_STATUS_STATE_IDLE   ",
         "C_STATUS_STATE_PRETRIG",
         "C_STATUS_STATE_ARMED  ",
         "C_STATUS_STATE_RUN    ",
         "C_STATUS_STATE_DONE   ",
         "C_STATUS_STATE_ILLEGAL",
         "C_STATUS_STATE_ILLEGAL",
         "C_STATUS_STATE_ILLEGAL",
   };
   sf.write(stateNames[(statusValue&C_STATUS_STATE_MASK)>>C_STATUS_STATE_OFFSET]);
   return sf.toString();
}

void writeControl(FT2232 &ft2232, uint8_t controlValue, bool verbose = false) {
   using namespace USBDM;

   const uint8_t readCommand[] = {
         C_WR_CONTROL,
         controlValue,
   };
   if (verbose) {
      console.write("transmitData(C_WR_CONTROL,").write(controlValue, Radix_16).writeln(")");
      console.write("Control(").write(getControlNames(controlValue)).write(", ").write(controlValue, Radix_16).writeln(")");
   }
   ft2232.transmitData(readCommand, sizeof(readCommand));
}

uint8_t readStatus(FT2232 &ft2232, bool verbose = false) {
   using namespace USBDM;

   if (verbose) {
      USBDM::console.writeln("transmitData(C_RD_STATUS,1)");
   }
   const uint8_t readCommand[] = {
         C_RD_STATUS, 1,
   };
   ft2232.transmitData(readCommand, sizeof(readCommand));
   uint8_t data[] = {0};
   ft2232.receiveData(data, sizeof(data));
   if (verbose) {
      console.write("receiveData(").write(data[0], Radix_16).writeln(")");
      console.write("readStatus() => ").write(getStatuslNames(data[0])).write(", ").writeln(data[0], Radix_16);
   }
   return data[0];
}

uint8_t readVersion(FT2232 &ft2232, bool verbose = false) {
   using namespace USBDM;

   if (verbose) {
      USBDM::console.writeln("transmitData(C_RD_VERSION,1)");
   }
   uint8_t readCommand[] = {
         C_RD_VERSION, 1,
   };
   ft2232.transmitData(readCommand, sizeof(readCommand));
   uint8_t data[] = {0};
   ft2232.receiveData(data, sizeof(data));
   if (verbose) {
      console.write("receiveData(").write(data[0], Radix_16).writeln(")");
      console.write("readVersion() => ").writeln(data[0], Radix_16);
   }
   return data[0];
}

void readCaptureData(FT2232 &ft2232, uint16_t *data, const unsigned size, bool verbose = false) {
   using namespace USBDM;

   static constexpr unsigned MAX_VALUES = 60000;
   if (verbose) {
      USBDM::console.writeln("readCaptureData() => ");
   }
   unsigned sizeInBytes = 2 * size;
   while (sizeInBytes > 0) {
      // Size for this transfer in items (2 bytes)
      unsigned blockSize = sizeInBytes;
      if (blockSize > MAX_VALUES) {
         blockSize = MAX_VALUES;
      }
      console.write("transmitData(C_RD_BUFFER,(").
            write(blockSize).write("),").
            write((uint8_t)blockSize, Radix_16).write(",").write((uint8_t)((blockSize)>>8), Radix_16).writeln(")");

      uint8_t readCommand[] = {
            C_RD_BUFFER,
            (uint8_t)(blockSize),
            (uint8_t)((blockSize)>>8),
      };
      ft2232.transmitData(readCommand, sizeof(readCommand));
      uint8_t buff[MAX_VALUES];
      ft2232.receiveData(buff, blockSize);
      for (unsigned index=0; index<blockSize/2; index++) {
         *data++ = buff[2*index] + (buff[(2*index)+1]<<16);
      }
      sizeInBytes -= blockSize;
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

/**
 *
 * @param ft2232
 * @param setup
 * @param size
 * @param pretrigSize
 * @param buffer
 */
void doCapture(
      FT2232         &ft2232,
      TriggerSetup   &setup,
      uint16_t        buffer[],
      bool            verbose = false) {

   writeLuts(ft2232, setup, false);

   writeCaptureLength(ft2232, setup.getSampleSize(), verbose);

   writePreTrigger(ft2232, setup.getPreTrigSize(), verbose);

   writeControl(ft2232, C_CONTROL_CLEAR, verbose);
   writeControl(ft2232, setup.getSampleRate(), verbose);

   // Check idle
   if (readStatus(ft2232, verbose) != C_STATUS_STATE_IDLE) {
      throw MyException("Unexpected analyser state in doCapture");
   }

   writeControl(ft2232, setup.getSampleRate()|C_CONTROL_START_ACQ, verbose);

   uint8_t state;
   do {
      uint8_t status = readStatus(ft2232, verbose);
      state = status & C_STATUS_STATE_MASK;
   } while (state != C_STATUS_STATE_DONE);
   readCaptureData(ft2232, buffer, setup.getSampleSize());
}

int main() {

   constexpr unsigned   PRETRIG_SIZE = 10000;
   constexpr unsigned   CAPTURE_SIZE = 40000;
   constexpr SampleRate sampleRate   = SampleRate_100ns;

//   TriggerSetup setup = {trigger0x7FFFor0x7FFE, 0, sampleRate, CAPTURE_SIZE, PRETRIG_SIZE};
   TriggerSetup setup = {triggersImmediate, 0, sampleRate, CAPTURE_SIZE, PRETRIG_SIZE};
//   TriggerSetup setup = {triggersdontcare, 3, sampleRate, CAPTURE_SIZE, PRETRIG_SIZE};
//   TriggerSetup setup = {triggers1, 3, sampleRate, CAPTURE_SIZE, PRETRIG_SIZE};

   USBDM::console.
      write("Sample interval           = ").
      write(getSamplePeriodIn_nanoseconds(sampleRate)).writeln(" ns");

   USBDM::console.
      write("Expected capture interval = ").
      write((setup.getSampleSize()*getSamplePeriodIn_nanoseconds(sampleRate))/1000).writeln(" us");

   try {
      FT2232 ft2232;
      try {
         uint8_t version = readVersion(ft2232, true);
         USBDM::console.write("Version = ").writeln(version);
      } catch (MyException &) {
         USBDM::console.writeln("Unable to read version");
      }

      int ch;
      do {
         uint16_t buffer[CAPTURE_SIZE];
         doCapture(ft2232, setup, buffer, true);

         puts("Again?");
         ch = getchar();
      } while (ch != 'n');

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
