; Interrupt Wrappers and handling functions
;  By Peter Johnson, 1999
;
; Wrapper function by DJ Delorie, Shawn Hargreaves, and others.
;
%include "myC32.mac"
%include "dpmi_mem.inc"

        BITS    32

        EXTERN  ___djgpp_ds_alias

; How many stacks to allocate for the irq wrappers. Could
; probably get away with fewer of these (but it could be dangerous :)
MAX_INTS        equ     8               ; timer + keyboard + soundcard + spares
INT_STACKS      equ     MAX_INTS
STACK_SIZE      equ     8*1024          ; an 8k stack should be plenty
STACK_SIZE_SHIFT equ    13

; Actually 16x8-byte structure:
;  4 bytes address, 2 bytes segment, 2 bytes padding
        
        SECTION .bss

        ALIGN 4

_Int_Lock_Area

_StackData      resb INT_STACKS*STACK_SIZE

_OldIntVectors  resd MAX_INTS*2		; Pointers to original interrupt handlers
_IntStacks      resd INT_STACKS		; Stacks for handler use (pointers into _StackData)
_IntHandlers    resd MAX_INTS		; Addresses of program interrupt handlers
_IntNumbers     resd MAX_INTS		; IRQ number the wrapper is allocated to

__end_Int_Lock_Area

_Default_PIC    resb 2
_Altered_PIC    resb 2

        SECTION .data

        ALIGN 4

_IntWrappers
        dd      _Int_Wrap0,  _Int_Wrap1,  _Int_Wrap2,  _Int_Wrap3
        dd      _Int_Wrap4,  _Int_Wrap5,  _Int_Wrap6,  _Int_Wrap7

_Int_Virgin     db      1
_PIC_Virgin     db      1

        SECTION .text

%macro INTWRAP 1
        ALIGN 4
_Int_Wrap%{1}:
        o16 push ds                     ; save registers
        o16 push es
        o16 push fs
        o16 push gs
        pusha
        
        ; __djgpp_ds_alias is interrupt secured selector
        mov     ax, [cs:___djgpp_ds_alias]
        mov     ds, ax                  ; set up selectors
        mov     es, ax
        mov     fs, ax
        mov     gs, ax
        
        mov     ecx, INT_STACKS-1       ; look for a free stack
        ; Search from the last toward the first
.StackSearchLoop:
        lea     ebx, [_IntStacks+ecx*4]
        cmp     ebx, 0
        jnz     .FoundStack             ; found one!
        
        dec     ecx                     ; backward
        jnz     .StackSearchLoop
        
        jmp     .GetOut                 ; No free stack!
        
.FoundStack:
        mov     ecx, esp                ; save old stack in dx:ecx
        mov     dx, ss
        
        mov     esp, [ebx]              ; set up our stack
        mov     ss, ax
        
        mov     dword [ebx], 0          ; flag the stack is in use
        
        push    edx                     ; push old stack onto new
        push    ecx
        push    ebx
        
        cld                             ; clear the direction flag
        
        mov     eax, _IntHandlers+4*%1
        call    [eax]                   ; call the C handler
   
        cli
        
        pop     ebx                     ; restore the old stack
        pop     ecx
        pop     edx
        mov     [ebx], esp
        mov     ss, dx
        mov     esp, ecx
        
        or      eax, eax                ; check return value
        jz      .GetOut
        
        popa                            ; chain to old handler
        o16 pop gs
        o16 pop fs
        o16 pop es
        o16 pop ds
        
        jmp far [cs:_OldIntVectors+8*%{1}]
        
.GetOut:
        popa                            ; iret
        o16 pop gs
        o16 pop fs
        o16 pop es
        o16 pop ds
        sti
        iret
%endmacro

_IntWrap

INTWRAP 0
INTWRAP 1
INTWRAP 2
INTWRAP 3
INTWRAP 4
INTWRAP 5
INTWRAP 6
INTWRAP 7

        ALIGN 4
__end_IntWrap

;----------------------------------------
; int Install_Int(int num, unsigned int Handler_Address);
; Purpose: Installs a interrupt handler for the specified interrupt, allocating
;          a wrapper function which will save registers and handle the stack
;          switching. The passed function should return zero in eax to exit the
;          interrupt with an iret instruction, and non-zero to chain to the old handler.
; Inputs:  num, the interrupt number to install the handler for
;          Handler_Address, the address of the handler function
; Outputs: EAX=-1 on error (unable to allocate a wrapper), 0 otherwise
; Notes:   A maximum of MAX_INTS interrupts may be hooked using this function.
;----------------------------------------
proc _Install_Int

