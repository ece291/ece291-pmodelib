; DPMI Interface - Memory-related Functions
;  By Peter Johnson, 1999

%include "myC32.mac"

%assign MAXMEMHANDLES   16                      ; Maximum number of handles available

        BITS    32

        SECTION .data

LinearList      times MAXMEMHANDLES dd 0        ; Linear addresses
SizeList        times MAXMEMHANDLES dd 0        ; Allocated sizes (for lock function)
HandleList      times MAXMEMHANDLES dd 0        ; DPMI Memory block handles
SelectorList    times MAXMEMHANDLES dw 0        ; Selectors to locked memory blocks

NumHandles      db      0

        SECTION .text

;----------------------------------------
; unsigned short AllocMem(unsigned int Size);
; Purpose: Allocates a memory block of Size bytes.
; Inputs:  Size, the size of the memory block to allocate.
; Outputs: A library handle to the memory block.
; Notes:   Can only allocate a maximum of MAXMEMHANDLES blocks.
;----------------------------------------
proc _AllocMem

%$Size          arg     4               ; Size (in bytes) of memory block to allocate

        push    esi
        push    edi
        push    es

        mov     ecx, MAXMEMHANDLES
        cmp     byte [NumHandles], MAXMEMHANDLES        ; Check to see if we have a handle free
        jz      .error

.find:                                          ; Search for an empty handle
        cmp     dword [SizeList+ecx*4], 0
        loopnz  .find

        push    ecx                             ; Put the index on the stack

        mov     ax, 0501h                       ; [DPMI 0.9] Allocate Linear Memory Block
        mov     ebx, [ebp + %$Size]             ; Size of block (32 bit)
        mov     cx, bx
        shr     ebx, 16                         ; size of block is stored in bx:cx
        or      cx, 0FFFh                       ; set the lower 12 bits to 1 to page-align

        int     31h

        pop     edx                             ; Get the index into edx

        jnc     .ok

.error:
        mov     ax, 0FFFFh                      ; Error out
        jmp     .done

.ok:
        shl     ebx, 16                         ; make bx:cx -> ebx
        mov     bx, cx
        shl     esi, 16                         ; same for si:di -> esi
        mov     si, di

        mov     ecx, dword [ebp + %$Size]       ; get size
        or      ecx, 0FFFh                      ; page align it
        mov     dword [LinearList+edx*4], ebx   ; Save into lists
        mov     dword [HandleList+edx*4], esi
        mov     dword [SizeList+edx*4], ecx

        inc     byte [NumHandles]
        mov     eax, edx                        ; Return the internal handle

.done:
        pop     es
        pop     edi
        pop     esi

endproc

;----------------------------------------
; void FreeMem(unsigned short Handle);
; Purpose: Frees a memory block allocated by AllocMem().
; Inputs:  Handle, the library handle of the memory block to free.
; Outputs: None
; Notes:   No error checking.
;----------------------------------------
proc _FreeMem

%$Handle        arg     2               ; Internal handle of memory block to free

        push    esi
        push    edi
        push    es

        xor     ecx, ecx
        mov     cx, [ebp + %$Handle]            ; Get Handle parameter

        cmp     cx, 0ffffh                      ; Check for valid handle
        jz      .done

        push    ecx                             ; Save index

        mov     esi, dword [HandleList+ecx*4]   ; Split DPMI handle -> si:di
        mov     di, si
        shr     esi, 16

        mov     ax, 0502h                       ; [DPMI 0.9] Free Memory Block
        int     31h

        pop     edx                             ; Retrieve index

        mov     dword [LinearList+edx*4], 0     ; Reset list values
        mov     dword [SizeList+edx*4], 0
        mov     dword [HandleList+edx*4], 0

.done:
        pop     es
        pop     edi
        pop     esi

endproc

;----------------------------------------
; char *LockMem(unsigned short Handle);
; Purpose: Get a selector to an allocated memory block.
; Inputs:  Handle, the library handle of the memory block to lock.
; Outputs: AX=selector
; Notes:   Not actually C-callable as such, as it doesn't return a valid
;          C pointer, but conforms to C calling convention.
;----------------------------------------
proc _LockMem

%$Handle        arg     2               ; Internal handle to lock

        push    esi
        push    edi

        xor     ecx, ecx
        mov     cx, [ebp + %$Handle]            ; Get Handle parameter

        cmp     cx, 0ffffh                      ; Check for valid handle
        jz      .error

        mov     ax, 0000h                       ; [DPMI 0.9] Allocate LDT Descriptor(s)
        mov     cx, 1                           ; 1 descriptor needed
        int     31h
        jc      .error
        mov     cx, [ebp + %$Handle]            ; Get Handle
        mov     word [SelectorList+ecx*2], ax   ; Save allocated selector
        mov     dx, ax                          ; Also save into a register that won't get clobbered

        mov     esi, dword [SizeList+ecx*4]     ; Split size -> si:di
        mov     di, si
        shr     esi, 16
        mov     ebx, dword [LinearList+ecx*4]   ; Split linear address -> bx:cx
        mov     cx, bx
        shr     ebx, 16
        mov     ax, 0600h                       ; [DPMI 0.9] Lock Linear Region
        int     31h
        jc      .error

        mov     ax, dx                          ; Put the selector in AX to keep it from getting clobbered
        mov     dx, cx                          ; Move linear address from above (bx:cx) -> cx:dx
        mov     cx, bx
        mov     bx, ax                          ; Now move the selector into BX
        mov     ax, 0007h                       ; [DPMI 0.9] Set Segment Base Address
        int     31h
        jc      .error

        mov     ax, 0008h                       ; [DPMI 0.9] Set Segment Limit
        mov     cx, si                          ; Move size from above (si:di) -> cx:dx
        mov     dx, di
        int     31h
        jc      .error

        mov     ax, bx                          ; Return selector

        jmp     .done
