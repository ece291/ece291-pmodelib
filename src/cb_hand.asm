; RM Callback Wrappers and handling functions
;  By Peter Johnson, 1999
%include "myC32.mac"
%include "dpmi_mem.inc"
%include "dpmi_int.inc"

        BITS    32

        EXTERN  ___djgpp_ds_alias

; How many stacks to allocate for the callback wrappers. Could
; probably get away with fewer of these (but it could be dangerous :)
MAX_RMCBS       equ     4               ; mouse + spares
RMCB_STACKS     equ     MAX_RMCBS
STACK_SIZE      equ     8*1024          ; an 8k stack should be plenty
STACK_SIZE_SHIFT equ    13

        SECTION .bss

        ALIGN 4

_RMCB_Registers resd RMCB_STACKS        	; Pointers to DPMI register structures
                                                ; (stored at "bottom" of wrapper stacks)

_RMCB_StackData resb RMCB_STACKS*STACK_SIZE     ; Pointers to wrapper stacks
__end_RMCB_StackData

        SECTION .data

        ALIGN 4

_RMCB_Lock_Area

_RMCBReturnTypes times MAX_RMCBS db 0   ; Return types of the wrappers (1=retf/0=iret)
_RMCBStacks     times RMCB_STACKS dd 0  ; Stacks for handler use (pointers into _RMCBStackData)
_RMCBHandlers   times MAX_RMCBS dd 0    ; Addresses of program callback handlers
_RMCBInHandlers times MAX_RMCBS db 0    ; Indicator of handler status (1=in handler)
_RMCBCallCounts times MAX_RMCBS dd 0    ; Number of times this handler has been called

__end_RMCB_Lock_Area

_RMCB_Wrappers
        dd      _RMCB_Wrap0, _RMCB_Wrap1, _RMCB_Wrap2, _RMCB_Wrap3

_RMCB_Virgin    db      1

_RMCB_RM_Addresses      times MAX_RMCBS dd 0

        SECTION .text

%macro RMCBWRAP 1
        ALIGN 4
_RMCB_Wrap%{1}:
	o16 push es
	o16 push ds
	o16 push es
	o16 pop	ds
        
	; __djgpp_ds_alias is secured selector
        mov     ax, [cs:___djgpp_ds_alias]
	mov	ds, ax
	
	inc	dword [_RMCBCallCounts+4*%{1}]
	
        ; Don't allow recursive calls
	cmp	byte [_RMCBInHandlers+%{1}], 0
	jne	.bypass
	mov	byte [_RMCBInHandlers+%{1}], 1
        
	; Set up remaining selectors	
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	
        ; Set up our own stack
	mov	ebx, [_RMCBStacks+4*%{1}]
	cld
	mov	ecx, esp
	mov	dx, ss
	mov	ss, ax
	mov	esp, ebx
	
        ; Save wrapper registers we need to keep values of
	push	edx
	push	ecx
	push	esi
	push	edi

        ; Call the user handler
	call	[_RMCBHandlers+4*%{1}]

        ; Restore wrapper registers
	pop	edi
	pop	esi
	pop	eax
	pop	ebx
	
        ; Restore DPMI stack
	mov	ss, bx
	mov	esp, eax

	; Allow us to be called again
	mov     byte [_RMCBInHandlers+%{1}], 0

.bypass:
	; Get our return type
	xor     eax, eax
	mov     al, [_RMCBReturnTypes+%{1}]

	; Restore selectors we've put on the stack	
	o16 pop	ds
	o16 pop	es

        ; Set return frame in DPMI_Regs structure given to us by DPMI
	mov	eax, [esi]
	mov	[es:edi+DPMI_IP_off], eax

        ; Do the proper return (retf=1/iret=0)
        or      eax, eax
        jz      .doiret

        ; RETF return
	add     word [es:edi+DPMI_SP_off], 4	; SP+=4
	iret

.doiret:
        ; IRET return
	mov     ax, [esi+4]
	mov     [es:edi+DPMI_FLAGS_off], ax
	add     word [es:edi+DPMI_SP_off], 6	; SP+=6
	iret
%endmacro

_RMCB_Wrap

RMCBWRAP 0
RMCBWRAP 1
RMCBWRAP 2
RMCBWRAP 3

        ALIGN 4
__end_RMCB_Wrap

;----------------------------------------
; boolean Get_RMCB(unsigned short *RM_Segment, unsigned short *RM_Offset,
;	unsigned int Handler_Address, boolean ReturnTypeRETF);
; Purpose: Gets a real-mode callback handler for the specified PM handler, allocating
;          a wrapper function which will save registers and handle the stack
;          switching.  The real-mode segment and offset to pass to the real-mode
;          function (eg, mouse interrupt) are returned into the variables pointed
;          to by RM_Segment and RM_Offset.  The return type of the handler is
;          signaled by ReturnTypeRETF (1=retf, 0=iret).
; Inputs:  Handler_Address, the address of the handler function
;          ReturnTypeRETF, return type of the wrapper (1=retf, 0=iret)
; Outputs: RM_Segment, the real-mode segment address of the callback function
;          RM_Offset, the real-mode offset address of the callback function
;	   EAX=1 on error (unable to allocate a wrapper), 0 otherwise
; Notes:   A maximum of MAX_RMCB wrappers may be allocated using this function.
;----------------------------------------
proc _Get_RMCB

