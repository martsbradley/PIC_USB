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
;     06/22/2005 - Added code to disable all endpoints on USRTIF and to mask
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
#include "usb_defs.inc"
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

    
    
    extern InitUsartComms, print, Delay
    
;bank0        udata
mybank1 udata   0x300
USB_buffer_desc     res    4
USB_buffer_data     res    8
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





STARTUP     code        0x0000
    goto        Main                    ; Reset vector
    nop
    nop
    goto        $                       ; High-priority interrupt vector trap
    nop
    nop
    nop
    nop
    nop
    nop
    goto        $                       ; Low-priority interrupt vector trap

HELLO_WORLD:
    da "HELLO WORLD\n\r"
USB_INITIALISED_DONE_STR:
    da "USB_init_done\n\r"
POWERED_STATE_STR:
    da "POWER STATE\n\r"
ADDRESS_STATE_STR:
    da "ADDRESS STATE\n\r"
DEFAULT_STATE_STR:
    da "DEFAULT STATE\n\r"
USB_INITIALISED:
    da "USB_init_called\n\r"
SET_CONFIG:
    da "SET_CONFIG\n\r"
PIC_CONFIGURED:
    da "PIC_CONFIGURED\n\r"
MartyHERE:
    da "MartyHERE\n\r"
DONE_THAT:
    da "DONE_THAT\n\r"
CONFIG_STATE_STR:
    da "CONFIG_NEVER_PRINT\n\r"
USB_INITIALISED_RETRY:
    da "USB_INITIALISED_RETRY\n\r" 
IDLE_CONDITION:
    da "IDLE_CONDITION\n\r"
INTERRUPT_HANDLED:
    da "Interrupt\n\r"
STALL_HANDSHAKE_STR:
    da "_istall\n\r"
USB_RESET_STR:
    da "Reset.\n\r"
TXN_COMPLETE_STR:
    da "TXN_COMPLETE\n\r"    
GET_DEVICE_DESCRIPTOR_STR:
    da "GET_DEVICE_DESCRIPTOR\n\r"
GET_CONFIG_DESCRIPTOR_STR:
    da "GET_CONFIG_DESCRIPTOR\n\r"
GET_ENDPOINT_DESCRIPTOR_STR:
    da "GET_ENDPOINT_DESCRIPTOR\n\r"
GET_STRING_DESCRIPTOR_STR:
    da "GET_STRING_DESCRIPTOR\n\r"
SET_DEVICE_ADDRESS_STR:
    da "SET_DEVICE_ADDRESS\n\r"
ProcessInToken_STR:
    da "ProcessInToken\n\r"
EP0_GET_DESC:
    da "EP0_GET_DESC\n\r"
EP0_SET_ADDR:
    da "EP0_SET_ADDR\n\r"

USBSTUFF    code
Descriptor
    movlw   upper Descriptor_begin
    movwf   TBLPTRU, ACCESS
    movlw   high Descriptor_begin
    movwf   TBLPTRH, ACCESS
    movlw   low Descriptor_begin
    banksel USB_desc_ptr
    addwf   USB_desc_ptr, W, BANKED
    ifset STATUS, C, ACCESS
        incf TBLPTRH, F, ACCESS
        ifset STATUS, Z, ACCESS
            incf TBLPTRU, F, ACCESS
        endi
    endi
    movwf TBLPTRL, ACCESS
   tblrd*
    movf TABLAT, W
    return

Descriptor_begin
Device
    db            0x12, DEVICE          ; bLength, bDescriptorType
    db            0x10, 0x01            ; bcdUSB (low byte), bcdUSB (high byte)
    db            0x00, 0x00            ; bDeviceClass, bDeviceSubClass
    db            0x00, MAX_PACKET_SIZE ; bDeviceProtocol, bMaxPacketSize
    db            0xD8, 0x04            ; idVendor (low byte), idVendor (high byte)
    db            0x14, 0x00            ; idProduct (low byte), idProduct (high byte)
    db            0x00, 0x00            ; bcdDevice (low byte), bcdDevice (high byte)
    db            0x01, 0x02            ; iManufacturer, iProduct
    db            0x00, NUM_CONFIGURATIONS    ; iSerialNumber (none), bNumConfigurations

Configuration1
    db            0x09, CONFIGURATION   ; bLength, bDescriptorType
    db            0x12, 0x00            ; wTotalLength (low byte), wTotalLength (high byte)
    db            NUM_INTERFACES, 0x01  ; bNumInterfaces, bConfigurationValue
    db            0x03, 0xA0            ; iConfiguration (none), bmAttributes
    db            0x32, 0x09            ; bMaxPower (100 mA), bLength (Interface1 descriptor starts here)
    db            INTERFACE, 0x00       ; bDescriptorType, bInterfaceNumber
    db            0x00, 0x00            ; bAlternateSetting, bNumEndpoints (excluding EP0)
    db            0xFF, 0x00            ; bInterfaceClass (vendor specific class code), bInterfaceSubClass
    db            0xFF, 0x00            ; bInterfaceProtocol (vendor specific protocol used), iInterface (none)
EndPoint1
    db            0x07, ENDPOINT        ; bLength, bDescriptorType
    db            0x01, 0b00001111      ; bEndpointAddress | Data Synchronous. Interrupt
    db            0x01, 0x00            ; one bytes
    DB            0x0f                  ; 16?? 
String0
    db            String1-String0, STRING    ; bLength, bDescriptorType
    db            0x09, 0x04            ; wLANGID[0] (low byte), wLANGID[0] (high byte)
