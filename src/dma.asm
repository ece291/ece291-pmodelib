; DMA interface code (used primarily by sound routines)
;  By Peter Johnson, 1999
;
; Code history (C version):
;       - Allegro
;	- MikMod
;	- GUS SDK (!)
;
%include "myC32.mac"
%include "dpmi_mem.inc"

        BITS    32

; DMA Controller #1 (8-bit controller)
DMA1_STAT       equ     8h              ; read status register
DMA1_WCMD       equ     8h              ; write command register
DMA1_WREQ       equ     9h              ; write request register
DMA1_SNGL       equ     0Ah             ; write single bit register
DMA1_MODE       equ     0Bh             ; write mode register
DMA1_CLRFF      equ     0Ch             ; clear byte ptr flip/flop
DMA1_MCLR       equ     0Dh             ; master clear register
DMA1_CLRM       equ     0Eh             ; clear mask register
DMA1_WRTALL     equ     0Fh             ; write all mask register

; DMA Controller #2 (16-bit controller)
DMA2_STAT       equ     0D0h            ; read status register
DMA2_WCMD       equ     0D0h            ; write command register
DMA2_WREQ       equ     0D2h            ; write request register
DMA2_SNGL       equ     0D4h            ; write single bit register
DMA2_MODE       equ     0D6h            ; write mode register
DMA2_CLRFF      equ     0D8h            ; clear byte ptr flip/flop
DMA2_MCLR       equ     0DAh            ; master clear register
DMA2_CLRM       equ     0DCh            ; clear mask register
DMA2_WRTALL     equ     0DEh            ; write all mask register

; stuff for each DMA channel
DMA0_ADDR       equ     0h              ; chan 0 base adddress
DMA0_CNT        equ     1h              ; chan 0 base count
DMA1_ADDR       equ     2h              ; chan 1 base adddress
DMA1_CNT        equ     3h              ; chan 1 base count
DMA2_ADDR       equ     4h              ; chan 2 base adddress
DMA2_CNT        equ     5h              ; chan 2 base count
DMA3_ADDR       equ     6h              ; chan 3 base adddress
DMA3_CNT        equ     7h              ; chan 3 base count
DMA4_ADDR       equ     0C0h            ; chan 4 base adddress
DMA4_CNT        equ     0C2h            ; chan 4 base count
DMA5_ADDR       equ     0C4h            ; chan 5 base adddress
DMA5_CNT        equ     0C6h            ; chan 5 base count
DMA6_ADDR       equ     0C8h            ; chan 6 base adddress
DMA6_CNT        equ     0CAh            ; chan 6 base count
DMA7_ADDR       equ     0CCh            ; chan 7 base adddress
DMA7_CNT        equ     0CEh            ; chan 7 base count

DMA0_PAGE       equ     87h             ; chan 0 page register (refresh)
DMA1_PAGE       equ     83h             ; chan 1 page register
DMA2_PAGE       equ     81h             ; chan 2 page register
DMA3_PAGE       equ     82h             ; chan 3 page register
DMA4_PAGE       equ     8Fh             ; chan 4 page register (unuseable)
DMA5_PAGE       equ     8Bh             ; chan 5 page register
DMA6_PAGE       equ     89h             ; chan 6 page register
DMA7_PAGE       equ     8Ah             ; chan 7 page register


        struc DMA_ENTRY
.dma_disable    resb    1               ; bits to disable dma channel
.dma_enable     resb    1               ; bits to enable dma channel
.page           resw    1               ; page port location
.addr           resw    1               ; addr port location
.count          resw    1               ; count port location
.single         resw    1               ; single mode port location
.mode           resw    1               ; mode port location
.clear_ff       resw    1               ; clear flip-flop port location
.write          resb    1               ; bits for write transfer
.read           resb    1               ; bits for read transfer
        endstruc


        SECTION .data

