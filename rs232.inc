    extern SHADOW_RS232_PTRU
    extern SHADOW_RS232_PTRH
    extern SHADOW_RS232_PTRL

PrintString macro string
    movlw upper string
    movwf SHADOW_RS232_PTRU, ACCESS 
    movlw high string
    movwf SHADOW_RS232_PTRH, ACCESS
    movlw low  string
    movwf SHADOW_RS232_PTRL, ACCESS
    call print
	endm


; Print a string from data memory
PrintData macro string
    movlw   high string
    movwf   SHADOW_RS232_PTRH, ACCESS
    movlw   low string
    movwf   SHADOW_RS232_PTRL, ACCESS
    call printData
	endm






   ;movwf   FSR2H, ACCESS
   ;movlw   low string
   ;movwf   FSR2L, ACCESS
