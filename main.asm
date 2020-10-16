; 
; Author: Bradley A. Minch
; Organization: Franklin W. Olin College of Engineering
; Revision History: 
;     01/19/2006 - Added wait for initial SE0 condition to clear at the end
;                  of InitUSB.
;     01/13/2006 - Fixed problem with DATA OUT transfers (only worked properly
;                  with class requests) in ProcessSetupToken.  Added code to
;                  disable all EPs except EP0 on a valid SET_CONFIGURATION
;                  request.  Changed code to use BSTALL instead of EPSTALL for
;                  Request Error on EP0.  Changed CLEAR_FEATURE, SET_FEATURE
;                  and GET_STATUS requests to use BSTALL instead of EPSTALL.
;                  Changed over from the deprecated __CONFIG assembler directive 
;                  to config for setting the configuration bits.  Eliminated the
;                  initial for loop from the start of the main section.
;     06/22/2005 - Added code to disable all endpoints on URSTIF and to mask
;                  bits 0, 1, and 7 of USTAT on TRNIF in serviceUSB.
;     04/21/2005 - Initial public release.
;
; ============================================================================
; 
; Peripheral Description:
; 
; This peripheral enumerates as a vendor-specific device. The main event loop 
; blinks an LED connected to RA1 on and off at about 2 Hz and the peripheral 
; responds to a pair of vendor-specific requests that turn on or off an LED ;
; connected to RA0.  The firmware is configured to use an external 4-MHz 
; crystal, to operate as a low-speed USB device, and to use the internal 
; pull-up resistor.
; 
; ============================================================================
;
; Software Licence Agreement:
; 
; THIS SOFTWARE IS PROVIDED IN AN "AS IS" CONDITION.  NO WARRANTIES, WHETHER 
; EXPRESS, IMPLIED OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, IMPLIED 
; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE APPLY 
; TO THIS SOFTWARE. THE AUTHOR SHALL NOT, UNDER ANY CIRCUMSTANCES, BE LIABLE 
; FOR SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES, FOR ANY REASON WHATSOEVER.
; 
#include <p18f2550.inc>

#include "engr2210.inc" 
#include "rs232.inc"
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

#define    SHOW_ENUM_STATUS 1
#define    SET_RA0            0x01        ; vendor-specific request to set RA0 to high
#define    CLR_RA0            0x02        ; vendor-specific request to set RA0 to low

    
    
    extern InitUsartComms, print, printData, Delay
    extern print, InterruptServiceRoutine

    
;bank0        udata
mybank1 udata   0x300
USB_BufferDescriptor     res    4
USB_BufferData     res    8
USB_error_flags     res    1  ; Was there an error.
USB_curr_config     res    1  ; Holds the value of the current configuration.
USB_device_status   res    1  ; Byte, sent to host request status
USB_dev_req         res    1
USB_address_pending res    1
USB_desc_ptr        res    1  ; address of descriptor
USB_bytes_left      res    1
USB_loop_index      res    1
USB_packet_length   res    1
USB_USTAT           res    1 ; Saved copy of USTAT special function register in memory.
USB_USWSTAT         res    1 ; Current state POWERED_STATE|DEFAULT_STATE|ADDRESS_STATE|CONFIG_STATE 
COUNTER_L           res    1
COUNTER_H           res    1

	   
RS232_RINGBUFFER      res 64
RS232_RINGBUFFER_HEAD res 1
RS232_RINGBUFFER_TAIL res 1
RS232_Temp1           res 1
RS232_Temp2           res 1
RS232_Temp3           res 1
RS232_Temp4           res 1
	   
#define    SIZE       0x10 ; 
	   
	
	   
    extern RS232_PTRU
    extern RS232_PTRH
    extern RS232_PTRL
	   
	   
	   
	   
	   
	   
	   
LAUNCH_PROGRAM code     0x00  
    goto        Main                    ; Reset vector
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
USB_INITIALISED:
    da "USB_init_called\r\n",0
    
    
;Return the number of stored bytes in W
RS232_RingBufferInit:
    clrf RS232_RINGBUFFER_HEAD, BANKED
    clrf  RS232_RINGBUFFER_TAIL, BANKED

    ; incrementing head means the buffer is full.
