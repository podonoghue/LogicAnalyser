/*
 ============================================================================
 Name        : TestFT2232H.c
 Author      : 
 Version     :
 Copyright   : Your copyright notice
 Description : Hello World in C, Ansi-style
 ============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <windows.h>
#include <stdio.h>

BOOL testComport()
{
  HANDLE hComm;

  hComm = CreateFile("\\\\.\\COM30",                //port name
                      GENERIC_READ | GENERIC_WRITE, //Read/Write
                      0,                            // No Sharing
                      NULL,                         // No Security
                      OPEN_EXISTING,// Open existing port only
                      0,            // Non Overlapped I/O
                      NULL);        // Null for Comm Devices

  if (hComm == INVALID_HANDLE_VALUE) {
      fprintf(stderr, "Error in opening serial port");
      return FALSE;
  }
  else {
      fprintf(stderr, "Opened serial port successfully");
  }

  DCB dcbSerialParams = { 0 }; // Initializing DCB structure
  dcbSerialParams.DCBlength = sizeof(dcbSerialParams);

  BOOL Status = GetCommState(hComm, &dcbSerialParams);
  if (!Status) {
     fprintf(stderr, "Failed GetCommState()\n");
     return FALSE;
  }
  //and set the values for Baud rate, Byte size, Number of start/Stop bits etc.

  dcbSerialParams.BaudRate = CBR_115200;  // Setting BaudRate = 115200
  dcbSerialParams.ByteSize = 8;           // Setting ByteSize = 8
  dcbSerialParams.StopBits = ONESTOPBIT;  // Setting StopBits = 1
  dcbSerialParams.Parity   = NOPARITY;    // Setting Parity = None

  Status = SetCommState(hComm, &dcbSerialParams);
  if (!Status) {
     fprintf(stderr, "Failed SetCommState()\n");
     return FALSE;
  }

  COMMTIMEOUTS timeouts = { 0 };
  timeouts.ReadIntervalTimeout         = 50; // in milliseconds
  timeouts.ReadTotalTimeoutConstant    = 50; // in milliseconds
  timeouts.ReadTotalTimeoutMultiplier  = 10; // in milliseconds
  timeouts.WriteTotalTimeoutConstant   = 50; // in milliseconds
  timeouts.WriteTotalTimeoutMultiplier = 10; // in milliseconds
  Status = SetCommTimeouts(hComm, &timeouts);
  if (!Status) {
     fprintf(stderr, "Failed SetCommTimeouts()\n");
     return FALSE;
  }

  for(;;) {
     char lpBuffer[] = "Hello World";
     DWORD dNoOfBytesWritten = 0;     // No of bytes written to the port

     Status = WriteFile(hComm,               // Handle to the Serial port
                        lpBuffer,            // Data to be written to the port
                        sizeof(lpBuffer),    // No of bytes to write
                        &dNoOfBytesWritten,  // Bytes written
                        NULL);
     if (!Status) {
        fprintf(stderr, "Failed WriteFile()\n");
        return FALSE;
     }
  }
  CloseHandle(hComm);//Closing the Serial Port

  return 0;
}

int main(void) {

   testComport();
	return EXIT_SUCCESS;
}
