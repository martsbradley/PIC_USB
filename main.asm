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

    
    
    extern PrintStrFn
    extern InitUsartComms, Delay
    extern InterruptServiceRoutine

    global RS232_RINGBUFFER, RS232_RINGBUFFER_HEAD, RS232_RINGBUFFER_TAIL
    global RS232_Temp_StrLen, RS232_Temp1, RS232_Temp2, RS232_Temp3
    global RS232_Temp4, RS232_Temp5, RS232_Temp6, RS232_Temp7,RS232_Temp8


    
;bank0        udata
mybank1 udata   0x300
RS232_RINGBUFFER      res SIZE         ;  this should be aligned on a byte.
RS232_RINGBUFFER_HEAD res 1
RS232_RINGBUFFER_TAIL res 1
RS232_Temp_StrLen     res 1
RS232_Temp1           res 1
RS232_Temp2           res 1
RS232_Temp3           res 1
RS232_Temp4           res 1
RS232_Temp5           res 1
RS232_Temp6           res 1
RS232_Temp7           res 1
RS232_Temp8           res 1

USB_BufferDescriptor  res 4
USB_BufferData        res 8
USB_error_flags       res 1  ; Was there an error.
USB_curr_config       res 1  ; Holds the value of the current configuration.
USB_device_status     res 1  ; Byte, sent to host request status
USB_dev_req           res 1
USB_address_pending   res 1
USB_desc_ptr          res 1  ; address of descriptor
USB_bytes_left        res 1
USB_loop_index        res 1
USB_packet_length     res 1
USB_USTAT             res 1 ; Saved copy of USTAT special function register in memory.
USB_USWSTAT           res 1 ; Current state POWERED_STATE|DEFAULT_STATE|ADDRESS_STATE|CONFIG_STATE 
COUNTER_L             res 1
COUNTER_H             res 1

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
OUTTOK:
    da "OUTK\r\n",0
PROCESS_ERR
    da "er\r\n",0
PROCESS_T
    da "t",0
    
PROCESS_SETUP_TOKEN_STR:
    da "s\r\n",0
PROCESS_OUT_TOKEN_STR:
    da "x\r\n",0
PROCESS_IN_TOKEN_STR:
    da "i\r\n",0
EP0InStr:
    da "z\r\n",0
EP1InStr:
    da "Z\r\n",0
EP2InStr:
    da "EP2InStr\r\n",0
EP1OutStr:
    da "T\r\n",0
SET_CONFIG_STR:
    da "q\r\n",0
HELLO_WORLD:
    da "Hi\r\n",0
POWERED_STATE_STR:
    da "Power\r\n",0
ADDRESS_STATE_STR:
    da "ADDR\r\n",0
DEFAULT_STATE_STR:
    da "DEFS\r\n",0
USB_INITIALISED:
    da "USB_init_called\r\n",0
SET_CONFIG_ERR_STR:
    da "e\r\n",0
PIC_CONFIGURED:
    da "Configured\r\n",0
IDLE_CONDITION:
    da "Idle\r\n",0
STALL_HANDSHAKE_STR:
    da "Stall\r\n",0
USB_RESET_STR:
    da "RST\r\n",0
GET_DEVICE_DESCRIPTOR_STR:
    da "Get_DeviceDescriptor\r\n",0
GET_CONFIG_DESCRIPTOR_STR:
    da "G_CD\r\n",0
GET_STRING_DESCRIPTOR_STR:
    da "G_SD\r\n",0
SET_DEVICE_ADDRESS_STR:
    da "S_AD\r\n",0

MARTY:
    da "MrY\r\n",0

USBSTUFF    code
getDescriptorByte
    movlw   upper Descriptor_begin
    movwf   TBLPTRU, ACCESS
    movlw   high Descriptor_begin
    movwf   TBLPTRH, ACCESS                  ; Now TBLPTR pointing towards descriptor. 
    movlw   low Descriptor_begin             ;
    banksel USB_desc_ptr                     ; ptr could be renamed idx.
    addwf   USB_desc_ptr, W, BANKED
    ifset STATUS, C, ACCESS
        incf TBLPTRH, F, ACCESS
        ifset STATUS, Z, ACCESS
            incf TBLPTRU, F, ACCESS
        endi
    endi
    movwf TBLPTRL, ACCESS
    TBLRD*                               ; Read from program memory.
    movf TABLAT, W                       ; Byte @ (Descriptor_begin + USB_desc_ptr) -> W
    return

