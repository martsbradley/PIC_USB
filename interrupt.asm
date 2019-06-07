
        list p=16f628a, free


        #include <p16f628a.inc>
    	ERRORLEVEL -302 ;removes warning message about using proper bank that occured on the line 'CLRF TRISB'
        #include util_macros.INC
extern stackcounter, stackmax,stackwtmp

extern ButtonPressedValue

extern twosComplement16bits,Add32bit32bit
extern Add32bit32bit,twosComplement32bits
extern Add32bit32bit,argA,argB

extern deltaArrayIndex
extern deltaArray0,deltaArray1,deltaArray2,deltaArray3
global InterruptServiceRoutine

extern this_capture32, CaptureCounter, timer1_overflow


group3 udata_shr ; Data that goes into the shared bank area
    W_TEMP      res 1
    STATUS_TEMP res 1
    PCLATH_TEMP res 1
    FSR_TEMP res 1
   

PROG  code
;--------------------------------------------------------------------------
; Interrupt Service Routine
;--------------------------------------------------------------------------
InterruptServiceRoutine:

    MOVWF W_TEMP               ;W to TEMP register

    SWAPF STATUS,W            ;status to be saved into W
    CLRF STATUS                ;0, regardless of current bank, Clears IRP,RP1,RP0
    MOVWF STATUS_TEMP          ;status to bank zero STATUS_TEMP register
    MOVF PCLATH, W             ;required if using pages 1, 2 and/or 3
    MOVWF PCLATH_TEMP             ;PCLATH into W
    CLRF PCLATH              ;zero, regardless of current page
    movfw FSR        ; context save: FSR
    movwf FSR_TEMP    ; context save

InterruptPortChange:
    btfsc INTCON, RBIE       ;if RBIE == 0 skip next
    btfss INTCON, RBIF       ;if RBIF == 1 skip next
    goto  InterruptTimer0
    bcf   INTCON, RBIF       ;clear the interrupt flag.
    btfss PORTB, RB5         ;if Adjust !pressed check if Set pressed
    goto  InterruptPortChangeStartTimer
    btfsc PORTB, RB4         ;if Set pressed skip next
    goto  InterruptServiceEnd
InterruptPortChangeStartTimer:
    bcf   INTCON, RBIE       ; Prevent interrupt on change
    movlw d'60'              ; 255 - 195 = 60   [ 50 ms is ~     ]
    movfw TMR0               ; Start the timer. [ 195 * 256mills ]
    bsf   INTCON, TMR0IE     ; Enable timer0 interrupt
    goto  InterruptServiceEnd
InterruptTimer0:
    btfsc INTCON, TMR0IE     ; if TMR0IE = 0 skip next
    btfss INTCON, TMR0IF     ; if TMR0IF = 1 skip next
    goto  InterruptCapturePin1
    bcf   INTCON, TMR0IE     ; Stop Timer0 Interrupts
    clrf  TMR0               ; clear the counter for T0
    bcf   INTCON, TMR0IF     ; clear the interrupt
InterruptTimer0CheckButton4:
    btfsc PORTB, RB5         ; was button 4 pressed
    goto  InterruptTimer0CheckButton5
    movlw BUTTON_RB5_ADJUST_PRESSED
    movwf ButtonPressedValue
    goto  InterruptServiceEnd
InterruptTimer0CheckButton5:
    btfsc PORTB, RB4         ; was button 5 pressed
    goto  InterruptServiceEnd
    movlw BUTTON_RB4_SET_PRESSED
    movwf ButtonPressedValue
    goto InterruptServiceEnd

InterruptCapturePin1:
    btfss PIR1, CCP1IF
    goto InterruptTimer1
    bcf   PIR1, CCP1IF

    incf  CaptureCounter,f

    clear32bitReg this_capture32
    movfw CCPR1L           ;Grab the time of the
    movwf this_capture32   ;Capture into this_capture32.
    movfw CCPR1H
    movwf this_capture32+1;

    goto InterruptServiceEnd


InterruptTimer1:
    btfss PIR1, TMR1IF
    goto InterruptTimer1End
    banksel PIE1                ;bank 1
    btfss PIE1, TMR1IE
    goto InterruptTimer1End
    banksel TMR0                ;bank0
    bcf  PIR1,TMR1IF
    incf timer1_overflow,f
InterruptTimer1End:
    banksel TMR0    ;bank0

InterruptServiceEnd:
    movfw FSR_TEMP    ; context restore
    movwf FSR
    MOVF  PCLATH_TEMP, W
    MOVWF PCLATH
    SWAPF STATUS_TEMP,W
    MOVWF STATUS
    SWAPF W_TEMP,F
    SWAPF W_TEMP,W

    retfie






    end
