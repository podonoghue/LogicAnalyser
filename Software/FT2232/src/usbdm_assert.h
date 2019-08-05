/*
 * usbdm_assert.h
 *
 *  Created on: 4 Aug 2019
 *      Author: podonoghue
 */

#ifndef USBDM_ASSERT_H_
#define USBDM_ASSERT_H_

#include <stdio.h>
#include <stdlib.h>

namespace USBDM {

/**
 * Print simple log message to console
 *
 * @param msg Message to print
 */
inline void log_error(const char *msg) {
   fprintf(stderr, "%s\n", msg);
}

inline void _usbdm_assert(const char *msg) {
   log_error(msg);
   ::_exit(-1);
}

} // End namespace USBDM

#if !defined (NDEBUG)
#define USBDM_STRINGIFY(x)  #x
#define USBDM_TOSTRING(x)   USBDM_STRINGIFY(x)

/**
 * Macro to do ASSERT operation in debug build
 *
 * @param __e Assert expression to evaluate
 * @param __m Message to print if expression is false
 */
#define USBDM_ASSERT(__e, __m) ((__e) ? (void)0 : (void)USBDM::_usbdm_assert("Assertion Failed @" __FILE__ ":" USBDM_TOSTRING(__LINE__) " - " __m))
#define usbdm_assert(__e, __m) USBDM_ASSERT(__e, __m)
#else
/**
 * Macro to do ASSERT operation in debug build
 *
 * @param __e Assert expression to evaluate
 * @param __m Message to print if expression is false
 */
#define USBDM_ASSERT(__e, __m) ((void)0)
#define usbdm_assert(__e, __m) ((void)0)
#endif





#endif /* USBDM_ASSERT_H_ */
