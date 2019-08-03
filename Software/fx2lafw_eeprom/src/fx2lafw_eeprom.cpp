/*
 ============================================================================
 Name        : IntelHex.c
 Author      :
 Version     :
 Copyright   : Your copyright notice
 Description : Hello World in C,0x Ansi-style
 ============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include "dslogic_eeprom.inc"
#include "saleae_image.inc"

typedef enum  {
   RecordType_Data = 0x00,
   RecordType_EOF  = 0x01,
} RecordType;

constexpr unsigned MAX_BYTES_PER_LINE = 16;

unsigned writeRecord(FILE *fp, RecordType recordType, unsigned maxNumBytes, unsigned offset, uint8_t *data) {
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
   writeRecord(fp, RecordType_EOF, 0, 0, NULL);
}

void writeArray(FILE *fp, unsigned numBytes, uint8_t data[], uint16_t address) {
   unsigned offset         = 0;
   unsigned remainingBytes = numBytes;

   while (remainingBytes > 0) {
      unsigned bytesWritten = writeRecord(fp, RecordType_Data, remainingBytes, address, data+offset);
      remainingBytes -= bytesWritten;
      offset         += bytesWritten;
      address        += bytesWritten;
   }
   writeEol(fp);
}

void writeBinary(FILE *fp, unsigned numBytes, uint8_t data[]) {
   fwrite(data, 1, numBytes, fp);
}

#define DATA_ARRAY saleae
#define FILENAME  "saleae"

//#define DATA_ARRAY dslogic
//#define FILENAME  "dslogic"


int main(void) {
   FILE *fp;

   fp= fopen(FILENAME ".iic", "wb");
   writeBinary(fp, sizeof(DATA_ARRAY)/sizeof(DATA_ARRAY[0]), DATA_ARRAY);
   fclose(fp);

   fp = fopen(FILENAME ".hex", "wb");
   writeArray(fp, sizeof(DATA_ARRAY)/sizeof(DATA_ARRAY[0]), DATA_ARRAY, 0x0000);
   fclose(fp);

   return EXIT_SUCCESS;
}