Descriptor_begin
Device
    db            0x12, DEVICE             ; bLength, bDescriptorType
    db            0x10, 0x01               ; bcdUSB (low byte), bcdUSB (high byte)
    db            0x00, 0x00               ; bDeviceClass, bDeviceSubClass
    db            0x00, MAX_PACKET_SIZE    ; bDeviceProtocol, bMaxPacketSize
    db            0xD8, 0x04               ; idVendor (low byte), idVendor (high byte)
    db            0x14, 0x00               ; idProduct (low byte), idProduct (high byte)
    db            0x00, 0x00               ; bcdDevice (low byte), bcdDevice (high byte)
    db            0x01, 0x02               ; iManufacturer, iProduct (String idx)
    db            0x00, NUM_CONFIGURATIONS ; iSerialNumber (none), bNumConfigurations

Configuration1
    db            0x09, CONFIGURATION   ; bLength, bDescriptorType
    db            0x20, 0x00            ; wTotalLength (low byte), wTotalLength (high byte)
    db            NUM_INTERFACES, 0x01  ; bNumInterfaces, bConfigurationValue
    db            0x03, 0xA0            ; iConfiguration String idx , bmAttributes
    db            0x32, 0x09            ; bMaxPower (100 mA), bLength (***Interface1 descriptor starts here)

Interface1
    db            INTERFACE, 0x00       ; bDescriptorType, bInterfaceNumber
    db            0x00, 0x02            ; bAlternateSetting, bNumEndpoints (excluding EP0)
    db            0xFF, 0x00            ; bInterfaceClass (vendor specific class code), bInterfaceSubClass
    db            0xFF, 0x04            ; bInterfaceProtocol (vendor specific), iInterface String idx

EndPoint1
    db            0x07, ENDPOINT        ; bLength, bDescriptorType
    db            0x01, 0x03            ; (EP1 & Dir OUT), (Interrupt & No Synch)
    db            0x08, 0x00            ; eight bytes
    db            0x04, 0x07            ; Interval...?  bLength (endpoitn2)

EndPoint2
    db            ENDPOINT, 0x82        ; bDescriptorType, bEndpointAddr & Direction IN
    db            0x03, 0x08            ; No Synch Interrupt  
    db            0x00, 0x04            ; one byte
    
;EndPoint2
;    db            0x07, ENDPOINT        ; bLength, bDescriptorType
;    db            0x82, 0x03            ; bEndpointAddr & Direction IN, No Synch Interrupt  
;    db            0x01, 0x00            ; one byte
;    db            0x04                  ; Interval...?    

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
    db            String4-String3, STRING
    db            'M', 0x00
    db            'y', 0x00
    db            ' ', 0x00
    db            'c', 0x00
    db            'o', 0x00
    db            'n', 0x00
    db            'f', 0x00
    db            'i', 0x00
    db            'g', 0x00
