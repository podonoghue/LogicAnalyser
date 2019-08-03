/*
 * HexImage.h
 *
 *  Created on: 3 Aug 2019
 *      Author: podonoghue
 */

#ifndef HEXIMAGE_H_
#define HEXIMAGE_H_

#include <stdint.h>
#include <stdio.h>
#include <ctype.h>
#include <stdexcept>

#include "MyException.h"
#include "printArray.h"

class HexImage {

   // Maximum bytes in a created HEX record
   static constexpr unsigned MAX_BYTES_PER_LINE = 16;

   typedef enum  {
      RecordType_Data = 0x00,
      RecordType_EOF  = 0x01,
   } RecordType;

   uint8_t *image;

   int getHex(char *&p) {
      if ((*p >= '0') && (*p<='9')) {
         return *p++-'0';
      }
      else if ((*p >= 'a') && (*p<='f')) {
         return *p++-'a' + 10;
      }
      else if ((*p >= 'A') && (*p<='F')) {
         return *p++-'A' + 10;
      }
      else {
         throw MyException("Illegal hex character");
      }
   }

   int get2Hex(char *&p) {
      int value1 = getHex(p);
      int value2 = getHex(p);
      return value1*0x10 + value2;
   }

   int get4Hex(char *&p) {
      int value1 = get2Hex(p);
      int value2 = get2Hex(p);
      return value1*0x100 + value2;
   }

   int loadHexRecord(FILE *fp) {
      char buffer[200];

      if (fgets(buffer, sizeof(buffer) , fp) == NULL) {
         if (ferror(fp) != 0) {
            return -1;
         }
         return 0;
      }
      char *p = buffer;
      while (isblank(*p)) {
         p++;
      }
      if (*p == '\0') {
         return 0;
      }
      if (*p != ':') {
         throw MyException("Expected ':' in hex file");
      }
      p++;
      int numBytes = get2Hex(p);
      uint8_t checksum = 0;
      checksum += numBytes>>8;
      checksum += numBytes;
      int address = get4Hex(p);
      checksum += address>>8;
      checksum += address;
      int recordType = get2Hex(p);
      checksum += recordType;
      if (recordType == 0x01) {
         int checksum = get2Hex(p);
         if (checksum != 0xFF) {
            throw MyException("Illegal checksum in hex file");
         }
         return 0;
      }
      if (recordType != 0x00) {
         return -1;
      }
      while(numBytes-->0) {
         int value = get2Hex(p);
         checksum += value;
         if ((unsigned)address >= image_size) {
            throw MyException("Address too large hex file");
         }
         image[address++] = value;
      }
      checksum = (~checksum+1)&0xFF;
      int value = get2Hex(p);
      if (value != checksum) {
         throw MyException("Illegal checksum in hex file");
      }
      return 1;
   }

   unsigned writeHexRecord(FILE *fp, RecordType recordType, unsigned maxNumBytes, unsigned offset, uint8_t *data) {
      uint8_t checksum = 0;

      if (maxNumBytes>MAX_BYTES_PER_LINE) {
         maxNumBytes = MAX_BYTES_PER_LINE;
      }
      checksum += maxNumBytes;
      checksum += (offset>>8)&0xFF;
      checksum += offset&0xFF;
      checksum += recordType;
      fprintf(fp, ":%02X%04X%02X", 16, offset, recordType);
      for (unsigned col=0; col<maxNumBytes;) {
         checksum +=  data[col];
         fprintf(fp, "%02X", data[col++]);
      }
      fprintf(fp, "%02X\n", (~checksum+1)&0xFF);
      return maxNumBytes;
   }

   void writeEol(FILE *fp) {
      writeHexRecord(fp, RecordType_EOF, 0, 0, NULL);
   }

public:
   const  unsigned image_size;

   HexImage(unsigned size) : image((uint8_t *)malloc(size)), image_size(size) {
      if (image == nullptr) {
         throw new std::range_error("Failed to allocate array");
      }
      memset(image, 0, size);
   }

   void print() {
      printArray(image, image_size);
   }

   uint8_t &operator[](unsigned index) {
      if (index >= image_size) {
         throw new std::range_error("Array index out of range");
      }
      return image[index];
   }

   void loadHexFile(const char *filename) {

      FILE *fp = fopen(filename,"rt");
      if (fp == 0) {
         throw new std::exception();
      }
      int recordOK;
      do {
         recordOK = loadHexRecord(fp);
      } while (recordOK > 0);
   }

   void saveHexFile(const char *filename) {

      FILE *fp = fopen(filename, "wt");
      if (fp == nullptr) {
         throw MyException("Unable to open file for saving");
      }

      uint16_t address        = 0x0000;
      unsigned remainingBytes = image_size;

      while (remainingBytes > 0) {
         unsigned bytesWritten = writeHexRecord(fp, RecordType_Data, remainingBytes, address, image+address);
         remainingBytes -= bytesWritten;
         address        += bytesWritten;
      }
      writeEol(fp);
   }

   int compare(HexImage &other) {
      if (image_size != other.image_size) {
         throw new std::range_error("Images are not the same size");
      }
      return memcmp(image, other.image, image_size);
   }

   uint8_t *toArray() {
      return image;
   }
};

#endif /* HEXIMAGE_H_ */
