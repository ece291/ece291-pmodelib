; Text Mode (80x25x16) routines
;  By Peter Johnson, 1999

%include "myC32.mac"		; C interface macros
%include "aura.inc"

	BITS	32

        EXTERN  _textdescriptor

	SECTION	.text

;----------------------------------------
; void TextSetPage(short PageNum);
;----------------------------------------
proc _TextSetPage

%$PageNum	arg	2

        mov     ax, [ebp+%$PageNum]
        mov     ah, 05h
        int     10h

endproc

;----------------------------------------
; void TextClearScreen(void);
; NOTE: Assumes es=[_textdescriptor]
;----------------------------------------
	GLOBAL	_TextClearScreen
_TextClearScreen

	push	edi

        xor     edi, edi
        xor     eax, eax
	mov	ecx, 1000
	rep	stosd		; clear all of display memory to black

	pop	edi

	ret

;----------------------------------------
; void TextWriteChar(short X, short Y, short Char, short Attrib);
; NOTE: Assumes es=[_textdescriptor]
;----------------------------------------
proc _TextWriteChar

%$X             arg	2
%$Y             arg     2
%$Char		arg	2
%$Attrib	arg	2

        push    ebx

	xor     ebx, ebx
        mov     bx, [ebp+%$Y]
        lea     ebx, [ebx+ebx*4]        ; Address = 2*(Row*80+Col)
        shl     ebx, 4
        xor     eax, eax
        mov     ax, [ebp+%$X]
        add     ebx, eax
        shl     ebx, 1

        mov     ah, [ebp+%$Attrib]
	mov     al, [ebp+%$Char]
        mov     [es:ebx], ax

        pop     ebx

endproc

;----------------------------------------
; void TextWriteString(short X, short Y, char *String, short Attrib);
; NOTE: Assumes es=[_textdescriptor], String in ds
;----------------------------------------
proc _TextWriteString

%$X		arg	2
%$Y		arg	2
%$String	arg	4
%$Attrib        arg	2

        push    ebx
	push    esi

	xor     ebx, ebx
        mov     bx, [ebp+%$Y]
        lea     ebx, [ebx+ebx*4]        ; Address = 2*(Row*80+Col)
        shl     ebx, 4
        xor     eax, eax
        mov     ax, [ebp+%$X]
        add     ebx, eax
        shl     ebx, 1

        mov     esi, [ebp+%$String]
        mov     ah, [ebp+%$Attrib]

.CopyLoop:
        mov     al, [esi]
        mov     [es:ebx], ax
	inc     esi
        add     ebx, 2
        test    al, al
        jnz     .CopyLoop

	pop     esi
        pop     ebx

endproc
