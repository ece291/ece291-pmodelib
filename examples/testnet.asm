; Test program for NetBIOS
;  By Peter Johnson, 2000
%include "lib291.inc"

        BITS 32

        GLOBAL _main

        SECTION .bss    ; Uninitialized data section

ReceiveString   resb 4096       ; 4K array of incoming strings
ReceiveIndex    resd 1          ; Current Postition in ReceiveString

        SECTION .data   ; Data Section

string          db      "WoW!",0Dh,0Ah,'$'

; Set this name for your own use
;    (But keep sting length=16)
GroupName       db      'ECE291TstLib2$$$'

; Set this name for your own use
;    (But keep sting length=16,
;     and location of 00 unchanged)
MyName          db      'ECE291Tester00$$'      

MyNum           db      63      ; My Player Number

TransmitString  db 'TestNet '   ; Sample Message to transmit

        SECTION .text ; Says that this is the start of the code section.

%macro Delay 1
        push    ecx
        mov     ecx,0FFFFh
%%loop1:
        push    ecx
        mov     ecx,%1
%%loop2:
        nop
        loop    %%loop2
        pop     ecx
        loop    %%loop1
        pop     ecx
%endmacro

; void NetDriver(char *ReceivePtr, int MessageLength);
; Purpose: Datagram callback routine
; Inputs:  ReceivePtr, pointer in _NetTransferSel to data received.
;          MessageLength, length of the message received (in bytes).
; Outputs: None
proc NetDriver
%$ReceivePtr    arg     4
%$MessageLength arg     4

        push    esi
        push    edi
        push    es

        mov     ax, ds
        mov     es, ax

        mov     eax, [ebp+%$MessageLength]
        
        ; Copy the received message into ReceiveString        
        push    ds
        mov     esi, [ebp+%$ReceivePtr]
        mov     edi, ReceiveString
        add     edi, [ReceiveIndex]     ; Index into ReceiveString
        mov     ds, [_NetTransferSel]
        mov     ecx, eax
        rep movsb
        pop     ds

        add     [ReceiveIndex], eax     ; Index for next incoming meesage

        pop     es
        pop     edi
        pop     esi
endproc
NetDriver_end

_main:
        push    esi
        push    edi
        
        call    _LibInit

        ; Lock up stuff callback will access
        invoke  _LockArea, ds, dword ReceiveString, dword 4096
        invoke  _LockArea, ds, dword ReceiveIndex, dword 4
        invoke  _LockArea, cs, dword NetDriver, dword NetDriver_end-NetDriver

        ; Set output buffer to all $'s
        mov     eax, '$$$$'
        mov     edi, ReceiveString
        mov     ecx, 1024
        rep stosd
        
        mov     dword [ReceiveIndex], 0
        
        ; Network init
        invoke  _NetInit, dword NetDriver, dword GroupName, dword MyName
        
        cmp     eax, -1
        je      near .exit

        mov     ecx, 5
.loopsend:
        push    ecx
        ; Copy the send string
        push    es
        mov     esi, TransmitString
        mov     edi, TXBuffer
        mov     es, [_NetTransferSel]
        mov     ecx, 2
        rep movsd
        pop     es

        invoke  _SendPacket, dword 8

        Delay 100
        pop     ecx
        
        loop    .loopsend

        ; Wait for a keypress
.loop:  
        mov     ah, 1   ; BIOS check key pressed function
        int     16h

        jz      .loop   ; Loop while no keypress

        ; Put the received string into DOS space
        push    es
        mov     es, [_Transfer_Buf]
        mov     ecx, 1024
        xor     edi, edi
        mov     esi, ReceiveString
        rep movsd
        pop     es

        ; Print it out
        mov     dword [DPMI_EAX], 0900h
        mov     dword [DPMI_EDX], 0
        mov     bx, [_Transfer_Buf_Seg]
        mov     [DPMI_DS], bx
        mov     bx, 21h
        call    DPMI_Int

        xor     eax, eax
        int     16h             ; Get the key pressed

        ; Network shutdown
        invoke  _NetRelease        

.exit:
        call    _LibExit
        
        pop     edi
        pop     esi
        
        ret
        

