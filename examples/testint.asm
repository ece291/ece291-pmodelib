; Test program for timer interrupt (hardware interrupt/IRQ handling)
;  By Peter Johnson, 1999
%include "lib291.inc"

        BITS 32


        GLOBAL _main

SECTION .data ; Data Section

        timercount      dd      0
        string          db      "WoW!",0Dh,0Ah,'$'

SECTION .text ; Says that this is the start of the code section.


TimerDriver
        inc     dword [timercount]
        mov     eax, 1                  ; chain!
        ret
TimerDriver_end

_main:
        call    _LibInit

        ; Lock up stuff interrupt will access
        invoke  _LockArea, ds, dword timercount, dword 1
        invoke  _LockArea, cs, dword TimerDriver, dword TimerDriver_end-TimerDriver

        ; Install the timer handler!
        invoke  _Install_Int, dword 8, dword TimerDriver

        ; Put the string into DOS space
        push    es
        mov     es, [_Transfer_Buf]
        mov     ecx, 7
        xor     edi, edi
        mov     esi, string
        rep     movsb
        pop     es

        ; Wait for a keypress
.loop:  
        mov     ecx, [timercount]
        cmp     ecx, 18
        jl      .nope

        mov     dword [timercount], 0

        mov     dword [DPMI_EAX], 0900h
        mov     dword [DPMI_EDX], 0
        mov     bx, [_Transfer_Buf_Seg]
        mov     [DPMI_DS], bx
        mov     bx, 21h
        call    DPMI_Int

.nope:
        mov     ah, 1   ; BIOS check key pressed function
        int     16h

        jz      .loop   ; Loop while no keypress

        xor     eax, eax
        int     16h             ; Get the key pressed

        ; Uninstall the timer handler!
        invoke  _Remove_Int, dword 8

        call    _LibExit
        ret
        

