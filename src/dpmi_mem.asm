; DPMI Interface - Memory-related Functions
;  By Peter Johnson, 1999-2001
;
; $Id: dpmi_mem.asm,v 1.9 2001/04/17 23:40:32 pete Exp $
%include "myC32.mac"

%assign MAXMEMHANDLES   16                      ; Maximum number of handles available

        BITS    32

; Define libc functions used for memory allocation
	EXTERN ___sbrk

___sbrk_arglen	equ	4

        SECTION .data

rcsid	db	'$Id: dpmi_mem.asm,v 1.9 2001/04/17 23:40:32 pete Exp $',0

HandleList      times MAXMEMHANDLES dd 0        ; DPMI Memory block handles
SelectorList    times MAXMEMHANDLES dw 0        ; Selectors to memory blocks

        SECTION .text

;----------------------------------------
; void *AllocMem(unsigned int Size);
; Purpose: Allocates Size bytes of memory by extending DS.
; Inputs:  Size, the amount of memory to allocate.
; Outputs: Returns offset of allocated memory, or -1 on error.
; Notes:   This function works by extending the DS selector limit by Size bytes
;          and returning the old limit.
;----------------------------------------
proc _AllocMem

.Size           arg     4

	; FIXME: write our own version of this! :)
	; Note to the curious: see DJGPP/src/libc/crt0/crt0.S to see how
	;  complex this function really is.
	invoke	___sbrk, dword [ebp+.Size]
	ret
endproc

;----------------------------------------
; short AllocSelector(unsigned int Size);
; Purpose: Allocates a memory block of Size bytes.
; Inputs:  Size, the size (in bytes) of the memory block to allocate.
; Outputs: AX=selector for the memory block, or -1 on error.
; Notes:   Can only allocate a maximum of MAXMEMHANDLES blocks.
;----------------------------------------
proc _AllocSelector

.Size           arg     4

.Index          equ     -4              ; free index into arrays

.STACK_FRAME_SIZE	equ     20

	sub	esp, .STACK_FRAME_SIZE	; allocate space for local vars
	push    esi
        push    edi
        push    es

        mov     ax, -1

        xor     ecx, ecx
.Find:                                          ; Search for an empty slot
        cmp     word [SelectorList+ecx*2], 0
        jne     near .Next

	mov     [ebp+.Index], ecx               ; Save found index
        
	mov     ax, 0000h                       ; [DPMI 0.9] Allocate LDT Descriptor(s)
        mov     cx, 1                           ; 1 descriptor needed
        int     31h
        jc      .Error
        
        mov     ecx, [ebp+.Index]               ; Retrieve index
	mov     word [SelectorList+ecx*2], ax   ; Save allocated selector
        

        mov     ax, 0501h                       ; [DPMI 0.9] Allocate Linear Memory Block
        mov     ebx, [ebp + .Size]              ; Size of block (32 bit)
        mov     cx, bx
        shr     ebx, 16                         ; size of block is stored in bx:cx
        or      cx, 0FFFh                       ; set the lower 12 bits to 1 to page-align
        int     31h
	jc      .Error

        mov     eax, [ebp+.Index]               ; Retrieve index

        shl     esi, 16                         ; Combine DPMI handle si:di
        mov     si, di                          ; into esi
	mov     [HandleList+eax*4], esi         ; and save
        
        mov	dx, cx				; Move bx:cx -> cx:dx
        mov     cx, bx
	mov     bx, [SelectorList+eax*2]        ; Now move the selector into BX
        mov     ax, 0007h                       ; [DPMI 0.9] Set Segment Base Address
        int     31h
        jc      .Error

        mov     ax, 0008h                       ; [DPMI 0.9] Set Segment Limit
        mov     ecx, [ebp + .Size]              ; Size of block (32 bit)
        mov     dx, cx
        shr     ecx, 16                         ; size of block is stored in cx:dx
        or      dx, 0FFFh                       ; set the lower 12 bits to 1 to page-align
	int     31h
        jc      .Error

        mov     eax, [ebp+.Index]
        mov     ax, [SelectorList+eax*2]        ; Return selector

        jmp     short .Done