String1
    db            String2-String1, STRING    ; bLength, bDescriptorType
    db            'M', 0x00            ; bString
    db            'a', 0x00
    db            'r', 0x00
    db            't', 0x00
    db            'y', 0x00
    db            ' ', 0x00
    db            'B', 0x00
    db            'r', 0x00
    db            'a', 0x00
    db            'd', 0x00
    db            'l', 0x00
    db            'e', 0x00
    db            'y', 0x00
    db            ' ', 0x00
    db            'T', 0x00
    db            'e', 0x00
    db            'c', 0x00
    db            'h', 0x00
    db            ' ', 0x00
    db            'L', 0x00
    db            'T', 0x00
    db            'D', 0x00
    db            '.', 0x00
    db            '.', 0x00
    db            '.', 0x00
    db            '.', 0x00
String2
    db            String3-String2, STRING    ; bLength, bDescriptorType
    db            'E', 0x00            ; bString
    db            'N', 0x00
    db            'G', 0x00
    db            'R', 0x00
    db            ' ', 0x00
    db            '2', 0x00
    db            '2', 0x00
    db            '1', 0x00
    db            '0', 0x00
    db            ' ', 0x00
    db            'P', 0x00
    db            'I', 0x00
    db            'C', 0x00
    db            '1', 0x00
    db            '8', 0x00
    db            'F', 0x00
    db            '2', 0x00
    db            '4', 0x00
    db            '5', 0x00
    db            '5', 0x00
    db            ' ', 0x00
    db            'U', 0x00
    db            'S', 0x00
    db            'B', 0x00
    db            ' ', 0x00
    db            'F', 0x00
    db            'i', 0x00
    db            'r', 0x00
    db            'm', 0x00
    db            'w', 0x00
    db            'a', 0x00
    db            'r', 0x00
    db            'e', 0x00
String3
    db            Descriptor_end-String3, STRING
    db            'M', 0x00
    db            'y', 0x00
    db            ' ', 0x00
    db            'c', 0x00
    db            'o', 0x00
    db            'n', 0x00
    db            'f', 0x00
    db            'i', 0x00
    db            'g', 0x00
Descriptor_end


;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ServiceUSB
    select
    caseset    UIR, UERRIF, ACCESS    ;  If there is an interrupt.
        clrf   UEIR, ACCESS           ;  Clear the error in software.
        break
    caseset    UIR, SOFIF, ACCESS     ;  Start of Frame token received by SIE
        bcf    UIR, SOFIF, ACCESS     ;  Clear this flag 
        break
    caseset    UIR,  IDLEIF, ACCESS   ;  Idle condition detected (been idle for 3ms or more)
        bcf    UIR,  IDLEIF, ACCESS   ;  Clear that idle condition.
        bsf    UCON, SUSPND, ACCESS   ;  Suspend the SIE to conserve power.
#ifdef SHOW_ENUM_STATUS
        movlw  0xE0                   ;  0b11100000 -> W
        andwf  PORTB, F, ACCESS       ;  AND 0xE0 with PORTB and store in PORTB
        bsf    PORTB, 4, ACCESS       ;  Also set bit 4 of PORTB
#endif
	PrintString IDLE_CONDITION
        break
    caseset UIR, ACTVIF, ACCESS       ;  There was activity on the USB
        bcf    UIR, ACTVIF, ACCESS    ;  Clear the activity detection flag.
        bcf    UCON, SUSPND, ACCESS   ;  Unsuspend the SIE.
    #ifdef SHOW_ENUM_STATUS
        movlw   0xE0
        andwf   PORTB, F, ACCESS
        banksel USB_USWSTAT
        movf    USB_USWSTAT, W, BANKED  ; Load current state into W.
        select
        case POWERED_STATE
	    PrintString POWERED_STATE_STR
            movlw    0x01
            break
        case DEFAULT_STATE
	    PrintString DEFAULT_STATE_STR
            movlw    0x02
            break
        case ADDRESS_STATE
	    PrintString ADDRESS_STATE_STR
            movlw    0x04
            break
        case CONFIG_STATE
            movlw    0x08
        ends
        iorwf  PORTB, F, ACCESS        ;  Update the port to reflect the state.
#endif
        break
    caseset     UIR, STALLIF, ACCESS  ; A stall handshake was sent by the SIE
        bcf     UIR, STALLIF, ACCESS  ; clear the stall handshake
	PrintString STALL_HANDSHAKE_STR
        break
    caseset UIR, URSTIF, ACCESS    ; USB Reset occurred.
	PrintString USB_RESET_STR
	
        banksel USB_curr_config
        clrf    USB_curr_config, BANKED
        bcf     UIR, TRNIF, ACCESS    ; clear TRNIF four times to clear out the USTAT FIFO
        bcf     UIR, TRNIF, ACCESS
        bcf     UIR, TRNIF, ACCESS
        bcf     UIR, TRNIF, ACCESS
        clrf    UEP0, ACCESS          ; clear all EP control registers 
        clrf    UEP1, ACCESS          ; to disable all endpoints.
        clrf    UEP2, ACCESS
        clrf    UEP3, ACCESS
        clrf    UEP4, ACCESS
        clrf    UEP5, ACCESS
        clrf    UEP6, ACCESS
        clrf    UEP7, ACCESS
        clrf    UEP8, ACCESS
        clrf    UEP9, ACCESS
        clrf    UEP10, ACCESS
        clrf    UEP11, ACCESS
        clrf    UEP12, ACCESS
        clrf    UEP13, ACCESS
        clrf    UEP14, ACCESS
        clrf    UEP15, ACCESS
        banksel BD0OBC
        movlw   MAX_PACKET_SIZE       ; 8 bytes lowest packet size for low and high speed.
        movwf   BD0OBC, BANKED
        movlw   low USB_Buffer        ; Get low bits from for the USB_Buffer
        movwf   BD0OAL, BANKED        ; EP0 OUT gets a buffer...
        movlw   high USB_Buffer       ; Get high bits from for the USB_Buffer
        movwf   BD0OAH, BANKED        ; ...set up its address
        movlw   0x88                  ; set UOWN bit (USB can write)
        movwf   BD0OST, BANKED        ; Controller hands over the buffer to the SIE.
        movlw   low (USB_Buffer+MAX_PACKET_SIZE)    ; EP0 IN gets a buffer...
        movwf   BD0IAL, BANKED
        movlw   high (USB_Buffer+MAX_PACKET_SIZE)
        movwf   BD0IAH, BANKED        ; ...set up its address
        movlw   0x08                  ; clear UOWN bit (MCU can write)
        movwf   BD0IST, BANKED
        clrf    UADDR, ACCESS         ; set USB Address to 0
        clrf    UIR, ACCESS           ; clear all the USB interrupt flags
        movlw   ENDPT_CONTROL         ; Setup UEP0 by setting EPHSHK, EPOUTEN & EPINEN
        movwf   UEP0, ACCESS          ; EP0 is a control pipe and requires an ACK
        movlw   0xFF               
        movwf   UEIE, ACCESS          ; Enable all usb error interrupts
        banksel USB_USWSTAT
        movlw   DEFAULT_STATE         ; Enter default state since this is a reset.
        movwf   USB_USWSTAT, BANKED
        movlw   0x01                  ; Self powered, remote wakeup disabled
        movwf   USB_device_status, BANKED   
    #ifdef SHOW_ENUM_STATUS
        movlw   0xE0
        andwf   PORTB, F, ACCESS
        bsf     PORTB, 1, ACCESS      ; set bit 1 of PORTB to indicate Powered state
    #endif
        break
    caseset  UIR, TRNIF, ACCESS    ; Processing of pending transaction is complete; 
