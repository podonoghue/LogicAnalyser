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

   // Highest loaded address
   unsigned loaded_image_size = 0;

   // Size of image
   const unsigned max_image_size;

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
         if ((unsigned)address >= max_image_size) {
            throw MyException("Address too large when loading hex file");
         }
         if ((unsigned)address >= loaded_image_size) {
            loaded_image_size = (unsigned)address + 1;
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

   /**
    * Constructor
    *
    * @param max_size    Size of image
    * @param fill        Value to fill array with
    */
   HexImage(unsigned max_size, uint8_t fill=0xFF) : max_image_size(max_size), image((uint8_t *)malloc(max_size)) {
      if (image == nullptr) {
         throw MyException("Failed to allocate array");
      }
      memset(image, fill, max_size);
   }

   /**
    * Get size of image
    *
    * This is set from the highest loaded address
    */
   unsigned getSize() {
      return loaded_image_size;
   }

   /**
    * Get size of image
    *
    * This is set from the highest loaded address
    */
   void setSize(unsigned size) {
      loaded_image_size = size;
   }

   /**
    * Get maximum size of image
    *
    * This is set from the size of the image when created
    */
   unsigned getMaxSize() {
      return max_image_size;
   }

   /**
    * Fill array with sequential pattern
    * (Apart from 1st 16 bytes)
    */
   void fillWithTestPattern() {
      for(unsigned index=0x10; index<getSize(); index++) {
         image[index] = index % 254;
      }
   }

   /**
    * Print image to std out
    */
   void print() {
      printArray(image, getSize());
   }

   uint8_t &operator[](unsigned index) {
      if (index >= getSize()) {
         throw MyException("Array index out of range");
      }
      return image[index];
   }

   /**
    * Load from Intel hex file
    *
    * @param filename   Name of file
    */
   void loadHexFile(const char *filename) {

      loaded_image_size = 0;

      FILE *fp = fopen(filename,"rt");
      if (fp == 0) {
         throw MyException("Failed to open hex file for reading '%s'", filename);
      }
      int recordOK;
      do {
         recordOK = loadHexRecord(fp);
      } while (recordOK > 0);

      fclose(fp);
   }

   /**
    * Save to Intel hex file
    *
    * @param filename   Name of file
    */
   void saveHexFile(const char *filename) {

      FILE *fp = fopen(filename, "wt");
      if (fp == nullptr) {
         throw MyException("Unable to open hex file for saving '%s'", filename);
      }

      uint16_t address        = 0x0000;
      unsigned remainingBytes = getSize();

      while (remainingBytes > 0) {
         unsigned bytesWritten = writeHexRecord(fp, RecordType_Data, remainingBytes, address, image+address);
         remainingBytes -= bytesWritten;
         address        += bytesWritten;
      }
      writeEol(fp);
      fclose(fp);
   }

   /**
    * Load binary image file
    *
    * @param filename   Name of file
    */
   void loadBinaryImageFile(const char *filename) {

      FILE *fp = fopen(filename,"rb");
      if (fp == 0) {
         throw MyException("Failed to open binary image file for reading '%s'", filename);
      }
      loaded_image_size = fread(image, 1, max_image_size, fp);
      fclose(fp);
   }

   /**
    * Save binary image file
    *
    * @param filename   Name of file
    */
   void saveBinaryImageFile(const char *filename) {

      FILE *fp = fopen(filename, "wb");
      if (fp == nullptr) {
         throw MyException("Unable to open binary image file for saving '%s'", filename);
      }
      fwrite(image, 1, getSize(), fp);
      fclose(fp);
   }

   /**
    * Save as C source code array
    *
    * @param filename   Name of file
    */
   void saveAsCSourceFile(const char *filename) {

      FILE *fp = fopen(filename, "wt");
      if (fp == nullptr) {
         throw MyException("Unable to open hex file for saving '%s'", filename);
      }

      uint16_t address        = 0x0000;
      unsigned remainingBytes = getSize();

      fprintf(fp, "#include <stdint.h>\n");
      fprintf(fp, "uint8_t image[] = {\n");

      while (remainingBytes > 0) {
         unsigned lineSize = remainingBytes;
         if (lineSize > 16) {
            lineSize = 16;
         }
         fprintf(fp, "   /* 0x%04X */ ", address);
         for(unsigned offset = 0; offset < lineSize; offset++) {
            fprintf(fp, "0x%02X, ", image[address+offset]);
         }
         fprintf(fp, "\n");
         remainingBytes -= lineSize;
         address        += lineSize;
      }

      fprintf(fp, "};\n");
      fclose(fp);
   }

   /**
    * Compare this image to another image
    *
    * @param other  Other image to check against
    *
    * @return  < 0 => Less than
    * @return  = 0 => Equal
    * @return  > 0 => Greater than
    */
   int compare(HexImage &other) {
      if (getSize() != other.getSize()) {
         throw MyException("Images are not the same size");
      }
      return memcmp(image, other.image, getSize());
   }

   /**
    * Return pointer to internal array
    *
    * @return Pointer to array
    */
   uint8_t *toArray() {
      return image;
   }
};

#endif /* HEXIMAGE_H_ */
