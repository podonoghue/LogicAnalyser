//============================================================================
// Name        : fx2lafw_eeprom_loader.cpp
// Author      : 
// Version     :
// Copyright   : Your copyright notice
// Description : Hello World in C++, Ansi-style
//============================================================================

#include <memory.h>
#include <stdio.h>
#include <ctype.h>
//#include <windows.h>
#include <time.h>

#include "HexImage.h"
#include "LibusbCpp.h"

static constexpr uint8_t REQUEST_OUT                  = 0x00;
static constexpr uint8_t REQUEST_IN                   = 0x80;

static constexpr uint8_t bmREQUEST_VENDOR_OUT         = 0x40 | REQUEST_OUT;
static constexpr uint8_t bmREQUEST_VENDOR_IN          = 0x40 | REQUEST_IN;

//static constexpr uint8_t EP_CONTROL_OUT = 0x00;

static constexpr uint8_t bREQUEST_FIRMWARE_LOAD       = 0xA0;
static constexpr uint8_t bREQUEST_SMALL_EEPROM_LOAD   = 0xA2;
static constexpr uint8_t bREQUEST_LARGE_EEPROM_LOAD   = 0xA9;

static constexpr unsigned MAX_EP0_PACKET_SIZE         = 64;

// CPUCS register in target (for processor reset)
static constexpr uint16_t CPUCS_ADDRESS               = 0xE600;

/**
 * Indicates which type of EEPROM
 */
enum EepromSize {
   EepromSize_Small = bREQUEST_SMALL_EEPROM_LOAD,  //!< EepromSize_Small
   EepromSize_Large = bREQUEST_LARGE_EEPROM_LOAD,  //!< EepromSize_Large
};

/**
 * USB devices to look for
 */
static const Libusb::UsbId usbIds[] = {
      {0x0925, 0x3881, "Saleae Logic Analyser"       },
      {0x04B4, 0x8613, "Cypress evaluation board"    },
      {0x2A0E, 0x0020, "DSLogic Plus"                },
      {0x2A0E, 0x0021, "DSLogic Basic"               },
      {0x2A0E, 0x0029, "DSLogic U2Basic"             },
      {0x08A9, 0x0014, "Broken 24MHz LA"             },
      {0,0,0                                         },
};

int msleep(long msec)
{
    struct timespec ts;
    int res;

    if (msec < 0)
    {
        errno = EINVAL;
        return -1;
    }

    ts.tv_sec = msec / 1000;
    ts.tv_nsec = (msec % 1000) * 1000000;

    do {
        res = nanosleep(&ts, &ts);
    } while (res && errno == EINTR);

    return res;
}

/**
 * Download a block of up to 64 bytes to target RAM
 *
 * @param usbDeviceHandle
 * @param startingAddress
 * @param length
 * @param firmware
 */
void downloadBlockToTargetRam(Libusb::Device device, uint16_t startingAddress, uint16_t length, uint8_t *data) {

   device->controlTransfer(
         bmREQUEST_VENDOR_OUT,      // requestType
         bREQUEST_FIRMWARE_LOAD,    // request
         startingAddress,           // value
         0,                         // index
         data,                      // data bytes
         length                     // size (# of data bytes)
   );
}

/**
 * Download data to target RAM
 *
 * @param usbDeviceHandle
 * @param startingAddress
 * @param length
 * @param firmware_image
 */
void downloadToTargetRam(Libusb::Device device, uint16_t startingAddress, uint16_t length, uint8_t *data) {

   while (length>0) {
      unsigned blockSize = length;
      if (blockSize>MAX_EP0_PACKET_SIZE) {
         blockSize = MAX_EP0_PACKET_SIZE;
      }
      downloadBlockToTargetRam(device, startingAddress, blockSize, data);
      data            += blockSize;
      startingAddress += blockSize;
      length          -= blockSize;
   }
}