String4
    db            Descriptor_end-String4, STRING
    db            'D', 0x00
    db            'M', 0x00
    db            'Z', 0x00
    db            ' ', 0x00
    db            'I', 0x00
    db            't', 0x00
    db            'r', 0x00
    db            'f', 0x00
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
	PrintStr IDLE_CONDITION
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
	    PrintStr POWERED_STATE_STR
            movlw    0x01
            break
        case DEFAULT_STATE
	    PrintStr DEFAULT_STATE_STR
            movlw    0x02
            break
        case ADDRESS_STATE
	    PrintStr ADDRESS_STATE_STR
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
	PrintStr STALL_HANDSHAKE_STR
        break
    caseset UIR, URSTIF, ACCESS    ; USB Reset occurred.
	PrintStr USB_RESET_STR
	
        banksel USB_curr_config
        clrf    USB_curr_config, BANKED
        bcf     UIR, TRNIF, ACCESS    ; clear TRNIF four times to clear out the USTAT FIFO
        bcf     UIR, TRNIF, ACCESS
        bcf     UIR, TRNIF, ACCESS
        bcf     UIR, TRNIF, ACCESS

        clrf    UEP0, ACCESS          ; clear all EP control registers 
        call clearNonControlEndPoints

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
        movlw    0x04              ; Buffer Descriptor table starts at Address 0x04
        movwf    FSR0H, ACCESS     ; Indirect addressing, copy in high byte.
        movf     USTAT, W, ACCESS  ; Read USTAT register for endpoint information
        andlw    0x7C              ; Mask out bits other than Endpoint and Direction
        movwf    FSR0L, ACCESS     ;    0000100 0EEEED00 (FSR0H-FSR0L)
        banksel  USB_BufferDescriptor   ; eg 0000100 00000000 EP0 Out -> 400h  // are in and out in the correct order
        movf     POSTINC0, W            ;    0000100 00000100 EP0 IN  -> 404h
                                        ;    0000100 00001000 EP1 Out -> 408h
                                        ;    0000100 00001100 EP1 In  -> 40ch
        movwf    USB_BufferDescriptor, BANKED  ; Copy received data to USB_BufferDescriptor
        movf     POSTINC0, W
        movwf    USB_BufferDescriptor+1, BANKED
        movf     POSTINC0, W
        movwf    USB_BufferDescriptor+2, BANKED
        movf     POSTINC0, W
        movwf    USB_BufferDescriptor+3, BANKED ; USB_BufferDescriptor now populated.
        movf     USTAT, W, ACCESS
        movwf    USB_USTAT, BANKED  ; Save the USB status register
        bcf      UIR, TRNIF, ACCESS ; Clear transaction complete interrupt flag
                                    ; USTAT FIFO can advance.
#ifdef SHOW_ENUM_STATUS
        andlw    0x18               ; Endpoint bits ENDP1:ENDP0 from USTAT register
        select                      ; Which endpoint was handled.
            case EP0
                movlw  0x20       ;0010 0000 pin 5, my red led.. for control End point.
                break                    
            case EP1                     
                movlw  0x40       ;0100 0000 pin 6
                break                    
            case EP2                     
                movlw  0x80       ;1000 000  pin 7
                break
        ends
        xorwf   PORTB, F, ACCESS    ; toggle bit 5, 6, or 7 to reflect EP activity
