//============================================================================
// Name        : FT2232.cpp
// Author      : pgo
// This program can be used to read and program the flash associated with
// a FT2232 device.
//============================================================================
#include <stdio.h>
#include <stdint.h>
#include <windows.h>
#include <assert.h>
#include "ftd2xx.h"
#include "printArray.h"

static constexpr unsigned EEPROM_SIZE = 128;

// For reference
//uint16_t HS1_Rev_A = {
//
//   0x0101, 0x0403, 0x6010, 0x0700, 0x2F80, 0x0008, 0x0000, 0x129A,
//   0x34AC, 0x1AE0, 0x0000, 0x0000, 0x0056, 0x0001, 0x92C7, 0x356A,
//   0x0150, 0x3070, 0x744A, 0x6761, 0x7348, 0x0031, 0x0000, 0x0000,
//   0x0000, 0x0000, 0x4400, 0x6769, 0x6C69, 0x6E65, 0x2074, 0x544A,
//   0x4741, 0x482D, 0x3153, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
//   0x0000, 0x0011, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
//   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
//   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
//   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
//   0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0312, 0x0044, 0x0069,
//   0x0067, 0x0069, 0x006C, 0x0065, 0x006E, 0x0074, 0x0334, 0x0044,
//   0x0069, 0x0067, 0x0069, 0x006C, 0x0065, 0x006E, 0x0074, 0x0020,
//   0x0041, 0x0064, 0x0065, 0x0070, 0x0074, 0x0020, 0x0055, 0x0053,
//   0x0042, 0x0020, 0x0044, 0x0065, 0x0076, 0x0069, 0x0063, 0x0065,
//   0x031A, 0x0032, 0x0031, 0x0030, 0x0032, 0x0030, 0x0035, 0x0033,
//   0x0031, 0x0033, 0x0039, 0x0038, 0x0033, 0x0302, 0x0000, 0xFAA2,
//
//};


FT_STATUS openEeprom(int deviceNumber, FT_HANDLE *ftHandle) {
   FT_STATUS ftStatus;

   ftStatus = FT_Open(deviceNumber, ftHandle);

   if (ftStatus == FT_OK) {
      // FT_Open OK, use ftHandle to access device
      fprintf(stderr, "FT_Open OK\n");
   } else {
      // FT_Open failed
      fprintf(stderr, "FT_Open Failed\n");
   }
   return ftStatus;
}

FT_STATUS readEeprom(uint16_t eeprom_image[EEPROM_SIZE], FT_HANDLE ftHandle) {
   FT_STATUS ftStatus;

   for (unsigned index=0; index < EEPROM_SIZE; index++) {
      ftStatus = FT_ReadEE(ftHandle, index, &eeprom_image[index]);
      if (ftStatus != FT_OK) {
         // FT_ReadEE failed
         fprintf(stderr, "FT_ReadEE Failed @0x%X, rc = %ld\n", index, ftStatus);
         return ftStatus;
      }
   }
   return FT_OK;
}

FT_STATUS programEeprom(uint16_t eeprom_image[EEPROM_SIZE], FT_HANDLE ftHandle) {
   FT_STATUS ftStatus;

   for (unsigned index=0; index < EEPROM_SIZE; index++) {
      ftStatus = FT_WriteEE(ftHandle, index, eeprom_image[index]);
      if (ftStatus != FT_OK) {
         // FT_ReadEE failed
         fprintf(stderr, "FT_ReadEE Failed @0x%X, rc = %ld\n", index, ftStatus);
         return ftStatus;
      }
   }
   return FT_OK;
}

bool saveImageToFile(const char *filename, uint16_t eeprom_image[EEPROM_SIZE]) {
   errno = 0;
   auto fp = fopen(filename, "wt");
   if (fp == nullptr) {
      fprintf(stderr, "File open failed for '%s', rc = %s\n", filename, strerror(errno));
      return false;
   }
   for (unsigned index=0; index < EEPROM_SIZE; index++) {
      int items = fprintf(fp, "%04X\n", eeprom_image[index]);
      if (items == 0) {
         fprintf(stderr, "File write failed, rc = %d\n", ferror(fp));
         return false;
      }
   }
   fclose(fp);
   return true;
}

