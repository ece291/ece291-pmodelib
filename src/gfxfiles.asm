; Various file loading functions
;  By Peter Johnson, 1999
;
; $Id: gfxfiles.asm,v 1.7 2000/12/18 07:28:46 pete Exp $
%include "myC32.mac"
%include "constant.inc"
%include "globals.inc"
%include "filefunc.inc"

	BITS	32

	EXTERN	_ScratchBlock
	EXTERN	_VideoBlock
	
	SECTION .data

ScreenShot_fn	db	'MP5Out?.bmp',0 ; Filename of screenshot file
ScreenShot_index	db	'A'

	SECTION .text

;----------------------------------------
; bool LoadBMP(char *Name, short Wheresel, void *Where)
; Purpose: Reads a 8 or 24-bit BMP file into a 32-bit buffer.
; Inputs:  Name, (path)name of the BMP file
;	   Wheresel, selector in which Where resides
;	   Where, pointer (in Wheresel) of data area
; Outputs: 1 on error, otherwise 0
; Notes:   Assumes destination is big enough to hold loaded 32-bit image.
;          Doesn't return size of loaded image (width x height).
;----------------------------------------
proc _LoadBMP

.Name		arg	4  
.Wheresel	arg	2
.Where		arg	4     

.file		equ	-4		; File handle (4 bytes)
.width		equ	-8		; Image width (from header)
.height		equ	-12		; Image height (from header)
.bytewidth	equ	-16		; Image width (in bytes)
.filebytewidth  equ     -20             ; Image width in file (in bytes)

.STACK_FRAME_SIZE	equ     20

	sub	esp, .STACK_FRAME_SIZE	; allocate space for local vars
	push	esi
	push	edi
	push	ebx

	; Open File
	invoke	_OpenFile, dword [ebp+.Name], word 0
	cmp	eax, -1
	jz	near .error
	mov	dword [ebp + .file], eax

	; Read Header
	invoke	_ReadFile, dword [ebp + .file], word [_ScratchBlock], dword 0, dword 54

	; Save width and height
	push	gs
	mov	gs, [_ScratchBlock]		; Point gs at the header

	cmp	word [gs:1Ch], 24
	je	near .Bitmap24	      
	
	mov	eax, [gs:12h]			; Get width from header
	mov	[ebp + .width], eax
	mov	eax, [gs:16h]			; Get height from header
	mov	[ebp + .height], eax
	
	pop	gs				; Restore gs
	
	; Read Palette
	invoke	_ReadFile, dword [ebp + .file], word [_ScratchBlock], dword 0, dword 1024
	
	; Read in data a row at a time
	mov	ebx, [ebp+.height]		; Start offset at lower
	dec	ebx				;  left hand corner (bitmap
	imul	ebx, dword [ebp+.width] 	;  goes from bottom up)
	xor	edi, edi			; Start with row 0
.NextRow:
	push	ebx
	invoke	_ReadFile, dword [ebp + .file], word [_ScratchBlock], dword 1024, dword [ebp + .width]	; Read row
	pop	ebx
	xor	esi, esi			; Start with column 0
	xor	edx, edx

	push	ds				; Redirect ds to avoid using segment offsets
	mov	ds, [_ScratchBlock]
	push	es				; Redirect es to destination area
	mov	es, [ebp + .Wheresel]

.NextCol:
	xor	ecx, ecx			; Clear registers
	xor	eax, eax
	mov	al, [1024 + esi]		; Get color index from line buffer
	shl	eax, 2				; Load address in palette of bgrx quad
	mov	ecx, [eax]			; Get bgrx quad from palette
	mov	eax, [ebp + .Where]		; Get starting address to write to
	mov	[es:eax+ebx*4], ecx		; Write to 32-bit buffer

	inc	ebx				; Increment byte count
	inc	esi				; Increment column count
	cmp	esi, dword [ebp + .width]	; Done with the column?
	jne	.NextCol

	pop	es				; Get back to normal ds and es
	pop	ds

	sub	ebx, [ebp+.width]		; Get to previous row
	sub	ebx, [ebp+.width]
	inc	edi				; Increment row count
	cmp	edi, dword [ebp + .height]	; Done with the image?
	jne	.NextRow

	jmp	.CloseFile

