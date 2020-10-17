    #include p18f2550.inc
    #include util_macros.inc
    #include rs232.inc
   
    global InitUsartComms, PrintStrFn
    global RS232_ReadByteFromBuffer
    
    extern RS232_RINGBUFFER, RS232_RINGBUFFER_HEAD, RS232_RINGBUFFER_TAIL
    extern RS232_Temp_StrLen, RS232_Temp1, RS232_Temp2, RS232_Temp3
    extern RS232_Temp4, RS232_Temp5, RS232_Temp6, RS232_Temp7,RS232_Temp8

    
    


; To make this RS232 transmission interrupt driven
; create three bytes that hold the upper middle and 
; lower portions of address of the string to be printed.
; 
; The table registers are adjusted by the handler 
; so these will need saved and restored by the 
; interrupt handler.

;         TBLPTRU TBLPTRH TBLPTRL
;
; Ensure that the PIR1,TXIF is 1 so ready to send.
; Update the three registers with the address of the
;
; The upper/high/low address of the string will be stored 
; to three rs232 registers RS232PTRU RS232PTRH RS232PTRL
;
; InterruptHandler:
;    Populate the TBLPTR registers from RS232PTR U/H/L
;    Lookup table to get the byte for W
;    Write out the data from W.
;    copy the latest TBLPTR registers to the RS232PTR U/H/L
;    Check for zero, clear interrupt flag.
;    Copy the byte to TXREG  
;
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

RS232_CODE  code
  

  
  
InitUsartComms:                 ; Setup the usart hardware
    call RS232_RingBufferInit
    bsf   TRISC, 7, ACCESS
    bsf   TRISC, 6, ACCESS
    banksel TXSTA
    movlw 0x19                 ; BAUD 9600  & FOSC 4000000L
    ;movlw 0x0c                  ; BAUD 19200 & FOSC 4000000L
    movwf SPBRG,ACCESS          ; 8 bit communication rather than 9bit
    movlw 0x04                  ; TXEN = 0, BRGH = 1
    movwf TXSTA,ACCESS          ; Asynchronous, TXEN
    banksel RCSTA
    movlw 0x90                  ; DIVIDER ((int)(FOSC/(16UL * BAUD) -1))
    movwf RCSTA,ACCESS          ; HIGH_SPEED 1
    
    bsf TXSTA, TXEN, ACCESS  ; Enable transmission, causes an interrupt.
    return

   
    
;Return the number of stored bytes in W
RS232_RingBufferInit:
    clrf RS232_RINGBUFFER_HEAD, BANKED
    clrf RS232_RINGBUFFER_TAIL, BANKED
    
    
   movlw SIZE
   movwf RS232_RINGBUFFER_HEAD, BANKED    
   
RS232_RingBufferInit_ClearByte:
   decf RS232_RINGBUFFER_HEAD, F, BANKED
   movlw high RS232_RINGBUFFER  ; Point again to the head of the RingBuffer
   movwf FSR2H, ACCESS
   movlw low RS232_RINGBUFFER
   addwf RS232_RINGBUFFER_HEAD, W, BANKED    
   movwf FSR2L, ACCESS    
   
   clrf POSTINC2,  ACCESS       ; Clear the buffer
   
   movf RS232_RINGBUFFER_HEAD, F, BANKED ;set the status bits.
   btfss STATUS,Z, ACCESS  ; If zero bit is set, skip the goto
   goto RS232_RingBufferInit_ClearByte
   
   clrf RS232_RINGBUFFER_HEAD, BANKED
   clrf RS232_RINGBUFFER_TAIL, BANKED
   return 
    

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
    movf RS232_RINGBUFFER_HEAD, W, BANKED
    cpfseq RS232_RINGBUFFER_TAIL, BANKED; skip if equal
    goto RS232_RingBufferBytesNotEmpty
    goto RS232_RingBufferBytesEmpty

RS232_RingBufferBytesNotEmpty:
    cpfsgt RS232_RINGBUFFER_TAIL, BANKED; skip if tail > head
    goto RS232_RingBufferTail_LT_HEAD

RS232_RingBufferBytesEmpty:
RS232_RingBufferTail_GT_HEAD:
    ; size = tail - head;
    movf  RS232_RINGBUFFER_HEAD, W, BANKED
    subwf RS232_RINGBUFFER_TAIL, W, BANKED 
    return

RS232_RingBufferTail_LT_HEAD:
    ; size = (SIZE - head) + tail;
    
    movf RS232_RINGBUFFER_HEAD, W, BANKED
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
BackupTablePointer:   
    movf TBLPTRU, W, ACCESS 
    movwf RS232_Temp5, BANKED

    movf TBLPTRH, W, ACCESS 
    movwf RS232_Temp6, BANKED

    movf TBLPTRL, W, ACCESS 
    movwf RS232_Temp7, BANKED
    return
