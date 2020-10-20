package com.mbradley;

import org.usb4java.Context;
import org.usb4java.LibUsb;
import org.usb4java.LibUsbException;

public class EventHandlingThread extends Thread
{
    /** If thread should abort. */
    private volatile boolean abort;
    private final Context context;
    private int count = 1;

    public EventHandlingThread(Context context) {
        this.context = context;
    }
    /**
     * Aborts the event handling thread.
     */
    public void abort()
    {
        this.abort = true;
    }
 
    @Override
    public void run()
    {
        System.out.println("Event Thread is" + Thread.currentThread().getName());
        while (!this.abort && count++ < 4)
        {
            // Let libusb handle pending events. This blocks until events
            // have been handled, a hotplug callback has been deregistered
            // or the specified time of 0.5 seconds (Specified in
            // Microseconds) has passed.
            
          //  System.out.println("Handling events starting");
            
            int result = LibUsb.handleEventsTimeout(context, 500000);
            
          //  System.out.println("Handling events. done");
            if (result != LibUsb.SUCCESS)
                throw new LibUsbException("Unable to handle events", result);
        }
    }
}