.Bitmap24:
	mov	eax, [gs:12h]			; Get width from header
	mov	[ebp + .width], eax
	lea	eax, [eax+eax*2]		; 24-bit bitmap -> 3 bytes/pixel
	mov	[ebp + .bytewidth], eax
        add     eax, 3                          ; rows are aligned on 4 byte
        and     al, 0FCh                        ; boundaries in file
        mov     [ebp + .filebytewidth], eax
	mov	eax, [gs:16h]			; Get height from header
	mov	[ebp + .height], eax

	pop	gs				; Restore gs

	; Read in data a row at a time
	mov	ebx, [ebp+.height]		; Start offset at lower
	dec	ebx				;  left hand corner (bitmap
	imul	ebx, [ebp+.width]		;  goes from bottom up)
	xor	edi, edi			; Start with row 0
.NextRow24:
	push	ebx
	invoke	_ReadFile, dword [ebp + .file], word [_ScratchBlock], dword 0, dword [ebp + .filebytewidth]    ; Read row
	pop	ebx
	xor	esi, esi			; Start with column 0
	xor	edx, edx

	push	ds				; Redirect ds to avoid using segment offsets
	mov	ds, [_ScratchBlock]
	push	es				; Redirect es to destination area
	mov	es, [ebp + .Wheresel]

.NextCol24:
	xor	ecx, ecx			; Clear registers
	xor	eax, eax
	mov	cl, [esi]			; Get red value from line buffer
	inc     esi
	shl	ecx, 8	      
	or	cl, [esi]			; Get green value from line buffer
        inc     esi
	shl	ecx, 8
	or	cl, [esi]			; Get blue value from line buffer
        inc     esi
	mov	eax, [ebp + .Where]		; Get starting address to write to
	mov	[es:eax+ebx*4], ecx		; Write to 32-bit buffer

	inc	ebx				; Increment dest. pixel count
	cmp	esi, dword [ebp + .bytewidth]	; Done with the column?
	jne	.NextCol24

	pop	es				; Get back to normal ds and es
	pop	ds

	sub	ebx, [ebp+.width]		; Get to previous row
	sub	ebx, [ebp+.width]
	inc	edi				; Increment row count
	cmp	edi, dword [ebp + .height]	; Done with the image?
	jne	.NextRow24

.CloseFile:
	; Close File
	invoke	_CloseFile, dword [ebp + .file]

	xor	eax, eax
	jmp	.done
.error:
	mov	eax, 1
.done:
	pop	ebx
	pop	edi
	pop	esi
	mov	esp, ebp		; discard storage for local variables
	ret
endproc

;----------------------------------------
; bool SaveBMP(char *Name, short Wheresel, void *Where, int Width, int Height)
; Purpose: Saves a 32-bit image into a 24-bit BMP file.
; Inputs:  Name, (path)name of the BMP file
;	   Wheresel, selector in which Where resides
;	   Where, pointer (in Wheresel) of data area
;          Width, width of image
;          Height, height of image
; Outputs: 1 on error, otherwise 0
;----------------------------------------
_SaveBMP_arglen equ     18
proc _SaveBMP
	
.Name		arg	4
.Wheresel	arg	2
.Where		arg	4
.Width          arg     4
.Height         arg     4

.file		equ	-4
.filebytewidth  equ     -8	; Image width in file (in bytes)