mydma
        ; channel 0
        istruc DMA_ENTRY
        at DMA_ENTRY.dma_disable,db 4
        at DMA_ENTRY.dma_enable,db 0
        at DMA_ENTRY.page,      dw DMA0_PAGE
        at DMA_ENTRY.addr,      dw DMA0_ADDR
        at DMA_ENTRY.count,     dw DMA0_CNT
        at DMA_ENTRY.single,    dw DMA1_SNGL
        at DMA_ENTRY.mode,      dw DMA1_MODE
        at DMA_ENTRY.clear_ff,  dw DMA1_CLRFF
        at DMA_ENTRY.write,     db 48h
        at DMA_ENTRY.read,      db 44h
        iend
        ; channel 1
        istruc DMA_ENTRY
        at DMA_ENTRY.dma_disable,db 5
        at DMA_ENTRY.dma_enable,db 1
        at DMA_ENTRY.page,      dw DMA1_PAGE
        at DMA_ENTRY.addr,      dw DMA1_ADDR
        at DMA_ENTRY.count,     dw DMA1_CNT
        at DMA_ENTRY.single,    dw DMA1_SNGL
        at DMA_ENTRY.mode,      dw DMA1_MODE
        at DMA_ENTRY.clear_ff,  dw DMA1_CLRFF
        at DMA_ENTRY.write,     db 49h
        at DMA_ENTRY.read,      db 45h
        iend
        ; channel 2
        istruc DMA_ENTRY
        at DMA_ENTRY.dma_disable,db 6
        at DMA_ENTRY.dma_enable,db 2
        at DMA_ENTRY.page,      dw DMA2_PAGE
        at DMA_ENTRY.addr,      dw DMA2_ADDR
        at DMA_ENTRY.count,     dw DMA2_CNT
        at DMA_ENTRY.single,    dw DMA1_SNGL
        at DMA_ENTRY.mode,      dw DMA1_MODE
        at DMA_ENTRY.clear_ff,  dw DMA1_CLRFF
        at DMA_ENTRY.write,     db 4Ah
        at DMA_ENTRY.read,      db 46h
        iend
        ; channel 3
        istruc DMA_ENTRY
        at DMA_ENTRY.dma_disable,db 7
        at DMA_ENTRY.dma_enable,db 3
        at DMA_ENTRY.page,      dw DMA3_PAGE
        at DMA_ENTRY.addr,      dw DMA3_ADDR
        at DMA_ENTRY.count,     dw DMA3_CNT
        at DMA_ENTRY.single,    dw DMA1_SNGL
        at DMA_ENTRY.mode,      dw DMA1_MODE
        at DMA_ENTRY.clear_ff,  dw DMA1_CLRFF
        at DMA_ENTRY.write,     db 4Bh
        at DMA_ENTRY.read,      db 47h
        iend
        ; channel 4
        istruc DMA_ENTRY
        at DMA_ENTRY.dma_disable,db 4
        at DMA_ENTRY.dma_enable,db 0
        at DMA_ENTRY.page,      dw DMA4_PAGE
        at DMA_ENTRY.addr,      dw DMA4_ADDR
        at DMA_ENTRY.count,     dw DMA4_CNT
        at DMA_ENTRY.single,    dw DMA2_SNGL
        at DMA_ENTRY.mode,      dw DMA2_MODE
        at DMA_ENTRY.clear_ff,  dw DMA2_CLRFF
        at DMA_ENTRY.write,     db 48h
        at DMA_ENTRY.read,      db 44h
        iend
        ; channel 5
        istruc DMA_ENTRY
        at DMA_ENTRY.dma_disable,db 5
        at DMA_ENTRY.dma_enable,db 1
        at DMA_ENTRY.page,      dw DMA5_PAGE
        at DMA_ENTRY.addr,      dw DMA5_ADDR
        at DMA_ENTRY.count,     dw DMA5_CNT
        at DMA_ENTRY.single,    dw DMA2_SNGL
        at DMA_ENTRY.mode,      dw DMA2_MODE
        at DMA_ENTRY.clear_ff,  dw DMA2_CLRFF
        at DMA_ENTRY.write,     db 49h
        at DMA_ENTRY.read,      db 45h
        iend
        ; channel 6
        istruc DMA_ENTRY
        at DMA_ENTRY.dma_disable,db 6
        at DMA_ENTRY.dma_enable,db 2
        at DMA_ENTRY.page,      dw DMA6_PAGE
        at DMA_ENTRY.addr,      dw DMA6_ADDR
        at DMA_ENTRY.count,     dw DMA6_CNT
        at DMA_ENTRY.single,    dw DMA2_SNGL
        at DMA_ENTRY.mode,      dw DMA2_MODE
        at DMA_ENTRY.clear_ff,  dw DMA2_CLRFF
        at DMA_ENTRY.write,     db 4Ah
        at DMA_ENTRY.read,      db 46h
        iend
        ; channel 7
        istruc DMA_ENTRY
        at DMA_ENTRY.dma_disable,db 7
        at DMA_ENTRY.dma_enable,db 3
        at DMA_ENTRY.page,      dw DMA7_PAGE
        at DMA_ENTRY.addr,      dw DMA7_ADDR
        at DMA_ENTRY.count,     dw DMA7_CNT
        at DMA_ENTRY.single,    dw DMA2_SNGL
        at DMA_ENTRY.mode,      dw DMA2_MODE
        at DMA_ENTRY.clear_ff,  dw DMA2_CLRFF
        at DMA_ENTRY.write,     db 4Bh
        at DMA_ENTRY.read,      db 47h
        iend

