package com.mbradley;

import org.usb4java.Context;
import org.usb4java.Device;
import org.usb4java.DeviceDescriptor;
import org.usb4java.DeviceHandle;
import org.usb4java.DeviceList;
import org.usb4java.LibUsb;
import org.usb4java.LibUsbException;
import static java.lang.System.out;

import java.nio.ByteBuffer;
import java.nio.IntBuffer;

public class App {
    static final int interfaceNumber = 0;
    static final short vendorId = 1240;
    static final short productId = 20;
    static final long timeout = 1000;

    private static void sendControlTransfer(DeviceHandle handle) {
        ByteBuffer buffer = ByteBuffer.allocateDirect(8);

        buffer.put(new byte[] { 'M', 'a', 'r', 't', 'y', '\r', '\n', '\0' });

        int transfered = LibUsb.controlTransfer(handle, (byte) (LibUsb.REQUEST_TYPE_CLASS | LibUsb.RECIPIENT_INTERFACE),
                (byte) 0x09, (short) 2, (short) 1, buffer, timeout);

        if (transfered < 0) {
            throw new LibUsbException("Control transfer failed", transfered);
        }

        System.out.println(transfered + " bytes sent");
    }

    private static void sendInterruptTransfer(DeviceHandle handle) {
        out.println("Interrupt Transfer");
        
        ByteBuffer buffer = ByteBuffer.allocateDirect(8);
        buffer.put(new byte[] { 'M', 'a', 'r', 't', 'y', '\r', '\n', '\0' });

        byte endpoint = 1 | LibUsb.ENDPOINT_OUT;

        IntBuffer transferred = IntBuffer.allocate(64);

        LibUsb.interruptTransfer(handle, endpoint, buffer, transferred, timeout);
    }

    private static void claim(DeviceHandle handle) {
        int result = LibUsb.claimInterface(handle, interfaceNumber);

        checkResult(result, "Unable to claim interface");
        out.println("Interface claimed");
        try {
            sendInterruptTransfer(handle);
        } finally {
            result = LibUsb.releaseInterface(handle, interfaceNumber);
            checkResult(result, "Unable to release interface");
        }
    }

    private static void openDevice(Device device) {
        int result = -1;
        DeviceHandle handle = new DeviceHandle();
        try {
            result = LibUsb.open(device, handle);

            checkResult(result, "Unable to open USB device");
            
            out.println("Obtained handle");
            
            claim(handle);
        } finally {
            if (result == 0) {
                LibUsb.close(handle);
            }
        }
    }

    public static Device findDevice(Context context) {
        DeviceList list = new DeviceList();
        int result = LibUsb.getDeviceList(context, list);
        if (result < 0) {
            throw new LibUsbException("Unable to get device list", result);
        }

        try {
            for (Device device : list) {
                DeviceDescriptor descriptor = new DeviceDescriptor();
                result = LibUsb.getDeviceDescriptor(device, descriptor);

                checkResult(result, "Unable to read device descriptor");
                out.printf("Vendor %d Product %d%n", descriptor.idVendor(), descriptor.idProduct());
                out.println(descriptor);

                out.println("\n\n");
                if (descriptor.idVendor() == vendorId && descriptor.idProduct() == productId) {
                    return device;
                }
            }
        } finally {
            LibUsb.freeDeviceList(list, true);
        }
        return null;
    }
    
    private static void checkResult(int result, String message) {
        if (result != LibUsb.SUCCESS) {
            throw new LibUsbException(message, result);
        }
    }
    
    public static void main(String[] args) {
        System.out.println("Hello World!");

        Context context = new Context();
        int result = LibUsb.init(context);

        checkResult(result, "Unable to initialize libusb.");

        System.out.println("result is " + result);
        try {
            Device dev = findDevice(context);
            if (dev != null) {
                out.println("Device found :-)");
                openDevice(dev);
            }
            else {
                out.println("Device not found.");
            }
            
        } finally {
            LibUsb.exit(context);
        }
    }
}