/**
 * Download firmware image to target RAM
 *
 * @param usbDeviceHandle
 * @param firmware_image
 */
void downloadFirmwareToTargetRam(Libusb::Device device, HexImage &firmware_image) {

   downloadToTargetRam(device, 0, firmware_image.getSize(), firmware_image.toArray());
}

/**
 * Upload a block from target RAM
 *
 * @param usbDeviceHandle
 * @param startingAddress
 * @param length
 * @param firmware
 */
void uploadBlockFromTargetRam(Libusb::Device device, uint16_t startingAddress, uint16_t length, uint8_t *data) {

   device->controlTransfer(
         bmREQUEST_VENDOR_IN,       // bRequestType
         bREQUEST_FIRMWARE_LOAD,    // bRequest
         startingAddress,           // wValue
         0,                         // wIndex
         data,                      // data bytes
         length                     // wLength (# of data bytes)
   );
}

/**
 *
 * @param usbDeviceHandle
 * @param startingAddress
 * @param length
 * @param firmware_image
 */
void uploadFromTargetRam(Libusb::Device device, uint16_t startingAddress, uint16_t length, uint8_t *data) {

   while (length>0) {
      unsigned blockSize = length;
      if (blockSize>64) {
         blockSize = 64;
      }
      uploadBlockFromTargetRam(device, startingAddress, blockSize, data);
      data            += blockSize;
      startingAddress += blockSize;
      length          -= blockSize;
   }
}

/**
 * Upload firmware image from target RAM
 *
 * @param usbDeviceHandle
 * @param firmware_image
 */
void uploadFirmwareFromTargetRam(Libusb::Device device, HexImage &firmware_image) {

   uploadFromTargetRam(device, 0x00, firmware_image.getSize(), firmware_image.toArray());
}

/**
 * Reset target processor
 * @note The target is held in reset
 *
 * @param usbDeviceHandle
 */
void resetProcessor(Libusb::Device device) {

   uint8_t data[] = {0x01};
   downloadBlockToTargetRam(device, CPUCS_ADDRESS, sizeof(data), data);
}

/**
 * Release reset of target processor
 * @note The target is held in reset
 *
 * @param usbDeviceHandle
 */
void releaseProcessorReset(Libusb::Device device) {

   uint8_t data[] = {0x00};
   downloadBlockToTargetRam(device, CPUCS_ADDRESS, sizeof(data), data);
}

// Maximum size of RAM on target
static constexpr int MAX_RAM_IMAGE_SIZE = 0x4000;

/**
 * Upload block from target EEPROM
 *
 * @param usbDeviceHandle
 * @param startingAddress
 * @param length
 * @param eeprom
 * @param eepromSize
 */
void uploadEepromBlockFromTarget(Libusb::Device device, uint16_t startingAddress, uint16_t length, uint8_t *eeprom, EepromSize eepromSize) {

   device->controlTransfer(
         bmREQUEST_VENDOR_IN,        // requestType
         eepromSize,                 // request
         startingAddress,            // value
         0x0000,                     // index
         eeprom,                     // data bytes
         length                      // size (# of data bytes)
   );
}

/**
 * Upload EEPROM from target
 *
 * @param usbDeviceHandle
 * @param eeprom_image
 * @param eepromSize
 */
void uploadEepromFromTarget(Libusb::Device device, HexImage &eeprom_image, EepromSize eepromSize) {

   uint8_t *firmware = eeprom_image.toArray();
   uint16_t startingAddress = 0x000;
   uint16_t length = eeprom_image.getSize();

   while (length>0) {
      unsigned blockSize = length;
      if (blockSize>64) {
         blockSize = 64;
      }
      uploadEepromBlockFromTarget(device, startingAddress, blockSize, firmware, eepromSize);
      firmware        += blockSize;
      startingAddress += blockSize;
      length          -= blockSize;
   }
}

