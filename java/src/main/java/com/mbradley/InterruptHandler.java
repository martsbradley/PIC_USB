package com.mbradley;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.CharBuffer;
import java.nio.IntBuffer;
import java.util.function.Consumer;
import static java.lang.System.out;

import org.usb4java.BufferUtils;
import org.usb4java.DeviceHandle;
import org.usb4java.LibUsb;
import org.usb4java.LibUsbException;
import org.usb4java.Transfer;
import org.usb4java.TransferCallback;


public class InterruptHandler implements Consumer<DeviceHandle> {

    static final long timeout = 1000;

    DeviceHandle handle ;;;// this ain't great.
    
    @Override
    public void accept(DeviceHandle handle) {
        this.handle = handle;
        write(handle, 8, martyWritten);
        write(handle, 8, martyWritten);
        write(handle, 8, martyWritten);
        write(handle, 8, martyWritten);
        
        System.out.printf("%s is the main thread%n", 
                           Thread.currentThread().getName()); 
        
    }   
    
    
    public void read(DeviceHandle handle, int size, TransferCallback callback)
    {
        ByteBuffer buffer = ByteBuffer.allocateDirect(size);
        
        Transfer transfer = LibUsb.allocTransfer();
        byte endpoint = 2 | LibUsb.ENDPOINT_IN;
                
        LibUsb.fillInterruptTransfer(transfer, handle, endpoint, buffer, callback, new Object(), size);
        
        System.out.println("Writing " + size + " bytes to device");
        int result = LibUsb.submitTransfer(transfer);
        
        if (result != LibUsb.SUCCESS) {
            throw new LibUsbException("Unable to submit transfer", result);
        }
    }
    
    
    /**
     * Asynchronously write some data to the device.
     * 
     * @param handle
     *            The device handle.
     * @param size
     *            The number of bytes to read from the device.
     * @param callback
     *            The callback to execute when data has been received.
     */
    public void write(DeviceHandle handle, int size, TransferCallback callback)
    {                    
         
                          //1       2       3       4       5       6      7        
                          //12345678123456781234567812345678123456781234567812345678
        String myString = "the lazy dog jumped over the brown foX|\r\n";

        size= myString.length();
        
        ByteBuffer buffer = ByteBuffer.allocateDirect(size);
       // buffer.put(new byte[] { 'M', 'a', 'r', 't', 'y', '\r', '\n', '\0' });
       
        buffer.put(myString.getBytes());
        
        Transfer transfer = LibUsb.allocTransfer();
        byte endpoint = 1 | LibUsb.ENDPOINT_OUT;
                
        LibUsb.fillInterruptTransfer(transfer, handle, endpoint, buffer, callback, new Object(), size);
        
        System.out.println("Writing " + size + " bytes to device");
        int result = LibUsb.submitTransfer(transfer);
        
        if (result != LibUsb.SUCCESS) {
            throw new LibUsbException("Unable to submit transfer", result);
        }
    }

    final TransferCallback martyWritten = new TransferCallback()
    {
        int callBackTimes = 0;
        
        @Override
        public void processTransfer(Transfer transfer)
        {
            System.out.printf("%s Call back times %d, Sent %d%n", 
                                    Thread.currentThread().getName(),
                                    ++callBackTimes, 
                                    transfer.actualLength());
            LibUsb.freeTransfer(transfer);            

            //  When the writing is done do some reading.
            read(handle, 8, readABC);
        }
    };
    
    
    final TransferCallback readABC = new TransferCallback()
    {
        int callBackTimes = 0;
        
        @Override
        public void processTransfer(Transfer transfer)
        { 
            System.out.printf("%s ReadCall %d, Received %d%n", 
                                    Thread.currentThread().getName(),
                                    ++callBackTimes,                                    
                                    transfer.actualLength());
            
            CharBuffer charBuffer  = transfer.buffer().asCharBuffer();
            
            out.println("Read ...'" + charBuffer.toString() + "'");
            
            LibUsb.freeTransfer(transfer);            
        }
    };
}