%$num           arg     4
%$handler       arg     4

        cmp     byte [_Int_Virgin], 0       ; first time we've been called?
        je      near .FindInt

        ; Lock up data arrays & stacks
        invoke  _LockArea, ds, dword _Int_Lock_Area, dword __end_Int_Lock_Area-_Int_Lock_Area
        ; Lock up wrapper functions
        invoke  _LockArea, cs, dword _IntWrap, dword __end_IntWrap-_IntWrap

        mov     ecx, INT_STACKS
.SetUpStacks:
        mov     edx, ecx
        dec     ecx
        shl     edx, STACK_SIZE_SHIFT
        sub     edx, 32
        add     edx, _StackData         ; stacks grow downwards, so:
        mov     [_IntStacks+ecx*4], edx ; IntStacks[x] = [offset]StackData+(x+1)*STACK_SIZE-32
        
        test    ecx, ecx
        jnz     .SetUpStacks

        mov     byte [_Int_Virgin], 0

.FindInt:
        ; Find a free wrapper and allocate it
        xor     ecx, ecx
.FindUnusedWrapper:
        cmp     dword [_IntHandlers+ecx*4], 0
        jne     near .NextWrapper

        ; Save parameters in array
        mov     edx, [ebp+%$handler]
        mov     [_IntHandlers+ecx*4], edx
        mov     ebx, [ebp+%$num]
        mov     [_IntNumbers+ecx*4], ebx

        push    ecx                     ; Save wrapper # on stack
        ; Save old interrupt vector
        xor     eax, eax
        mov     ax, 0204h               ; [DPMI 0.9] Get Protected Mode Interrupt Vector
        int     31h
        pop     ebx                     ; Get wrapper # back into ebx
        mov     [_OldIntVectors+ebx*8], edx     ; Save offset
        mov     [_OldIntVectors+ebx*8+4], cx    ; Save selector

        ; Set new interrupt vector
        mov     ax, 0205h               ; [DPMI 0.9] Set Protected Mode Interrupt Vector
        mov     edx, [_IntWrappers+ebx*4]       ; Offset of handler
        mov     ebx, [ebp+%$num]                ; Interrupt number
        mov     cx, cs                          ; Selector of handler
        int     31h

        xor     eax, eax
        jmp     short .Done
.NextWrapper:
        inc     ecx
        cmp     ecx, MAX_INTS
        jl      .FindUnusedWrapper

        mov     eax, -1
.Done:

endproc

;----------------------------------------
; void Remove_Int(int num);
; Purpose: Removes an interrupt handler, restoring the old vector.
; Inputs:  num, the interrupt number to uninstall the handler for.
; Outputs: None
;----------------------------------------
proc _Remove_Int

%$num           arg     4

        mov     ebx, [ebp+%$num]
        xor     ecx, ecx
.FindWrapper:
        cmp     [_IntNumbers+ecx*4], ebx
        jne     .NextWrapper

        push    ecx                     ; Save wrapper # on stack
	; Restore old interrupt vector
        xor     eax, eax
        mov     ax, 0205h               ; [DPMI 0.9] Set Protected Mode Interrupt Vector
        mov     edx, [_OldIntVectors+ecx*8]     ; Offset of handler
        mov     cx, [_OldIntVectors+ecx*8+4]    ; Selector of handler
        int     31h

        pop     ecx                     ; Get wrapper # back
        ; Indicate wrapper as being free
        xor     eax, eax
        mov     [_IntNumbers+ecx*4], eax
        mov     [_IntHandlers+ecx*4], eax

        jmp     short .Done
.NextWrapper:        
        inc     ecx
        cmp     ecx, MAX_INTS
        jl      .FindWrapper

.Done:

endproc

;----------------------------------------
; void Exit_IRQ(void)
; Purpose: Restores the default IRQ masks.
; Inputs:  None
; Outputs: None
;----------------------------------------
        GLOBAL  _Exit_IRQ
_Exit_IRQ

        cmp     byte [_PIC_Virgin], 0
        jne     .Done

        mov     al, [_Default_PIC]
        out     21h, al
        mov     al, [_Default_PIC+1]
        out     0A1h, al

        mov     byte [_PIC_Virgin], 1

.Done:
        ret

;----------------------------------------
; void Init_IRQ(void)
; Purpose: Saves the default IRQ masks.
; Inputs:  None
; Outputs: None
;----------------------------------------
        GLOBAL  _Init_IRQ
_Init_IRQ

        cmp     byte [_PIC_Virgin], 0
        je      .Done

        in      al, 21h
        mov     [_Default_PIC], al
        in      al, 0A1h
        mov     [_Default_PIC+1], al

        mov     word [_Altered_PIC], 0

        mov     byte [_PIC_Virgin], 0

.Done:
        ret

;----------------------------------------
; void Restore_IRQ(int num)
; Purpose: Restores default masking for an IRQ.
; Inputs:  num, the IRQ to restore to its original masking.
; Outputs: None
;----------------------------------------
proc _Restore_IRQ