.STACK_FRAME_SIZE	equ     8

	sub	esp, .STACK_FRAME_SIZE	; Allocate space for local variables
	push	esi
	push	edi
	push	ebx
	
	invoke	_OpenFile, dword [ebp+.Name], word 1																;to write
	cmp	eax, -1
	jz	near .Error
	
	mov	[ebp+.file], eax	; Save the file handle

	; Initialize header
	push	es
	mov	es, [_ScratchBlock]

        cld
        xor     edi, edi

        ; BITMAPFILEHEADER
	mov	ax, 'BM'	        ; bfType
        stosw
	; Calculate bfSize
	mov     eax, [ebp+.Width]
	lea	eax, [eax+eax*2]		; 24-bit bitmap -> 3 bytes/pixel
        add     eax, 3                          ; rows are aligned on 4 byte
        and     al, 0FCh                        ; boundaries in file
	mov     [ebp+.filebytewidth], eax       ; save file width on stack
	imul    eax, dword [ebp+.Height]        ; total size of image
        add     eax, 54                         ; + total header size
        stosd
	xor	eax, eax                ; bfReserved
        stosd
	mov	ax, 54		        ; bfOffBits
        stosd
	
        ; BITMAPINFOHEADER
	mov	ax, 40                  ; biSize
        stosd
	mov     eax, [ebp+.Width]       ; biWidth
	stosd         
        mov     eax, [ebp+.Height]      ; biHeight
	stosd        
	mov	ax, 1                   ; biPlanes
        stosw
	mov	ax, 24                  ; biBitCount
        stosw
        xor     eax, eax
        mov     ecx, 6
        rep stosd                       ; 0 rest of header

        pop     es

	; Write the header out
	invoke	_WriteFile, dword [ebp+.file], word [_ScratchBlock], dword 0, dword 54

        ; Zero buffer to be sure row padding is zeroed
        push    es
        mov     es, [_ScratchBlock]
	mov     ecx, [ebp+.filebytewidth]
        shr     ecx, 2
        xor     eax, eax
        rep stosd
        pop     es

        mov     ebx, [ebp+.Height]      ; Start at end since bitmap file is bottom up
        dec     ebx
        imul    ebx, dword [ebp+.Width]
        shl     ebx, 2

.NextRow:
	xor	esi, esi		; Start with column 0
	xor	edi, edi

        mov     ecx, [ebp+.Width]       ; Pixels to copy this row

	push	es
	mov	es, [_ScratchBlock]

	push	ds
	mov	ds, [ebp+.Wheresel]

.NextCol:
	mov	eax, [ebx+esi*4]		; Read from 32-bit buffer
	mov	[es:edi], al			; Put blue value into line buffer
	shr     eax, 8
	mov	[es:edi + 1], al		; Put green value into line buffer
	shr	eax, 8
	mov	[es:edi + 2], al		; Put red value into line buffer
	
        add     edi, 3                          ; Increment dest pointer
	inc     esi                             ; Increment source pixel
	cmp	esi, ecx
	jne	.NextCol

	pop	ds
	pop	es

	; Write line out to file
	push	ebx
	invoke	_WriteFile, dword [ebp+.file], word [_ScratchBlock], dword 0, dword [ebp+.filebytewidth]
	pop	ebx

        mov     ecx, [ebp+.Width]
        shl     ecx, 2
	sub	ebx, ecx			; Get to previous row

        neg     ecx
	cmp	ebx, ecx
	jne	.NextRow

.CloseFile:
	invoke	_CloseFile, dword [ebp+.file]
	xor     eax, eax
	jmp	.Done

.Error:
	mov	eax, 1

.Done:
	pop	ebx
	pop	edi
	pop	esi
	mov	esp, ebp
	ret
endproc

;----------------------------------------
; void ScreenShot(void);
; Purpose: Saves the backbuffer as a raw graphics file.
; Inputs:  None
; Outputs: None
; Notes:   Uses global variable ScreenShot_fn to determine filename to write to.
;----------------------------------------
proc _ScreenShot

	mov	al, [ScreenShot_index]
	mov	[ScreenShot_fn+7], al
	inc	al
	mov	[ScreenShot_index], al

	invoke	_SaveBMP, dword ScreenShot_fn, word [_VideoBlock], dword 0, dword WINDOW_W, dword WINDOW_H

	ret
endproc