/**
 * Upload block from target EEPROM
 *
 * @param usbDeviceHandle
 * @param startingAddress
 * @param length
 * @param eeprom
 * @param eepromSize
 */
void downloadEepromBlockToTarget(Libusb::Device device, uint16_t startingAddress, uint16_t length, uint8_t *eeprom, EepromSize eepromSize) {

   device->controlTransfer(
         bmREQUEST_VENDOR_OUT,       // requestType
         eepromSize,                 // request
         startingAddress,            // value
         0x0000,                     // index
         eeprom,                     // data bytes
         length                      // size (# of data bytes)
   );
}
/**
 * Download EEPROM to target
 *
 * @param usbDeviceHandle
 * @param eeprom_image
 * @param eepromSize
 */
void downloadEepromToTarget(Libusb::Device device, HexImage &eeprom_image, EepromSize eepromSize) {

   uint8_t *firmware = eeprom_image.toArray();
   uint16_t startingAddress = 0x000;
   uint16_t length = eeprom_image.getSize();

   printf("Programming\n");
   unsigned count = 0;
   while (length>0) {
      unsigned blockSize = length;
      if (blockSize>64) {
         blockSize = 64;
      }
      downloadEepromBlockToTarget(device, startingAddress, blockSize, firmware, eepromSize);
      firmware        += blockSize;
      startingAddress += blockSize;
      length          -= blockSize;
      count++;
      if (count>=50) {
         printf("\n");
         count = 0;
      }
      else {
         printf(".");
      }
      fflush(stdout);
   }
   printf("\n");
}

/**
 * Download the EEPROM Utility program to the target RAM
 *
 * @param handle
 */
void downloadEepromUtility(Libusb::Device device) {

   HexImage firmware_image(MAX_RAM_IMAGE_SIZE);

   firmware_image.loadHexFile("Vend_Ax.hex");
   firmware_image.saveAsCSourceFile("Vend_Ax.cpp");
//   firmware_image.print();

   resetProcessor(device);
   downloadFirmwareToTargetRam(device, firmware_image);

   HexImage firmware_image_readback(firmware_image.getSize());
   firmware_image_readback.setSize(firmware_image.getSize());

   uploadFirmwareFromTargetRam(device, firmware_image_readback);

   if (firmware_image.compare(firmware_image_readback) != 0) {
      fprintf(stdout, "Firmware verify failed\n");
      throw MyException("Firmware verify failed");
   }
   else {
      fprintf(stdout, "Firmware download OK\n");
   }
   releaseProcessorReset(device);

   msleep(100);
//   Sleep(100);
}

struct EepromTypes {
      const char *name;
      unsigned    size;
      EepromSize  eepromAccessType;
};

/**
 * Read EEPROM from target and save to file
 *
 * @param eepromType Type of EEPROM
 * @param filename   Name of file to write EEPROM image to
 */
void readEeprom(EepromTypes eepromType, const char *filename) {

   Libusb libusb;
   Libusb::Device handle = libusb.openDevice(usbIds);

   printf("Found PID = 0x%04X, VID = 0x%04X, '%s'\n", handle->pid, handle->vid, handle->description);
   downloadEepromUtility(handle);

   HexImage eeprom_image(eepromType.size);
   eeprom_image.setSize(eepromType.size);
   uploadEepromFromTarget(handle, eeprom_image, eepromType.eepromAccessType);

   if ((eeprom_image[0] == 0xCD) && (eeprom_image[1] == 0xCD)) {
      fprintf(stdout, "Failed EEPROM read. Wrong image size type?");
      throw MyException("Failed EEPROM read. Wrong image size type?");
   }
   eeprom_image.saveHexFile(filename);
   fprintf(stdout, "Original EEPROM contents (%d bytes) (saved to %s) :\n", eeprom_image.getSize(), filename);
   eeprom_image.print();
}

/**
 * Write file to target EEPROM
 *
 * @param eepromType
 * @param new_load_filename
 * @param randomDid
 */