%$RM_Segment    	arg     4
%$RM_Offset     	arg     4
%$Handler_Address       arg     4
%$ReturnTypeRETF        arg     4

        cmp     byte [_RMCB_Virgin], 0      ; first time we've been called?
        je      near .FindRMCB

        ; Lock up data arrays
        invoke  _LockArea, ds, dword _RMCB_Lock_Area, dword __end_RMCB_Lock_Area-_RMCB_Lock_Area
        ; Lock up wrapper functions
        invoke  _LockArea, cs, dword _RMCB_Wrap, dword __end_RMCB_Wrap-_RMCB_Wrap
        ; Lock and set up stacks
        invoke  _LockArea, ds, dword _RMCB_StackData, dword __end_RMCB_StackData-_RMCB_StackData

        mov     ecx, RMCB_STACKS
.SetUpStacks:
        mov     edx, ecx
        dec     ecx
        shl     edx, STACK_SIZE_SHIFT
        sub     edx, 32
        add     edx, _RMCB_StackData    	; stacks grow downwards, so:
        mov     [_RMCBStacks+ecx*4], edx	; RMCB_Stacks[x] = [offset]RMCB_StackData+(x+1)*STACK_SIZE-32
        sub     edx, STACK_SIZE-32      	; place DPMI registers structures at bottom of stack
        mov     [_RMCB_Registers+ecx*4], edx	; RMCB_Registers[x] = [offset]RMCB_StackData+x*STACK_SIZE

        test    ecx, ecx
        jnz     .SetUpStacks

        mov     byte [_RMCB_Virgin], 0

.FindRMCB:
        ; Find a free wrapper and allocate it
        xor     ecx, ecx
.FindUnusedWrapper:
        cmp     dword [_RMCBHandlers+ecx*4], 0
        jne     near .NextWrapper

        ; Save parameters in array
        mov     edx, [ebp+%$Handler_Address]
        mov     [_RMCBHandlers+ecx*4], edx
        mov     ebx, [ebp+%$ReturnTypeRETF]
        mov     [_RMCBReturnTypes+ecx], bl

        ; Clear array flags
        mov     byte [_RMCBInHandlers+ecx], 0
        mov     dword [_RMCBCallCounts+ecx*4], 0

        ; Get a callback address from DPMI
        push    ecx                             ; Save the wrapper #

	push    ds                              ; Save registers
        push    es
        push    esi
        push    edi

        mov     esi, [_RMCB_Wrappers+ecx*4]     ; Offset of handler
        mov     edi, [_RMCB_Registers+ecx*4]    ; Offset of DPMI registers structure
        
	push	ds                              ; ES:EDI = DPMI registers structure
        pop     es
	
	push    cs                              ; DS:ESI = handler
        pop     ds
	        
	mov     ax, 0303h               ; [DPMI 0.9] Allocate Real Mode Callback Address
        int     31h

        pop     edi                             ; Restore registers
        pop     esi
	pop     es
        pop     ds

        pop     ebx                     ; Restore the wrapper #

        jc      .Done                   ; Leave if error

        ; Grab return values
        mov     eax, [ebp+%$RM_Segment]
        mov     [eax], cx
        mov     eax, [ebp+%$RM_Offset]
        mov     [eax], dx

        ; Save RM seg:off in library for check in Free_RMCB
        shl     ecx, 16
        mov     cx, dx
        mov     [_RMCB_RM_Addresses+ebx*4], ecx

        xor     eax, eax
        jmp     short .Done
.NextWrapper:
        inc     ecx
        cmp     ecx, MAX_RMCBS
        jl      near .FindUnusedWrapper

        mov     eax, 1
.Done:

endproc

;----------------------------------------
; void Free_RMCB(short RM_Segment, short RM_Offset);
; Purpose: Frees a real-mode callback wrapper
; Inputs:  RM_Segment, the real-mode segment address of the callback function
;          RM_Offset, the real-mode offset address of the callback function
; Outputs: None
;----------------------------------------
proc _Free_RMCB

%$RM_Segment	arg     2
%$RM_Offset     arg     2

        mov     bx, [ebp+%$RM_Segment]
        shl     ebx, 16
        mov     bx, [ebp+%$RM_Offset]
        
	xor     ecx, ecx
.FindWrapper:
        cmp     [_RMCB_RM_Addresses+ecx*4], ebx
        jne     .NextWrapper

	push	ecx
	 
        ; Tell DPMI to free callback
        xor     eax, eax
        mov     ax, 0304h               ; [DPMI 0.9] Free Real Mode Callback Address
        mov     cx, [ebp+%$RM_Segment]  ; Segment of callback
        mov     dx, [ebp+%$RM_Offset]   ; Offset of callback
        int     31h

        pop     ecx

        ; Indicate wrapper as being free
        xor     eax, eax
        mov     [_RMCB_RM_Addresses+ecx*4], eax
        mov     [_RMCBHandlers+ecx*4], eax

        jmp     short .Done
.NextWrapper:        
        inc     ecx
        cmp     ecx, MAX_RMCBS
        jl      .FindWrapper

.Done:

endproc
