    #include p18f2550.inc
    #include util_macros.inc
    global print, InitUsartComms, 
    extern RS232_PTRU
    extern RS232_PTRH
    extern RS232_PTRL

    extern SHADOW_RS232_PTRU
    extern SHADOW_RS232_PTRH
    extern SHADOW_RS232_PTRL


; To make this RS232 transmission interrupt driven
; create three bytes that hold the upper middle and 
; lower portions of address of the string to be printed.
; 
; The table registers are adjusted by the handler 
; so these will need saved and restored by the 
; interrupt handler.

;         TBLPTRU TBLPTRH TBLPTRL
;
; Ensure that the PIR1,TXIF is 1 so ready to send.
; Update the three registers with the address of the
;
; The upper/high/low address of the string will be stored 
; to three rs232 registers RS232PTRU RS232PTRH RS232PTRL
;
; InterruptHandler:
;    Populate the TBLPTR registers from RS232PTR U/H/L
;    Lookup table to get the byte for W
;    Write out the data from W.
;    copy the latest TBLPTR registers to the RS232PTR U/H/L
;    Check for zero, clear interrupt flag.
;    Copy the byte to TXREG  
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

RS232_CODE  code

print:
    btfss PIE1, TXIE , ACCESS   ; skip next if TXIE == 1 skip prints if tx is busy
    btfsc TXSTA, TXEN, ACCESS   ; skip next if TXEN == 0 skip prints if tx is busy
    return

    movf SHADOW_RS232_PTRU, W  
    movwf RS232_PTRU           
                               
    movf SHADOW_RS232_PTRH, W  
    movwf RS232_PTRH

    movf SHADOW_RS232_PTRL, W
    movwf RS232_PTRL

    bsf PIE1, TXIE, ACCESS   ; Enable interrupt
    bsf TXSTA, TXEN, ACCESS  ; Enable transmission, causes an interrupt.
    return
    
;  printNewLine:
;      movlw 0x0D   ; CR
;      movlw 0x0A   ; LF
;      return
    
InitUsartComms:                 ; Setup the usart hardware
    bsf   TRISC, 7, ACCESS
    bsf   TRISC, 6, ACCESS
    banksel TXSTA
    movlw 0x19                  ; BAUD 9600 & FOSC 4000000L
    movwf SPBRG,ACCESS          ; 8 bit communication rather than 9bit
    movlw 0x04                  ; TXEN = 0
    movwf TXSTA,ACCESS          ; Asynchronous, TXEN
    banksel RCSTA
    movlw 0x90                  ; DIVIDER ((int)(FOSC/(16UL * BAUD) -1))
    movwf RCSTA,ACCESS          ; HIGH_SPEED 1
    return

    END                         ;Stop assembling here