mydma_end
     
        SECTION .text

DMA_Start_Funcs         ; Mark the beginning of code area to lock

;----------------------------------------
; bool DMA_Allocate_Mem(int Size, short *Selector, unsigned long *LinearAddress)
; Purpose: Allocates the specified amount of conventional memory, ensuring that
;          the returned block doesn't cross a page boundary.
; Inputs:  Size, size (in bytes) to allocate for the DMA butter
; Outputs: Selector, the selector that should be used to free the block
;          LinearAddress, the linear address of the block
;          On error, eax=1, Selector=LinearAddress=0.
;----------------------------------------
proc _DMA_Allocate_Mem

%$Size          arg     4
%$Selector      arg     4
%$LinearAddress arg     4

        ; Allocate twice as much memory as we really need
        mov     ebx, [ebp+%$Size]
        shl     ebx, 1                  ; 2x
        add     ebx, 15                 ; correct for rounding
        shr     ebx, 4                  ; 16-byte paragraphs

        mov	ax, 0100h	; [DPMI 0.9] Allocate DOS Memory Block
	int	31h
        jc      .error

        mov     ebx, [ebp+%$Selector]
        mov     [ebx], dx       ; Save selector

        and     eax, 0FFFFh     ; Mask off high 16 bits of eax
        shl     eax, 4          ; Change the returned segment into a linear address

        ; If it crosses a page boundary, use the second half of the block
        ; (if linaddr>>16 != (linaddr+size)>>16, it crosses a page boundary)
        mov     ebx, eax
        shr     ebx, 16

        mov     edx, eax
        add     edx, [ebp+%$Size]
        shr     edx, 16

        cmp     ebx, edx
        je      .save

        add     eax, [ebp+%$Size]

.save:
        ; Save LinearAddress
        mov     ebx, [ebp+%$LinearAddress]
        mov     [ebx], eax

        xor     eax, eax
        jmp     .done
.error:
        xor     eax, eax
        mov     ebx, [ebp+%$Selector]
        mov     [ebx], ax
        mov     edx, [ebp+%$LinearAddress]
        mov     [edx], eax
        inc     eax
.done:

endproc

;----------------------------------------
; void DMA_Start(int Channel, unsigned long Address, int Size, bool auto_init, bool Write)
; Purpose: Starts the DMA controller for the specified channel, transferring
;          size bytes from addr (the block must not cross a page boundary).
; Inputs:  Channel, DMA channel to start controller on
;          Address, linear address to transfer data from
;          Size, number of bytes to transfer
;          auto_init, if set, use the endless repeat DMA mode
;          Write, if set, use write mode, otherwise use read mode
;          (use read mode when doing sound input)
; Outputs: None
;----------------------------------------
proc _DMA_Start

%$Channel       arg     4
%$Address       arg     4
%$Size          arg     4
%$auto_init     arg     4
%$Write         arg     4

        push    esi
        push    edi

        mov     edx, [ebp+%$Channel]    ; edx = channel
        mov     esi, edx
        imul    esi, byte DMA_ENTRY_size
        add     esi, mydma              ; offset into mydma array

        mov     ebx, [ebp+%$Address]    ; ebx = address
        mov     ecx, ebx
        shr     ecx, 16                 ; ecx = page

        mov     eax, [ebp+%$Size]       ; eax = size

        cmp     edx, 4
        jb      .not16bit               ; 16 bit data is halved

        shr     ebx, 1                  ; address/=2
        shr     eax, 1                  ; size/=2

.not16bit:
        mov     edx, eax                ; edx = size        

        and     ebx, 0FFFFh             ; ebx = offset = address & 0xffff
        dec     edx                     ; size--

        cmp     dword [ebp+%$Write], 0
        jz      .NotWrite
        mov     eax, [esi+DMA_ENTRY.write]      ; eax = mode
        jmp     short .DoneWrite