void writeEeprom(EepromTypes eepromType, const char * new_load_filename) {

   static constexpr const char *old_save_filename = "saved_eeprom_image.hex";

   Libusb libusb;
   Libusb::Device handle = libusb.openDevice(usbIds);

   downloadEepromUtility(handle);

   HexImage original_eeprom_image(eepromType.size);
   original_eeprom_image.setSize(eepromType.size);

   uploadEepromFromTarget(handle, original_eeprom_image, eepromType.eepromAccessType);

   if ((original_eeprom_image[0] == 0xCD) && (original_eeprom_image[1] == 0xCD)) {
      throw MyException("Failed EEPROM read. Wrong image size type?");
   }
   original_eeprom_image.saveHexFile(old_save_filename);
   fprintf(stdout, "Original EEPROM contents (%d bytes) (saved to %s) :\n", original_eeprom_image.getSize(), old_save_filename);
   original_eeprom_image.print();

   HexImage new_eeprom_image(eepromType.size);
   new_eeprom_image.loadHexFile(new_load_filename);
   new_eeprom_image.setSize(eepromType.size);

   if (new_eeprom_image.compare(original_eeprom_image) == 0) {
      printf("Current EEPROM contents same as new image - programming skipped");
   }
   else {
      downloadEepromToTarget(handle, new_eeprom_image, eepromType.eepromAccessType);

      HexImage verify_eeprom_image(eepromType.size);
      verify_eeprom_image.setSize(eepromType.size);

      uploadEepromFromTarget(handle, verify_eeprom_image, eepromType.eepromAccessType);

      if (verify_eeprom_image.compare(new_eeprom_image) != 0) {
         fprintf(stderr, "EEPROM Verify failed\n");
         throw MyException("EEPROM Verify failed");
      }

      fprintf(stdout, "New EEPROM contents (%d bytes) (loaded from %s) :\n", new_eeprom_image.getSize(), new_load_filename);
      new_eeprom_image.print();
      printf("Completed Programming\n");
   }
}

/**
 * Verify target EEPROM against file
 *
 * @param eepromType
 * @param new_load_filename
 */
void verifyEeprom(EepromTypes eepromType, const char *new_load_filename) {

   Libusb libusb;
   Libusb::Device handle = libusb.openDevice(usbIds);

   downloadEepromUtility(handle);

   HexImage original_eeprom_image(eepromType.size);
   original_eeprom_image.setSize(eepromType.size);

   uploadEepromFromTarget(handle, original_eeprom_image, eepromType.eepromAccessType);

   if ((original_eeprom_image[0] == 0xCD) && (original_eeprom_image[1] == 0xCD)) {
      throw MyException("Failed EEPROM read. Wrong image size type?");
   }
   fprintf(stdout, "EEPROM contents (%d bytes) :\n", original_eeprom_image.getSize());
   original_eeprom_image.print();

   HexImage verify_eeprom_image(eepromType.size);
   verify_eeprom_image.loadHexFile(new_load_filename);
   verify_eeprom_image.setSize(eepromType.size);

   if (verify_eeprom_image.compare(original_eeprom_image) == 0) {
      printf("Current EEPROM contents same as new image - verified OK\n");
   }
   else {
      throw MyException("Verify failed");
   }
}

EepromTypes eepromTypes[] = {
      {"24LC01",      128,  EepromSize_Small }, // 0
      {"24LC02",      256,  EepromSize_Small }, // 1
      {"24LC04",      512,  EepromSize_Small }, // 2
      {"24LC64",     8192,  EepromSize_Large }, // 3
      {"24LC128",   16384,  EepromSize_Large }, // 4
      {"M24128",    16384,  EepromSize_Large }, // 4
};

/**
 * Get EEPROM information based on type name
 *
 * @param name
 *
 * @return
 */
