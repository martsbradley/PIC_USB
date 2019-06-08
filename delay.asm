    #include p18f2550.inc
    global DelayOneSecond
    global DelayTenthSecond

BANK0 udata
CounterA  res 1     ; string being printed.
CounterB  res 1
  
DELAY_CODE  code

DelayOneSecond:    
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

DelayTenthSecond:
    banksel CounterA
    movlw	0x1F
    movwf	CounterA
    movlw	0x4F
    movwf	CounterB
Delay_0:
    decfsz	CounterA, f
    goto	$+2
    decfsz	CounterB, f
    goto	Delay_0
                    ;2 cycles
    goto	$+2
    return

    
    
    END
