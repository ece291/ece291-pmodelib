; JPG graphics file loading functions
;  By Peter Johnson, 2001
;
; Dependent on C stdio, stdlib, and readjpg.
;
; $Id: jpg.asm,v 1.1 2001/10/17 20:54:50 pete Exp $
%include "myC32.mac"
	BITS 32

; Declare C functions we call
	EXTERN	_fopen
	EXTERN	_fclose
	EXTERN	_readjpg_init
	EXTERN	_readjpg_get_row
	EXTERN	_readjpg_cleanup

_fopen_arglen			equ	8
_fclose_arglen			equ	4
_free_arglen			equ	4
_readjpg_init_arglen		equ	12
_readjpg_get_row_arglen		equ	4

	SECTION .bss
image_width	resd	1
image_height	resd	1

	SECTION .data

rcsid	db	'$Id: jpg.asm,v 1.1 2001/10/17 20:54:50 pete Exp $'

filemode	db	'rb', 0

	SECTION .text

;----------------------------------------
; int LoadJPG(char *Name, void *Where, int *Width, int *Height)
; Purpose: Reads a JPG file into a 32-bit buffer.
; Inputs:  Name, (path)name of the JPG file
;	   Where, pointer (in Wheresel) of data area
; Outputs: 1 on error, 0 otherwise
; Notes:   Assumes destination is big enough to hold loaded 32-bit image.
;          Returns width and height in passed pointers (if pointers nonzero).
;          This code "cheats" by interfacing with a C library to actually do
;          the reading.  But that's okay because JPG is insanely complex :).
;----------------------------------------
proc _LoadJPG

.Name		arg	4  
.Where		arg	4
.Width		arg	4
.Height		arg	4

.infile		equ	-4
.imagedata	equ	-8

.STACK_FRAME_SIZE	equ     8

	sub	esp, .STACK_FRAME_SIZE	; allocate space for local vars
	push	es
	push	esi
	push	edi

	mov	ax, ds		; Set up es the way C expects it
	mov	es, ax

	; Open the file.  We have to use fopen() when interfacing with C functs
	invoke	_fopen, dword [ebp+.Name], dword filemode
	test	eax, eax
	jz	near .error
	mov	[ebp+.infile], eax

	; Read the JPG header.  Close and error return if problem with JPG
	invoke	_readjpg_init, eax, dword image_width, dword image_height
	test	eax, eax
	jz	.readjpginitok
	invoke	_fclose, dword [ebp+.infile]
	jmp	.error
.readjpginitok:
	
	; Read the image, row by row
	mov	esi, [ebp+.Where]
	mov	edi, [image_height]

.nextrow:
	; Get a row of 32-bit pixels from the JPG
	invoke	_readjpg_get_row, dword esi

	mov	eax, [image_width]
	shl	eax, 2
	add	esi, eax
	dec	edi
	jnz	.nextrow
	
	call	_readjpg_cleanup
	invoke	_fclose, dword [ebp+.infile]

	mov	eax, [ebp+.Width]
	test	eax, eax
	jz	.dontsavewidth
	mov	ecx, [image_width]
	mov	[eax], ecx
.dontsavewidth:
	mov	eax, [ebp+.Height]
	test	eax, eax
	jz	.dontsaveheight
	mov	ecx, [image_height]
	mov	[eax], ecx
.dontsaveheight:

	xor	eax, eax
	jmp	short .done

.error:
	xor	eax, eax
	inc	eax
.done:
	pop	edi
	pop	esi
	pop	es
	mov	esp, ebp		; discard storage for local variables
	ret
endproc

