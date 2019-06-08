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

    
    extern InitUsartComms, print, Delay,InterruptServiceRoutine
    
.udata   
    COUNTER_H           res    1

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
LAUNCH_PROGRAM code     0x00  

    goto        Main                    
    nop
    nop
    goto        $                    ; High-priority interrupt vector trap
    nop
    nop
    nop
    nop
    nop
    nop
    goto        InterruptServiceRoutine


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MAIN_PROGRAM code

HELLO_WORLD:
    da "HELLO WORLD\n\r"
DONE_THAT:
    da "DONE_THAT:\n\r"
MartyHERE:
    da "MartyHERE\n\r"

Main
    clrf        PORTA,  ACCESS
    movlw       0x0F
    movwf       ADCON1, ACCESS    ; Set up PORTA to be digital I/Os rather than A/D converter.
    clrf        TRISA,  ACCESS    ; Set up all PORTA pins to be digital outputs.
    
    call	InitUsartComms
    PrintString HELLO_WORLD

    PrintString MartyHERE

    repeat
        call Delay
        PrintString DONE_THAT
    forever

    end
