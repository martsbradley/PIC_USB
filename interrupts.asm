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
TBLPTRL_TEMP  res 1
TABLAT_TEMP  res 1


SHADOW_RS232_PTRU   res 1  ; The Macro PrintString will overwrite these without
SHADOW_RS232_PTRH   res 1  ; checking if the printing is currently using the
SHADOW_RS232_PTRL   res 1  ; variables below.  The function print
                           ; will overwrite the variables below if they are
                           ; not currently in use.
RS232_PTRU          res 1  ; These store the current print head of the RS232 output.
RS232_PTRH          res 1
RS232_PTRL          res 1

WRITE_THIS          res 1

   
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

    MOVWF W_TEMP, ACCESS       ;W to TEMP register
    SWAPF STATUS,W             ;status to be saved into W
    CLRF STATUS                ;0, regardless of current bank, Clears IRP,RP1,RP0
    MOVWF STATUS_TEMP, ACCESS  ;status to bank zero STATUS_TEMP register
    MOVF PCLATH, W             ;required if using pages 1, 2 and/or 3
    MOVWF PCLATH_TEMP, ACCESS  ;PCLATH into W

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

    CLRF TABLAT, ACCESS

InterruptTransmitRS232Ready:
    btfsc PIR1, TXIF, ACCESS ;skip if TXIF == 0 means that TXREG is empty
    btfss PIE1, TXIE, ACCESS ;skip if TXIE == 1 skip next because it is enabled.
    goto InterruptServiceEnd

    btfss TXSTA, TXEN, ACCESS ;skip if TXEN == 1 because transmission enabled.
    goto InterruptServiceEnd


    ; Now need to restore the saved RS232 table pointers to the table

    movf RS232_PTRU, W
    movwf TBLPTRU, ACCESS

    movf RS232_PTRH, W
    movwf TBLPTRH, ACCESS

    movf RS232_PTRL, W
    movwf TBLPTRL, ACCESS

    tblrd*+	


    movf TABLAT, W, ACCESS    
    movwf WRITE_THIS

    addlw 0x00              ; Check for end of string \0 character
    btfsc STATUS,Z, ACCESS  ; If zero bit is clear, skip the goto
    goto InterruptRS232TxDone

    movf WRITE_THIS, W
    movwf TXREG,ACCESS      ; Send the data

    ; Now TABLAT holds the data and the TBLPTR pointer has been incremented
    ; So put the new pointer address into the RS232 registers.

    movf TBLPTRU, W
    movwf RS232_PTRU, ACCESS

    movf TBLPTRH, W
    movwf RS232_PTRH, ACCESS

    movf TBLPTRL, W
    movwf RS232_PTRL, ACCESS

    goto InterruptServiceEnd

InterruptRS232TxDone:
    ; The entire string has been transmitted, so disable TXIE.
    ; When the next string is sent TXIE will be enabled again.


    clrf RS232_PTRU, ACCESS
    clrf RS232_PTRH, ACCESS
    clrf RS232_PTRL, ACCESS
    clrf TBLPTRU, ACCESS
    clrf TBLPTRH, ACCESS
    clrf TBLPTRL, ACCESS
    
    bcf TXSTA, TXEN, ACCESS ; Disable transmission.
    bcf PIE1, TXIE, ACCESS  ; Disable interrupt

   ;movlw 0xAB;             ; Writing something noticable to TXREG clears TXIF.
   ;movwf TXREG,ACCESS      ; 0xAB should not be output.

InterruptServiceEnd:

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
    swapf STATUS_TEMP,W
    movwf STATUS, ACCESS
    swapf W_TEMP,F, ACCESS
    swapf W_TEMP,W, ACCESS

    retfie

    end