EepromTypes *getEepromType(const char *name) {
   for (unsigned index=0; index<(sizeof(eepromTypes)/sizeof(eepromTypes[0])); index++) {
      if (strcasecmp(eepromTypes[index].name, name) == 0) {
         return &eepromTypes[index];
      }
   }
   return nullptr;
}

/**
 * Quick hack to convert a fixed file from binary image to Intel HEX file
 */
void binaryToHexFile() {

   HexImage image(16384, 0x00);
   image.loadBinaryImageFile("24c128_basic.bin");
   image.saveHexFile("24c128_basic.hex");
}

void usage() {
   fprintf(stderr,
         "\n"
         "Usage: \n"
         "    fx2lafw_eeprom_loader -t <eeprom_type> -r <filename> \n"
         "    fx2lafw_eeprom_loader -t <eeprom_type> -p <filename> \n"
         "    fx2lafw_eeprom_loader -t <eeprom_type> -v <filename> \n"
         "\n"
         "    eeprom_type = 24LC01, 24LC02, 24LC04, 24LC64, 24LC128, M24128\n"
         "    -p = Program EEPROM\n"
         "    -r = Read EEPROM\n"
         "    -v = Verify EEPROM\n"
         "\n"
   );
}

enum Action {Action_None, Action_Program, Action_Verify, Action_Read, Action_Saleae, };

int main(int argc, const char *argv[]) {
   Action      action      = Action_None;
   const char *eepromType  = nullptr;
   const char *filename    = nullptr;

   try {
      if ((argc != 5) && (argc != 2)) {
         usage();
         throw MyException("Wrong number of arguments");
      }
      for (int index = 1; index<argc; ) {
         if (strcmp(argv[index], "-t") == 0) {
            // EEPROM type
            index++;
            if (eepromType != nullptr) {
               throw MyException("Conflicting options");
            }
            eepromType = argv[index++];
         }
         else if (strcmp(argv[index], "-p") == 0) {
            // Program
            index++;
            if (filename != nullptr) {
               throw MyException("Multiple filenames");
            }
            filename = argv[index++];
            action   = Action_Program;
         }
         else if (strcmp(argv[index], "-v") == 0) {
            // Verify
            index++;
            if (filename != nullptr) {
               throw MyException("Multiple filenames");
            }
            filename = argv[index++];
            action   = Action_Verify;
         }
         else if (strcmp(argv[index], "-r") == 0) {
            // Read
            index++;
            if (filename != nullptr) {
               throw MyException("Multiple filenames");
            }
            filename = argv[index++];
            action   = Action_Read;
         }
         else if (strcmp(argv[index], "-s") == 0) {
            // Read
            index++;
            eepromType  = "24LC02";
            filename    = "eeprom_image_saleae.hex";
            action      = Action_Saleae;
         }
         else {
            usage();
            throw MyException("Illegal arguments '%s'", argv[index]);
         }
      }
      if ((action == Action_None) || (filename == nullptr)) {
         usage();
         throw MyException("Illegal or missing arguments");
      }
      EepromTypes *type = getEepromType(eepromType);
      if (type == nullptr) {
         usage();
         throw MyException("Unknown EEPROM type '%s'", eepromType);
      }
      printf("EEPROM is %s (%d bytes)\n", type->name, type->size);

      switch(action) {
         case Action_Saleae:
            // no break
         case Action_Program:
            printf("EEPROM action is Program\n");
            writeEeprom(*type, filename);
            break;
         case Action_Verify:
            printf("EEPROM action is Verify\n");
            verifyEeprom(*type, filename);
            break;
         case Action_Read:
            printf("EEPROM action is Read\n");
            readEeprom(*type, filename);
            break;
         default:
            break;
      }
   }
   catch (std::exception &e) {
      fprintf(stdout, "Error: %s\n", e.what());
      fflush(stderr);
   }
   catch (std::exception *e) {
      fprintf(stdout, "Error: %s\n", e->what());
      fflush(stderr);
   }

   return 0;
}
