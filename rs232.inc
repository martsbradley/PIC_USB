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
