/*
 * LibUsbCpp.h
 *
 *  Created on: 5 Aug 2019
 *      Author: podonoghue
 */

#ifndef LIBUSBCPP_H_
#define LIBUSBCPP_H_

#include "libusb.h"
#include <vector>
#include <memory>

#include "MyException.h"

class Libusb {
private:
   class LibUsbDevice {
   public:
      libusb_device *device;
      uint16_t       pid;
      uint16_t       vid;
      const char    *description;

      LibUsbDevice(
            libusb_device *device,
            uint16_t       pid,
            uint16_t       vid,
            const char    *description) : device(device), pid(pid), vid(vid), description(description) {
      }
   };

   static constexpr unsigned   timeoutValue = 500; // ms

   using LibUsbDeviceList   = std::vector<LibUsbDevice>;
   using LibusbDeviceHandle = libusb_device_handle *;

   LibUsbDeviceList  bdmDevices;
   libusb_context    *context;

   /**
    *  Release all devices referenced by bdm_usb_findDevices
    *
    *  @return BDM_RC_OK - success
    */
   void releaseUsbDevices() {
      for (auto device : bdmDevices) {
         libusb_unref_device(device.device);
      }
      bdmDevices.clear();
   }

public:

   class Device_Internal {
   private:

      LibusbDeviceHandle libusbDeviceHandle;

   public:
      const uint16_t vid;
      const uint16_t pid;
      const char *description;

      /**
       *
       * @param libUsbDevice
       */
      Device_Internal(LibUsbDevice libUsbDevice) : vid(libUsbDevice.vid), pid(libUsbDevice.pid), description(libUsbDevice.description) {

         int rc = libusb_open(libUsbDevice.device, &libusbDeviceHandle);

         if (rc != LIBUSB_SUCCESS) {
            throw MyException("libusb_open() failed, rc = (%d):%s\n", rc, libusb_error_name(rc));
         }
         int configuration = 0;
         rc = libusb_get_configuration(libusbDeviceHandle, &configuration);
         if (rc != LIBUSB_SUCCESS) {
            throw MyException("libusb_get_configuration() failed, rc = (%d):%s\n", rc, libusb_error_name(rc));
         }
      //   fprintf(stdout,  "libusb_get_configuration() done, configuration = %d\n", configuration);
         if (configuration != 1) {
            // It should be possible to set the same configuration but this fails with LIBUSB_ERROR_BUSY
            rc = libusb_set_configuration(libusbDeviceHandle, 1);
            if (rc != LIBUSB_SUCCESS) {
               // Release the device
               libusb_close(libusbDeviceHandle);
               throw MyException("libusb_set_configuration(1) failed, rc = (%d):%s\n", rc, libusb_error_name(rc));
            }
         }
         rc = libusb_claim_interface(libusbDeviceHandle, 0);
         if (rc != LIBUSB_SUCCESS) {
            libusb_close(libusbDeviceHandle);
            throw MyException("libusb_claim_interface(0) failed, rc = (%d):%s\n", rc, libusb_error_name(rc));
         }
      }

      ~Device_Internal() {
         libusb_close(libusbDeviceHandle);
         libusbDeviceHandle = nullptr;
      }

      /**
       *
       * @param request_type
       * @param bRequest
       * @param wValue
       * @param wIndex
       * @param data
       * @param wLength
       */
      void controlTransfer(
            uint8_t               request_type,
            uint8_t               bRequest,
            uint16_t              wValue,
            uint16_t              wIndex,
            unsigned char *       data,
            uint16_t              wLength
             ) {
         if (libusbDeviceHandle == nullptr) {
            throw MyException("No device open!!");
         }
         int rc = libusb_control_transfer(
               libusbDeviceHandle,
               request_type,     // requestType
               bRequest,         // request
               wValue,           // value
               wIndex,           // index
               data,             // data bytes
               wLength,          // size (# of data bytes)
               timeoutValue      // how long to wait for reply
         );
         if (rc < 0) {
            throw MyException("libusb_control_transfer() failed, send failed (USB error = %d)\n", rc);
         }
         if (rc != wLength) {
            throw MyException("libusb_control_transfer() failed, only %d bytes transferred)\n", rc);
         }
      }

   };

   using Device = std::shared_ptr<Device_Internal>;

   /*
    *  Initialisation of low-level USB interface
    */
   Libusb() {
      // Initialise LIBUSB
      context = nullptr;
      int rc = libusb_init(&context);
      if (rc != LIBUSB_SUCCESS) {
         throw MyException("libusb_init() Failed, rc=%d, %s\n", rc, libusb_error_name(rc));
      }
   }

   /**
    * VID, PID pair identifying a target device
    */
   typedef struct {
      uint16_t    vid;
      uint16_t    pid;
      const char *description;
   } UsbId;

   /**
    *  Find all devices currently attached to the computer
    *
    *   @return true  Success, found at least 1 device
    *   @return false Failed, no device found or various errors
    */
   void findUsbDevices(const UsbId usbIds[]) {

//      fprintf(stdout, "Looking for devices:");
//      for(const UsbId *p=usbIds; p->vid!=0; p++) {
//         fprintf(stdout, "[v:%4.4X,p:%4.4X] ", p->vid, p->pid);
//      }
//      fprintf(stdout, "\n");

      // Release any currently referenced devices
      releaseUsbDevices();

      // discover all USB devices
      libusb_device **list;

      ssize_t cnt = libusb_get_device_list(context, &list);
      if (cnt < 0) {
         throw MyException("libusb_get_device_list() failed! \n");
      }

      // Copy the ones we are interested in to our own list
      for (int deviceIndex=0; deviceIndex<cnt; deviceIndex++) {
         // Check each device and copy any USBDMs to local list
         //      fprintf(stderr,  "bdm_usb_find_devices() ==> checking device #%d\n", deviceIndex);
         libusb_device *currentDevice = list[deviceIndex];
         libusb_device_descriptor deviceDescriptor;
         int rc = libusb_get_device_descriptor(currentDevice, &deviceDescriptor);
         if (rc != LIBUSB_SUCCESS) {
            continue; // Skip device
         }
         for(const UsbId *p=usbIds; p->vid!=0; p++) {
            if ((deviceDescriptor.idVendor==p->vid)&&(deviceDescriptor.idProduct==p->pid)) {
               //               fprintf(stdout, "Found device VID=%4.4X, PID=%4.4X\n", deviceDescriptor.idVendor, deviceDescriptor.idProduct);
               // Found a device
               LibUsbDevice device(currentDevice, p->vid, p->pid, p->description);
               bdmDevices.push_back(device); // Record found device
               libusb_ref_device(currentDevice);    // Reference so we don't lose it
               break;
            }
         }
      }
      // Free the original list (devices referenced above are still held)
      libusb_free_device_list(list, true);
   }

   /**
    *  De-initialise low-level USB interface
    */
   ~Libusb() {
      try {
         releaseUsbDevices();
         libusb_exit(context);
      }
      catch(std::exception &) {
      }
   }

   /**
    * Open first target device found
    *
    * @return handle
    */
   Device openDevice(const UsbId usbIds[]) {

      findUsbDevices(usbIds);

      if (bdmDevices.empty()) {
         throw MyException("No devices found");
      }
      if (bdmDevices.size() > 1) {
         throw MyException("Too many devices found");
      }
      auto device = new Device_Internal(bdmDevices.at(0));
      releaseUsbDevices();
      return std::shared_ptr<Device_Internal>(device);
   }

};

#endif /* LIBUSBCPP_H_ */
