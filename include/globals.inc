; General constants and stuff
;  By Peter Johnson, 1999

        EXTERN _VideoBlock      ; 32-bit Video Block Selector
        EXTERN _ScratchBlock    ; Scratch Block (1 meg)
        EXTERN _textsel         ; Selector to the textmode ram

NET_BUFFER_SIZE equ     16*1024         ; Network send/receive buffer size
                                        ; (per buffer)
        
RXBuffer        equ     0               ; Receive Data Buffer (offset into NetTransferSel)
TXBuffer        equ     NET_BUFFER_SIZE ; Transmit Data Buffer (offset into NetTransferSel)

