/*
 * console.h
 *
 *  Created on: 4 Aug 2019
 *      Author: podonoghue
 */

#ifndef CONSOLE_H_
#define CONSOLE_H_

#include <stdio.h>

#include "formatted_io.h"

namespace USBDM {

class Console : public FormattedIO {

public:
   void flushOutput() {
      fflush(stdout);
   }

   void flushInput() {
   }

protected:
   void _writeChar(char ch) {
      putc(ch, stdout);
   }

   int _readChar() {
      return getc(stdin);
   }

   bool _isCharAvailable() {
      return true;
   }
};

extern USBDM::Console console;

}    // End namespace USBDM

#endif /* CONSOLE_H_ */
