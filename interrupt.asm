    #include p18f2550.inc
    #include engr2210.inc

;    ERRORLEVEL -302 ;removes warning message about using proper bank that occured on the line 'CLRF TRISB'

    ;extern this_capture32, CaptureCounter, timer1_overflow

    global InterruptServiceRoutine

ACCESS_DATA  udata_acs
W_TEMP       res 1
STATUS_TEMP  res 1
PCLATH_TEMP  res 1

TBLPTRU_TEMP res 1  ; These need saved because the RS232 interrupt uses them.
TBLPTRH_TEMP res 1
TBLPTR_TEMP  res 1
TABLAT_TEMP  res 1

RS232_PTRU   res 1  ; These store the current print head of the RS232 output.
RS232_PTRH   res 1
RS232_PTRL   res 1

   
INTERRUPT_CODE  code
;--------------------------------------------------------------------------
; Interrupt Service Routine
;--------------------------------------------------------------------------
InterruptServiceRoutine:

    MOVWF W_TEMP               ;W to TEMP register
    SWAPF STATUS,W             ;status to be saved into W
    CLRF STATUS                ;0, regardless of current bank, Clears IRP,RP1,RP0
    MOVWF STATUS_TEMP          ;status to bank zero STATUS_TEMP register
    MOVF PCLATH, W             ;required if using pages 1, 2 and/or 3
    MOVWF PCLATH_TEMP          ;PCLATH into W

    MOVWF PCLATH_TEMP          ;PCLATH into W

    CLRF PCLATH                ;zero, regardless of current page

    MOVF TBLPTRU, W            ; save table pointer registers.
    MOVWF TBLPTRU_TEMP

    MOVF TBLPTRH, W
    MOVWF TBLPTRH_TEMP

    MOVF TBLPTR, W
    MOVWF TBLPTR_TEMP

    MOVF TABLAT, W
    MOVWF TABLAT_TEMP

InterruptTransmitRS232Ready:
    btfsc PIE1, TXIE     ;if TXIE == 0 skip next because it is not enabled.
    btfss PIR1, TXIF     ;if TXIR == 1 skip next because ready to transmit.
    goto InterruptServiceEnd

    ; Now need to restore the saved RS232 table pointers to the table

    movf RS232_PTRU, W
    movwf TBLPTRU

    movf RS232_PTRH, W
    movwf TBLPTRH

    movf RS232_PTRL, W
    movwf TBLPTR

    tblrd*+	
    MOVF TABLAT, W, ACCESS    

    addlw 0x00              ; Check for end of string \0 character
    btfsc STATUS,Z, ACCESS
    goto InterruptRS232TxDone

    movwf   TXREG,ACCESS    ; Send the data

    ; Now that the TBLPTR has been incremented, save it again into the RS232 Registers.

    movf TBLPTRU, W
    movwf RS232_PTRU

    movf TBLPTRH, W
    movwf RS232_PTRH

    movf TBLPTR, W
    movwf RS232_PTRL


InterruptRS232TxDone:
    ; The entire string has been transmitted, so disable TXIE.
    ; When the next string is sent TXIE will be enabled again.
    bcf PIE1, TXIE     

InterruptServiceEnd:

    movf TABLAT_TEMP, W   ; restore table pointer registers.
    movwf TABLAT

    movf TBLPTR_TEMP, W    
    movwf TBLPTR

    movf TBLPTRH_TEMP, W
    movwf TBLPTRH

    movf TBLPTRU_TEMP, W            
    movwf TBLPTRU

    movf  PCLATH_TEMP, W
    movwf PCLATH
    swapf STATUS_TEMP,W
    movwf STATUS
    swapf W_TEMP,F
    swapf W_TEMP,W

    retfie

    end




;   InterruptPortChange:
;       btfsc INTCON, RBIE       ;if RBIE == 0 skip next
;       btfss INTCON, RBIF       ;if RBIF == 1 skip next
;       goto  InterruptTimer0
;       bcf   INTCON, RBIF       ;clear the interrupt flag.
;       btfss PORTB, RB5         ;if Adjust !pressed check if Set pressed
;       goto  InterruptPortChangeStartTimer
;       btfsc PORTB, RB4         ;if Set pressed skip next
;       goto  InterruptServiceEnd
;   InterruptPortChangeStartTimer:
;       bcf   INTCON, RBIE       ; Prevent interrupt on change
;       movlw d'60'              ; 255 - 195 = 60   [ 50 ms is ~     ]
;       ;MOVFmovfw TMR0               ; Start the timer. [ 195 * 256mills ]
;       bsf   INTCON, TMR0IE     ; Enable timer0 interrupt
;       goto  InterruptServiceEnd
;   InterruptTimer0:
;       btfsc INTCON, TMR0IE     ; if TMR0IE = 0 skip next
;       btfss INTCON, TMR0IF     ; if TMR0IF = 1 skip next
;       goto  InterruptCapturePin1
;       bcf   INTCON, TMR0IE     ; Stop Timer0 Interrupts
;       clrf  TMR0               ; clear the counter for T0
;       bcf   INTCON, TMR0IF     ; clear the interrupt
;   InterruptTimer0CheckButton4:
;       btfsc PORTB, RB5         ; was button 4 pressed
;       goto  InterruptTimer0CheckButton5
;       ;movwf ButtonPressedValue
;       goto  InterruptServiceEnd
;   InterruptTimer0CheckButton5:
;       btfsc PORTB, RB4         ; was button 5 pressed
;       goto  InterruptServiceEnd
;       ;movlw BUTTON_RB4_SET_PRESSED
;       ;movwf ButtonPressedValue
;       goto InterruptServiceEnd

;   InterruptCapturePin1:
;       btfss PIR1, CCP1IF
;       goto InterruptTimer1
;       bcf   PIR1, CCP1IF

;       ;incf  CaptureCounter,f

;       ;clear32bitReg this_capture32
;       ;movfw CCPR1L           ;Grab the time of the
;       ;movwf this_capture32   ;Capture into this_capture32.
;       ;movfw CCPR1H
;       ;movwf this_capture32+1;

;       goto InterruptServiceEnd


;   InterruptTimer1:
;       btfss PIR1, TMR1IF
;       goto InterruptTimer1End
;       banksel PIE1                ;bank 1
;       btfss PIE1, TMR1IE
;       goto InterruptTimer1End
;       banksel TMR0                ;bank0
;       bcf  PIR1,TMR1IF
;       ;incf timer1_overflow,f
;   InterruptTimer1End:
;       banksel TMR0    ;bank0