bool loadImageFromFile(const char *filename, uint16_t eeprom_image[EEPROM_SIZE]) {
   errno = 0;
   auto fp = fopen(filename, "rt");
   if (fp == nullptr) {
      fprintf(stderr, "File open failed for '%s', rc = %s\n", filename, strerror(errno));
      return false;
   }
   for (unsigned index=0; index < EEPROM_SIZE; index++) {
      unsigned temp;
      int items = fscanf(fp, "%04X\n", &temp);
      if (items == 0) {
         fprintf(stderr, "File read failed, rc = %d\n", ferror(fp));
         return false;
      }
      eeprom_image[index] = temp;
   }
   fclose(fp);
   return true;
}

FT_STATUS eraseEeprom(FT_HANDLE ftHandle) {
   FT_STATUS ftStatus;
   ftStatus = FT_EraseEE(ftHandle);
   if (ftStatus != FT_OK) {
      // FT_ReadEE failed
      fprintf(stderr, "FT_EraseEE Failed, rc = %ld\n", ftStatus);
   }
   return ftStatus;
}

bool verify(uint16_t reference_image[EEPROM_SIZE], FT_HANDLE ftHandle) {
   printf("Verifying EEPROM contents\n");

   FT_STATUS ftStatus;
   uint16_t readback_image[EEPROM_SIZE];

   ftStatus = readEeprom(readback_image, ftHandle);
   if (ftStatus != FT_OK) {
      printf("Reading EEPROM failed!\n");
      return false;
   }
   printf("Read-back EEPROM contents\n");
   printArray(readback_image, EEPROM_SIZE);
   if (memcmp(reference_image, readback_image, EEPROM_SIZE) != 0) {
      printf("Verifying EEPROM failed!\n");
      return false;
   }
   printf("Verifying EEPROM OK!\n");
   return true;
}

/**
 * Read EEPROM and save to file
 *
 * @param fileName
 * @param ftHandle
 *
 * @return
 */
int readAction(const char *argFileName, FT_HANDLE ftHandle) {
   FT_STATUS ftStatus;
   uint16_t eeprom_image[EEPROM_SIZE];
   char fileName[100];

   printf("Reading EEPROM contents\n");

   strncpy(fileName, argFileName, sizeof(fileName)-10);
   char *period= strchr(fileName, '.');
   if (period == nullptr) {
      strcat(fileName,".txt");
   }

   ftStatus = readEeprom(eeprom_image, ftHandle);
   if (ftStatus != FT_OK) {
      return false;
   }
   printf("Original EEPROM contents\n");
   printArray(eeprom_image, EEPROM_SIZE);

   printf("Saving EEPROM image to '%s'\n", fileName);
   if (!saveImageToFile(fileName, eeprom_image)) {
      return false;
   }
   printf("Saving EEPROM completed\n");
   return true;
}

/**
 * Read EEPROM and compare to file contents
 *
 * @param fileName
 * @param ftHandle
 *
 * @return
 */
int verifyAction(const char *argFileName, FT_HANDLE ftHandle) {
   FT_STATUS ftStatus;
   uint16_t reference_image[EEPROM_SIZE];
   char fileName[100];

   printf("Verifying EEPROM contents\n");

   strncpy(fileName, argFileName, sizeof(fileName)-10);
   char *period= strchr(fileName, '.');
   if (period == nullptr) {
      strcat(fileName,".txt");
   }
   if (!loadImageFromFile(fileName, reference_image)) {
      return false;
   }
   printf("EEPROM image to verify\n");
   printArray(reference_image, EEPROM_SIZE);

   ftStatus = verify(reference_image, ftHandle);
   if (ftStatus != FT_OK) {
      return false;
   }
   printf("Verifying EEPROM completed\n");
   return true;
}

