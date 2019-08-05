/*
 * MyException.h
 *
 *  Created on: 3 Aug 2019
 *      Author: podonoghue
 */

#ifndef MYEXCEPTION_H_
#define MYEXCEPTION_H_

#include <string>
#include <exception>
#include <stdio.h>
#include <stdarg.h>

class MyException : public std::exception {

   std::string reason;

public:
   MyException() {
      reason = "Anonymous";
   }

   MyException(const char *format, ...) {
      char buff[100];
      va_list args;
      va_start(args, format);
      vsnprintf(buff, sizeof(buff), format, args);
      this->reason = buff;
   }

   virtual const char * what () const throw () override {
      return reason.c_str();
    }

   virtual ~MyException() {
   }
};

#endif /* MYEXCEPTION_H_ */
