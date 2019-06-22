USTAT USB_USTAT UIR.TRNIF

USTAT 
    The SIE Transaction status register, it is only valid when the TRNIF interrupt
    flag is asserted.  USTAT is a four byte fifo.
    USTAT contains the endpoint number, and IN/OUT direction.

USB_USTAT
    This is a copy for the microcontroller of the USTAT buffer, take a copy while
    the SIE is under management of the microcontroller.

TRNIF
    Interrupt flag to show that USTAT is vaild.  When TRNIF is cleared USTAT is 
    moved onto the next of its four bytes.

USB_bytes_left
    This is a user managed byte
    
USB_BufferDescriptor 4 bytes long
    This is the buffer descriptor.

USB_buffer_data   8 bytes long.
    Must be the data....


UIR, UERRIF
UIR, ACTVIF
UIR, SOFIF
USB_USWSTAT
UIR, URSTIF

USB_error_flags
USB_buffer_desc

BD0OBC 
BD0IST
BD0OST 

Funciton to handle the clear.
Function to handle the status bulbs.



Describe.
---------
IN vs OUT 
    In - Informs the USB device that the host wishes to read information.
    Out - Informs the USB device that the host wishes to send information. 
DATA0/DATA1


SOF
    The SOF packet consists of an 11-bit frame number is sent by the host every 1 ms ± 500 ns.




StandardRequests this handles the setup request from the host.
Here the host might request a descriptor.
So the PIC updates the usb buffers to hold that descriptor such that at the next frame
the IN TOKEN from the host will mean that the descriptor is send.

(Above might be incorrect and needs confirmed.) VERY IMPORTANT TO UNDERSTAND.

The next frame the device needs to respond from ProcessInToken with the requested data.
lsusb -v -d 04d8:0014