#endif
        clrf    USB_error_flags, BANKED    ; clear USB error flags

        ;PrintStr PROCESS_T

        movf    USB_BufferDescriptor, W, BANKED
                                 ; The PID is presented by the SIE in the BDnSTAT
        andlw   0x3C             ; extract PID bits 0011 1100 (PID3:PID2:PID1:PID0)

        select
        case TOKEN_SETUP
            ;PrintStr PROCESS_SETUP_TOKEN_STR
            call        ProcessSetupToken
            break
        case TOKEN_IN
            ;PrintStr PROCESS_IN_TOKEN_STR
            call        ProcessInToken
            break
        case TOKEN_OUT
            ;PrintStr PROCESS_OUT_TOKEN_STR
            call        ProcessOutToken
            break
        ends
        banksel USB_error_flags
        ifset USB_error_flags, 0, BANKED    ; if there was a Request Error...
            PrintStr PROCESS_ERR
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

    call copyPayloadToBufferData

    banksel  BD0OBC
    movlw    MAX_PACKET_SIZE
    movwf    BD0OBC, BANKED      ; reset the byte count
    movwf    BD0IST, BANKED      ; return the in buffer to us (dequeue any pending requests)
    banksel  USB_BufferData+bmRequestType


    ;  Really don't understand this if statement!!!!!
    ifclr USB_BufferData+bmRequestType, 7, BANKED  ; Host to Device.
        ifl  USB_BufferData+wLength,     NE, 0  ; 
        orif USB_BufferData+wLengthHigh, NE, 0  ; 
            movlw  0xC8     ; UOWN + DTS + INCDIS + DTSEN set
        otherwise
            movlw  0x88     ; UOWN + DTSEN set
        endi
    otherwise               ; Device to Host.
        movlw      0x88     ; UOWN + DTSEN set
    endi

    banksel BD0OST
    movwf   BD0OST, BANKED        ; set EP0 OUT UOWN back to USB and 
                                  ; DATA0/DATA1 packet according to request type
    bcf     UCON, PKTDIS, ACCESS  ; Assuming there is nothing to dequeue, 
                                  ; token and packet processing enabled.
    banksel USB_dev_req
    movlw   NO_REQUEST
    movwf   USB_dev_req, BANKED   ; clear the device request in process

    movf    USB_BufferData+bmRequestType, W, BANKED
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
    movf USB_BufferData+bRequest, W, BANKED
    select

    ; >>>>  STANDARD REQUESTS  <<<< ;
    case GET_STATUS   
        ;  The host can ask for the status of the device, an interface or an
        ;  end point.
        movf  USB_BufferData+bmRequestType, W, BANKED
        andlw 0x1F                    ; extract request recipient bits
        select
        case RECIPIENT_DEVICE
            call pointToCtrlEPInputBuffer
            banksel USB_device_status               
            movf    USB_device_status, W, BANKED 
            movwf   POSTINC0                   ; copy device status byte to EP0 buffer
            clrf    INDF0
            banksel BD0IBC
            call updateControlTxTwoBytes
            break

        case RECIPIENT_INTERFACE 
            movf USB_USWSTAT, W, BANKED
            select
            case ADDRESS_STATE
                ; Set Request Error flag
                bsf USB_error_flags, 0, BANKED
                break
            case CONFIG_STATE
                ; Used to return the status of the interface. Such a request to the 
                ; interface should return two bytes of value 0x00.

                ifl USB_BufferData+wIndex, LT, NUM_INTERFACES
                    call pointToCtrlEPInputBuffer
                    clrf POSTINC0         ;  It is only clearing the two bytes of data. 
                    clrf INDF0            ;  See comment 9 lines above.
                    call updateControlTxTwoBytes
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
                movf USB_BufferData+wIndex, W, BANKED ; Get EP
                andlw 0x0F                             ; Strip off direction bit
                ifset STATUS, Z, ACCESS                ; see if it is EP0
                    call pointToCtrlEPInputBuffer
                    banksel USB_BufferData+wIndex
                                                       
                    ifset USB_BufferData+wIndex, 7, BANKED ; If the specified direction is IN
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
                    call updateControlTxTwoBytes
                otherwise
                    bsf   USB_error_flags, 0, BANKED        ; set Request Error flag
                endi
                break
            case CONFIG_STATE

                call pointToCtrlEPInputBuffer

                movlw   high UEP0                   ; put UEP0 address...
                movwf   FSR1H, ACCESS
                movlw   low UEP0
                movwf   FSR1L, ACCESS               ; ...into FSR1
                movlw   high BD0OST                 ; put BDndST address...
                movwf   FSR2H, ACCESS

                ; Now ... 
                ; FSR0 contains address of BD0 IN BUFFER data
                ; FSR1 contains address of UEP0 
                ; FSR2 high byte contains high address of Buffer Descriptors Table
                ; FSR2 low byte calculated below.

                banksel USB_BufferData+wIndex
                movf    USB_BufferData+wIndex, W, BANKED
                andlw   0x8F                      ; mask out all but the direction bit 
                                                  ; and EP number.
                movwf   FSR2L, ACCESS
                                                  ;D000 EEEE  D -> direction bit, E -> Endpoint bit
                rlncf   FSR2L, F, ACCESS          ;000E EEED 
                rlncf   FSR2L, F, ACCESS          ;00EE EED0  FSR2L now contains the proper
                rlncf   FSR2L, F, ACCESS          ;0EEE ED00  offset into the BD table for the 
                                                  ;           specified EP

                                                  ;ENDPOINT  ADDRESS OFFSET
                                                  ;1 0001    00001D00    8 bytes
                                                  ;2 0010    00010D00    16 bytes
                                                  ;3 0011    00011D00    24 bytes  

                movlw  low BD0OST
                addwf  FSR2L, F, ACCESS           ; ...into FSR2
                ifset STATUS, C, ACCESS
                    incf FSR2H, F, ACCESS
                endi
                movf  USB_BufferData+wIndex, W, BANKED   ; Get EndPoint 
                andlw 0x0F                               ; Strip off direction bit leavng 
                                                         ; only End Point.
                ifset USB_BufferData+wIndex, 7, BANKED   ; if the specified EP direction is IN...
                                                         ; add endpoint number to FSR1 address to 
                                                         ; access relevant UEP* register
                    andifclr PLUSW1, EPINEN, ACCESS      ; ...and the specified EP is not 
                                                         ; enabled for IN transfers.
                    bsf      USB_error_flags, 0, BANKED  ; set Request Error flag

                elsifclr     USB_BufferData+wIndex, 7, BANKED   
                andifclr     PLUSW1, EPOUTEN, ACCESS    ; otherwise, if the 
                                                        ; specified EP direction is OUT
                                                        ; and the specified EP is
                                                        ; not enabled for OUT transfers.
                    bsf      USB_error_flags, 0, BANKED ; set Request Error flag
                otherwise
                    movf     INDF2, W                   ; move contents of specified BDndST 
                                                        ; register into WREG
                    andlw    0x04                       ; extract the BSTALL bit
                    movwf    INDF0
                    rrncf    INDF0, F
                    rrncf    INDF0, F                   ; shift BSTALL bit into the lsb position
                    clrf     PREINC0                                        
                    banksel  BD0IBC
                    call updateControlTxTwoBytes
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
        movf USB_BufferData+bmRequestType, W, BANKED
        andlw 0x1F                    ; extract request recipient bits
        select
        case RECIPIENT_DEVICE
            ; This device only handles remote wakeup.
            movf USB_BufferData+wValue, W, BANKED
            select
            case DEVICE_REMOTE_WAKEUP
                ifl USB_BufferData+bRequest, EQ, CLEAR_FEATURE
                    bcf  USB_device_status, 1, BANKED
                otherwise
                    bsf  USB_device_status, 1, BANKED
                endi
                call updateControlTxZeroBytes
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
                movf  USB_BufferData+wIndex, W, BANKED    ; get EP
                andlw 0x0F                                 ; strip off direction bit
                ifset STATUS, Z, ACCESS                    ; see if it is EP0
                    call updateControlTxZeroBytes
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

                movf  USB_BufferData+wIndex, W, BANKED   ; get EP
                andlw 0x0F                                ; strip off direction bit
                ifclr STATUS, Z, ACCESS                   ; if it was not EP0...
                    addwf FSR0L, F, ACCESS                ; add EP number to FSR0
                    ifset STATUS, C, ACCESS
                        incf FSR0H, F, ACCESS
                    endi
                    ; Now FSR0 has the address of the relevant UEPn register.

                    rlncf USB_BufferData+wIndex, F, BANKED
                    rlncf USB_BufferData+wIndex, F, BANKED
                    rlncf USB_BufferData+wIndex, W, BANKED   ; WREG now contains the proper offset into the BD table for the specified EP
                    andlw 0x7C                                ; mask out all but the direction bit and EP number (after three left rotates)
                    addwf FSR1L, F, ACCESS                    ; add BD table offset to FSR1
                    ifset STATUS, C, ACCESS
                        incf FSR1H, F, ACCESS
                    endi
                    ; Now FSR1 has the address of the Buffer descriptor.

                    ifset USB_BufferData+wIndex, 1, BANKED    ; if the specified EP direction (now bit 1) is IN...
                        ifset INDF0, EPINEN, ACCESS            ; if the specified EP is enabled for IN transfers...
                            ifl USB_BufferData+bRequest, EQ, CLEAR_FEATURE
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
                            ifl USB_BufferData+bRequest, EQ, CLEAR_FEATURE
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
                    call updateControlTxZeroBytes
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
        ifset USB_BufferData+wValue, 7, BANKED        ; if new device address is illegal, send Request Error
            bsf USB_error_flags, 0, BANKED    ; set Request Error flag
        otherwise
            ;PrintStr SET_DEVICE_ADDRESS_STR
            movlw   SET_ADDRESS
            movwf   USB_dev_req, BANKED           ; processing a set address request
            movf    USB_BufferData+wValue, W, BANKED
            movwf   USB_address_pending, BANKED   ; save new address
            call updateControlTxZeroBytes
        endi
    break

    ; >>>>  STANDARD REQUESTS  <<<< ;
    case GET_DESCRIPTOR
        movwf USB_dev_req, BANKED                ; processing a GET_DESCRIPTOR request
        movf  USB_BufferData+(wValue+1), W, BANKED
        select
        case DEVICE
            PrintStr GET_DEVICE_DESCRIPTOR_STR
            movlw low (Device-Descriptor_begin)
            movwf USB_desc_ptr, BANKED
            call  getDescriptorByte                ; get descriptor length
            movwf USB_bytes_left, BANKED
            call Update_USB_bytes_left
            call SendDescriptorPacket
            break

        case CONFIGURATION
            PrintStr GET_CONFIG_DESCRIPTOR_STR
            movf USB_BufferData+wValue, W, BANKED
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
                call getDescriptorByte            ; get total descriptor length
                movwf USB_bytes_left, BANKED
                movlw 0x02
                subwf USB_desc_ptr, F, BANKED    ; subtract offset for wTotalLength
                call Update_USB_bytes_left
                call SendDescriptorPacket
            endi
            break
        case STRING
            ;PrintStr GET_STRING_DESCRIPTOR_STR
            movf USB_BufferData+wValue, W, BANKED
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
            case 4
                movlw low (String4-Descriptor_begin)
                break		
            default
                bsf USB_error_flags, 0, BANKED    ; Set Request Error flag
            ends

            ifclr USB_error_flags, 0, BANKED
                movwf        USB_desc_ptr, BANKED
                call  getDescriptorByte        ; get descriptor length
                movwf USB_bytes_left, BANKED
                call Update_USB_bytes_left
                call SendDescriptorPacket
            endi
            break
        default
            bsf  USB_error_flags, 0, BANKED    ; set Request Error flag
        ends
        break

    ; >>>>  STANDARD REQUESTS  <<<< ;
    case GET_CONFIGURATION
        call pointToCtrlEPInputBuffer
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
        ifl USB_BufferData+wValue, LE, NUM_CONFIGURATIONS
            call clearNonControlEndPoints
            movf  USB_BufferData+wValue, W, BANKED
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
                call setupEndpoint1
		call setupEndpoint2
		
		
		
