; Miscellaneous Routines
;  By Peter Johnson, 2000
; Based on LIB291 BINASC

%include "myC32.mac"            ; C interface macros

        BITS    32

        GLOBAL  BinAsc

        SECTION .data

Ten     dw      10

        SECTION .text

; BinAsc
; Purpose: Converts from binary to ASCII string
; Inputs:  AX = 16-bit signed integer to be converted.
;          EBX = starting offset for a 7-byte buffer to hold the result.
; Outputs: EBX = offset of first nonblank character of the string
;                (may be a minus sign)
;          CL = Number of nonblank characters generated
BinAsc
        push    esi
        push    edi
        push    edx
        
        mov     di, ax
        
        xor     cl, cl
        mov     esi, 5
.loop0:
        mov     byte [ebx+esi], ' '
        dec     esi
        jge     .loop0
        mov     byte [ebx+6], '$'
        
        add     ebx, 5
        cmp     ax, 0
        jge     .loop1
        neg     ax
.loop1:
        xor     edx, edx
        div     word [Ten]
        add     dl, 30h
        mov     [ebx], dl
        inc     cl
        cmp     ax, 0
        je      .check
        dec     ebx
        jmp     .loop1
.check:
        cmp     di, 0
        jge     .done
        dec     ebx
        mov     byte [ebx], '-'
        add     cl, 1
.done:
        mov     ax, di
        pop     edx
        pop     edi
        pop     esi
        ret

