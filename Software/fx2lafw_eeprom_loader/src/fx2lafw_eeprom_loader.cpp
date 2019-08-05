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
#include <windows.h>
using namespace std;

#include "libusb.h"

#include "HexImage.h"

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
 * VID, PID pair identifying a target device
 */
typedef struct {
   uint16_t vid;
   uint16_t pid;
} UsbId;

/**
 * USB devices to look for
 */
static const UsbId usbIds[] = {
      {0x0925, 0x3881}, // Saleae Logic Analyser
      {0x04B4, 0x8613}, // Cypress evaluation board
      {0x2A0E, 0x0020}, // DSLogic Plus
      {0x2A0E, 0x0021}, // DSLogic
      {0x08A9, 0x0014}, // Broken 24MHz LA
      {0,0}
};

static constexpr unsigned   timeoutValue = 500; // ms
static libusb_context      *context;
static bool                 initialised = false;

// Count of devices found
static unsigned deviceCount = 0;

// Maximum number of target devices
static constexpr unsigned MAX_DEVICES = 10;

static struct libusb_device *bdmDevices[MAX_DEVICES+1] = {
      NULL
};

/**
 *  Initialisation of low-level USB interface
 *
 *  @return BDM_RC_OK        - success
 *  @return BDM_RC_USB_ERROR - various errors
 */
bool start_libusb() {

   // Clear array of devices found so far
   for (unsigned i=0; i<=MAX_DEVICES; i++) {
      bdmDevices[i] = NULL;  // Clear the list of devices
   }
   deviceCount = 0;

   // Initialise LIBUSB
   context = 0;
   int rc = libusb_init(&context);
   if (rc != LIBUSB_SUCCESS) {
      fprintf(stderr, "libusb_init() Failed, rc=%d, %s\n", rc, libusb_error_name(rc));
      return false;
   }
   initialised = true;
   return true;
}

/**
 *  De-initialise low-level USB interface
 *
 *  @return BDM_RC_OK        - success
 *  @return BDM_RC_USB_ERROR - various errors
 */
bool stop_libusb() {

   if (initialised) {
      libusb_exit(context);
   }
   initialised = false;
   return true;
}

/**
 *  Release all devices referenced by bdm_usb_findDevices
 *
 *  @return BDM_RC_OK - success
 */
bool release_UsbDevices(void) {

   if (!initialised) {
      return false;
   }

   // Unreference all devices
   for(unsigned index=0; index<deviceCount; index++) {
      if (bdmDevices[index] != NULL) {
         libusb_unref_device(bdmDevices[index]);
      }
      bdmDevices[index] = NULL;
   }
   deviceCount = 0;
   return true;
}

/**
 *  Find all USBDM devices attached to the computer
 *
 *   @param deviceCount Number of devices found.  This is set
 *                      to zero on any error.
 *
 *   @return true  Success, found at least 1 device
 *   @return false Failed, no device found or various errors
 */
bool find_usbDevices(unsigned &devCount, const UsbId usbIds[]) {

   fprintf(stdout, "Looking for devices:");
   for(const UsbId *p=usbIds; p->vid!=0; p++) {
      fprintf(stdout, "[v:%4.4X,p:%4.4X] ", p->vid, p->pid);
   }
   fprintf(stdout, "\n");
   devCount = 0; // Assume failure

   // Release any currently referenced devices
   release_UsbDevices();

   // discover all USB devices
   libusb_device **list;

   ssize_t cnt = libusb_get_device_list(context, &list);
   if (cnt < 0) {
      fprintf(stderr, "libusb_get_device_list() failed! \n");
      return false;
   }

   // Copy the ones we are interested in to our own list
   deviceCount = 0;
   for (int deviceIndex=0; deviceIndex<cnt; deviceIndex++) {
      // Check each device and copy any USBDMs to local list
      //      fprintf(stderr,  "bdm_usb_find_devices() ==> checking device #%d\n", deviceIndex);
      libusb_device *currentDevice = list[deviceIndex];
      libusb_device_descriptor deviceDescriptor;
      int rc = libusb_get_device_descriptor(currentDevice, &deviceDescriptor);
      if (rc != LIBUSB_SUCCESS) {
         continue; // Skip device
      }
      bool found = false;
      for(const UsbId *p=usbIds; p->vid!=0; p++) {
         if ((deviceDescriptor.idVendor==p->vid)&&(deviceDescriptor.idProduct==p->pid)) {
            fprintf(stdout, "Found device VID=%4.4X, PID=%4.4X\n", deviceDescriptor.idVendor, deviceDescriptor.idProduct);
            found = true;
            break;
         }
      }
      if (found) {
         // Found a device
         uint8_t busNumber = libusb_get_bus_number(currentDevice);
         uint8_t address   = libusb_get_device_address(currentDevice);
         //         fprintf(stdout,  "==> Found USBDM device, List[%d] = #%d, dev#=%d, addr=%d\n", deviceCount, deviceIndex, busNumber, address);

         // Check if real device
         // A bug in LIBUSB with Windows 7 requires this check to discard phantom devices
         libusb_device_handle *usbDeviceHandle = 0;
         if (libusb_open(currentDevice, &usbDeviceHandle) == LIBUSB_ERROR_NOT_SUPPORTED) {
            fprintf(stdout,  "Discarding USBDM device as phantom, List[%d] = #%d, dev#=%d, addr=%d\n", deviceCount, deviceIndex, busNumber, address);
            continue;
         }
         if (usbDeviceHandle != 0) {
            // Ignore any error on close
            libusb_close(usbDeviceHandle);
         }
         bdmDevices[deviceCount++] = currentDevice; // Record found device
         libusb_ref_device(currentDevice);          // Reference so we don't lose it
         bdmDevices[deviceCount]=NULL;           // Terminate the list again
         if (deviceCount>MAX_DEVICES) {
            break;
         }
      }
   }
   // Free the original list (devices referenced above are still held)
   libusb_free_device_list(list, true);

   devCount = deviceCount;

   if(deviceCount>0) {
      return true;
   }
   else {
      return false;
   }
}