;       PrintString TXN_COMPLETE_STR
        movlw    0x04
        movwf    FSR0H, ACCESS     ; Indirect addressing,
        movf     USTAT, W, ACCESS  ; Read USTAT register for endpoint information
        andlw    0x7C              ; Mask out bits other than Endpoint and Direction
        movwf    FSR0L, ACCESS     ;    0000100 0EEEED00 (FSR0H-FSR0L)
        banksel  USB_buffer_desc   ; eg 0000100 00000000 EP0 Out-> 400h
        movf     POSTINC0, W       ;    0000100 00000100 EP0 IN -> 404h
        movwf    USB_buffer_desc, BANKED  ; Copy received data to USB_buffer_desc
        movf     POSTINC0, W
        movwf    USB_buffer_desc+1, BANKED
        movf     POSTINC0, W
        movwf    USB_buffer_desc+2, BANKED
        movf     POSTINC0, W
        movwf    USB_buffer_desc+3, BANKED
        movf     USTAT, W, ACCESS
        movwf    USB_USTAT, BANKED  ; Save the USB status register
        bcf      UIR, TRNIF, ACCESS ; Clear transaction complete interrupt flag
#ifdef SHOW_ENUM_STATUS
        andlw    0x18               ; Endpoint bits ENDP1:ENDP0 from USTAT register
        select                      ; Which endpoint was handled.
            case EP0
                movlw  0x20
                break
            case EP1
                movlw  0x40
                break
            case EP2
                movlw  0x80
                break
        ends
        xorwf   PORTB, F, ACCESS    ; toggle bit 5, 6, or 7 to reflect EP activity