;    incf RS232_RINGBUFFER_HEAD, F, BANKED
;    incf RS232_RINGBUFFER_HEAD, F, BANKED
;    incf RS232_RINGBUFFER_HEAD, F, BANKED
;    incf RS232_RINGBUFFER_TAIL, F, BANKED    
    ; Adding five entries.
;    incf RS232_RINGBUFFER_TAIL, F, BANKED
;    incf RS232_RINGBUFFER_TAIL, F, BANKED
;    incf RS232_RINGBUFFER_TAIL, F, BANKED
;    incf RS232_RINGBUFFER_TAIL, F, BANKED
;    incf RS232_RINGBUFFER_TAIL, F, BANKED
    return
    
;===============================================================================
;Return the number of stored bytes in W
RS232_RingBufferBytesStored_Fn:
    movf RS232_RINGBUFFER_HEAD, W
    cpfseq RS232_RINGBUFFER_TAIL, BANKED; skip if equal
    goto RS232_RingBufferBytesNotEmpty
    goto RS232_RingBufferBytesEmpty

RS232_RingBufferBytesNotEmpty:
    cpfsgt RS232_RINGBUFFER_TAIL, BANKED; skip if tail > head
    goto RS232_RingBufferTail_LT_HEAD

RS232_RingBufferBytesEmpty:
RS232_RingBufferTail_GT_HEAD:
    ; size = tail - head;
    movf  RS232_RINGBUFFER_HEAD, BANKED
    subwf RS232_RINGBUFFER_TAIL,  W, BANKED 
    return

RS232_RingBufferTail_LT_HEAD:
    ; size = (SIZE - head) + tail;
    
    movf RS232_RINGBUFFER_HEAD, W
    SUBLW SIZE		    ; (SIZE - HEAD) -> w
    addwf RS232_RINGBUFFER_TAIL,  W, BANKED    
    
    ; SUBLW kk	   Subtract W from literal (kk - WREG) ? WREG
    ; SUBWF f,d,a  Subtract WREG from f	   (f ? WREG) ? dest
    ; ADDWF f,d    Add w AND f             (WREG + f) ? dest 
    
    return
    
;;===============================================================================
; Returns the available bytes in W
RS232_RingBufferBytesFree_FN:
   
    
   movlw 0x01
   sublw SIZE	    ;subtract W from literal (SIZE - 0x01)
   movwf RS232_Temp1, BANKED
   
   
   call  RS232_RingBufferBytesStored_Fn
   subwf RS232_Temp1, W, BANKED
   
   return
    
    
;===============================================================================

StringLengthFN:
    movf RS232_PTRU, W       ; this is table/program memory.
    movwf TBLPTRU, ACCESS    ; need same for ram.

    movf RS232_PTRH, W
    movwf TBLPTRH, ACCESS

    movf RS232_PTRL, W
    movwf TBLPTRL, ACCESS

    clrf RS232_Temp2, ACCESS      ; Initialize counter to 0
StringLengthFNNext:
    tblrd*+                 ; Read byte and increment pointer
    movf TABLAT, W, ACCESS  ; Take the read byte from the latch.

    addlw 0x00              ; Check for end of string \0 character
    btfsc STATUS,Z, ACCESS  ; If zero bit is clear, skip the goto
    goto StringLengthDone
    incf RS232_Temp2, F, ACCESS
    goto StringLengthFNNext

StringLengthDone:
    incf RS232_Temp2, F, ACCESS   ; Increment once for the \0
    movf RS232_Temp2, W
    return 
    
    
RS232_AddByteToBuffer:
   ; Move byte in w onto the buffer, already know there is space  
   ; for it.

   movwf RS232_Temp3, ACCESS
 
   movlw high RS232_RINGBUFFER
   movwf FSR2L, ACCESS
   movlw low RS232_RINGBUFFER
   addwf RS232_RINGBUFFER_TAIL, W
   movwf FSR2L, ACCESS           ;Now pointing at correct buffer location

   movwf RS232_Temp3, ACCESS
   movwf POSTINC0, ACCESS       ; puts chararacter onto the buffer
   ;incrememnt the tail of he buffer... wrapping around ..
   incf  RS232_RINGBUFFER_TAIL, F, ACCESS
   movlw SIZE -1
   andwf RS232_RINGBUFFER_TAIL, F, ACCESS
   return

    movf POSTINC2, W    ; Read byte and increment pointer

    addlw 0x00              ; Check for end of string \0 character
    btfsc STATUS,Z, ACCESS  ; If zero bit is clear, skip the goto
    goto InterruptRS232TxDone

    movwf TXREG,ACCESS      ; Send the data

    movf FSR2H, W
    movwf RS232_PTRH, ACCESS

    movf FSR2L, W
    movwf RS232_PTRL, ACCESS
