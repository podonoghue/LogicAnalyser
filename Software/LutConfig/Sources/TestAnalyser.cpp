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
#include "hardware.h"
#include "spi.h"

#include "EncodeLuts.h"

using namespace Analyser;

// LED connection - change as required
using Led   = USBDM::GpioA<2,USBDM::ActiveLow>;

USBDM::Spi0 spi{};

void initHardware() {
   Led::setOutput(USBDM::PinDriveStrength_High, USBDM::PinDriveMode_PushPull, USBDM::PinSlewRate_Slow);

   spi.configureAllPins();

   // Configure SPI parameters for odd transmissions
   spi.setSpeed(100*USBDM::kHz);
   spi.setMode(USBDM::SpiMode_0, USBDM::SpiOrder_MsbFirst);
   spi.setPeripheralSelect(USBDM::SpiPeripheralSelect_0, USBDM::ActiveLow, USBDM::SpiSelectMode_Idle);
   spi.setFrameSize(8);
}

uint8_t *formatData(unsigned size, uint32_t *data) {
   for(unsigned index=0; index<size; index++) {
      data[index] = __builtin_bswap32(data[index]);
   }
   return reinterpret_cast<uint8_t *>(data);
}

static constexpr unsigned CONFIGURATION_SIZE = 4;

struct ConfigType {
   uint8_t sampleWidth;
   uint8_t maxTriggerSteps;
   uint8_t maxTriggerConditions;
   uint8_t matchCounterBits;
};

static constexpr uint8_t KEY[] = {0xA5,0x5E,0x12,0x34};

/**
 * Get configuration from hardware
 * Only available after a reset
 *
 * @param[out] config
 */
void getConfig(ConfigType &config) {

   Led::high();
   USBDM::waitUS(20);
   Led::low();
   USBDM::waitUS(200);

   uint8_t configuration[4*CONFIGURATION_SIZE];

   spi.startTransaction();
   spi.txRx(4*CONFIGURATION_SIZE, (const uint8_t *)nullptr, (uint8_t *)configuration);
   spi.endTransaction();

   if (memcmp(configuration,KEY,4) == 0) {
      unsigned index = 4;
      config.sampleWidth            = configuration[index++];
      config.maxTriggerSteps        = configuration[index++];
      config.maxTriggerConditions   = configuration[index++];
      config.matchCounterBits       = configuration[index++];

      USBDM::console.write("config.sampleWidth          = ").writeln(config.sampleWidth);
      USBDM::console.write("config.maxTriggerSteps      = ").writeln(config.maxTriggerSteps);
      USBDM::console.write("config.maxTriggerConditions = ").writeln(config.maxTriggerConditions);
      USBDM::console.write("config.matchCounterBits     = ").writeln(config.matchCounterBits);
   }
   else {
      USBDM::console.write("Failed to get configuration\n");
   }
}

/**
 *
 * @param[in]     numLuts
 * @param[inout]  luts
 */
void txRxLuts(unsigned numLuts, uint32_t luts[]) {
   Led::high();
   USBDM::waitUS(20);
   Led::low();
   USBDM::waitUS(200);

   // Data
   if (numLuts>0) {
      formatData(numLuts, luts);

      spi.startTransaction();
      spi.txRx(4*numLuts, (const uint8_t *)luts, (uint8_t *)luts);
      spi.endTransaction();
   }
}

void sendTriggerLuts(
      const char *trigger0,
      const char *trigger1 ) {

   uint32_t lutValues[LUTS_PER_TRIGGER_STEP_FOR_PATTERNS];
   TriggerStep trigger = {
         trigger0,
         trigger1,
         Polarity::Normal,
         Polarity::Normal,
         Operation::And,
         false,
         100,
   };
   USBDM::console.write("Sending T0='").write(trigger0);
   USBDM::console.write("', T1='").write(trigger1);
   USBDM::console.writeln("'");
   getTriggerStepPatternMatcherLutValues(trigger, lutValues);
   USBDM::console.write("tx: ");
   printLuts(lutValues, LUTS_PER_TRIGGER_STEP_FOR_PATTERNS);
   txRxLuts(sizeof(lutValues)/sizeof(lutValues[0]), lutValues);
   //   console.write("rx: ");
   //   printLuts(lutValues, LUTS_PER_TRIGGER_STEP_FOR_PATTERNS);
   USBDM::console.readChar();
}

void testConfig() {
   for (;;) {
      ConfigType config;
      getConfig(config);
      USBDM::waitUS(100);
   }
}

