; Maybe safer if the pointers were save/restored.
; especially if try to print during some other peice of code using them.
    
    
    ; Print a string from program memory
PrintStr macro string
    movlw upper string
    movwf TBLPTRU, ACCESS 
    movlw high string
    movwf TBLPTRH, ACCESS
    movlw low  string
    movwf TBLPTRL, ACCESS
    call PrintStrFn
	endm

; Print a string from GFR General File Registors 
; Using FSR1 because the add to buffer uses FSR2
PrintData macro string
    movlw   high string
    movwf FSR1H, ACCESS

    movlw   low string
    movwf FSR1L, ACCESS

    call PrintDataFn
	endm
	
	
#define    SIZE       0x40 ;