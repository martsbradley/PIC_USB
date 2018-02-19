#include <p18f2550.inc>
 
     global Delay

BANK0 udata
CounterA  res 1     ; string being printed.
CounterB  res 1
  
PROG  code

Delay:    ; Currently configured for a one second delay.
    banksel CounterA
    movlw .250
    movwf CounterB, BANKED   
Delay_outer:  
    movlw .222                
    movwf CounterA, BANKED           
Delay_1:
    goto $+2     ; Each nop (column 3 of spreadsheet) is 3 cycles.  
    goto $+2
    goto $+2
    goto $+2
    goto $+2
    decfsz  CounterA, f, BANKED
    bra     Delay_1            
    decfsz  CounterB, f, BANKED 
    bra     Delay_outer        
    return 
    
    
    END