/**
 *  Open connection to device enumerated by find_usbDevices()
 *
 *  @param device_no Device number to open
 *
 *   @return !=0  Success, device handle
 *   @return ==0  Failed
 */
libusb_device_handle *open_usbDevice(unsigned int device_no) {

   libusb_device_handle *usbDeviceHandle = nullptr;
   if (!initialised) {
      fprintf(stderr,  "Not Initialised device\n");
      throw MyException("Interface not initialised");
   }
   if (device_no >= deviceCount) {
      throw MyException("Illegal device #");
   }
//   fprintf(stdout,  "libusb_open(), bdmDevices[%d] = %p\n", device_no, bdmDevices[device_no]);

   int rc = libusb_open(bdmDevices[device_no], &usbDeviceHandle);

   if (rc != LIBUSB_SUCCESS) {
      fprintf(stderr,  "libusb_open() failed, rc = (%d):%s\n", rc, libusb_error_name(rc));
      throw MyException("libusb_open() failed");
   }
   int configuration = 0;
   rc = libusb_get_configuration(usbDeviceHandle, &configuration);
   if (rc != LIBUSB_SUCCESS) {
      fprintf(stderr,  "libusb_get_configuration() failed, rc = (%d):%s\n", rc, libusb_error_name(rc));
      throw MyException("libusb_get_configuration() failed");
   }
//   fprintf(stdout,  "libusb_get_configuration() done, configuration = %d\n", configuration);
   if (configuration != 1) {
      // It should be possible to set the same configuration but this fails with LIBUSB_ERROR_BUSY
      rc = libusb_set_configuration(usbDeviceHandle, 1);
      if (rc != LIBUSB_SUCCESS) {
         fprintf(stderr,  "libusb_set_configuration(1) failed, rc = (%d):%s\n", rc, libusb_error_name(rc));
         // Release the device
         libusb_close(usbDeviceHandle);
         throw MyException("libusb_get_configuration() failed");
      }
   }
   rc = libusb_claim_interface(usbDeviceHandle, 0);
   if (rc != LIBUSB_SUCCESS) {
      fprintf(stderr,  "libusb_claim_interface(0) failed, rc = (%d):%s\n", rc, libusb_error_name(rc));
      libusb_close(usbDeviceHandle);
      throw MyException("libusb_claim_interface() failed");
   }
   return (usbDeviceHandle);
}

/**
 * Open first target device found
 *
 * @return handle
 */
libusb_device_handle *openDevice() {

   if (!start_libusb()) {
      throw MyException("start_libusb() failed");
   }
   unsigned devCount;

   find_usbDevices(devCount, usbIds);

   if (devCount > 1) {
      throw MyException("Too many devices found");
   }
   if (devCount == 0) {
      throw MyException("No devices found");
   }
   return open_usbDevice(0);
}

/**
 * Download a block of up to 64 bytes to target RAM
 *
 * @param usbDeviceHandle
 * @param startingAddress
 * @param length
 * @param firmware
 */