#endif
        clrf    USB_error_flags, BANKED    ; clear USB error flags
        movf    USB_buffer_desc, W, BANKED
                                 ; The PID is presented by the SIE in the BDnSTAT
        andlw   0x3C             ; extract PID bits 0011 1100 (PID3:PID2:PID1:PID0)
        select
        case TOKEN_SETUP
            call        ProcessSetupToken
            break
        case TOKEN_IN
            call        ProcessInToken
            break
        case TOKEN_OUT
            call        ProcessOutToken
            break
        ends
        banksel USB_error_flags
        ifset USB_error_flags, 0, BANKED    ; if there was a Request Error...
            banksel BD0OBC
            movlw   MAX_PACKET_SIZE
            movwf   BD0OBC                ; ...get ready to receive the next Setup token...
            movlw   0x84
            movwf   BD0IST
            movwf   BD0OST                ; ...and issue a protocol stall on EP0
        endi
        break
    ends
    return
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ProcessSetupToken
    
    banksel  USB_buffer_data
    movf     USB_buffer_desc+ADDRESSH, W, BANKED
    movwf    FSR0H, ACCESS
    movf     USB_buffer_desc+ADDRESSL, W, BANKED
    movwf    FSR0L, ACCESS
    movf     POSTINC0, W
    movwf    USB_buffer_data, BANKED
    movf     POSTINC0, W
    movwf    USB_buffer_data+1, BANKED  ; Move received bytes to USB_buffer_Data
    movf     POSTINC0, W
    movwf    USB_buffer_data+2, BANKED  ; Move received bytes to USB_buffer_Data
    movf     POSTINC0, W
    movwf    USB_buffer_data+3, BANKED  ; Move received bytes to USB_buffer_Data
    movf     POSTINC0, W
    movwf    USB_buffer_data+4, BANKED  ; Move received bytes to USB_buffer_Data
    movf     POSTINC0, W
    movwf    USB_buffer_data+5, BANKED  ; Move received bytes to USB_buffer_Data
    movf     POSTINC0, W
    movwf    USB_buffer_data+6, BANKED  ; Move received bytes to USB_buffer_Data
    movf     POSTINC0, W
    movwf    USB_buffer_data+7, BANKED  ; Move received bytes to USB_buffer_Data
    banksel  BD0OBC
    movlw    MAX_PACKET_SIZE
    movwf    BD0OBC, BANKED      ; reset the byte count
    movwf    BD0IST, BANKED      ; return the in buffer to us (dequeue any pending requests)
    banksel  USB_buffer_data+bmRequestType


    ;  Really don't understand this if statement!!!!!
    ifclr USB_buffer_data+bmRequestType, 7, BANKED  ; Host to Device.
        ifl  USB_buffer_data+wLength,     NE, 0  ; 
        orif USB_buffer_data+wLengthHigh, NE, 0  ; 
            movlw  0xC8     ; UOWN + DTS + INCDIS + DTSEN set
        otherwise
            movlw  0x88     ; UOWN + DTSEN set
        endi
    otherwise               ; Device to Host.
        movlw      0x88     ; UOWN + DTSEN set
    endi

    banksel BD0OST
    movwf   BD0OST, BANKED  ; set EP0 OUT UOWN back to USB and DATA0/DATA1 packet according to request type
    bcf     UCON, PKTDIS, ACCESS  ; Assuming there is nothing to dequeue, token and packet processing enabled.
    banksel USB_dev_req
    movlw   NO_REQUEST
    movwf   USB_dev_req, BANKED         ; clear the device request in process

    movf    USB_buffer_data+bmRequestType, W, BANKED
                  ; The bmRequestType is the first 8 bits of the Request data.
                  ; 0110 0000 -> Extract Type of Request
    andlw    0x60  ; http://wiki.osdev.org/Universal_Serial_Bus#Standard_Requests

    select
        case STANDARD
            call StandardRequests
            break
        case CLASS
            call ClassRequests
            break
        case VENDOR
            call VendorRequests
            break
        default
            bsf USB_error_flags, 0, BANKED    ; set Request Error flag
    ends
    return
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
StandardRequests
    movf USB_buffer_data+bRequest, W, BANKED
    select

    ; >>>>  STANDARD REQUESTS  <<<< ;
    case GET_STATUS   
        ;  The host can ask for the status of the device, an interface or an
        ;  end point.
        movf  USB_buffer_data+bmRequestType, W, BANKED
        andlw 0x1F                    ; extract request recipient bits
        select
        case RECIPIENT_DEVICE
            banksel BD0IAH
            movf    BD0IAH, W, BANKED
            movwf   FSR0H, ACCESS
            movf    BD0IAL, W, BANKED  ; get buffer pointer
            movwf   FSR0L, ACCESS
            banksel USB_device_status
            ; copy device status byte to EP0 buffer
            movf    USB_device_status, W, BANKED 
            movwf   POSTINC0
            clrf    INDF0
            banksel BD0IBC
            movlw   0x02
            movwf   BD0IBC, BANKED ; Setting byte count to 2
            movlw   0xC8
            movwf   BD0IST, BANKED ; Send packet as DATA1, set UOWN bit    
            break

        case RECIPIENT_INTERFACE 
            movf USB_USWSTAT, W, BANKED
            select
            case ADDRESS_STATE
                ; Set Request Error flag
                bsf USB_error_flags, 0, BANKED
                break
            case CONFIG_STATE
                ; Used to return the status of the interface. Such a request to the interface should return 
                ; two bytes of value 0x00.
                ifl USB_buffer_data+wIndex, LT, NUM_INTERFACES
                    banksel BD0IAH
                    movf    BD0IAH, W, BANKED
                    movwf   FSR0H, ACCESS
                    movf    BD0IAL, W, BANKED    ; Get buffer pointer
                    movwf   FSR0L, ACCESS
                    clrf    POSTINC0
                    clrf    INDF0
                    movlw   0x02
                    movwf   BD0IBC, BANKED       ; Set byte count to 2
                    movlw   0xC8
                    movwf   BD0IST, BANKED       ; Send packet as DATA1, set UOWN bit                                                                                                
                otherwise
                    ; Host queried state of unknown interface.
                    bsf USB_error_flags, 0, BANKED ; Set Request Error flag
                endi
                break
            ends
            break
        case RECIPIENT_ENDPOINT 
            movf USB_USWSTAT, W, BANKED
            select
            case ADDRESS_STATE  
                ;  Returns two bytes indicating the status (Halted/Stalled) of a endpoint
                movf USB_buffer_data+wIndex, W, BANKED ; Get EP
                andlw 0x0F                             ; Strip off direction bit
                ifset STATUS, Z, ACCESS                ; see if it is EP0
                    banksel BD0IAH
                    movf    BD0IAH, W, BANKED          ; put EP0 IN buffer pointer...
                    movwf   FSR0H, ACCESS
                    movf    BD0IAL, W, BANKED
                    movwf   FSR0L, ACCESS              ; ...into FSR0
                    banksel USB_buffer_data+wIndex
                                                       ; If the specified direction is IN...
                    ifset USB_buffer_data+wIndex, 7, BANKED        
                        banksel  BD0IST
                        movf     BD0IST, W, BANKED
                    otherwise
                        banksel  BD0OST
                        movf     BD0OST, W, BANKED
                    endi
                    andlw 0x04            ; extract the BSTALL bit
                    movwf INDF0
                    rrncf INDF0, F
                    rrncf INDF0, F        ; shift BSTALL bit into the lsb position
                    clrf  PREINC0
                    movlw 0x02
                    movwf BD0IBC, BANKED  ; set byte count to 2
                    movlw 0xC8
                    movwf BD0IST, BANKED  ; send packet as DATA1, set UOWN bit
                otherwise
                    bsf   USB_error_flags, 0, BANKED        ; set Request Error flag
                endi
                break
            case CONFIG_STATE

                banksel BD0IAH
                movf    BD0IAH, W, BANKED                    ; put EP0 IN buffer pointer...
                movwf   FSR0H, ACCESS
                movf    BD0IAL, W, BANKED
                movwf   FSR0L, ACCESS                        ; ...into FSR0

                movlw   high UEP0                            ; put UEP0 address...
                movwf   FSR1H, ACCESS
                movlw   low UEP0
                movwf   FSR1L, ACCESS                        ; ...into FSR1
                movlw   high BD0OST                            ; put BDndST address...
                movwf   FSR2H, ACCESS

                ; Now ... 
                ; FSR0 contains address of BD0 IN BUFFER data
                ; FSR1 contains address of UEP0 
                ; FSR2 high byte contains high address of Buffer Descriptors Table
                ; FSR2 low byte calculated below.


                banksel USB_buffer_data+wIndex
                movf    USB_buffer_data+wIndex, W, BANKED
                andlw   0x8F                                   ; mask out all but the direction bit and EP number
                movwf   FSR2L, ACCESS
                                                  ;D000 EEEE   ; D -> direction bit, E -> Endpoint bit 
                rlncf   FSR2L, F, ACCESS          ;000E EEED   
                rlncf   FSR2L, F, ACCESS          ;00EE EED0
                rlncf   FSR2L, F, ACCESS          ;0EEE ED00   ; FSR2L now contains the proper offset into the BD table for the specified EP

                                              ;ENDPOINT  ADDRESS OFFSET
                                              ;1 0001    00001D00    8 bytes
                                              ;2 0010    00010D00    16 bytes
                                              ;3 0011    00011D00    24 bytes  Each Descriptor is 8 bytes long

                movlw  low BD0OST
                addwf  FSR2L, F, ACCESS           ; ...into FSR2
                ifset STATUS, C, ACCESS
                    incf FSR2H, F, ACCESS
                endi
                movf  USB_buffer_data+wIndex, W, BANKED   ; Get EndPoint 
                andlw 0x0F                                ; Strip off direction bit leavng only End Point.
                ifset USB_buffer_data+wIndex, 7, BANKED          ; if the specified EP direction is IN...
                                                                 ; add endpoint number to FSR1 address to access relevant UEP* register
                    andifclr PLUSW1, EPINEN, ACCESS              ; ...and the specified EP is not enabled for IN transfers...
                    bsf      USB_error_flags, 0, BANKED          ; ...set Request Error flag
                elsifclr     USB_buffer_data+wIndex, 7, BANKED   ; otherwise, if the specified EP direction is OUT...
                andifclr     PLUSW1, EPOUTEN, ACCESS             ; ...and the specified EP is not enabled for OUT transfers...
                    bsf      USB_error_flags, 0, BANKED          ; ...set Request Error flag
                otherwise
                    movf     INDF2, W                        ; move the contents of the specified BDndST register into WREG
                    andlw    0x04                            ; extract the BSTALL bit
                    movwf    INDF0
                    rrncf    INDF0, F
                    rrncf    INDF0, F                        ; shift BSTALL bit into the lsb position
                    clrf     PREINC0                                        
                    banksel  BD0IBC
                    movlw    0x02
                    movwf    BD0IBC, BANKED                    ; set byte count to 2
                    movlw    0xC8
                    movwf    BD0IST, BANKED                    ; send packet as DATA1, set UOWN bit
                endi
                break
            default
                bsf USB_error_flags, 0, BANKED    ; set Request Error flag
            ends
            break
        default
            bsf USB_error_flags, 0, BANKED    ; set Request Error flag
        ends
    break

    ; >>>>  STANDARD REQUESTS  <<<< ;
    case CLEAR_FEATURE
    case SET_FEATURE
        movf USB_buffer_data+bmRequestType, W, BANKED
        andlw 0x1F                    ; extract request recipient bits
        select
        case RECIPIENT_DEVICE
            ; This device only handles remote wakeup.
            movf USB_buffer_data+wValue, W, BANKED
            select
                case DEVICE_REMOTE_WAKEUP
                ifl USB_buffer_data+bRequest, EQ, CLEAR_FEATURE
                    bcf  USB_device_status, 1, BANKED
                otherwise
                    bsf  USB_device_status, 1, BANKED
                endi
                banksel BD0IBC
                clrf    BD0IBC, BANKED                    ; set byte count to 0
                movlw   0xC8
                movwf   BD0IST, BANKED                    ; send packet as DATA1, set UOWN bit
                break
            default
                bsf   USB_error_flags, 0, BANKED        ; set Request Error flag
            ends
            break
        case RECIPIENT_ENDPOINT
            movf USB_USWSTAT, W, BANKED
            select
            case ADDRESS_STATE
                ;  In Address state only can handle endpoint zero.
                movf  USB_buffer_data+wIndex, W, BANKED    ; get EP
                andlw 0x0F                                 ; strip off direction bit
                ifset STATUS, Z, ACCESS                    ; see if it is EP0
                    banksel BD0IBC
                    clrf    BD0IBC, BANKED                 ; set byte count to 0
                    movlw   0xC8
                    movwf   BD0IST, BANKED                 ; send packet as DATA1, set UOWN bit
                otherwise
                    bsf USB_error_flags, 0, BANKED         ; set Request Error flag
                endi
                break
            case CONFIG_STATE
                movlw high UEP0              ; 
                movwf FSR0H, ACCESS
                movlw low UEP0
                movwf FSR0L, ACCESS          ; put UEP0 address into FSR0

                movlw high BD0OST            ; ...
                movwf FSR1H, ACCESS
                movlw low BD0OST
                movwf FSR1L, ACCESS          ; put BD0OST address into FSR1

                movf  USB_buffer_data+wIndex, W, BANKED   ; get EP
                andlw 0x0F                                ; strip off direction bit
                ifclr STATUS, Z, ACCESS                   ; if it was not EP0...
                    addwf FSR0L, F, ACCESS                ; add EP number to FSR0
                    ifset STATUS, C, ACCESS
                        incf FSR0H, F, ACCESS
                    endi
                    ; Now FSR0 has the address of the relevant UEPn register.

                    rlncf USB_buffer_data+wIndex, F, BANKED
                    rlncf USB_buffer_data+wIndex, F, BANKED
                    rlncf USB_buffer_data+wIndex, W, BANKED   ; WREG now contains the proper offset into the BD table for the specified EP
                    andlw 0x7C                                ; mask out all but the direction bit and EP number (after three left rotates)
                    addwf FSR1L, F, ACCESS                    ; add BD table offset to FSR1
                    ifset STATUS, C, ACCESS
                        incf FSR1H, F, ACCESS
                    endi
                    ; Now FSR1 has the address of the Buffer descriptor.

                    ifset USB_buffer_data+wIndex, 1, BANKED    ; if the specified EP direction (now bit 1) is IN...
                        ifset INDF0, EPINEN, ACCESS            ; if the specified EP is enabled for IN transfers...
                            ifl USB_buffer_data+bRequest, EQ, CLEAR_FEATURE
                                clrf  INDF1                    ; clear the stall on the specified EP
                            otherwise
                                movlw 0x84
                                movwf INDF1                    ; stall the specified EP
                            endi
                        otherwise
                            bsf USB_error_flags, 0, BANKED     ; set Request Error flag
                        endi
                    otherwise                                  ; ...otherwise the specified EP direction is OUT, so...
                        ifset INDF0, EPOUTEN, ACCESS           ; if the specified EP is enabled for OUT transfers...
                            ifl USB_buffer_data+bRequest, EQ, CLEAR_FEATURE
                                movlw 0x88
                                movwf INDF1                    ; clear the stall on the specified EP                                                    
                            otherwise
                                movlw 0x84
                                movwf INDF1                    ; stall the specified EP
                            endi
                        otherwise
                            bsf USB_error_flags, 0, BANKED     ; set Request Error flag
                        endi
                    endi
                endi
                ifclr USB_error_flags, 0, BANKED    ; if there was no Request Error...
                    banksel BD0IBC
                    clrf    BD0IBC, BANKED          ; set byte count to 0
                    movlw   0xC8
                    movwf   BD0IST, BANKED          ; send packet as DATA1, set UOWN bit
                endi
                break
            default
                bsf            USB_error_flags, 0, BANKED    ; set Request Error flag
            ends
            break
        default
            bsf USB_error_flags, 0, BANKED    ; set Request Error flag
        ends
        break

    ; >>>>  STANDARD REQUESTS  <<<< ;
    case SET_ADDRESS
        ifset USB_buffer_data+wValue, 7, BANKED        ; if new device address is illegal, send Request Error
            bsf USB_error_flags, 0, BANKED    ; set Request Error flag
        otherwise
            PrintString SET_DEVICE_ADDRESS_STR
            movlw   SET_ADDRESS
            movwf   USB_dev_req, BANKED           ; processing a set address request
            movf    USB_buffer_data+wValue, W, BANKED
            movwf   USB_address_pending, BANKED   ; save new address
            banksel BD0IBC
            clrf    BD0IBC, BANKED                ; set byte count to 0
            movlw   0xC8
            movwf   BD0IST, BANKED                ; send packet as DATA1, set UOWN bit
        endi
    break

    ; >>>>  STANDARD REQUESTS  <<<< ;
    case GET_DESCRIPTOR
        movwf USB_dev_req, BANKED                ; processing a GET_DESCRIPTOR request
        movf  USB_buffer_data+(wValue+1), W, BANKED
        select
        case DEVICE
            PrintString GET_DEVICE_DESCRIPTOR_STR
            movlw low (Device-Descriptor_begin)
            movwf USB_desc_ptr, BANKED
            call  Descriptor                ; get descriptor length
            movwf USB_bytes_left, BANKED
            call SendDescriptorPacket

            break

        case ENDPOINT
            PrintString GET_ENDPOINT_DESCRIPTOR_STR
            break
        case CONFIGURATION
            PrintString GET_CONFIG_DESCRIPTOR_STR
            movf USB_buffer_data+wValue, W, BANKED
            select
            case 0
                movlw low (Configuration1-Descriptor_begin)
                break
            default
                bsf USB_error_flags, 0, BANKED    ; set Request Error flag
            ends
            ifclr USB_error_flags, 0, BANKED
                addlw 0x02                ; add offset for wTotalLength
                movwf USB_desc_ptr, BANKED
                call Descriptor            ; get total descriptor length
                movwf USB_bytes_left, BANKED
                movlw 0x02
                subwf USB_desc_ptr, F, BANKED    ; subtract offset for wTotalLength
                call SendDescriptorPacket
            endi
            break
        case STRING
            PrintString GET_STRING_DESCRIPTOR_STR
            movf USB_buffer_data+wValue, W, BANKED
            select
            case 0
                movlw low (String0-Descriptor_begin)
                break
            case 1
                movlw low (String1-Descriptor_begin)
                break
            case 2
                movlw low (String2-Descriptor_begin)
                break
	    case 3
                movlw low (String3-Descriptor_begin)
                break		
            default
                bsf USB_error_flags, 0, BANKED    ; Set Request Error flag
            ends

            ifclr USB_error_flags, 0, BANKED
                movwf        USB_desc_ptr, BANKED
                call  Descriptor        ; get descriptor length
                movwf USB_bytes_left, BANKED
                call SendDescriptorPacket
            endi
            break
        default
            bsf  USB_error_flags, 0, BANKED    ; set Request Error flag
        ends
        break

    ; >>>>  STANDARD REQUESTS  <<<< ;
    case GET_CONFIGURATION
        banksel     BD0IAH
        movf        BD0IAH, W, BANKED
        movwf       FSR0H, ACCESS
        movf        BD0IAL, W, BANKED
        movwf       FSR0L, ACCESS
        banksel     USB_curr_config
        movf        USB_curr_config, W, BANKED
        movwf       INDF0                    ; copy current device configuration to EP0 IN buffer
        banksel     BD0IBC
        movlw       0x01
        movwf       BD0IBC, BANKED            ; set EP0 IN byte count to 1
        movlw       0xC8
        movwf       BD0IST, BANKED            ; send packet as DATA1, set UOWN bit
        break

    ; >>>>  STANDARD REQUESTS  <<<< ;
    case SET_CONFIGURATION
        PrintString SET_CONFIG
        ifl USB_buffer_data+wValue, LE, NUM_CONFIGURATIONS
            clrf  UEP1, ACCESS        ; clear all EP control registers except for EP0 to disable EP1-EP15 prior to setting configuration
            clrf  UEP2, ACCESS
            clrf  UEP3, ACCESS
            clrf  UEP4, ACCESS
            clrf  UEP5, ACCESS
            clrf  UEP6, ACCESS
            clrf  UEP7, ACCESS
            clrf  UEP8, ACCESS
            clrf  UEP9, ACCESS
            clrf  UEP10, ACCESS
            clrf  UEP11, ACCESS
            clrf  UEP12, ACCESS
            clrf  UEP13, ACCESS
            clrf  UEP14, ACCESS
            clrf  UEP15, ACCESS
            movf  USB_buffer_data+wValue, W, BANKED
            movwf USB_curr_config, BANKED
            select
            case 0
                movlw  ADDRESS_STATE
                movwf  USB_USWSTAT, BANKED