.NotWrite:
        mov     eax, [esi+DMA_ENTRY.read]       ; eax = mode
.DoneWrite:

        cmp     dword [ebp+%$auto_init], 0
        jz      .NotAutoInit
        or      eax, 10h                ; mode |= 0x10
.NotAutoInit:

        mov     [ebp+%$Size], edx       ; put size back on stack, to free edx
        mov     edi, eax                ; edi = mode, to free eax

        ; disable channel
        mov     dx, [esi+DMA_ENTRY.single]
        mov     al, [esi+DMA_ENTRY.dma_disable]
        out     dx, al
        ; set mode
        mov     dx, [esi+DMA_ENTRY.mode]
        mov     eax, edi                ; grab mode
        out     dx, al
        ; clear flip-flop
        mov     dx, [esi+DMA_ENTRY.clear_ff]
        xor     eax, eax                ; out 0
        out     dx, al
        ; address LSB
        mov     dx, [esi+DMA_ENTRY.addr]
        mov     eax, ebx                ; grab offset
        out     dx, al
        ; address MSB
        shr     eax, 8
        out     dx, al
        ; page number
        mov     dx, [esi+DMA_ENTRY.page]
        mov     eax, ecx                ; grab page
        out     dx, al
        ; clear flip-flop
        mov     dx, [esi+DMA_ENTRY.clear_ff]
        xor     eax, eax                ; out 0
        out     dx, al
        ; count LSB
        mov     dx, [esi+DMA_ENTRY.count]
        mov     eax, [ebp+%$Size]       ; grab size
        out     dx, al
        ; count MSB
        shr     eax, 8
        out     dx, al
        ; enable channel
        mov     dx, [esi+DMA_ENTRY.single]
        mov     al, [esi+DMA_ENTRY.dma_enable]
        out     dx, al

        pop     edi
        pop     esi

endproc

;----------------------------------------
; void DMA_Stop(int Channel)
; Purpose: Disables the specified DMA channel.
; Inputs:  Channel, the DMA channel to disable
; Outputs: None
;----------------------------------------
proc _DMA_Stop

%$Channel       arg     4

        mov     ebx, [ebp+%$Channel]
        imul    ebx, byte DMA_ENTRY_size
        add     ebx, mydma              ; offset into mydma array

        mov     dx, [ebx+DMA_ENTRY.single]
        mov     al, [ebx+DMA_ENTRY.dma_disable]
        out     dx, al

endproc


;----------------------------------------
; unsigned long DMA_Todo(int Channel)
; Purpose: Returns the current position in a DMA transfer. Interrupts should be
;          disabled before calling this function.
; Inputs:  Channel, the channel to get the position of
; Outputs: The current position in the selected channel
;----------------------------------------
proc _DMA_Todo

%$Channel       arg     4

        mov     ebx, [ebp+%$Channel]
        imul    ebx, byte DMA_ENTRY_size
        add     ebx, mydma              ; offset into mydma array

        mov     dx, [ebx+DMA_ENTRY.clear_ff]
        mov     al, 0ffh
        out     dx, al

        mov     dx, [ebx+DMA_ENTRY.count]

        xor     ebx, ebx        ; clear high 16 bits
        xor     ecx, ecx
.loop:
        in      al, dx  ; low word
        xor     bx, bx
        mov     bl, al
        in      al, dx  ; high word
        shl     ax, 8
        or      bx, ax

        in      al, dx  ; low word
        xor     cx, cx
        mov     cl, al
        in      al, dx  ; high word
        shl     ax, 8
        or      cx, ax

        sub     bx, cx
        cmp     bx, 40h
        jg      .loop

        mov     eax, [ebp+%$Channel]
        cmp     al, 3
        jle     .not16bit
        shl     ecx, 1          ; double count for 16 bit transfers
.not16bit

        mov     eax, ecx        ; return count

endproc

DMA_End_Funcs           ; Mark the end of code area to lock


;----------------------------------------
; void DMA_Lock_Mem(void)
; Purpose: Locks the memory used by the dma routines.
; Inputs:  None
; Outputs: None
;----------------------------------------
        GLOBAL  _DMA_Lock_Mem
_DMA_Lock_Mem

        invoke  _LockArea, ds, dword mydma, dword mydma_end-mydma
        invoke  _LockArea, cs, dword DMA_Start_Funcs, dword DMA_End_Funcs-DMA_Start_Funcs

        ret

