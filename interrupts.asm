    #include p18f2550.inc
    #include engr2210.inc

;    ERRORLEVEL -302 ;removes warning message about using proper bank that occured on the line 'CLRF TRISB'


    global InterruptServiceRoutine
    global RS232_PTRU
    global RS232_PTRH
    global RS232_PTRL
    global SHADOW_RS232_PTRU
    global SHADOW_RS232_PTRH
    global SHADOW_RS232_PTRL
    global PRINTDATA_OR_PROG

ACCESS_DATA  udata_acs
PCLATH_TEMP  res 1

TBLPTRU_TEMP res 1  ; These need saved because the RS232 interrupt uses them.
TBLPTRH_TEMP res 1
TBLPTRL_TEMP res 1
TABLAT_TEMP  res 1

FSR2H_TEMP res 1
FSR2L_TEMP res 1


SHADOW_RS232_PTRU   res 1  ; The Macro PrintString will overwrite these without
SHADOW_RS232_PTRH   res 1  ; checking if the printing is currently using the
SHADOW_RS232_PTRL   res 1  ; variables below.  The function print
                           ; will overwrite the variables below if they are
                           ; not currently in use.
RS232_PTRU          res 1  ; These store the current print head of the RS232 output.
RS232_PTRH          res 1
RS232_PTRL          res 1

PRINTDATA_OR_PROG           res 1  ; 0x01 if Data, otherwise print from program memory


   
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

    btfss PIE1, TXIE, ACCESS ;skip if TXIE == 1 because transmission enabled.
    goto InterruptServiceEnd


    ; Now need to restore the saved RS232 table pointers to the table

    btfsc PRINTDATA_OR_PROG, 0, ACCESS   ; Check whether to send data from program 
    goto SendRS232FromData               ; memory or from data?

SendRS232FromProgram:
    movf RS232_PTRU, W
    movwf TBLPTRU, ACCESS

    movf RS232_PTRH, W
    movwf TBLPTRH, ACCESS

    movf RS232_PTRL, W
    movwf TBLPTRL, ACCESS

    tblrd*+                 ; Read byte and increment pointer
    movf TABLAT, W, ACCESS  ; Take the read byte from the latch.

    addlw 0x00              ; Check for end of string \0 character
    btfsc STATUS,Z, ACCESS  ; If zero bit is clear, skip the goto
    goto InterruptRS232TxDone

    movwf TXREG,ACCESS      ; Send the data

    ; Now TABLAT holds the data and the TBLPTR pointer has been incremented
    ; to the next address, so put the new address into the RS232 registers.

    movf TBLPTRU, W
    movwf RS232_PTRU, ACCESS

    movf TBLPTRH, W
    movwf RS232_PTRH, ACCESS

    movf TBLPTRL, W
    movwf RS232_PTRL, ACCESS
    goto InterruptServiceEnd


SendRS232FromData:
    movf RS232_PTRH, W
    movwf FSR2H, ACCESS

    movf RS232_PTRL, W
    movwf FSR2L, ACCESS


    movf POSTINC2, W    ; Read byte and increment pointer

    addlw 0x00              ; Check for end of string \0 character
    btfsc STATUS,Z, ACCESS  ; If zero bit is clear, skip the goto
    goto InterruptRS232TxDone

    movwf TXREG,ACCESS      ; Send the data

    movf FSR2H, W
    movwf RS232_PTRH, ACCESS

    movf FSR2L, W
    movwf RS232_PTRL, ACCESS

    goto InterruptServiceEnd

InterruptRS232TxDone:
    ; The entire string has been transmitted, so disable TXIE.
    ; When the next string is sent TXIE will be enabled again.

    bcf PIE1, TXIE,  ACCESS   ; Disable interrupts

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