#ifdef SHOW_ENUM_STATUS
                movlw  0xE0
                andwf  PORTB, F, ACCESS
                bsf    PORTB, 2, ACCESS
#endif
                break
            default
                movlw  CONFIG_STATE
                movwf  USB_USWSTAT, BANKED
#ifdef SHOW_ENUM_STATUS
                movlw  0xE0
                andwf  PORTB, F, ACCESS
                bsf    PORTB, 3, ACCESS
#endif
            ends
            banksel BD0IBC
            clrf    BD0IBC, BANKED            ; set byte count to 0
            movlw   0xC8
            movwf   BD0IST, BANKED            ; send packet as DATA1, set UOWN bit
        otherwise
            bsf     USB_error_flags, 0, BANKED    ; set Request Error flag
        endi
        break
    ; >>>>  STANDARD REQUESTS  <<<< ;
    case GET_INTERFACE
        movf        USB_USWSTAT, W, BANKED
        select
        case CONFIG_STATE
            ifl USB_buffer_data+wIndex, LT, NUM_INTERFACES
                banksel  BD0IAH
                movf     BD0IAH, W, BANKED
                movwf    FSR0H, ACCESS
                movf     BD0IAL, W, BANKED        ; get buffer pointer
                movwf    FSR0L, ACCESS
                clrf     INDF0                    ; always send back 0 for bAlternateSetting
                movlw    0x01
                movwf    BD0IBC, BANKED            ; set byte count to 1
                movlw    0xC8
                movwf    BD0IST, BANKED            ; send packet as DATA1, set UOWN bit
                otherwise
                bsf      USB_error_flags, 0, BANKED    ; set Request Error flag
            endi
            break
        default
            bsf  USB_error_flags, 0, BANKED    ; set Request Error flag
        ends
        break
    ; >>>>  STANDARD REQUESTS  <<<< ;
    case SET_INTERFACE
        movf  USB_USWSTAT, W, BANKED
        select
        case CONFIG_STATE
            ifl USB_buffer_data+wIndex, LT, NUM_INTERFACES
                movf  USB_buffer_data+wValue, W, BANKED
                select
                case 0                                    ; currently support only bAlternateSetting of 0
                    banksel BD0IBC
                    clrf    BD0IBC, BANKED            ; set byte count to 0
                    movlw   0xC8
                    movwf   BD0IST, BANKED            ; send packet as DATA1, set UOWN bit
                    break
                default
                    bsf     USB_error_flags, 0, BANKED    ; set Request Error flag
                ends
            otherwise
                bsf  USB_error_flags, 0, BANKED    ; set Request Error flag
            endi
            break
        default
            bsf USB_error_flags, 0, BANKED    ; set Request Error flag
        ends
        break
    case SET_DESCRIPTOR
    case SYNCH_FRAME
    default
        bsf  USB_error_flags, 0, BANKED    ; set Request Error flag
        break
    ends
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ClassRequests
    movf   USB_buffer_data+bRequest, W, BANKED
    select
    default
        bsf  USB_error_flags, 0, BANKED    ; set Request Error flag
    ends
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
VendorRequests
    movf        USB_buffer_data+bRequest, W, BANKED
    select
    case SET_RA0
        bsf         PORTA, 0, ACCESS        ; set RA0 high
        banksel     BD0IBC
        clrf        BD0IBC, BANKED          ; set byte count to 0
        movlw       0xC8
        movwf       BD0IST, BANKED          ; send packet as DATA1, set UOWN bit
        break
    case CLR_RA0
        bcf         PORTA, 0, ACCESS        ; set RA0 low
        banksel     BD0IBC
        clrf        BD0IBC, BANKED          ; set byte count to 0
        movlw       0xC8
        movwf       BD0IST, BANKED          ; send packet as DATA1, set UOWN bit
        break
    default
        bsf         USB_error_flags, 0, BANKED    ; set Request Error flag
    ends
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ProcessInToken
    ;PrintString ProcessInToken_STR
    banksel USB_USTAT
    movf  USB_USTAT, W, BANKED
    andlw 0x18        ; extract the EP bits
    select
    case EP0
        movf USB_dev_req, W, BANKED
        select
        case SET_ADDRESS
            PrintString EP0_SET_ADDR
            movf   USB_address_pending, W, BANKED
            movwf  UADDR, ACCESS
            select
            case 0
                movlw DEFAULT_STATE
                movwf USB_USWSTAT, BANKED
    #ifdef SHOW_ENUM_STATUS
                movlw 0xE0
                andwf PORTB, F, ACCESS
                bsf   PORTB, 1, ACCESS
    #endif
                break
            default
                movlw ADDRESS_STATE
                movwf USB_USWSTAT, BANKED
    #ifdef SHOW_ENUM_STATUS
                movlw 0xE0
                andwf PORTB, F, ACCESS
                bsf   PORTB, 2, ACCESS
    #endif
            ends
            break
        case GET_DESCRIPTOR
            ; print statements here seem to cause
            ; issues - maybe affecting timing 
            call SendDescriptorPacket
            break
        ends
        break
    case EP1
	break
    case EP2
	break
    ends
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ProcessOutToken
    banksel  USB_USTAT
    movf     USB_USTAT, W, BANKED
    andlw    0x18        ; extract the EP bits
    select
    case EP0
	banksel BD0OBC
	movlw   MAX_PACKET_SIZE
	movwf   BD0OBC, BANKED
	movlw   0x88
	movwf   BD0OST, BANKED
	clrf    BD0IBC, BANKED        ; set byte count to 0
	movlw   0xC8
	movwf   BD0IST, BANKED        ; send packet as DATA1, set UOWN bit
	break
    case EP1
	break
    case EP2
	break
    ends
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SendDescriptorPacket
    ifl   USB_buffer_data+(wLength+1), EQ, 0
    andiff USB_buffer_data+wLength,    LT, USB_bytes_left
        movf  USB_buffer_data+wLength, W, BANKED
        movwf USB_bytes_left, BANKED
    endi

    banksel    USB_bytes_left   ; probably unneeded?

    ifl USB_bytes_left, LT, MAX_PACKET_SIZE
        movlw  NO_REQUEST
        movwf  USB_dev_req, BANKED        ; sending a short packet, so clear device request
        movf   USB_bytes_left, W, BANKED
    otherwise
        movlw  MAX_PACKET_SIZE
    endi
    subwf    USB_bytes_left, F, BANKED
    movwf    USB_packet_length, BANKED
    banksel  BD0IBC
    movwf    BD0IBC, BANKED            ; set EP0 IN byte count with packet size
    movf     BD0IAH, W, BANKED        ; put EP0 IN buffer pointer...
    movwf    FSR0H, ACCESS
    movf     BD0IAL, W, BANKED
    movwf    FSR0L, ACCESS            ; ...into FSR0
    banksel  USB_loop_index
    forlf USB_loop_index, 1, USB_packet_length
        call  Descriptor            ; get next byte of descriptor being sent
        movwf POSTINC0            ; copy to EP0 IN buffer, and increment FSR0
        incf  USB_desc_ptr, F, BANKED    ; increment the descriptor pointer
        next USB_loop_index
    banksel   BD0IST
    movlw     0x40
    xorwf     BD0IST, W, BANKED        ; toggle the DATA01 bit
    andlw     0x40                    ; clear the PIDs bits
    iorlw     0x88                    ; set UOWN and DTS bits
    movwf     BD0IST, BANKED
    return
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;APPLICATION    code
InitUSB
    PrintString USB_INITIALISED
    clrf        UIE, ACCESS                ; USB Interrupt Enable register - Mask all USB interrupts
    clrf        UIR, ACCESS                ; USB Interrupt Status register - Clear all interrupt flags
    movlw       0x14                       ; UPUEN  = 1 On-chip pull-up on D+, so full speed.
    ; UTRDIS = 1 On-chip transceiver enabled.
    movwf       UCFG, ACCESS
    movlw       0x08                       ; USBEN = 1
    movwf       UCON, ACCESS               ; Enable the USB module and its supporting circuitry
    banksel     USB_curr_config
    clrf        USB_curr_config, BANKED
    clrf        USB_USWSTAT, BANKED        ; Default to powered state.
    movlw       0x01                       ; Self powered without remote wakeup.
                                           ; See Standard Request GetStatus for device
    movwf       USB_device_status, BANKED  ; 0x01 into USB_device_status.
    movlw       NO_REQUEST
    movwf       USB_dev_req, BANKED        ; No device requests in process.