bool programAction(const char *argFileName, FT_HANDLE ftHandle) {
   FT_STATUS ftStatus;
   char fileName[100];

   printf("Programming EEPROM contents\n");

   strncpy(fileName, argFileName, sizeof(fileName)-10);
   char *period= strchr(fileName, '.');
   if (period == nullptr) {
      strcat(fileName,".txt");
   }
   char oldFileName[100];
   strncpy(oldFileName, argFileName, sizeof(oldFileName)-10);
   period= strchr(oldFileName, '.');
   if (period != nullptr) {
      *period = '\0';
   }
   strcat(oldFileName,"_old.txt");

   uint16_t old_image[EEPROM_SIZE];
   uint16_t new_image[EEPROM_SIZE];

   if (!loadImageFromFile(fileName, old_image)) {
      return false;
   }
   printf("EEPROM image being overwritten\n");
   printArray(old_image, EEPROM_SIZE);

   printf("Saving old EEPROM image to '%s'\n", oldFileName);
   if (!saveImageToFile(oldFileName, old_image)) {
      return false;
   }

   if (!loadImageFromFile(fileName, new_image)) {
      return false;
   }
   printf("EEPROM image to program\n");
   printArray(new_image, EEPROM_SIZE);

   printf("Erasing EEPROM\n");
   ftStatus = eraseEeprom(ftHandle);
   if (ftStatus != FT_OK) {
      return false;
   }
   printf("Programming EEPROM from '%s'\n", fileName);
   ftStatus = programEeprom(new_image, ftHandle);
   if (ftStatus != FT_OK) {
      return false;
   }
   if (!verify(new_image, ftHandle)) {
      return false;
   }
   printf("Verifying EEPROM completed\n");
   return true;
}

int main(int argc, const char *argv[]) {

   const char *programName = nullptr;

   typedef enum {a_verify, a_program, a_read } ProgramMode;
   ProgramMode programMode = a_verify;

   const char *argFileName = "eeprom";

   for (unsigned index=0; (int)index<argc; index++) {
      printf("argv[%2d] = \'%s\'\n", index, argv[index]);
   }
   if (argc>0) {
      programName = argv[0];
      const char *key = strstr(programName, "programEeprom");
      if (key != 0) {
         programMode = a_program;
      }
      key = strstr(programName, "readEeprom");
      if (key != 0) {
         programMode = a_read;
      }
      key = strstr(programName, "verifydEeprom");
      if (key != 0) {
         programMode = a_verify;
      }
   }
   for (unsigned index=1; (int)index<argc; index++) {
      printf("argv[%2d] = \'%s\'\n", index, argv[index]);
      if ((*argv[index] == '-') || (*argv[index] == '/')) {
         if ((strcmp(argv[index]+1, "v") == 0)) {
            programMode = a_verify;
         }
         else if (strcmp(argv[index]+1, "p") == 0) {
            programMode = a_program;
         }
         else if (strcmp(argv[index]+1, "r") == 0) {
            programMode = a_read;
         }
      }
      else {
         argFileName = argv[index];
      }
   }

   FT_HANDLE ftHandle;
   FT_STATUS ftStatus;

   ftStatus = openEeprom(0, &ftHandle);
   if (ftStatus != FT_OK) {
      return EXIT_FAILURE;
   }

   unsigned long userAreaSize;

   ftStatus = FT_EE_UASize(ftHandle, &userAreaSize);

   printf("User area = %ld\n", userAreaSize);

   switch(programMode) {
      case a_verify:
         if (!verifyAction(argFileName, ftHandle)) {
            return EXIT_FAILURE;
         }
         break;

      case a_read:
         if (!readAction(argFileName, ftHandle)) {
            return EXIT_FAILURE;
         }
         break;

      case a_program:
         if (!programAction(argFileName, ftHandle)) {
            return EXIT_FAILURE;
         }
         break;

      default:
         break;
   }
   return EXIT_SUCCESS;
}
