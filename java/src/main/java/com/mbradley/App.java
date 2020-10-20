package com.mbradley;

import org.usb4java.Context;
import org.usb4java.Device;
import org.usb4java.DeviceDescriptor;
import org.usb4java.DeviceHandle;
import org.usb4java.DeviceList;
import org.usb4java.LibUsb;
import org.usb4java.LibUsbException;
import org.usb4java.TransferCallback;
 

import java.nio.ByteBuffer;
import java.nio.IntBuffer;
import java.util.function.Consumer;
import static java.lang.System.out;

public class App {
    static final int interfaceNumber = 0;
    static final short vendorId = 1240;
    static final short productId = 20;

    private static void claim(DeviceHandle handle, Consumer<DeviceHandle> program) throws InterruptedException {
        int result = LibUsb.claimInterface(handle, interfaceNumber);

        checkResult(result, "Unable to claim interface");
        out.println("Interface claimed");
        try {

            program.accept(handle);
            out.println("accept completed");
            
            for (int times = 0; times < 4; times++) {
               // out.println("main thread sleeping");
                Thread.sleep(1000);
                
            }
        } finally {
            result = LibUsb.releaseInterface(handle, interfaceNumber);
            out.println("Interface released");
            checkResult(result, "Unable to release interface");
        }
    }

    private static void openDevice(Device device, Consumer<DeviceHandle> program) throws InterruptedException {
        int result = -1;
        DeviceHandle handle = new DeviceHandle();
        try {
            result = LibUsb.open(device, handle);

            checkResult(result, "Unable to open USB device");
            
            out.println("Obtained handle");
            
            claim(handle, program);
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
//                out.printf("Vendor %d Product %d%n", descriptor.idVendor(), descriptor.idProduct());
//                out.println(descriptor);
//
//                out.println("\n\n");
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
    
    public static void main(String[] args) throws InterruptedException {
        System.out.println("Hello World!");

        Context context = new Context();
        int result = LibUsb.init(context);

        checkResult(result, "Unable to initialize libusb.");

        System.out.println("result is " + result);
        try {
            Device dev = findDevice(context);
            if (dev != null) {
                out.println("Device found :-)");
                
                EventHandlingThread thread = new EventHandlingThread(context);
                thread.start();
                
                openDevice(dev, new InterruptHandler());
                
                

                thread.join();
            }
            else {
                out.println("Device not found.");
            }
            
        } finally {
            LibUsb.exit(context);
        }
    }
}
