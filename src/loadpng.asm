; PNG graphics file loading functions
;  By Peter Johnson, 2001
;
; Dependent on C stdio, stdlib, and readpng.
;
; $Id: loadpng.asm,v 1.2 2003/05/01 04:07:14 pete Exp $
%include "myC32.mac"
	BITS 32

; Declare C functions we call
	EXTERN	_fopen
	EXTERN	_fclose
	EXTERN	_free
	EXTERN	_readpng_init
	EXTERN	_readpng_get_image
	EXTERN	_readpng_cleanup

_fopen_arglen			equ	8
_fclose_arglen			equ	4
_free_arglen			equ	4
_readpng_init_arglen		equ	12
_readpng_get_image_arglen	equ	12
_readpng_cleanup_arglen		equ	4

	SECTION .bss
image_width	resd	1
image_height	resd	1
image_channels	resd	1
image_rowbytes	resd	1

	SECTION .data

rcsid	db	'$Id: loadpng.asm,v 1.2 2003/05/01 04:07:14 pete Exp $'

filemode	db	'rb', 0

	SECTION .text

;----------------------------------------
; int LoadPNG(char *Name, void *Where, int *Width, int *Height)
; Purpose: Reads a PNG file into a 32-bit buffer.
; Inputs:  Name, (path)name of the PNG file
;	   Where, pointer (in Wheresel) of data area
; Outputs: 1 on error, 0 otherwise
; Notes:   Assumes destination is big enough to hold loaded 32-bit image.
;          Returns width and height in passed pointers (if pointers nonzero).
;          This code "cheats" by interfacing with a C library to actually do
;          the reading.  But that's okay because PNG is insanely complex :).
;----------------------------------------
proc _LoadPNG

.Name		arg	4  
.Where		arg	4
.Width		arg	4
.Height		arg	4

.infile		local	4
.imagedata	local	4

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

	; Read the PNG header.  Close and error return if problem with PNG
	invoke	_readpng_init, eax, dword image_width, dword image_height
	test	eax, eax
	jz	.readpnginitok
	invoke	_fclose, dword [ebp+.infile]
	jmp	.error
.readpnginitok:
	
	; Read the image
	invoke	_readpng_get_image, dword image_channels, dword image_rowbytes, dword [ebp+.Where]

	invoke	_readpng_cleanup, dword 0
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
	ret
endproc
_LoadPNG_arglen	equ	16

;----------------------------------------
; int LoadPNG_Sel(char *Name, short Wheresel, void *Where, int *Width,
;                 int *Height)
; Purpose: Reads a PNG file into a 32-bit buffer.
; Inputs:  Name, (path)name of the PNG file
;	   Wheresel, selector in which Where resides
;	   Where, pointer (in Wheresel) of data area
; Outputs: 1 on error, 0 otherwise
; Notes:   Assumes destination is big enough to hold loaded 32-bit image.
;          Returns width and height in passed pointers (if pointers nonzero).
;          This code "cheats" by interfacing with a C library to actually do
;          the reading.  But that's okay because PNG is insanely complex :).
;----------------------------------------
proc _LoadPNG_Sel

.Name		arg	4  
.Wheresel	arg	2
.Where		arg	4
.Width		arg	4
.Height		arg	4

.infile		local	4
.imagedata	local	4	

	mov	ax, ds
	cmp	ax, word [ebp+.Wheresel]
	jne	.notds

	invoke	_LoadPNG, dword [ebp+.Name], dword [ebp+.Where], dword [ebp+.Width], dword [ebp+.Height]
	ret
.notds:
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

	; Read the PNG header.  Close and error return if problem with PNG
	invoke	_readpng_init, eax, dword image_width, dword image_height
	test	eax, eax
	jz	.readpnginitok
	invoke	_fclose, dword [ebp+.infile]
	jmp	.error
.readpnginitok:
	
	; Read the image
	invoke	_readpng_get_image, dword image_channels, dword image_rowbytes, dword 0
	mov	[ebp+.imagedata], eax

	invoke	_readpng_cleanup, dword 0
	invoke	_fclose, dword [ebp+.infile]

	cmp	dword [ebp+.imagedata], 0
	jz	.error

	; Copy the image data into the passed buffer
	mov	ecx, [image_width]
	imul	ecx, [image_height]
	mov	esi, [ebp+.imagedata]
	mov	es, [ebp+.Wheresel]
	mov	edi, [ebp+.Where]
	rep movsd

	mov	ax, ds
	mov	es, ax

	invoke	_free, dword [ebp+.imagedata]

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
	ret
endproc