%$num           arg     4

        cmp     byte [_PIC_Virgin], 0
        jne     near .Done

        mov     ecx, [ebp+%$num]
        cmp     ecx, 7
        jle     .NotHighIRQ

        in      al, 0A1h        ; get current masking

        ; Calculate bl=1<<(num-8) and dl=~(1<<(num-8))
        sub     ecx, 8
        mov     dl, 1
        shl     dl, cl
        mov     bl, dl
        not     dl
        
        and     al, dl          ; portin &= ~(1<<(num-8))
         
        ; portin |= Default_PIC[1] & (1<<(num-8))
        mov     cl, [_Default_PIC+1]
        and     cl, bl
        or      al, cl
        
        out     0A1h, al        ; output modified masking

        ; Altered_PIC[1] &= ~(1<<(num-8))
        mov     cl, [_Altered_PIC+1]
        and     cl, dl
        mov     [_Altered_PIC+1], cl

        cmp     cl, 0
        jne     .Done           ; If no high IRQs remain, also restore

        mov     ecx, 2          ;  cascade (IRQ2)

.NotHighIRQ:

        in      al, 21h         ; get current masking

        ; Calculate bl=1<<num and dl=~(1<<num)
        mov     dl, 1
        shl     dl, cl
        mov     bl, dl
        not     dl

        and     al, dl          ; portin &= ~(1<<num)

        ; portin |= Default_PIC[0] & (1<<num)
        mov     cl, [_Default_PIC]
        and     cl, bl
        or      al, cl

        out     021h, al        ; output modified masking

        ; Altered_PIC[0] &= ~(1<<num)
        mov     cl, [_Altered_PIC]
        and     cl, dl
        mov     [_Altered_PIC], cl

.Done:

endproc


;----------------------------------------
; void Enable_IRQ(int num)
; Purpose: Unmasks an IRQ.
; Inputs:  num, the IRQ to unmask.
; Outputs: None
;----------------------------------------
proc _Enable_IRQ

%$num           arg     4

        invoke  _Init_IRQ

        in      al, 21h

        mov     ecx, [ebp+%$num]
        cmp     ecx, 7
        jle     .LowIRQ

        ; First unmask cascade (IRQ2)
        and     al, 0FBh
        out     21h, al

        ; Then unmask PIC-2 interrupt
        in      al, 0A1h

        ; Calculate bl=1<<(num-8) and dl=~(1<<(num-8))
        mov     dl, 1
        shl     dl, cl
        mov     bl, dl
        not     dl

        and     al, dl          ; portin &= ~(1<<(num-8))
        out     0A1h, al        ; output modified masking

        ; Altered_PIC[1] |= 1<<(num-8)
        mov     cl, [_Altered_PIC+1]
        or      cl, bl
        mov     [_Altered_PIC+1], cl
      
        jmp     short .Done

.LowIRQ:
        ; Unmask PIC-1 interrupt

        ; Calculate bl=1<<num and dl=~(1<<num)
        mov     dl, 1
        shl     dl, cl
        mov     bl, dl
        not     dl

        and     al, dl          ; portin &= ~(1<<num)
        out     21h, al         ; output modified masking
        
        ; Altered_PIC[0] |= 1<<num
        mov     cl, [_Altered_PIC]
        or      cl, bl
        mov     [_Altered_PIC], cl

.Done:

endproc

;----------------------------------------
; void Disable_IRQ(int num)
; Purpose: Masks an IRQ.
; Inputs:  num, the IRQ to mask
; Outputs: None
;----------------------------------------
proc _Disable_IRQ

%$num           arg     4

        invoke  _Init_IRQ

        mov     ecx, [ebp+%$num]
        cmp     ecx, 7
        jle     .LowIRQ

        ; Mask PIC-2 interrupt
        in      al, 0A1h

        ; Calculate dl=1<<(num-8)
        mov     dl, 1
        shl     dl, cl

        and     al, dl          ; portin &= 1<<(num-8)
        out     0A1h, al        ; output modified masking

        ; Altered_PIC[1] |= 1<<(num-8)
        mov     cl, [_Altered_PIC+1]
        or      cl, dl
        mov     [_Altered_PIC+1], cl

        jmp     short .Done

.LowIRQ:
        ; Mask PIC-1 interrupt
        in      al, 21h

        ; Calculate dl=1<<num
        mov     dl, 1
        shl     dl, cl

        and     al, dl          ; portin &= 1<<num
        out     21h, al         ; output modified masking

        ; Altered_PIC[0] |= 1<<num
        mov     cl, [_Altered_PIC]
        or      cl, dl
        mov     [_Altered_PIC], cl

.Done:

endproc
