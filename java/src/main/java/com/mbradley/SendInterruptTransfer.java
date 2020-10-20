package com.mbradley;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.IntBuffer;
import java.util.function.Consumer;
import static java.lang.System.out;

import org.usb4java.BufferUtils;
import org.usb4java.DeviceHandle;
import org.usb4java.LibUsb;
import org.usb4java.LibUsbException;
import org.usb4java.Transfer;
import org.usb4java.TransferCallback;

public class SendInterruptTransfer implements Consumer<DeviceHandle> {

    static final long timeout = 1000;

    @Override
    public void accept(DeviceHandle handle) {
        out.println("Interrupt Transfer");

        ByteBuffer buffer = ByteBuffer.allocateDirect(8);
        buffer.put(new byte[] { 'M', 'a', 'r', 't', 'y', '\r', '\n', '\0' });

        byte endpoint = 1 | LibUsb.ENDPOINT_OUT;

        IntBuffer transferred = IntBuffer.allocate(64);

        int result = LibUsb.interruptTransfer(handle, endpoint, buffer, transferred, timeout);
        
        if (result == 0) {
            out.println("Sent bytes");
        }
        else {
            out.println("Some problem with interruptTransfer");
        }
    }
}
