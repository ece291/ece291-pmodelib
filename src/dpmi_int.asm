; DPMI Interface - Interrupt-related Functions
;  By Peter Johnson, 1999
;
; $Id: dpmi_int.asm,v 1.4 2001/04/17 23:40:32 pete Exp $
%include "myC32.mac"

	SECTION .bss

	GLOBAL	DPMI_Regs
	GLOBAL	DPMI_EDI
	GLOBAL	DPMI_ESI
	GLOBAL	DPMI_EBP
	GLOBAL	DPMI_EBX
	GLOBAL	DPMI_EDX
	GLOBAL	DPMI_ECX
	GLOBAL	DPMI_EAX
	GLOBAL	DPMI_FLAGS
	GLOBAL	DPMI_ES
	GLOBAL	DPMI_DS
	GLOBAL	DPMI_FS
	GLOBAL	DPMI_GS
	GLOBAL	DPMI_SP
	GLOBAL	DPMI_SS

; DPMI Registers Structure
DPMI_Regs
DPMI_EDI	resd	1
DPMI_ESI	resd	1
DPMI_EBP	resd	1
DPMI_RES0	resd	1
DPMI_EBX	resd	1
DPMI_EDX	resd	1
DPMI_ECX	resd	1
DPMI_EAX	resd	1
DPMI_FLAGS	resw	1
DPMI_ES		resw	1
DPMI_DS		resw	1
DPMI_FS		resw	1
DPMI_GS		resw	1
DPMI_IP		resw	1
DPMI_CS		resw	1
DPMI_SP		resw	1
DPMI_SS		resw	1

	GLOBAL	_Transfer_Buf
	GLOBAL	_Transfer_Buf_Seg
	GLOBAL	_Transfer_Buf_Size

_Transfer_Buf		resw	1	; DPMI Transfer Buffer (Selector)
_Transfer_Buf_Seg	resw	1	; DPMI Transfer Buffer (RM Segment)
_Transfer_Buf_Size	equ	2048*16 ; Size of Transfer Buffer

	SECTION .data

rcsid	db	'$Id: dpmi_int.asm,v 1.4 2001/04/17 23:40:32 pete Exp $',0

	SECTION .text

;----------------------------------------
; DPMI_Int
; Purpose: Simulate a real-mode interrupt with the ability to set
;	   ALL registers, including segments, without faulting
; Inputs:  DPMI_Regs filled with RM interrupt inputs
;	   BX=the interrupt number
; Outputs: DPMI_Regs filled with RM interrupt outputs
;	   CF=1 if error, AX=error code (see DPMI ref for codes)
; Notes:   Clobbers CX, DX
;	   Not C-Style.
;----------------------------------------
	GLOBAL	DPMI_Int
DPMI_Int
	push	es
	push	edi

	mov	dx, ds
	mov	ax, 0300h	; [DPMI 0.9] Simulate Real Mode Interrupt
	mov	cx, 0
	mov	es, dx
	mov	edi, DPMI_Regs
	int	31h
	
	pop	edi
	pop	es

	ret

;----------------------------------------
; bool AllocTransferBuf(void);
; Purpose: Allocates transfer buffer for transferring data from real to
;	   protected mode and vice-versa.
; Inputs:  None
; Outputs: 1 on error, 0 otherwise
;----------------------------------------
	GLOBAL	_AllocTransferBuf
_AllocTransferBuf

	mov	ax, 0100h	; [DPMI 0.9] Allocate DOS Memory Block
	mov	bx, 2048	; Allocate 32k (2048 16-byte paragraphs)
	int	31h
	jc	.error

	mov	word [_Transfer_Buf_Seg], ax	; Store selector and RM segment
	mov	word [_Transfer_Buf], dx

	mov	word [DPMI_DS], ax		; Also fill the DPMI_Regs segments
	mov	word [DPMI_ES], ax		;  with the RM segment value
	mov	word [DPMI_FS], ax
	mov	word [DPMI_GS], ax

	xor	ax, ax
	jmp	.done
.error:
	mov	ax, 1
	
.done:
	ret

;----------------------------------------
; void FreeTransferBuf(void);
; Purpose: Frees transfer buffer allocated by AllocTransferBuf().
; Inputs:  None
; Outputs: None
; Notes:   No error checking.
;----------------------------------------
	GLOBAL	_FreeTransferBuf
_FreeTransferBuf

	mov	ax, 0101h	; [DPMI 0.9] Free DOS Memory Block
	mov	dx, [_Transfer_Buf]
	int	31h

	ret

