; Text Mode (80x25x16) routines
;  By Peter Johnson, 1999
;
; $Id: textmode.asm,v 1.7 2000/12/18 07:28:46 pete Exp $
%include "myC32.mac"		; C interface macros
%include "globals.inc"

	BITS	32

        EXTERN  _textsel

	SECTION	.text

;----------------------------------------
; void SetModeC80(void);
; Purpose: Sets 80x25 16-color text mode.
; Inputs:  None
; Outputs: None
;----------------------------------------
	GLOBAL	_SetModeC80
_SetModeC80

	push	ebp		; preserve caller's stack frame

	mov	ax, 03h		; 80x25 text mode
	int	10h

	pop	ebp		; restore caller's stack frame

	ret

;----------------------------------------
; void TextSetPage(short PageNum);
; Purpose: Sets current visible textmode page.
; Inputs:  PageNum, the page number to switch to (0-7)
; Outputs: None
;----------------------------------------
proc _TextSetPage

.PageNum	arg	2

        mov     ax, [ebp+.PageNum]
        mov     ah, 05h
        int     10h

	ret
endproc

;----------------------------------------
; void TextClearScreen(void);
; Purpose: Clears the textmode screen (first page only)
; Inputs:  None
; Outputs: None
; Notes:   Assumes es=[_textsel]
;----------------------------------------
	GLOBAL	_TextClearScreen
_TextClearScreen

	push	edi

        xor     edi, edi
        mov     eax, 07000700h
	mov	ecx, 1000
	rep	stosd		; clear all of display memory to black

	pop	edi

	ret

;----------------------------------------
; void TextWriteChar(short X, short Y, short Char, short Attrib);
; Purpose: Writes a single character (with attribute) to the textmode screen.
; Inputs:  X, column at which to write the character (0-79)
;          Y, row at which to write the character (0-24)
;          Char, character to write to the screen (0-255)
;          Attrib, attribute with which to draw the character
; Outputs: None
; Notes:   Assumes es=[_textsel]
;----------------------------------------
proc _TextWriteChar

.X              arg	2
.Y              arg     2
.Char		arg	2
.Attrib		arg	2

        push    ebx

	xor     ebx, ebx
        mov     bx, [ebp+.Y]
        lea     ebx, [ebx+ebx*4]        ; Address = 2*(Row*80+Col)
        shl     ebx, 4
        xor     eax, eax
        mov     ax, [ebp+.X]
        add     ebx, eax
        shl     ebx, 1

        mov     ah, [ebp+.Attrib]
	mov     al, [ebp+.Char]
        mov     [es:ebx], ax

        pop     ebx

	ret
endproc

;----------------------------------------
; void TextWriteString(short X, short Y, char *String, short Attrib);
; Purpose: Writes a string (with attribute) to the textmode screen.
; Inputs:  X, column at which to write the first character (0-79)
;          Y, row at which to write the first character (0-24)
;          String, string to write to the screen
;          Attrib, attribute with which to draw the string
; Outputs: None
; Notes:   Assumes es=[_textsel], String in ds
;----------------------------------------
proc _TextWriteString

.X		arg	2
.Y		arg	2
.String		arg	4
.Attrib		arg	2

        push    ebx
	push    esi

	xor     ebx, ebx
        mov     bx, [ebp+.Y]
        lea     ebx, [ebx+ebx*4]        ; Address = 2*(Row*80+Col)
        shl     ebx, 4
        xor     eax, eax
        mov     ax, [ebp+.X]
        add     ebx, eax
        shl     ebx, 1

        mov     esi, [ebp+.String]
        mov     ah, [ebp+.Attrib]

.CopyLoop:
        mov     al, [esi]
        mov     [es:ebx], ax
	inc     esi
        add     ebx, 2
        test    al, al
        jnz     .CopyLoop

	pop     esi
        pop     ebx

	ret
endproc