#ifdef SHOW_ENUM_STATUS
    clrf        TRISB, ACCESS              ; Set all bits of PORTB as outputs.
    movlw       0x01
    movwf       PORTB, ACCESS              ; Set bit zero to indicate Powered status.
#endif
    repeat                                 ; Wait
	PrintString USB_INITIALISED_RETRY
	call Delay
    untilclr    UCON, SE0, ACCESS          ;   ...until initial SE0 condition clears.
                                           ;   SE0 == Single Ended Zero
    return
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++    
Main
    clrf        PORTA,  ACCESS
    movlw       0x0F
    movwf       ADCON1, ACCESS    ; Set up PORTA to be digital I/Os rather than A/D converter.
    clrf        TRISA,  ACCESS    ; Set up all PORTA pins to be digital outputs.
    
    call	InitUsartComms
    PrintString HELLO_WORLD
    
    call        InitUSB           ; Initialize the USB registers and serial interface engine.
    PrintString USB_INITIALISED_DONE_STR

    repeat
        call     ServiceUSB       ; Service USB requests...
        banksel  USB_USWSTAT
    until USB_USWSTAT, EQ, CONFIG_STATE  ; ...until the host configures the peripheral
    
    PrintString PIC_CONFIGURED
    
    bsf         PORTA, 0, ACCESS      ; set RA0 high
    banksel     COUNTER_L
    clrf        COUNTER_L, BANKED
    clrf        COUNTER_H, BANKED

    PrintString MartyHERE

    repeat
        banksel COUNTER_L
        incf    COUNTER_L, F, BANKED
        ifset STATUS, Z, ACCESS
            incf COUNTER_H, F, BANKED
        endi
        ifset  COUNTER_H, 7, BANKED
            bcf PORTA, 1, ACCESS
        otherwise
            bsf PORTA, 1, ACCESS
        endi
        call   ServiceUSB

        ;PrintString DONE_THAT
    forever

    end
;  USB Reset sends the device into the default state.
;  Default State -> Address State -> Configured State



;   P18F2550 £4.80 https://coolcomponents.co.uk/products/pic-18f2550-mcu?utm_medium=cpc&utm_source=googlepla&variant=45222867086&gclid=EAIaIQobChMI7KP0mdHk1wIV5p3tCh1kUQI-EAkYASABEgLexfD_BwE
;   USB MICRO b    https://coolcomponents.co.uk/products/usb-b-socket-breakout-board
;   Do I have the capacitors.
;   DO I have the lead for that micro?
