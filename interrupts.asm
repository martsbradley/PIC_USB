    #include p18f2550.inc
    #include engr2210.inc

;    ERRORLEVEL -302 ;removes warning message about using proper bank that occured on the line 'CLRF TRISB'


    global InterruptServiceRoutine
     
    extern RS232_ReadByteFromBuffer

ACCESS_DATA  udata_acs
PCLATH_TEMP  res 1

TBLPTRU_TEMP res 1  ; These need saved because the RS232 interrupt uses them.
TBLPTRH_TEMP res 1
TBLPTRL_TEMP res 1
TABLAT_TEMP  res 1

FSR2H_TEMP res 1
FSR2L_TEMP res 1


RS232_BUFFER_CHAR   res 1  ; The Macro PrintString will overwrite these without
 


   
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

    MOVF FSR2H, W
    MOVWF FSR2H_TEMP, ACCESS

    MOVF FSR2L, W
    MOVWF FSR2L_TEMP, ACCESS

InterruptTransmitRS232Ready:
    btfss PIR1, TXIF, ACCESS ;skip if TXIF == 1 means ready to send another byte.
    goto InterruptServiceEnd

    btfsc PIE1, TXIE, ACCESS ;skip if TXIE == 0 because transmission disabled.
    goto SendRS232
    
    
USBInterruptCheck:    
    select
    caseset    UIR, UERRIF, ACCESS    ;  If an Error Condition Interrupt.
        clrf   UEIR, ACCESS           ;  Clear the error in software.
        break
    caseset    UIR, SOFIF, ACCESS     ;  Start of Frame token received by SIE
        bcf    UIR, SOFIF, ACCESS     ;  Clear this flag
        break
    caseset    UIR, STALLIF, ACCESS   ; A stall handshake was sent by the SIE
        bcf    UIR, STALLIF, ACCESS   ; clear the stall handshake
        break	
    caseset    UIR,  IDLEIF, ACCESS   ;  Idle condition detected (been idle for 3ms or more)
        bcf    UIR,  IDLEIF, ACCESS   ;  Clear that idle condition.
        bsf    UCON, SUSPND, ACCESS   ;  Suspend the SIE to conserve power.
        break
    caseset UIR, ACTVIF, ACCESS       ;  There was activity on the USB
        bcf    UIR, ACTVIF, ACCESS    ;  Clear the activity detection flag.
        bcf    UCON, SUSPND, ACCESS   ;  Unsuspend the SIE.
        break
     ends
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