void testIndividualTriggerPattern() {
   initHardware();
   for (;;) {

      //      sendTriggerLuts("XX", "XX"); // T0 action on B.0
      //      sendTriggerLuts("X0", "XX");
      //      sendTriggerLuts("X1", "XX");
      //      sendTriggerLuts("XR", "XX");
      //      sendTriggerLuts("XF", "XX");
      //      sendTriggerLuts("XC", "XX");
      //      sendTriggerLuts("XX", "XX"); // T1 action on B.0
      //      sendTriggerLuts("XX", "X0");
      //      sendTriggerLuts("XX", "X1");
      //      sendTriggerLuts("XX", "XR");
      //      sendTriggerLuts("XX", "XF");
      //      sendTriggerLuts("XX", "XC");
      //      sendTriggerLuts("XX", "XX"); // T1 action on B.1
      //      sendTriggerLuts("XX", "0X");
      //      sendTriggerLuts("XX", "1X");
      //      sendTriggerLuts("XX", "RX");
      //      sendTriggerLuts("XX", "FX");
      //      sendTriggerLuts("XX", "CX");
      //      sendTriggerLuts("XX", "XX"); // T0 action on B.1
      //      sendTriggerLuts("0X", "XX");
      //      sendTriggerLuts("1X", "XX");
      //      sendTriggerLuts("RX", "XX");
      //      sendTriggerLuts("FX", "XX");
      //      sendTriggerLuts("CX", "XX");
      sendTriggerLuts("XXXX", "XXXX"); // T0 action on B.0
      sendTriggerLuts("XXX0", "XXXX");
      sendTriggerLuts("XXX1", "XXXX");
      sendTriggerLuts("XXXR", "XXXX");
      sendTriggerLuts("XXXF", "XXXX");
      sendTriggerLuts("XXXC", "XXXX");


      //      static const uint16_t txData_16bit[] = { 0x43A1,0x42B2,0x51C3,0x50D4,0x60E5,0x6FF0, }; // 12 bytes
      //      uint16_t rxData_16bit[sizeof(txData_16bit)/sizeof(txData_16bit[0])] = {0};
   }
}


TriggerStep triggers1[MAX_TRIGGER_STEPS] = {
      // Pattern 0 Pattern 1      Polarity 0          Polarity 1          Count
      {   "XX",     "XX",    Polarity::Normal,   Polarity::Disabled,  Operation::And, false, 5},
      {   "X0",     "X0",    Polarity::Normal,   Polarity::Disabled,  Operation::And, false, 10},
      {   "X1",     "X1",    Polarity::Normal,   Polarity::Disabled,  Operation::And, false, 15},
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

void printTriggers(TriggerSetup triggers) {
   for (unsigned step=0; step<MAX_TRIGGER_STEPS; step++) {
      USBDM::console.writeln(triggers.triggers[step].toString());
   }
}

int main() {

   uint32_t lutValues[TOTAL_TRIGGER_LUTS] = {0};

   initHardware();

   TriggerSetup setup = {triggers1, 4};

   printTriggers(setup);

   USBDM::console.write("Trigger Counts");
   getTriggerCountLutValues(setup, lutValues);
   printLuts(lutValues, LUTS_FOR_TRIGGER_COUNTS);

   for(;;) {
      getTriggerPatternMatcherLutValues(setup,  lutValues+START_TRIGGER_PATTERN_LUTS);
      getTriggerCombinerLutValues(setup, lutValues+START_TRIGGER_COMBINER_LUTS);
      getTriggerCountLutValues(setup, lutValues+START_TRIGGER_COUNT_LUTS);
      getTriggerFlagLutValues(setup, lutValues+START_TRIGGER_FLAG_LUTS);
      txRxLuts(TOTAL_TRIGGER_LUTS, lutValues);
      USBDM::console.write("Again?");
      USBDM::console.readChar();
   }
//   uint32_t lutValues[LUTS_FOR_TRIGGER_PATTERNS+LUTS_FOR_TRIGGER_COMBINERS];
//
//   initHardware();
//
//   USBDM::console.writeln();
//   TriggerStep *triggers = triggers4;
//   printTriggers(triggers);
//   for (;;) {
//      getTriggerPatternMatcherLutValues(triggers,  lutValues+START_TRIGGER_PATTERN_LUTS);
//      getTriggerCombinerLutValues(triggers, lutValues+START_TRIGGER_COMBINER_LUTS);
////      USBDM::console.write("Trigger patterns");
////      printLuts(lutValues+START_TRIGGER_PATTERN_LUTS,  LUTS_FOR_TRIGGER_PATTERNS);
////      USBDM::console.write("Trigger Combiners");
////      printLuts(lutValues+START_TRIGGER_COMBINER_LUTS, LUTS_FOR_TRIGGER_COMBINERS);
////      USBDM::console.writeln("");
//      txRxLuts(LUTS_FOR_TRIGGER_PATTERNS+LUTS_FOR_TRIGGER_COMBINERS, lutValues);
//   }
//
//   USBDM::console.writeln(" T1 =>           1100");
//   USBDM::console.writeln(" T0 =>           1010");
//   USBDM::console.setWidth(8).setPadding(USBDM::Padding_LeadingZeroes);
//   USBDM::console.write("!T1 && !T0 0b").writeln(encodeCombination(polarityII, Analyser::And), USBDM::Radix_2);
//   USBDM::console.write("!T1 &&  T0 0b").writeln(encodeCombination(polarityIN, Analyser::And), USBDM::Radix_2);
//   USBDM::console.write(" T1 && !T0 0b").writeln(encodeCombination(polarityNI, Analyser::And), USBDM::Radix_2);
//   USBDM::console.write(" T1 &&  T0 0b").writeln(encodeCombination(polarityNN, Analyser::And), USBDM::Radix_2);
//   USBDM::console.write("!T1 || !T0 0b").writeln(encodeCombination(polarityII, Analyser::OR),  USBDM::Radix_2);
//   USBDM::console.write("!T1 ||  T0 0b").writeln(encodeCombination(polarityIN, Analyser::OR),  USBDM::Radix_2);
//   USBDM::console.write(" T1 || !T0 0b").writeln(encodeCombination(polarityNI, Analyser::OR),  USBDM::Radix_2);
//   USBDM::console.write(" T1 ||  T0 0b").writeln(encodeCombination(polarityNN, Analyser::OR),  USBDM::Radix_2);
//   USBDM::console.resetFormat();
   for(;;) {
      __asm__("bkpt");
   }
}