.Error:
	cmp     word [SelectorList+ecx*2], 0
        je      .DontFree

        ; Free the allocated selector
	mov     bx, [SelectorList+ecx*2]
	mov     ax, 0001h                       ; [DPMI 0.9] Free LDT Descriptor
        int     31h
	mov     word [SelectorList+ecx*2], 0    ; Show as being free in array
.DontFree:
	mov     ax, -1
        jmp     short .Done

.Next:	
	inc     ecx
        cmp     ecx, MAXMEMHANDLES
	jl      near .Find

.Done:
        pop     es
        pop     edi
        pop     esi
	mov	esp, ebp			; discard storage for local variables
	ret
endproc

;----------------------------------------
; void FreeSelector(unsigned short Selector);
; Purpose: Frees a memory block allocated by AllocMem().
; Inputs:  Selector, the selector of the memory block to free.
; Outputs: None
;----------------------------------------
proc _FreeSelector

.Selector	arg     2

        push    esi
        push    edi
        push    es

        mov     bx, [ebp + .Selector]           ; Get parameter

        xor     ecx, ecx
.Find:                                          ; Search for selector
        cmp     [SelectorList+ecx*2], bx
        jne     .Next
        
        ; Selector is already in bx
	mov     ax, 0001h                       ; [DPMI 0.9] Free LDT Descriptor
        int     31h
        
	mov     esi, dword [HandleList+ecx*4]   ; Split DPMI handle -> si:di
        mov     di, si
        shr     esi, 16

        mov     ax, 0502h                       ; [DPMI 0.9] Free Memory Block
        int     31h

        xor     eax, eax
        mov     [HandleList+ecx*4], eax         ; Reset list values
        mov     [SelectorList+ecx*2], ax
        
	jmp     short .Done

.Next:
	inc     ecx
        cmp     ecx, MAXMEMHANDLES
	jl      .Find

.Done:
        pop     es
        pop     edi
        pop     esi
	ret
endproc

;----------------------------------------
; bool GetPhysicalMapping(unsigned int *LinearAddress,
;  short *Selector, unsigned long PhysicalAddress, int Size);
; Purpose: Maps a physical memory region into linear memory space.
; Inputs:  PhysicalAddress, the starting physical address to map.
;          Size, the size of the region to map.
; Outputs: LinearAddress, the linear address of the mapped region.
;          Selector, a selector that can be used to access the region.
;          AX=1 if an error occurred, 0 otherwise.
; Notes:   This function is used by the library to map the physical address
;          returned by VESA into a linear address/selector so it can be used
;          to draw directly into the framebuffer.
;----------------------------------------
proc _GetPhysicalMapping

.LinearAddressPtr       arg     4
.SelectorPtr            arg     4
.PhysicalAddress        arg     4
.Size                   arg     4

        push    esi
        push    edi
        push    ebx

        ; First map the physical address into linear memory
        ; If it's below the 1MB limit, just directly map it (bugfix)
        mov     ebx, [ebp+.PhysicalAddress]
        cmp     ebx, 100000h
        jb      .LinearMappingDone

        mov     ecx, ebx
        shr     ebx, 16         ; BX:CX = physical address of memory
        mov     esi, [ebp+.Size]
        mov     edi, esi
        shr     esi, 16         ; SI:DI = size of region to map (bytes)
        mov     ax, 0800h       ; [DPMI 0.9] Physical Address Mapping
        int     31h
        jc      .error          ; Returns linear address in BX:CX

        mov     ax, 0600h       ; [DPMI 0.9] Lock Linear Region
        int     31h
        jc      .error

        shl     ebx, 16         ; Put (locked) linear address into ebx
        mov     bx, cx

