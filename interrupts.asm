    #include p18f2550.inc
    #include engr2210.inc

;    ERRORLEVEL -302 ;removes warning message about using proper bank that occured on the line 'CLRF TRISB'

    ;extern this_capture32, CaptureCounter, timer1_overflow

    global InterruptServiceRoutine
    global RS232_PTRU
    global RS232_PTRH
    global RS232_PTRL
    global SHADOW_RS232_PTRU
    global SHADOW_RS232_PTRH
    global SHADOW_RS232_PTRL

ACCESS_DATA  udata_acs
W_TEMP       res 1
STATUS_TEMP  res 1
PCLATH_TEMP  res 1

TBLPTRU_TEMP res 1  ; These need saved because the RS232 interrupt uses them.
TBLPTRH_TEMP res 1
TBLPTR_TEMP  res 1
TABLAT_TEMP  res 1


SHADOW_RS232_PTRU   res 1  ; The Macro PrintString will overwrite these without
SHADOW_RS232_PTRH   res 1  ; checking if the printing is currently using the
SHADOW_RS232_PTRL   res 1  ; variables below.  The function print
                           ; will overwrite the variables below if they are
                           ; not currently in use.
RS232_PTRU          res 1  ; These store the current print head of the RS232 output.
RS232_PTRH          res 1
RS232_PTRL          res 1

   
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

    MOVWF W_TEMP               ;W to TEMP register
    SWAPF STATUS,W             ;status to be saved into W
    CLRF STATUS                ;0, regardless of current bank, Clears IRP,RP1,RP0
    MOVWF STATUS_TEMP          ;status to bank zero STATUS_TEMP register
    MOVF PCLATH, W             ;required if using pages 1, 2 and/or 3
    MOVWF PCLATH_TEMP          ;PCLATH into W

    MOVWF PCLATH_TEMP          ;PCLATH into W

    CLRF PCLATH                ;zero, regardless of current page

    MOVF TBLPTRU, W            ; save table pointer registers.
    MOVWF TBLPTRU_TEMP

    MOVF TBLPTRH, W
    MOVWF TBLPTRH_TEMP

    MOVF TBLPTR, W
    MOVWF TBLPTR_TEMP

    MOVF TABLAT, W
    MOVWF TABLAT_TEMP

InterruptTransmitRS232Ready:

;   PIR1:TXIF: EUSART Transmit Interrupt Flag bit
;   1 = The EUSART transmit buffer, TXREG, is empty (cleared when TXREG is written)
;   0 = The EUSART transmit buffer is full


    ;btfsc PIE1, TXIE     ;skip if TXIE == 0 skip next because it is not enabled.
    btfss PIR1, TXIF     ;skip if TXIF == 1 means that TXREG is empty
    goto InterruptServiceEnd

    ; Now need to restore the saved RS232 table pointers to the table

    movf RS232_PTRU, W
    movwf TBLPTRU

    movf RS232_PTRH, W
    movwf TBLPTRH

    movf RS232_PTRL, W
    movwf TBLPTR

    tblrd*+	
    movf TABLAT, W, ACCESS    

    addlw 0x00              ; Check for end of string \0 character
    btfsc STATUS,Z, ACCESS  ; If zero bit is set, execute the goto
    goto InterruptRS232TxDone

    movwf TXREG,ACCESS    ; Send the data

    ; Now that the TBLPTR has been incremented, save it again into the RS232 Registers.

    movf TBLPTRU, W
    movwf RS232_PTRU

    movf TBLPTRH, W
    movwf RS232_PTRH

    movf TBLPTR, W
    movwf RS232_PTRL

    goto InterruptServiceEnd

InterruptRS232TxDone:
    ; The entire string has been transmitted, so disable TXIE.
    ; When the next string is sent TXIE will be enabled again.

    bcf PIE1, TXIE          ; Disable interrupt
    bcf TXSTA, TXEN, ACCESS ; Disable transmission.

InterruptServiceEnd:

    movf TABLAT_TEMP, W   ; restore table pointer registers.
    movwf TABLAT

    movf TBLPTR_TEMP, W    
    movwf TBLPTR

    movf TBLPTRH_TEMP, W
    movwf TBLPTRH

    movf TBLPTRU_TEMP, W            
    movwf TBLPTRU

    movf  PCLATH_TEMP, W
    movwf PCLATH
    swapf STATUS_TEMP,W
    movwf STATUS
    swapf W_TEMP,F
    swapf W_TEMP,W

    retfie

    end
