; Miscellaneous Routines
;  By Peter Johnson, 2000
;
; Based on LIB291 BINASC, ASCBIN by Michael Loui and Tom Maciukenas
;
; $Id: misc.asm,v 1.4 2001/04/17 23:40:32 pete Exp $
%include "myC32.mac"            ; C interface macros

        BITS    32

        GLOBAL  BinAsc
	GLOBAL	AscBin

	SECTION .bss

Minus	resb	1
Digits	resb	1
Status	resb	1

        SECTION .data

rcsid	db	'$Id: misc.asm,v 1.4 2001/04/17 23:40:32 pete Exp $',0

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
        jmp     short .loop1
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

; AscBin
; Purpose: Converts from ASCII string to binary
; Inputs:  EBX = Starting offset of first char of ASCII string
; Outputs: AX = Signed 16-bit number having value of ASCII string
;          EBX = Offset of first non-convertible character
;          DL = Status of this call:
;                0 if no conversion errors
;                1 if string had no valid digits
;                2 if string had too many digits
;                3 if overflow
;                4 if underflow (too negative)
AscBin
	push	esi
	push	dx

	mov	ax, 0
	mov	byte [Minus], 0
	mov	byte [Digits], 0

.spaces:
	cmp	byte [ebx], ' '
	jne	.signs
	inc	ebx
	jmp	short .spaces

.signs:
	cmp	byte [ebx], '+'
	je	.incbx
	cmp	byte [ebx], '-'
	jne	.scan
	mov	byte [Minus], 1

.incbx:
	inc	ebx

.scan:
	mov	dl, [ebx]
	cmp	dl, '0'
	jb	.end
	cmp	dl, '9'
	ja	.end
	jmp	short .case

.end:
	cmp	byte [Digits], 0
	jz	.error1
	jmp	short .endok

.case:
	inc	byte [Digits]
	cmp	byte [Digits], 5
	jg	.error2
	mov	dh, 0
	sub	dx, '0'
	mov	si, dx
	imul	word [Ten]
	jo	.error34
	add	ax, si
	jo	.error34
	inc	ebx
	jmp	short .scan

.endok:
	mov	byte [Status], 0
	cmp	byte [Minus], 1
	jne	.done
	neg	ax
	jmp	short .done

.error1:
	mov	byte [Status], 1
	jmp	short .done

.error2:
	mov	byte [Status], 2
	jmp	.done

.error34:
	cmp	byte [Minus], 1
	je	.ck216
	mov	byte [Status], 3
	jmp	short .done

.ck216:
	cmp	ax, 8000h
	jne	.error4
	cmp	byte [ebx+1], '0'
	jb	.ok216
	cmp	byte [ebx+1], '9'
	ja	.ok216
	jmp	.error4

.ok216:
	mov	byte [Status], 0
	jmp	short .done

.error4:
	mov	byte [Status], 4

.done:
	pop	dx
	pop	esi
	mov	dl, [Status]
	ret

