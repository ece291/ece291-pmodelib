; Graphics (640x480x32-bit) routines
;  By Peter Johnson, 2000
;
; $Id: graphics.asm,v 1.2 2000/12/14 07:52:21 pete Exp $
%include "myC32.mac"		; C interface macros

%include "constant.inc"
%include "dpmi_int.inc"
%include "dpmi_mem.inc"
%include "vesa.inc"

	BITS	32

	GLOBAL _VideoBlock

	STRUC	VESASupp	; VESA supplemental info block
.Signature		resb	7
.Version		resw	1
.SubFunc		resb	8
.OEMSoftwareRev		resw	1
.OEMVendorNamePtr	resd	1
.OEMProductNamePtr	resd	1
.OEMProductRevPtr	resd	1
.OEMStringPtr		resd	1
.Reserved		resb	221
	ENDSTRUC

	SECTION .bss

_VideoBlock	resw	1	; 32-bit Video Backbuffer Selector
VESA_Selector	resw	1	; Selector for VESA, 0 if 291 interface
SuppInfo	resb	256	; VESA supplemental info block
DisplayWidth	resd	1	; Width of display (in pixels)
DisplayHeight	resd	1	; Height of display (in pixels)
BytesPerLine	resd	1	; Bytes per scanline (DisplayWidth*4)

	SECTION .text

;----------------------------------------
; bool SetGraphics(short Width, short Height);
; Purpose: Sets the graphics mode.
; Inputs:  Width, the width of the graphics screen (in pixels)
;	   Height, the height of the graphics screen (in pixels)
; Outputs: 1 on error, 0 otherwise
; Notes:   Will first try to use the accelerated ECE 291 "VESA" driver,
;	   but will fall back on VESA LFB if necessary (but this is not
;	   guaranteed to work).  Always allocates a 32-bit mode.
;----------------------------------------
proc _SetGraphics

%$Width		arg	2
%$Height	arg	2

	; Prepare Transfer buffer, DPMI_Regs structure
	mov	es, [_Transfer_Buf]
	mov	ax, [_Transfer_Buf_Seg]
	mov	[DPMI_DS], ax
	mov	[DPMI_ES], ax
	mov	ecx, 64		; 64 dwords = 256 bytes
	xor	edi, edi
	xor	eax, eax
	rep stosd		; Clear transfer buffer

        ; Try to access 291 "VESA" driver
        mov     dword [DPMI_EAX], 4F23h ; [VESA] Supplemental API (ECE 291)
	mov	dword [DPMI_EBX], 0	; [VESA] Get Supplemental API info
	mov	dword [DPMI_EDI], 0	; ES:DI = Buffer for SVGA info
	mov	bx, 10h
	call	DPMI_Int
	mov	eax, [DPMI_EAX]		; Grab return value

	test	ah, ah
	jnz	near .no291drv		; VESA Supplemental API not installed

	push	ds
	mov	ax, ds
	mov	ds, [_Transfer_Buf]
	xor	esi, esi
	mov	es, ax
	mov	edi, SuppInfo
	mov	ecx, 64		; 64 dwords = 256 bytes
	rep movsd		; Copy into local structure from transfer buffer
	pop	ds

	cmp	dword [SuppInfo+VESASupp.Signature+3], '/291'
	jne	.no291drv	; Invalid info block or not 291 supplemental API

	xor	eax, eax
	mov	ax, [ebp+%$Width]
	mov	[DisplayWidth], eax

	shl	eax, 2
	mov	[BytesPerLine], eax

	xor	eax, eax
	mov	ax, [ebp+%$Height]
	mov	[DisplayHeight], eax

	; Alloc 32-bit Video Backbuffer
	mov	edx, [BytesPerLine]
	imul	eax, edx
	invoke	_AllocMem, dword eax
	cmp	ax, -1
	je	.error
	mov	word [_VideoBlock], ax
	
	mov	ax, 4F23h		; [VESA] Supplemental API (ECE 291)
	mov	bl, 2			; [291] Start Graphics Mode
	mov	cx, [ebp+%$Width]	; [291] Display Width
	shl	ecx, 16
	mov	cx, [ebp+%$Height]	; [291] Display Height
	mov	dx, [_VideoBlock]	; [291] PM Selector of backbuffer
	xor	edi, edi		; [291] PM Offset of backbuffer
	int	10h

	xor	eax, eax
	jmp	.done

