; Library init/deinit code for DJGPP/NASM
;  By Peter Johnson, 1999-2000
;
; Primarily saves segment registers and allocates selector to textmode RAM
%include "myC32.mac"
%include "dpmi_int.inc"
%include "dpmi_mem.inc"
%include "constant.inc"

	BITS 32

	GLOBAL _LibInit
        GLOBAL _LibExit

	GLOBAL _djgpp_ds
	GLOBAL _djgpp_es
	GLOBAL _djgpp_fs
	GLOBAL _djgpp_gs
	GLOBAL _VideoBlock	
	GLOBAL _ScratchBlock
	GLOBAL _textsel

	SECTION .bss

_djgpp_ds	resw	1		; Saved selectors from djgpp startup
_djgpp_es	resw	1
_djgpp_fs	resw	1
_djgpp_gs	resw	1

_VideoBlock_Handle	resw	1	; 32-bit Video Block Handle - ~768 KB
_VideoBlock		resw	1	; 32-bit Video Block Selector
_ScratchBlock_Handle	resw	1	; "Scratch" Block Handle - 1 MB
_ScratchBlock		resw	1	; "Scratch" Block Selector

	SECTION .data

_textsel	dw	0h		; 16-bit storage for text selector

	SECTION .text

;----------------------------------------
; bool LibInit(void);
; Purpose: Initializes static library components.  Call this before calling any library routines!
; Inputs:  None
; Outputs: 1 on error, otherwise 0
;----------------------------------------
_LibInit

	; Save DJGPP startup selectors
	mov	[_djgpp_ds], ds
	mov	[_djgpp_es], es
	mov	[_djgpp_fs], fs
	mov	[_djgpp_gs], gs
	
	; Grab a descriptor for textmode RAM from DPMI
	mov	ax, 02h				; [DPMI] segment -> descriptor
	mov	ebx, 0b800h			; segment to get a descriptor for
	int	31h
	jc	near .error			; exit if error
	mov	[_textsel], ax			; save selector
	
	; Alloc 32-bit Video Block
	invoke	_AllocMem, dword WINDOW_W*WINDOW_H*4
	cmp	ax, -1
	je	near .error
	mov	word [_VideoBlock], ax
	mov	gs, ax
	
	; Alloc "Scratch" Block
	invoke	_AllocMem, dword 1024*1024
	cmp	ax, -1
	je	near .error
	mov	word [_ScratchBlock], ax

	; Get RM interrupt transfer buffer
	invoke	_AllocTransferBuf	

        xor     eax, eax
        jmp     .leave
.error:
        xor     eax, eax
        inc     eax
.leave:
        ret

;----------------------------------------
; void LibExit(void);
; Purpose: Deinitializes library
; Inputs:  None
; Outputs: None
; Notes:   Blindly assumes you called _LibInit.
;----------------------------------------
_LibExit

	; Free RM interrupt transfer buffer
	invoke	_FreeTransferBuf	

	; Free 32-bit Video Block
	invoke	_FreeMem, word [_VideoBlock]
	; Free "Scratch" Block
	invoke	_FreeMem, word [_ScratchBlock]
	
	; Restore DJGPP startup selectors
	mov	ds, [_djgpp_ds]
	mov	es, [_djgpp_es]
	mov	fs, [_djgpp_fs]
	mov	gs, [_djgpp_gs]

        ret
