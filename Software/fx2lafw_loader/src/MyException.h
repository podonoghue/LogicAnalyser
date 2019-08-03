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

class MyException : public std::exception {

   std::string reason;

public:
   MyException() {
      reason = "Anonymous";
   }

   MyException(const char *reason) {
      this->reason = reason;
   }

   virtual const char * what () const throw () override {
      return reason.c_str();
    }

   virtual ~MyException() {
   }
};

#endif /* MYEXCEPTION_H_ */