#endif
            ends

            call updateControlTxZeroBytes
        otherwise
            PrintStr SET_CONFIG_ERR_STR
            bsf     USB_error_flags, 0, BANKED    ; set Request Error flag
        endi
        break
    ; >>>>  STANDARD REQUESTS  <<<< ;
    case GET_INTERFACE
        movf        USB_USWSTAT, W, BANKED
        select
        case CONFIG_STATE
            ifl USB_BufferData+wIndex, LT, NUM_INTERFACES
                call pointToCtrlEPInputBuffer
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
            ifl USB_BufferData+wIndex, LT, NUM_INTERFACES
                movf  USB_BufferData+wValue, W, BANKED
                select
                case 0                                    ; currently support only bAlternateSetting of 0
                    call updateControlTxZeroBytes
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
    movf   USB_BufferData+bRequest, W, BANKED
    select
    default
        bsf  USB_error_flags, 0, BANKED    ; set Request Error flag
    ends
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
VendorRequests
    movf        USB_BufferData+bRequest, W, BANKED
    select
    case SET_RA0
        bsf         PORTA, 0, ACCESS        ; set RA0 high
        call updateControlTxZeroBytes
        break
    case CLR_RA0
        bcf         PORTA, 0, ACCESS        ; set RA0 low
        call updateControlTxZeroBytes

        break
    default
        bsf         USB_error_flags, 0, BANKED    ; set Request Error flag
    ends
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ProcessInToken
    banksel USB_USTAT
    movf  USB_USTAT, W, BANKED
    andlw 0x18        ; extract the EP bits
    ;PrintStr PROCESS_IN_TOKEN_STR
    select
    case EP0
        ;PrintStr EP0InStr
        movf USB_dev_req, W, BANKED
        select
        case SET_ADDRESS
            PrintStr SET_DEVICE_ADDRESS_STR
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
            call SendDescriptorPacket
            break
        ends
        break
    case EP1
        PrintStr EP1InStr
	break
    case EP2
        PrintStr EP2InStr
	;Send something to the host over USB.
	
	
        movlw   low (USB_Buffer+  4*MAX_PACKET_SIZE)
        movwf   FSR0L, ACCESS     
        movlw   high (USB_Buffer+ 4*MAX_PACKET_SIZE)
        movwf   FSR0H, ACCESS
	
	movlw   0x41  ; Char 'a'?
        movwf   POSTINC0
	movlw   0x42  ; Char 'b'?
        movwf   POSTINC0
	movlw   0x43  ; Char 'c'?
        movwf   POSTINC0
	movlw   0x44  ; Char 'd'?
        movwf   POSTINC0
	movlw   0x45  ; Char 'e'?
        movwf   POSTINC0
	movlw   0x46  ; Char '\0'
        movwf   POSTINC0
	movlw   0x47  ; Char '\0'
        movwf   POSTINC0
	movlw   0x00  ; Char '\0'
        movwf   POSTINC0
	
	
	
	banksel BD2IBC
	movlw   8
	movwf   BD2IBC, BANKED
	movlw   0x00
	movwf   BD2IST, BANKED
	break
    ends
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
ProcessOutToken
    ;PrintStr OUTTOK
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
        call updateControlTxZeroBytes
	break
    case EP1
        ; PrintStr EP1OutStr
        call copyPayloadToBufferData
        ; Receive data from the host.
	; and copy it to the RS232.
	
        ;PrintData USB_BufferData

	banksel BD1OBC
	movlw   MAX_PACKET_SIZE
	movwf   BD1OBC, BANKED
	movlw   0x80   ;  DISABLED SYNCHRONIATION DATA0/DATA1 ETC.
	movwf   BD1OST, BANKED
	break
    case EP2
	break
    ends
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Update_USB_bytes_left
    ifl USB_BufferData+(wLength+1), EQ, 0
    andiff USB_BufferData+wLength, LT, USB_bytes_left
        movf  USB_BufferData+wLength, W, BANKED
        movwf USB_bytes_left, BANKED
    endi
    return
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