InterruptRS232TxDone:
InterruptServiceEnd:		;///////????????//
    goto InterruptServiceEnd
;===============================================================================    
PrintStrinT macro string
    movlw upper string
    movwf TBLPTRU, ACCESS 
    movlw high string
    movwf TBLPTRH, ACCESS
    movlw low  string
    movwf TBLPTRL, ACCESS
    call PrintStrFn
	endm

;===============================================================================

PrintStrFn:
    ; If there space in the buffer to hold the string
    call StringLengthFN
    movwf RS232_Temp4, BANKED

    call RS232_RingBufferBytesFree_FN

    cpfsgt RS232_Temp4, BANKED; skip next when String length < Bytes Free 
    return              ; just return don't print string.

    ;The string needs put on the buffer.

RS232_AddNextByte:
    tblrd*+                 ; Read byte and increment pointer
    movf TABLAT, W, ACCESS  ; Take the read byte from the latch.

    movwf RS232_Temp4, BANKED
    
    call RS232_AddByteToBuffer

    ;if zero was just added then 
    ;raise the interrupt enable and return.

    addlw 0x00              ; Check for end of string \0 character
    btfss STATUS,Z, ACCESS  ; If zero bit is set stop adding bytes
    goto RS232_AddNextByte
    ; enable interrupts.

;===============================================================================


    
    
    
    
    
    

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++    
Main
    clrf        PORTA,  ACCESS
    movlw       0x0F
    movwf       ADCON1, ACCESS    ; Set up PORTA to be digital I/Os rather than A/D converter.
    clrf        TRISA,  ACCESS    ; Set up all PORTA pins to be digital outputs.
    
    call	InitUsartComms

    bcf    RCON, IPEN,   ACCESS          ; Disable priority levels on interrupts.
    bsf    INTCON, GIE,  ACCESS          ; Enable all unmasked interrupts.
    bsf    INTCON, PEIE, ACCESS          ; Enables all unmasked peripheral interrupts.
    bcf    PIE1, TXIE ,  ACCESS          ; Disable transmission interrupts.

    PrintString USB_INITIALISED
    
    

    repeat
        banksel COUNTER_L
	call RS232_RingBufferInit
	call RS232_RingBufferBytesStored_Fn
	call RS232_RingBufferBytesFree_FN
	

	
	
        incf    COUNTER_L, F, BANKED
        ifset STATUS, Z, ACCESS
            incf COUNTER_H, F, BANKED
        endi
        ifset  COUNTER_H, 7, BANKED
            bcf PORTA, 1, ACCESS
        otherwise
            bsf PORTA, 1, ACCESS
        endi 
    forever

    end
;  USB Reset sends the device into the default state.
;  Default State -> Address State -> Configured State



;   P18F2550 £4.80 https://coolcomponents.co.uk/products/pic-18f2550-mcu?utm_medium=cpc&utm_source=googlepla&variant=45222867086&gclid=EAIaIQobChMI7KP0mdHk1wIV5p3tCh1kUQI-EAkYASABEgLexfD_BwE
;   USB MICRO b    https://coolcomponents.co.uk/products/usb-b-socket-breakout-board
;   Do I have the capacitors.
;   DO I have the lead for that micro?

    
    
    ;Software for pic stored at
    ;/home/martin/Software/PIC/MPLAB_Projects/USB_Proj2/USB_Proj2.X
    
    ;  lsusb  -d 04d8:0014 -v
    
    


    ; SUBLW kk	   Subtract W from literal (kk - WREG) ? WREG
    ; SUBWF f,d,a  Subtract WREG from f	   (f ? WREG) ? dest
    ; ADDWF f,d    Add w AND f             (WREG + f) ? dest 