void downloadBlockToTargetRam(libusb_device_handle *usbDeviceHandle, uint16_t startingAddress, uint16_t length, uint8_t *data) {

   int rc = libusb_control_transfer(
         usbDeviceHandle,
         bmREQUEST_VENDOR_OUT,      // requestType
         bREQUEST_FIRMWARE_LOAD,    // request
         startingAddress,           // value
         0,                         // index
         data,                      // data bytes
         length,                    // size (# of data bytes)
         timeoutValue               // how long to wait for reply
   );
   if (rc < 0) {
      fprintf(stderr,  "libusb_control_transfer() failed, send failed (USB error = %d)\n", rc);
      throw MyException("libusb_control_transfer() failed");
   }
   if (rc != length) {
      fprintf(stderr,  "libusb_control_transfer() failed, only %d bytes transferred)\n", rc);
      throw MyException("libusb_control_transfer() failed");
   }
}

/**
 * Download data to target RAM
 *
 * @param usbDeviceHandle
 * @param startingAddress
 * @param length
 * @param firmware_image
 */
void downloadToTargetRam(libusb_device_handle *usbDeviceHandle, uint16_t startingAddress, uint16_t length, uint8_t *data) {

   while (length>0) {
      unsigned blockSize = length;
      if (blockSize>MAX_EP0_PACKET_SIZE) {
         blockSize = MAX_EP0_PACKET_SIZE;
      }
      downloadBlockToTargetRam(usbDeviceHandle, startingAddress, blockSize, data);
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
void downloadFirmwareToTargetRam(libusb_device_handle *usbDeviceHandle, HexImage &firmware_image) {

   downloadToTargetRam(usbDeviceHandle, 0, firmware_image.getSize(), firmware_image.toArray());
}

int LIBUSB_CALL libusb_control_transfer(
   libusb_device_handle *dev_handle,
   uint8_t               request_type,
   uint8_t               bRequest,
   uint16_t              wValue,
   uint16_t              wIndex,
   unsigned char *       data,
   uint16_t              wLength,
   unsigned int          timeout
);

/**
 * Upload a block from target RAM
 *
 * @param usbDeviceHandle
 * @param startingAddress
 * @param length
 * @param firmware
 */
void uploadBlockFromTargetRam(libusb_device_handle *usbDeviceHandle, uint16_t startingAddress, uint16_t length, uint8_t *data) {

   int rc = libusb_control_transfer(
         usbDeviceHandle,
         bmREQUEST_VENDOR_IN,       // bRequestType
         bREQUEST_FIRMWARE_LOAD,    // bRequest
         startingAddress,           // wValue
         0,                         // wIndex
         data,                      // data bytes
         length,                    // wLength (# of data bytes)
         timeoutValue               // how long to wait for reply
   );

   if (rc < 0) {
      fprintf(stderr,  "libusb_control_transfer() failed, send failed (USB error = %d)\n", rc);
      throw MyException("libusb_control_transfer() failed");
   }
   if (rc != length) {
      fprintf(stderr,  "libusb_control_transfer() failed, only %d bytes transferred)\n", rc);
      throw MyException("libusb_control_transfer() failed");
   }
}

/**
 *
 * @param usbDeviceHandle
 * @param startingAddress
 * @param length
 * @param firmware_image
 */
void uploadFromTargetRam(libusb_device_handle *usbDeviceHandle, uint16_t startingAddress, uint16_t length, uint8_t *data) {

   while (length>0) {
      unsigned blockSize = length;
      if (blockSize>64) {
         blockSize = 64;
      }
      uploadBlockFromTargetRam(usbDeviceHandle, startingAddress, blockSize, data);
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
void uploadFirmwareFromTargetRam(libusb_device_handle *usbDeviceHandle, HexImage &firmware_image) {

   uploadFromTargetRam(usbDeviceHandle, 0x00, firmware_image.getSize(), firmware_image.toArray());
}

/**
 * Reset target processor
 * @note The target is held in reset
 *
 * @param usbDeviceHandle
 */
void resetProcessor(libusb_device_handle *usbDeviceHandle) {

   uint8_t data[] = {0x01};
   downloadBlockToTargetRam(usbDeviceHandle, CPUCS_ADDRESS, sizeof(data), data);
}

/**
 * Release reset of target processor
 * @note The target is held in reset
 *
 * @param usbDeviceHandle
 */
void releaseProcessorReset(libusb_device_handle *usbDeviceHandle) {

   uint8_t data[] = {0x00};
   downloadBlockToTargetRam(usbDeviceHandle, CPUCS_ADDRESS, sizeof(data), data);
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
void uploadEepromBlockFromTarget(libusb_device_handle *usbDeviceHandle, uint16_t startingAddress, uint16_t length, uint8_t *eeprom, EepromSize eepromSize) {

   int rc = libusb_control_transfer(
         usbDeviceHandle,
         bmREQUEST_VENDOR_IN,        // requestType
         eepromSize,                 // request
         startingAddress,            // value
         0x0000,                     // index
         eeprom,                     // data bytes
         length,                     // size (# of data bytes)
         timeoutValue                // how long to wait for reply
   );

   if (rc < 0) {
      fprintf(stderr,  "libusb_control_transfer() failed, send failed (USB error = %d)\n", rc);
      throw MyException("libusb_control_transfer() failed");
   }
   if (rc != length) {
      fprintf(stderr,  "libusb_control_transfer() failed, only %d bytes transferred)\n", rc);
      throw MyException("libusb_control_transfer() failed");
   }
}

/**
 * Upload EEPROM from target
 *
 * @param usbDeviceHandle
 * @param eeprom_image
 * @param eepromSize
 */
void uploadEepromFromTarget(libusb_device_handle *usbDeviceHandle, HexImage &eeprom_image, EepromSize eepromSize) {

   uint8_t *firmware = eeprom_image.toArray();
   uint16_t startingAddress = 0x000;
   uint16_t length = eeprom_image.getSize();

   while (length>0) {
      unsigned blockSize = length;
      if (blockSize>64) {
         blockSize = 64;
      }
      uploadEepromBlockFromTarget(usbDeviceHandle, startingAddress, blockSize, firmware, eepromSize);
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
void downloadEepromBlockToTarget(libusb_device_handle *usbDeviceHandle, uint16_t startingAddress, uint16_t length, uint8_t *eeprom, EepromSize eepromSize) {

   int rc = libusb_control_transfer(
         usbDeviceHandle,
         bmREQUEST_VENDOR_OUT,       // requestType
         eepromSize,                 // request
         startingAddress,            // value
         0x0000,                     // index
         eeprom,                     // data bytes
         length,                     // size (# of data bytes)
         timeoutValue                // how long to wait for reply
   );

   if (rc < 0) {
      fprintf(stderr,  "libusb_control_transfer() failed, send failed (USB error = %d)\n", rc);
      throw MyException("libusb_control_transfer() failed");
   }
   if (rc != length) {
      fprintf(stderr,  "libusb_control_transfer() failed, only %d bytes transferred)\n", rc);
      throw MyException("libusb_control_transfer() failed");
   }
}
/**
 * Download EEPROM to target
 *
 * @param usbDeviceHandle
 * @param eeprom_image
 * @param eepromSize
 */
void downloadEepromToTarget(libusb_device_handle *usbDeviceHandle, HexImage &eeprom_image, EepromSize eepromSize) {

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
      downloadEepromBlockToTarget(usbDeviceHandle, startingAddress, blockSize, firmware, eepromSize);
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
void downloadEepromUtility(libusb_device_handle *handle) {

   HexImage firmware_image(MAX_RAM_IMAGE_SIZE);

   firmware_image.loadHexFile("Vend_Ax.hex");
   firmware_image.saveAsCSourceFile("Vend_Ax.cpp");
//   firmware_image.print();

   resetProcessor(handle);
   downloadFirmwareToTargetRam(handle, firmware_image);

   HexImage firmware_image_readback(firmware_image.getSize());
   firmware_image_readback.setSize(firmware_image.getSize());

   uploadFirmwareFromTargetRam(handle, firmware_image_readback);

   if (firmware_image.compare(firmware_image_readback) != 0) {
      fprintf(stdout, "Firmware verify failed\n");
      throw MyException("Firmware verify failed");
   }
   else {
      fprintf(stdout, "Firmware download OK\n");
   }
   releaseProcessorReset(handle);

   Sleep(100);
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

   try {
      libusb_device_handle *handle = openDevice();

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
   catch (MyException &e) {
      release_UsbDevices();
      throw(e);
   }
   if (!stop_libusb()) {
      fprintf(stdout, "stop_libusb() failed\n");
      throw MyException("stop_libusb() failed\n");
   }
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

   try {
      libusb_device_handle *handle = openDevice();

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
   catch (MyException &e) {
      release_UsbDevices();
      throw(e);
   }
   catch (MyException *e) {
      release_UsbDevices();
      throw(e);
   }
   if (!stop_libusb()) {
      fprintf(stdout, "stop_libusb() failed\n");
      throw MyException("stop_libusb() failed");
   }
}

/**
 * Verify target EEPROM against file
 *
 * @param eepromType
 * @param new_load_filename
 */
void verifyEeprom(EepromTypes eepromType, const char *new_load_filename) {

   try {
      libusb_device_handle *handle = openDevice();

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
         printf("Current EEPROM contents same as new image - verified OK");
      }
      else {
         throw MyException("Verify failed");
      }
   }
   catch (MyException &e) {
      release_UsbDevices();
      throw(e);
   }
   catch (MyException *e) {
      release_UsbDevices();
      throw(e);
   }
   if (!stop_libusb()) {
      fprintf(stdout, "stop_libusb() failed\n");
      throw MyException("stop_libusb() failed");
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