SendDescriptorPacket
    banksel    USB_bytes_left
    ifl USB_bytes_left, LT, MAX_PACKET_SIZE
        movlw  NO_REQUEST
        movwf  USB_dev_req, BANKED    ; sending a short packet, so clear device request
        movf   USB_bytes_left, W, BANKED
    otherwise
        movlw  MAX_PACKET_SIZE
    endi
    subwf    USB_bytes_left, F, BANKED
    movwf    USB_packet_length, BANKED
    banksel  BD0IBC
    movwf    BD0IBC, BANKED           ; set EP0 IN byte count with packet size
    call pointToCtrlEPInputBuffer

    banksel  USB_loop_index
    forlf USB_loop_index, 1, USB_packet_length
        call  getDescriptorByte       ; get next byte of descriptor being sent
        movwf POSTINC0                ; copy to EP0 IN buffer, and increment FSR0
        incf  USB_desc_ptr, F, BANKED ; increment the descriptor pointer
        next USB_loop_index
    banksel   BD0IST
    movlw     0x40
    xorwf     BD0IST, W, BANKED       ; toggle the DATA01 bit
    andlw     0x40                    ; clear the PIDs bits
    iorlw     0x88                    ; set UOWN and DTS bits
    movwf     BD0IST, BANKED
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
updateControlTxTwoBytes:
    movlw   0x02
    movwf   BD0IBC, BANKED ; Setting byte count as 2 bytes
    movlw   0xC8
    movwf   BD0IST, BANKED ; Send packet as DATA1, set UOWN bit    
    return

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
updateControlTxZeroBytes:
    banksel BD0IBC
    clrf    BD0IBC, BANKED                    ; set byte count to 0
    movlw   0xC8
    movwf   BD0IST, BANKED ; Send packet as DATA1, set UOWN bit    
    return

