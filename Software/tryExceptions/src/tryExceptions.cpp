//============================================================================
// Name        : tryExceptions.cpp
// Author      : 
// Version     :
// Copyright   : Your copyright notice
// Description : Hello World in C++, Ansi-style
//============================================================================

#include <iostream>
#include "MyException.h"

using namespace std;

void doit(int v) {

   if (v != 0) {
      throw MyException("oPPS");
   }
}

int main() {
   fprintf(stderr, "Starting\n");
   try {
      doit(1);
   }
   catch (std::exception &e) {
      printf("Exception, reason = %s", e.what());
   }
	return 0;
}
