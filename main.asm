    list p=18f2550
    #include p18f2550.inc
    #include rs232.inc
    errorlevel -207
    config PLLDIV = 1, CPUDIV = OSC1_PLL2 , USBDIV = 2,FOSC = XT_XT 
    config IESO = OFF,PWRT = OFF,BOR = OFF, VREGEN = OFF,WDT = OFF,WDTPS = 32768   ;  I turned this off!!!
    config MCLRE = ON,LPT1OSC = OFF, PBADEN = OFF, CCP2MX = ON
    config STVREN = ON
    config LVP = OFF 
    config XINST = OFF
    config DEBUG = ON
    config CP0 = OFF, CP1 = OFF, CP2 = OFF, CP3 = OFF
    config CPB = OFF, CPD = OFF
    config WRT0 = OFF, WRT1 = OFF, WRT2 = OFF, WRT3 = OFF
    config WRTB = OFF, WRTC = OFF, WRTD = OFF
    config EBTR0 = OFF,EBTR1 = OFF,EBTR2 = OFF,EBTR3 = OFF,EBTRB = OFF

    
    extern InitUsartComms, print, InterruptServiceRoutine
    extern DelayOneSecond, DelayTenthSecond
    
.udata   
    COUNTER_H           res    1

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
LAUNCH_PROGRAM code     0x00  

    goto        Main                    
    nop
    nop
    goto        InterruptServiceRoutine
    nop
    nop
    nop
    nop
    nop
    nop
    goto        $


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MAIN_PROGRAM code

ONE:
    da "One\n\r"
TWO:
    da "Two\n\r"
THREE:
    da "Three\n\r"

Main
    call DelayOneSecond
    clrf   PORTA,  ACCESS
    movlw  0x0F
    movwf  ADCON1, ACCESS    ; Set up PORTA to be digital I/Os rather than A/D converter.
    clrf   TRISA,  ACCESS    ; Set up all PORTA pins to be digital outputs.
    

    bcf    RCON, IPEN            ; Disable priority levels on interrupts.
    bsf    INTCON, GIE           ; Enable all unmasked interrupts.
    bsf    INTCON, PEIE          ; Enables all unmasked peripheral interrupts.

    call   InitUsartComms


HERE:
    PrintString ONE
    call DelayTenthSecond
    call DelayTenthSecond
    PrintString TWO
    call DelayTenthSecond
    call DelayTenthSecond
    PrintString THREE
    call DelayTenthSecond
    call DelayTenthSecond
    goto HERE

    end