.no291drv:
	invoke	_CheckVESA, dword 100h
	test	eax, eax
	jnz	.done

	push	es
	call	_SetVESA
	mov	[VESA_Selector], es
	pop	es
	jmp	short .done

.error:
	xor	eax, eax
	inc	eax	
.done:

endproc

;----------------------------------------
; void UnsetGraphics(void);
; Purpose: Gets out of graphics mode.
; Inputs:  None
; Outputs: None
;----------------------------------------
        GLOBAL  _UnsetGraphics
_UnsetGraphics

	cmp	word [VESA_Selector], 0
	jnz	.UseVESA

	mov	ax, 4F23h
	mov	bl, 3
	int	10h

	jmp	short .done

.UseVESA:
	push	es
	mov	es, [VESA_Selector]

	call	_UnsetVESA

	pop	es

.done:
	; Free 32-bit Video Block
	invoke	_FreeMem, word [_VideoBlock]
	xor	eax, eax
	mov	[_VideoBlock], ax

	ret

;----------------------------------------
; void WritePixel(short X, short Y, unsigned int Color);
; Purpose: Draws a pixel on the backbuffer.
; Inputs:  X, the x coordinate of the point to draw
;          Y, the y coordinate of the point to draw
;          Color, the 32-bit color value to draw
; Outputs: None
;----------------------------------------
proc _WritePixel

%$X             arg     2
%$Y             arg     2
%$Color         arg     4

	push	es

	cmp	word [VESA_Selector], 0
	jnz	.UseVESA

	mov	es, [_VideoBlock]

        xor     eax, eax
        mov     ax, [ebp+%$Y]
        imul    eax, dword [BytesPerLine]
        xor     ebx, ebx
        mov     bx, [ebp+%$X]
        shl     ebx, 2
        add     ebx, eax

        mov     eax, [ebp+%$Color]
        mov     [es:ebx], eax           ; draw the pixel in the desired color

	jmp	.Done
.UseVESA:
	mov	es, [VESA_Selector]

	invoke	_WritePixelVESA, word [ebp+%$X], word [ebp+%$Y], dword [ebp+%$Color]

.Done:
	pop	es
endproc

;----------------------------------------
; unsigned int ReadPixel(short X, short Y);
; Purpose: Reads the color value of a pixel on the backbuffer.
; Inputs:  X, the x coordinate of the point to read
;          Y, the y coordinate of the point to read
; Outputs: The 32-bit color value of the pixel
;----------------------------------------
proc _ReadPixel

%$X             arg     2
%$Y             arg     2

	push	es

	cmp	word [VESA_Selector], 0
	jnz	.UseVESA

	mov	es, [_VideoBlock]

        xor     eax, eax
        mov     ax, [ebp+%$Y]
        imul    eax, dword [BytesPerLine]
        xor     ebx, ebx
        mov     bx, [ebp+%$X]
        shl     ebx, 2
        add     ebx, eax

        mov     eax, [es:ebx]           ; get the pixel color

	jmp	.Done
.UseVESA:
	mov	es, [VESA_Selector]

	invoke	_ReadPixelVESA, word [ebp+%$X], word [ebp+%$Y]

.Done:
	pop	es

endproc

;----------------------------------------
; void RefreshVideoBuffer(void);
; Purpose: Copies the backbuffer to the display memory.
; Inputs:  _VideoBlock filled with new screen data.
; Outputs: None
;----------------------------------------
	GLOBAL	_RefreshVideoBuffer
_RefreshVideoBuffer
	; Is 291 interface available?
	cmp	word [VESA_Selector], 0
	jnz	.UseVESA

	mov	ax, 4F23h
	mov	bl, 4
	int	10h

	ret

.UseVESA:
	push	es
	mov	es, [VESA_Selector]

	call	_RefreshVideoBufferVESA

	pop	es

	ret