pointToCtrlEPInputBuffer:
    banksel  BD0IAH
    movf     BD0IAH, W, BANKED              ;DUPLICATE
    movwf    FSR0H, ACCESS
    movf     BD0IAL, W, BANKED        ; get buffer pointer
    movwf    FSR0L, ACCESS
    return 

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
copyPayloadToBufferData:
    banksel  USB_BufferData
    movf     USB_BufferDescriptor+ADDRESSH, W, BANKED
    movwf    FSR0H, ACCESS
    movf     USB_BufferDescriptor+ADDRESSL, W, BANKED
    movwf    FSR0L, ACCESS
    movf     POSTINC0, W
    movwf    USB_BufferData, BANKED
    movf     POSTINC0, W
    movwf    USB_BufferData+1, BANKED  ; Move received bytes to USB_BufferData
    movf     POSTINC0, W
    movwf    USB_BufferData+2, BANKED  ; Move received bytes to USB_BufferData
    movf     POSTINC0, W
    movwf    USB_BufferData+3, BANKED  ; Move received bytes to USB_BufferData
    movf     POSTINC0, W
    movwf    USB_BufferData+4, BANKED  ; Move received bytes to USB_BufferData
    movf     POSTINC0, W
    movwf    USB_BufferData+5, BANKED  ; Move received bytes to USB_BufferData
    movf     POSTINC0, W
    movwf    USB_BufferData+6, BANKED  ; Move received bytes to USB_BufferData
    movf     POSTINC0, W
    movwf    USB_BufferData+7, BANKED  ; Move received bytes to USB_BufferData
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
setupEndpoint1:        
    banksel BD1OBC
    movlw   MAX_PACKET_SIZE       ; 8 bytes lowest packet size for low and high speed.
    movwf   BD1OBC, BANKED
    movlw   low (USB_Buffer+  2*MAX_PACKET_SIZE)    ; EP1 OUT gets a buffer...
    movwf   BD1OAL, BANKED
    movlw   high (USB_Buffer+ 2*MAX_PACKET_SIZE)    ; EP1 OUT gets a buffer...
    movwf   BD1OAH, BANKED
    movlw   0xC8                  ; set UOWN bit Data1 Data synchronization enabled.
    movlw   0x88                  ; set UOWN bit (SIE can write)
    movwf   BD1OST, BANKED        ; synchronization byte needed?

    movlw   ENDPT_OUT_ONLY        ; EP1 is gets output from host
    movwf   UEP1, ACCESS          ; 
    return
    
    
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
setupEndpoint2:
    banksel BD2IBC
    movlw   MAX_PACKET_SIZE       ; 8 bytes lowest packet size for low and high speed.
    movwf   BD2IBC, BANKED
    movlw   low (USB_Buffer+  4*MAX_PACKET_SIZE)    ; EP1 OUT gets a buffer...
    movwf   BD2IAL, BANKED
    movlw   high (USB_Buffer+ 4*MAX_PACKET_SIZE)    ; EP1 OUT gets a buffer...
    movwf   BD2IAH, BANKED
    movlw   0x80                  ;CPU owns buffer, no syn
    movwf   BD2IST, BANKED        ; synchronization byte needed?

    movlw   ENDPT_IN_ONLY        ; EP1 is gets output from host
    movwf   UEP2, ACCESS          ; 
    return
    
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
clearNonControlEndPoints:
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
    return

InitUSB
    PrintStr USB_INITIALISED
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

    bcf    RCON, IPEN,   ACCESS          ; Disable priority levels on interrupts.
    bsf    INTCON, GIE,  ACCESS          ; Enable all unmasked interrupts.
    bsf    INTCON, PEIE, ACCESS          ; Enables all unmasked peripheral interrupts.
    bcf    PIE1, TXIE ,  ACCESS          ; Disable transmission interrupts.

    PrintStr HELLO_WORLD
    
    call        InitUSB           ; Initialize the USB registers and serial interface engine.

    repeat
        call     ServiceUSB       ; Service USB requests...
        banksel  USB_USWSTAT
    until USB_USWSTAT, EQ, CONFIG_STATE  ; ...until the host configures the peripheral
    
    PrintStr PIC_CONFIGURED
    
    bsf         PORTA, 0, ACCESS      ; set RA0 high
    banksel     COUNTER_L
    clrf        COUNTER_L, BANKED
    clrf        COUNTER_H, BANKED

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
    
    
