    #include p18f2550.inc
    #include "usb_defs.inc"
    global clearNonControlEndPoints, setupEndpoint0, setupEndpoint1,setupEndpoint2
USB_PROGRAM code
 
 
 
 ;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
setupEndpoint0:
    banksel BD0OBC
    movlw   MAX_PACKET_SIZE       ; 8 bytes lowest packet size for low and high speed.
    movwf   BD0OBC, BANKED
    movlw   low (USB_Buffer+  0*MAX_PACKET_SIZE); Get low bits from for the USB_Buffer
    movwf   BD0OAL, BANKED        ; EP0 OUT gets a buffer...
    movlw   high (USB_Buffer+ 0*MAX_PACKET_SIZE); Get high bits from for the USB_Buffer
    movwf   BD0OAH, BANKED        ; ...set up its address
    movlw   SIE_DTSEN             ; set UOWN bit (USB can write)
    movwf   BD0OST, BANKED        ; Controller hands over the buffer to the SIE.

    movlw   low (USB_Buffer + 1*MAX_PACKET_SIZE)    ; EP0 IN gets a buffer...
    movwf   BD0IAL, BANKED
    movlw   high (USB_Buffer+ 1*MAX_PACKET_SIZE)
    movwf   BD0IAH, BANKED        ; ...set up its address
    movlw   CPU_DTSEN
    movwf   BD0IST, BANKED        ; Microcontroller owns EP0 I

    movlw   ENDPT_CONTROL         ; Setup UEP0 by setting EPHSHK, EPOUTEN & EPINEN
    movwf   UEP0, ACCESS          ; EP0 is a control pipe and requires an ACK
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
setupEndpoint1:
    banksel BD1OBC

    movlw   MAX_PACKET_SIZE       ; 8 bytes lowest packet size for low and high speed.
    movwf   BD1OBC, BANKED
    movlw   low (USB_Buffer+  2*MAX_PACKET_SIZE)    ; EP1 OUT gets a buffer...
    movwf   BD1OAL, BANKED
    movlw   high (USB_Buffer+ 2*MAX_PACKET_SIZE)    ; EP1 OUT gets a buffer...
    movwf   BD1OAH, BANKED
    movlw   SIE_DTS_DTSEN         ; set UOWN bit Data1 Data synchronization enabled.
    movlw   SIE_DTSEN             ; set UOWN bit (SIE can write)
    movwf   BD1OST, BANKED        ; synchronization byte enabled.

    movlw   ENDPT_OUT_ONLY        ; EP1 is gets output from host
    movwf   UEP1, ACCESS          ;

    return
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
setupEndpoint2:
    banksel BD2IBC
    movlw   MAX_PACKET_SIZE       ; 8 bytes lowest packet size for low and high speed.
    movwf   BD2IBC, BANKED
    movlw   low (USB_Buffer+  4*MAX_PACKET_SIZE)    ; EP1 OUT gets a buffer...
    movwf   BD2IAL, BANKED
    movlw   high (USB_Buffer+ 4*MAX_PACKET_SIZE)    ; EP1 OUT gets a buffer...
    movwf   BD2IAH, BANKED
    movlw   SIE_DTSEN             ; Synchronization enabled.
    movwf   BD2IST, BANKED        ;

    movlw   ENDPT_IN_ONLY        ; EP2 sends the host data
    movwf   UEP2, ACCESS          ;
    return
 
 ;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
clearNonControlEndPoints:
    clrf    UEP1, ACCESS          ; to disable all endpoints.
    clrf    UEP2, ACCESS
    clrf    UEP3, ACCESS
    clrf    UEP4, ACCESS
    clrf    UEP5, ACCESS
    clrf    UEP6, ACCESS
    clrf    UEP7, ACCESS
    clrf    UEP8, ACCESS
    clrf    UEP9, ACCESS
    clrf    UEP10, ACCESS
    clrf    UEP11, ACCESS
    clrf    UEP12, ACCESS
    clrf    UEP13, ACCESS
    clrf    UEP14, ACCESS
    clrf    UEP15, ACCESS
    return
    
    end