;===============================================================================
RestoreTablePointer:   
    movf RS232_Temp5, W, BANKED 
    movwf TBLPTRU, ACCESS
    
    movf RS232_Temp6, W, BANKED 
    movwf TBLPTRH, ACCESS

    movf RS232_Temp7, W, BANKED 
    movwf TBLPTRL, ACCESS   
    return
;===============================================================================
StringLengthFN:
    call BackupTablePointer
    
    clrf RS232_Temp_StrLen, BANKED      ; Initialize counter to 0
StringLengthFNNext:
    tblrd*+                 ; Read byte and increment pointer
    movf TABLAT, W, ACCESS  ; Take the read byte from the latch.

    addlw 0x00              ; Check for end of string \0 character
    btfsc STATUS,Z, ACCESS  ; If zero bit is clear, skip the goto
    goto StringLengthDone
    incf RS232_Temp_StrLen, F, BANKED
    goto StringLengthFNNext

StringLengthDone:
    call RestoreTablePointer
    incf RS232_Temp_StrLen, F, BANKED   ; Increment once for the \0
    movf RS232_Temp_StrLen, W, BANKED
    
    return 
;===============================================================================
; Move byte in w onto the buffer    
; Return -1 (0xFF) if there are no bytes to be read
RS232_ReadByteFromBuffer:    
    ;Are here more than 0 bytes stored?
   call RS232_RingBufferBytesStored_Fn
   btfsc STATUS,Z, ACCESS  ; If zero bit is clear, skip the return
   retlw 0xFF		   ; return -1 if there is no data.
   
   movlw high RS232_RINGBUFFER  ; Point into the RingBuffer
   movwf FSR2H, ACCESS
   movlw low RS232_RINGBUFFER
   addwf RS232_RINGBUFFER_HEAD, W, BANKED    
   movwf FSR2L, ACCESS    
        
   movf POSTINC2, W, ACCESS       ; Read character into W
   movwf RS232_Temp8, BANKED    ; Keep the byte to be written.
   
   movlw high RS232_RINGBUFFER  ; Point again to the head of the RingBuffer
   movwf FSR2H, ACCESS
   movlw low RS232_RINGBUFFER
   addwf RS232_RINGBUFFER_HEAD, W, BANKED    
   movwf FSR2L, ACCESS    
   
   clrf POSTINC2,  ACCESS       ; Clear the buffer
   
   
   incf  RS232_RINGBUFFER_HEAD, F, BANKED 
   movlw SIZE - 1
   andwf RS232_RINGBUFFER_HEAD, F, BANKED  ;  Wrap around 
   

   
   movf RS232_Temp8, W, BANKED  ; The byte to be written -> W
   return
    
    
;===============================================================================
; Move byte in w onto the buffer    
RS232_AddByteToBuffer:
   movwf RS232_Temp3, BANKED    ; Keep the byte to be written.
 
   movlw high RS232_RINGBUFFER  ; Point into the RingBuffer
   movwf FSR2H, ACCESS
   movlw low RS232_RINGBUFFER
   addwf RS232_RINGBUFFER_TAIL, W, BANKED    
   movwf FSR2L, ACCESS           

   movf RS232_Temp3, W, BANKED  ; The byte to be written -> W
   movwf POSTINC2, ACCESS       ; Write character onto the buffer

   incf  RS232_RINGBUFFER_TAIL, F, BANKED 
   movlw SIZE - 1
   andwf RS232_RINGBUFFER_TAIL, F, BANKED  ;  Wrap around 
   movf RS232_Temp3, W, BANKED ; Put the byte back into W for test for \0
   return

;===============================================================================

PrintStrFn:
    ; If there space in the buffer to hold the string
    call StringLengthFN
    movwf RS232_Temp4, BANKED

    bcf PIE1, TXIE,  ACCESS   ; Disable interrupts as we want the ring buffer
			      ; not to change while updating it.      
			      
    call RS232_RingBufferBytesFree_FN
    ; Loosing one byte because using <, should be <=
    cpfslt RS232_Temp4, BANKED; skip next when String length < Bytes Free
    goto PrintStrFnDone       ; Don't print string.

RS232_AddNextByte:
    tblrd*+                 ; Read byte and increment pointer
    movf TABLAT, W, ACCESS  ; Take the read byte from the latch.

    call RS232_AddByteToBuffer

    ; If zero was just added then 
    ; raise the interrupt enable and return.

    addlw 0x00              ; Check for end of string \0 character
    btfss STATUS,Z, ACCESS  ; If zero bit is set stop adding bytes
    goto RS232_AddNextByte

    ; Update the RS232 to send the details from the buffer.
    
PrintStrFnDone:   
    bsf PIE1, TXIE,  ACCESS   ; Enable interrupts again
    return
    
    
    
    END                         ;Stop assembling here
