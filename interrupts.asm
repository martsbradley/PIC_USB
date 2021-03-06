    #include p18f2550.inc
    #include engr2210.inc
    #include usb_defs.inc
;    ERRORLEVEL -302 ;removes warning message about using proper bank that occured on the line 'CLRF TRISB'


    global InterruptServiceRoutine, INTERRUPT_FLAG
     
    extern RS232_ReadByteFromBuffer
    extern clearNonControlEndPoints, setupEndpoint0
    
    ; should consider putting these usb registers into the access bank.
    extern USB_curr_config,USB_USWSTAT,USB_device_status
    extern USB_BufferDescriptor, USB_USTAT, USB_error_flags
    
ACCESS_DATA  udata_acs
PCLATH_TEMP  res 1

TBLPTRU_TEMP res 1  ; These need saved because the RS232 interrupt uses them.
TBLPTRH_TEMP res 1
TBLPTRL_TEMP res 1
TABLAT_TEMP  res 1

FSR2H_TEMP res 1
FSR2L_TEMP res 1


RS232_BUFFER_CHAR   res 1  ; The Macro PrintString will overwrite these without
 
INTERRUPT_FLAG res 1	   ; Updated with the details of the interrupt.
FSR0H_TEMP  res 1
FSR0L_TEMP  res 1
 

 
   
INTERRUPT_CODE  code
;--------------------------------------------------------------------------
; Interrupt Service Routine
;
;
;
;
;   PIE1:
;   TXIE: EUSART Transmit Interrupt Enable bit
;   1 = Enables the EUSART transmit interrupt
;--------------------------------------------------------------------------
InterruptServiceRoutine:

    MOVF PCLATH, W             ;required if using pages 1, 2 and/or 3
    MOVWF PCLATH_TEMP, ACCESS  ;PCLATH into W

    CLRF PCLATH                ;zero, regardless of current page


    MOVF TBLPTRU, W            ; save table pointer registers.
    MOVWF TBLPTRU_TEMP, ACCESS

    MOVF TBLPTRH, W
    MOVWF TBLPTRH_TEMP, ACCESS

    MOVF TBLPTRL, W
    MOVWF TBLPTRL_TEMP, ACCESS

    MOVF TABLAT, W
    MOVWF TABLAT_TEMP, ACCESS

    MOVF  FSR2H, W
    MOVWF FSR2H_TEMP, ACCESS

    MOVF  FSR2L, W
    MOVWF FSR2L_TEMP, ACCESS

    MOVF  FSR0H, W
    MOVWF FSR0H_TEMP, ACCESS

    MOVF  FSR0L, W
    MOVWF FSR0L_TEMP, ACCESS



InterruptTransmitRS232Ready:
    btfss PIR1, TXIF, ACCESS ;skip if TXIF == 1 means ready to send another byte.
    goto InterruptServiceEnd

    btfsc PIE1, TXIE, ACCESS ;skip if TXIE == 0 because transmission disabled.
    goto SendRS232
    
    btfss PIR2, USBIF, ACCESS ; 
    goto InterruptServiceEnd
    
USBInterruptCheck:    
    
    ifset    UIR, UERRIF, ACCESS    ;  If an Error Condition Interrupt.
        clrf   UEIR, ACCESS           ;  Clear the error in software.
	bsf INTERRUPT_FLAG, USB_ERROR_FLAG_BIT, ACCESS
        goto USBInterruptHandled
    endi
    
    ifset   UIR, SOFIF, ACCESS     ;  Start of Frame token received by SIE
        bcf UIR, SOFIF, ACCESS     ;  Clear this flag
        goto USBInterruptHandled
    endi
    
    ifset   UIR, STALLIF, ACCESS   ; A stall handshake was sent by the SIE
        bcf UIR, STALLIF, ACCESS   ; clear the stall handshake
	bsf INTERRUPT_FLAG, USB_STALL_FLAG_BIT, ACCESS
        goto USBInterruptHandled
    endi	
    
    ifset   UIR,  IDLEIF, ACCESS   ;  Idle condition detected (been idle for 3ms or more)

        bsf UIE, ACTVIE, ACCESS    ;  Unmask the activity interrupt.
        bsf UCON, SUSPND, ACCESS   ;  Suspend the SIE to conserve power.
        bcf UIR,  IDLEIF, ACCESS   ;  Clear that idle condition.

	bsf INTERRUPT_FLAG, USB_IDLE_FLAG_BIT, ACCESS
        goto USBInterruptHandled
    endi
    
    ifset   UIR, ACTVIF, ACCESS    ;  There was activity on the USB
        bcf UCON, SUSPND, ACCESS   ;  Unsuspend the SIE.

USB_ACTIVITYWAKEUPLOOP:            ; Datasheet said
        btfss UIR, ACTVIF, ACCESS  ; Need to keep trying to clear the
        bra USB_ACTIVITYWAKEUP_DONE; flag after a suspend.
        bcf UIR, ACTVIF, ACCESS
        bra USB_ACTIVITYWAKEUPLOOP