.error:
        mov     cx, [ebp + %$Handle]            ; Get Handle
        mov     ax, 0                           ; Return 0
        mov     word [SelectorList+ecx*2], 0    ; Clear selector
.done:
        pop     edi
        pop     esi

endproc

;----------------------------------------
; void UnlockMem(unsigned short Handle);
; Purpose: Unlocks memory locked by LockMem().
; Inputs:  Handle, the library handle of the block to unlock.
; Outputs: None
; Notes:   After this function is called, the selector originally returned
;          by LockMem will be invalid (and will cause an exception if used).
;----------------------------------------
proc _UnlockMem

%$Handle        arg     2               ; Internal handle to unlock

        push    esi
        push    edi

        xor     ecx, ecx
        mov     cx, [ebp + %$Handle]            ; Get Handle parameter

        cmp     cx, 0ffffh                      ; Check for valid handle
        jz      .done

        push    ecx                             ; Save handle

        mov     bx, word [SelectorList+ecx*2]   ; Get selector
        cmp     bx, 0
        jz      .done
        mov     ax, 0001h                       ; [DPMI 0.9] Free LDT Descriptor
        int     31h

        mov     esi, dword [SizeList+ecx*4]     ; Split size -> si:di
        mov     di, si
        shr     esi, 16
        mov     ebx, dword [LinearList+ecx*4]   ; Split linear address -> bx:cx
        mov     cx, bx
        shr     ebx, 16
        mov     ax, 0601h                       ; [DPMI 0.9] Unlock Linear Region
        int     31h

        pop     ecx                             ; Get handle
        mov     word [SelectorList+ecx*2], 0    ; Clear selector

.done:
        pop     edi
        pop     esi
        
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

%$LinearAddressPtr      arg     4
%$SelectorPtr           arg     4
%$PhysicalAddress       arg     4
%$Size                  arg     4

        push    esi
        push    edi
        push    ebx

        ; First map the physical address into linear memory
        ; If it's below the 1MB limit, just directly map it (bugfix)
        mov     ebx, [ebp+%$PhysicalAddress]
        cmp     ebx, 100000h
        jb      .LinearMappingDone

        mov     ecx, ebx
        shr     ebx, 16         ; BX:CX = physical address of memory
        mov     esi, [ebp+%$Size]
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
        mov     edi, [ebp+%$LinearAddressPtr]
        mov     [edi], ebx      ; Save linear mapping

        ; Now get a selector for the memory region
        mov     ax, 0000h       ; [DPMI 0.9] Allocate LDT Descriptor(s)
        xor     ecx, ecx        ; Clear high word of ecx because of GDB bug
        mov     cx, 1           ; Get 1 descriptor
        int     31h
        jc      .SelectorError

        mov     edi, [ebp+%$SelectorPtr]
        mov     [edi], ax       ; Save selector

        ; Set the base and limit for the new selector
        mov     ecx, ebx
        mov     edx, ebx
        shr     ecx, 16         ; CX:DX = 32-bit linear base address
        mov     bx, ax          ; BX = selector
        mov     ax, 0007h       ; [DPMI 0.9] Set Segment Base Address
        int     31h
        jc      .SelectorError

        mov     ecx, [ebp+%$Size]
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
        mov     ebx, [ebp+%$PhysicalAddress]
        cmp     ebx, 100000h
        jb      .LinearMappingFreeDone

        mov     edi, [ebp+%$LinearAddressPtr]
        mov     ebx, [edi]
        mov     ecx, ebx
        shr     ebx, 16         ; BX:CX = linear address
        mov     ax, 0801h       ; [DPMI 0.9] Free Physical Address Mapping
        int     31h

.LinearMappingFreeDone:
        mov     edi, [ebp+%$LinearAddressPtr]
        mov     dword [edi], 0
.error:
        mov     eax, 1
.done:

        pop     ebx
        pop     edi
        pop     esi
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

%$LinearAddressPtr      arg     4
%$SelectorPtr           arg     4

        push    esi

        ; First, free the linear address mapping
        mov     esi, [ebp+%$LinearAddressPtr]
        mov     ebx, [esi]

        cmp     ebx, 100000h
        jb      .LinearMappingFreeDone  ; If <1MB, don't need to free

        mov     ecx, ebx
        shr     ebx, 16         ; BX:CX = linear address
        mov     ax, 0801h       ; [DPMI 0.9] Free Physical Address Mapping
        int     31h

.LinearMappingFreeDone:
        mov     dword [esi], 0

        mov     esi, [ebp+%$SelectorPtr]
        mov     bx, [esi]       ; BX = selector to free
        test    bx, bx          ; Make sure the selector is valid (eg, not 0)
        jz      .Done
        mov     ax, 0001h       ; [DPMI 0.9] Free LDT Descriptor
        int     31h

        mov     word [esi], 0

.Done:
        pop     esi
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

%$Selector      arg     2
%$Offset        arg     4
%$Length        arg     4

        push    esi
        push    edi

        mov     ax, 0006h               ; [DPMI 0.9] Get Segment Base Address
        mov     bx, [ebp+%$Selector]
        int     31h
        jc      .Done

        shl     ecx, 16                 ; Move cx:dx address into ecx
        mov     cx, dx

        add     ecx, [ebp+%$Offset]     ; Add in offset into selector
        
        mov     ebx, ecx                ; Linear address in bx:cx
        shr     ebx, 16

        mov     esi, [ebp+%$Length]     ; Length in si:di
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

endproc
