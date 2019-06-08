



PrintString macro string
    movlw upper string
    movwf TBLPTRU, ACCESS 
    movlw high string
    movwf TBLPTRH, ACCESS
    movlw low  string
    movwf TBLPTRL, ACCESS
    call print
	endm
