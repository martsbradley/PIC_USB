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
    extern SHADOW_RS232_PTRU
    extern SHADOW_RS232_PTRH
    extern SHADOW_RS232_PTRL
    
.udata   
    COUNTER_H           res    1

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
LAUNCH_PROGRAM code     0x00  

    goto        Main                    
    nop
    nop
    goto        InterruptServiceRoutine  ; Address 0x08 low interrupt vector
    nop
    nop
    nop
    nop
    nop
    nop
    goto        Main
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

MAIN_PROGRAM code

XXA:
   da "K"
ONE:
    da "Mary\n\r\0"
XXB:
   da "K"

Main
    call DelayOneSecond
    clrf   PORTA,  ACCESS
    movlw  0x0F
    movwf  ADCON1, ACCESS    ; Set up PORTA to be digital I/Os rather than A/D converter.
    clrf   TRISA,  ACCESS    ; Set up all PORTA pins to be digital outputs.
    
    call   InitUsartComms

    bcf    RCON, IPEN,   ACCESS            ; Disable priority levels on interrupts.
    bsf    INTCON, GIE,  ACCESS           ; Enable all unmasked interrupts.
    bsf    INTCON, PEIE, ACCESS          ; Enables all unmasked peripheral interrupts.
    bsf    PIE1, TXIE ,  ACCESS           ; Enable transmission interrupts.


HERE:
    movlw upper ONE
    movwf SHADOW_RS232_PTRU, ACCESS 
    movlw high ONE
    movwf SHADOW_RS232_PTRH, ACCESS
    movlw low  ONE
    movwf SHADOW_RS232_PTRL, ACCESS

    call print
    call DelayOneSecond

    goto HERE

    end