.LinearMappingDone:
        mov     edi, [ebp+.LinearAddressPtr]
        mov     [edi], ebx      ; Save linear mapping

        ; Now get a selector for the memory region
        mov     ax, 0000h       ; [DPMI 0.9] Allocate LDT Descriptor(s)
        xor     ecx, ecx        ; Clear high word of ecx because of GDB bug
        mov     cx, 1           ; Get 1 descriptor
        int     31h
        jc      .SelectorError

        mov     edi, [ebp+.SelectorPtr]
        mov     [edi], ax       ; Save selector

        ; Set the base and limit for the new selector
        mov     ecx, ebx
        mov     edx, ebx
        shr     ecx, 16         ; CX:DX = 32-bit linear base address
        mov     bx, ax          ; BX = selector
        mov     ax, 0007h       ; [DPMI 0.9] Set Segment Base Address
        int     31h
        jc      .SelectorError

        mov     ecx, [ebp+.Size]
        dec     ecx
        mov     edx, ecx
        shr     ecx, 16         ; CX:DX = 32-bit segment limit
        mov     ax, 0008h       ; [DPMI 0.9] Set Segment Limit
        int     31h
        jc      .SelectorError

        xor     eax, eax
        jmp     .done
.SelectorError:
        ; If error while allocating selector, free the linear mapping
        mov     ebx, [ebp+.PhysicalAddress]
        cmp     ebx, 100000h
        jb      .LinearMappingFreeDone

        mov     edi, [ebp+.LinearAddressPtr]
        mov     ebx, [edi]
        mov     ecx, ebx
        shr     ebx, 16         ; BX:CX = linear address
        mov     ax, 0801h       ; [DPMI 0.9] Free Physical Address Mapping
        int     31h

.LinearMappingFreeDone:
        mov     edi, [ebp+.LinearAddressPtr]
        mov     dword [edi], 0
.error:
        mov     eax, 1
.done:

        pop     ebx
        pop     edi
        pop     esi
	ret
endproc

;----------------------------------------
; void FreePhysicalMapping(unsigned int *LinearAddress, short *Selector);
; Purpose: Frees the resources allocated by GetPhysicalMapping().
; Inputs:  LinearAddress, the linear address of the mapping to free.
;          Selector, the selector used to point to the mapped memory block.
; Outputs: None
; Notes:   LinearAddress and Selector are cleared to 0.
;----------------------------------------
proc _FreePhysicalMapping

.LinearAddressPtr       arg     4
.SelectorPtr            arg     4

        push    esi

        ; First, free the linear address mapping
        mov     esi, [ebp+.LinearAddressPtr]
        mov     ebx, [esi]

        cmp     ebx, 100000h
        jb      .LinearMappingFreeDone  ; If <1MB, don't need to free

        mov     ecx, ebx
        shr     ebx, 16         ; BX:CX = linear address
        mov     ax, 0801h       ; [DPMI 0.9] Free Physical Address Mapping
        int     31h

.LinearMappingFreeDone:
        mov     dword [esi], 0

        mov     esi, [ebp+.SelectorPtr]
        mov     bx, [esi]       ; BX = selector to free
        test    bx, bx          ; Make sure the selector is valid (eg, not 0)
        jz      .Done
        mov     ax, 0001h       ; [DPMI 0.9] Free LDT Descriptor
        int     31h

        mov     word [esi], 0

.Done:
        pop     esi
	ret
endproc

;----------------------------------------
; bool LockArea(short Selector, unsigned int Offset, unsigned int Length)
; Purpose: Locks an area of memory so it's safe for an interrupt handler
;          to access
; Inputs:  Selector, selector of the area to lock
;          Offset, offset in selector of the start of the area
;          Length, length of the area
; Outputs: AX=1 on error, 0 otherwise
;----------------------------------------
proc _LockArea

.Selector       arg     2
.Offset         arg     4
.Length         arg     4

        push    esi
        push    edi

        mov     ax, 0006h               ; [DPMI 0.9] Get Segment Base Address
        mov     bx, [ebp+.Selector]
        int     31h
        jc      .Done

        shl     ecx, 16                 ; Move cx:dx address into ecx
        mov     cx, dx

        add     ecx, [ebp+.Offset]      ; Add in offset into selector
        
        mov     ebx, ecx                ; Linear address in bx:cx
        shr     ebx, 16

        mov     esi, [ebp+.Length]      ; Length in si:di
        mov     edi, esi
        shr     esi, 16

        mov     ax, 0600h               ; [DPMI 0.9] Lock Linear Region
        int     31h
        jc      .Error

        xor     eax, eax
        jmp     short .Done

.Error:
        mov     eax, 1

.Done:
        pop     edi
        pop     esi
	ret
endproc