USB_ACTIVITYWAKEUP_DONE:


       bcf UIE, ACTVIE, ACCESS    ;  Mask the activity interrupt.
       bsf INTERRUPT_FLAG, USB_ACTIVITY_FLAG_BIT, ACCESS
       goto USBInterruptHandled
    endi
    
    ifset UIR, URSTIF, ACCESS    ; USB Reset occurred.
        banksel USB_curr_config
        clrf    USB_curr_config, BANKED
        bcf     UIR, TRNIF, ACCESS    ; clear TRNIF four times to clear out the USTAT FIFO
        bcf     UIR, TRNIF, ACCESS
        bcf     UIR, TRNIF, ACCESS
        bcf     UIR, TRNIF, ACCESS

        clrf    UEP0, ACCESS          ; clear all EP control registers

        call clearNonControlEndPoints
        call setupEndpoint0

        clrf    UADDR, ACCESS         ; set USB Address to 0
        clrf    UIR, ACCESS           ; clear all the USB interrupt flags

        movlw   0xFF
        movwf   UEIE, ACCESS          ; Enable all usb error interrupts
        banksel USB_USWSTAT
        movlw   DEFAULT_STATE         ; Enter default state since this is a reset.
        movwf   USB_USWSTAT, BANKED
        movlw   0x01                  ; Self powered, remote wakeup disabled
        movwf   USB_device_status, BANKED
	
	#ifdef SHOW_ENUM_STATUS
        movlw   0xE0
        andwf   PORTB, F, ACCESS
        bsf     PORTB, 1, ACCESS      ; set bit 1 of PORTB to indicate Powered state
	#endif
	bsf INTERRUPT_FLAG, USB_RESET_FLAG_BIT, ACCESS
        goto USBInterruptHandled
    endi    


    ifset  UIR, TRNIF, ACCESS    ; Processing of pending transaction is complete;

        movlw    0x04              ; Buffer Descriptor table starts at Address 0x0400
        movwf    FSR0H, ACCESS     ; Indirect addressing, copy in high byte.
        movf     USTAT, W, ACCESS  ; Read USTAT register for endpoint information
        andlw    0x7C              ; Mask out bits other than Endpoint and Direction
        movwf    FSR0L, ACCESS     ;    0000100 0EEEED00 (FSR0H-FSR0L)
        banksel  USB_BufferDescriptor   ; eg 0000100 00000000 EP0 Out -> 0x400  
        movf     POSTINC0, W, ACCESS    ;    0000100 00000100 EP0 IN  -> 0x404
                                        ;    0000100 00001000 EP1 Out -> 0x408
                                        ;    0000100 00001100 EP1 In  -> 0x40C
        movwf    USB_BufferDescriptor, BANKED  ; Copy received data to USB_BufferDescriptor
        movf     POSTINC0, W, ACCESS
        movwf    USB_BufferDescriptor+1, BANKED
        movf     POSTINC0, W, ACCESS
        movwf    USB_BufferDescriptor+2, BANKED
        movf     POSTINC0, W, ACCESS
        movwf    USB_BufferDescriptor+3, BANKED ; USB_BufferDescriptor now populated.
        movf     USTAT, W, ACCESS
        movwf    USB_USTAT, BANKED  ; Save the USB status register
        bcf      UIR, TRNIF, ACCESS ; Clear transaction complete interrupt flag
                                    ; USTAT FIFO can advance.
        clrf    USB_error_flags, BANKED    ; clear USB error flags

        bsf INTERRUPT_FLAG, USB_TRNIE_FLAG_BIT, ACCESS
        bcf UIE, TRNIE, ACCESS   ; stop taking futher interrupts.
        bcf UIR, TRNIF, ACCESS   ; clear the interrupt flag.

        goto USBInterruptHandled

    endi
    
    
USBInterruptHandled:
    bcf PIR2, USBIF, ACCESS	   ;  Clear the USB Interrupt flag.
    goto InterruptServiceEnd
    
SendRS232:
    call  RS232_ReadByteFromBuffer
    movwf RS232_BUFFER_CHAR, ACCESS
    xorlw 0xFF          ;  0xFF xor char if char was FF then zero bit set. 
    
    btfsc STATUS, Z, ACCESS  ; If zero bit is clear, skip the goto
    goto  InterruptRS232TxDone
    
    movf  RS232_BUFFER_CHAR, W, ACCESS
    movwf TXREG, ACCESS      ; Send the data

   goto InterruptServiceEnd

InterruptRS232TxDone:
    ; The read of the buffer returned 0xFF so
    ; the entire buffer is empty, therefore disable TXIE.
    ; When the next string is sent TXIE will be enabled again.

    ;bcf TXSTA, TXEN, ACCESS  ; Disable transmission.
    bcf PIE1, TXIE,  ACCESS  ; Disable interrupts

InterruptServiceEnd:

    movf  FSR0H_TEMP, W, ACCESS
    movwf FSR0H, ACCESS
        
    movf  FSR0L_TEMP, W, ACCESS
    movwf FSR0L, ACCESS

    movf FSR2H_TEMP, W
    movwf FSR2H, ACCESS

    movf FSR2L_TEMP, W            
    movwf FSR2L, ACCESS



    movf TABLAT_TEMP, W   ; restore table pointer registers.
    movwf TABLAT, ACCESS

    movf TBLPTRL_TEMP, W    
    movwf TBLPTRL, ACCESS

    movf TBLPTRH_TEMP, W
    movwf TBLPTRH, ACCESS

    movf TBLPTRU_TEMP, W            
    movwf TBLPTRU, ACCESS


    movf  PCLATH_TEMP, W
    movwf PCLATH, ACCESS

    retfie  FAST  ;STATUS, WREG and BSR handled by fast stack.

    end
