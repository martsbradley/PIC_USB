#include p18f2550.inc
#include util_macros.inc
     global print, InitUsartComms, RS232_SendByte


BANK0 udata
printchar_hi  res 1     ; string being printed.
printchar_lo  res 1
PrintCounter1 res 1
 
RS232_CODE  code

; To make this RS232 transmission interrupt driven
; create three bytes that  hold the upper middle and 
; lower portions of address of the string to be printed.
; 
; The table registers are adjusted by the handler 
; so these will need saved and restored by the 
; interrupt handler.

;         TBLPTRU TBLPTRH TBLPTRL
;
;
; 
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


    
lookupX:
    TBLRD*+	
    movf TABLAT, W, ACCESS    
    return
   
    
print:
    call lookupX             ; get a byte (this is the magic)
    addlw 0x00              ; Check for end of string \0 character
    btfsc STATUS,Z, ACCESS
    return                  ;\0 hit - return from print subroutine.
    call RS232_SendByte
    goto print              ; do it again
    
    
printNewLine:
    movlw 0x0D   ; CR
    call RS232_SendByte
    movlw 0x0A   ; LF
    call RS232_SendByte
    return
    
    
; Print the decimal digits without the leading zeros
; Initialise counter to process first seven digits.

RS232_SendByte:
    btfss   PIR1,TXIF ,ACCESS      ; If TXIF = 1 ready to send another char
    goto    RS232_SendByte
    movwf   TXREG,ACCESS
    return

InitUsartComms:                        ; Setup the usart hardware
    bsf   TRISC, 7, ACCESS
    bsf   TRISC, 6, ACCESS
    banksel TXSTA
    movlw 0x19            ; BAUD 9600 & FOSC 4000000L
    movwf SPBRG,ACCESS          ; 8 bit communication rather than 9bit
    movlw 0x24
    movwf TXSTA,ACCESS
    banksel RCSTA
    movlw 0x90            ; DIVIDER ((int)(FOSC/(16UL * BAUD) -1))
    movwf RCSTA,ACCESS          ; HIGH_SPEED 1
    return

    END                     ;Stop assembling here



;   INTCON:
;   GIE
;   1 = Enables all unmasked interrupts

;   IPEN
;   1 = Enables all unmasked peripheral interrupts



;   PIR1
;   TXIF: EUSART Transmit Interrupt Flag bit
;   1 = The EUSART transmit buffer, TXREG, is empty (cleared when TXREG is written)
;   0 = The EUSART transmit buffer is full



;   PIE1:
;   TXIE: EUSART Transmit Interrupt Enable bit
;   1 = Enables the EUSART transmit interrupt
