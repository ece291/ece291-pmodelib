; Test program for timer interrupt (hardware interrupt/IRQ handling)
;  By Peter Johnson, 1999
%include "lib291.inc"

        BITS 32


        GLOBAL _main

SECTION .bss

        mouse_seg       resw    1
        mouse_off       resw    1

SECTION .data ; Data Section

        buttonstatus    dw      0
        prevstatus      dw      0
        string          db      "WoW!",0Dh,0Ah,'$'

SECTION .text ; Says that this is the start of the code section.


; Callbacks get DPMIRegsPtr as a pointer to the DPMI registers structure
proc MouseCallback
%$DPMIRegsPtr	arg     4

        push    esi
        mov     esi, [ebp+%$DPMIRegsPtr]

        mov     eax, [esi+DPMI_EBX_off]
        mov     [buttonstatus], ax

        pop     esi

endproc
MouseCallback_end

_main:
        call    _LibInit

        ; Lock up stuff interrupt will access
        invoke  _LockArea, ds, dword buttonstatus, dword 2
        invoke  _LockArea, cs, dword MouseCallback, dword MouseCallback_end-MouseCallback

        ; Initialize the mouse driver
        xor     eax, eax
        int     33h

        ; Get a RM callback address for the mouse callback
        invoke  _Get_RMCB, dword mouse_seg, dword mouse_off, dword MouseCallback, dword 1
        cmp     eax, 0
        jnz     near .error

        ; Install the mouse callback
      	mov	dword [DPMI_EAX], 0Ch
	mov	dword [DPMI_ECX], 7Fh
	xor     edx, edx
        mov     dx, [mouse_off]
	mov	[DPMI_EDX], edx
      	mov     ax, [mouse_seg]
	mov	[DPMI_ES], ax
        mov     bx, 33h
        call    DPMI_Int

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
        mov     cx, [buttonstatus]
        mov     dx, [prevstatus]
        cmp     cx, dx
        je      .nope

        mov     [prevstatus], cx

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

        ; Uninstall mouse callback
      	mov	dword [DPMI_EAX], 0Ch
	xor     edx, edx
	mov	[DPMI_ECX], edx
	mov	[DPMI_EDX], edx
	mov	[DPMI_ES], dx
        mov     bx, 33h
        call    DPMI_Int

        ; Free the RM callback address
        invoke  _Free_RMCB, word [mouse_seg], word [mouse_off]

.error:
        call    _LibExit
	ret
        

