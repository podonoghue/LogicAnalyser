/*
 ============================================================================
 * @file    main.cpp (180.ARM_Peripherals/Sources/main.cpp)
 * @brief   Basic C++ demo
 *
 *  Created on: 10/1/2016
 *      Author: podonoghue
 ============================================================================
 */
#include "hardware.h"
#include "spi.h"

// Allow access to USBDM methods without USBDM:: prefix
using namespace USBDM;

/**
 * See more examples in Snippets directory
 */

// LED connection - change as required
using Led   = GpioA<2,ActiveLow>;

void runTests() {
   // Instantiate Uart1
   Uart1 uart;
   uart.configureAllPins();

   Spi0 spi{};
   spi.configureAllPins();

   // Configure SPI parameters for odd transmissions
   spi.setSpeed(200*kHz);
   spi.setMode(SpiMode_0);
   spi.setPeripheralSelect(SpiPeripheralSelect_0, ActiveLow, SpiSelectMode_Continuous);
   spi.setFrameSize(8);

   // Save configuration
   SpiConfig configurationOdd = spi.getConfiguration();

   // Configure SPI parameters for even transmissions
   spi.setSpeed(500*kHz);
   spi.setMode(SpiMode_0);
   spi.setPeripheralSelect(SpiPeripheralSelect_2, ActiveLow, SpiSelectMode_Idle);
   spi.setFrameSize(12);

   // Save configuration
   SpiConfig configurationEven = spi.getConfiguration();

   for (;;) {
      static const uint8_t  txData_8bit[]  = { 0xA1,0xB2,0xC3,0xD4,0xE5, };
      static const uint16_t txData_12bit[] = { 0x3A1,0x2B2,0x1C3,0x0D4,0x0E5, };
      uint8_t  rxData_8bit[sizeof(txData_8bit)/sizeof(txData_8bit[0])] = {0};
      uint16_t rxData_12bit[sizeof(txData_12bit)/sizeof(txData_12bit[0])] = {0};

      Led::high();
      waitUS(20);
      Led::low();
      waitUS(20);

      uart.writeln("Hello world\n");

      spi.startTransaction(configurationOdd);
      spi.txRx(sizeof(txData_8bit)/sizeof(txData_8bit[0]), txData_8bit, rxData_8bit); // 5 bytes
      spi.setPeripheralSelectMode(SpiSelectMode_Idle);
      spi.txRx(sizeof(txData_8bit)/sizeof(txData_8bit[0]), txData_8bit, rxData_8bit); // 5 bytes
      spi.endTransaction();
      waitUS(100);

      spi.startTransaction(configurationEven);
      spi.txRx(sizeof(txData_12bit)/sizeof(txData_12bit[0]), txData_12bit, rxData_12bit); // 5 bytes
      spi.txRx(sizeof(txData_12bit)/sizeof(txData_12bit[0]), txData_12bit, rxData_12bit); // 5 bytes
      spi.endTransaction();
      waitUS(100);
   }
}

int main() {
   console.writeln("Starting\n");
   console.write("SystemCoreClock = ").writeln(SystemCoreClock);
   console.write("SystemBusClock  = ").writeln(SystemBusClock);

   Led::setOutput(PinDriveStrength_High, PinDriveMode_PushPull, PinSlewRate_Slow);

   runTests();

   return 0;
}
