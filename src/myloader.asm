; Generic loader code for DJGPP/NASM
;  By Peter Johnson, 1999
;
; Program entry point, allocates descriptor to video RAM
%include "myC32.mac"
%include "dpmi_int.inc"
%include "dpmi_mem.inc"
%include "constant.inc"

	BITS 32

	GLOBAL _main
	GLOBAL _djgpp_ds
	GLOBAL _djgpp_es
	GLOBAL _djgpp_fs
	GLOBAL _djgpp_gs
	GLOBAL _VideoBlock
	GLOBAL _ScratchBlock
	GLOBAL _textdescriptor

	EXTERN _mymain

;	EXTERN _atoi
;_atoi_arglen		equ	4

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

_textdescriptor dw	0h		; 16-bit storage for text descriptor

	SECTION .text

; ClearVideoBlock
; Clears the memory in _VideoBlock so that it doesn't contain garbage!
ClearVideoBlock:
	push	es
	mov	es, word [_VideoBlock]
	xor	edi, edi
	xor	eax, eax
	mov	ecx, WINDOW_W*WINDOW_H
	rep stosd
	pop	es

	ret
	
;----------------------------------------
; int main(int argc, char *argv[]);
; Purpose: Called from DJGPP loader after PM initialization.
; Inputs:  argc, number of arguments (including program name)
;	   argv, argument contents
; Outputs: 1 on error, otherwise 0
;----------------------------------------
proc _main

%$argc	arg	4
%$argv	arg	4

	; Save DJGPP startup selectors
	mov	[_djgpp_ds], ds
	mov	[_djgpp_es], es
	mov	[_djgpp_fs], fs
	mov	[_djgpp_gs], gs
	
;	; Parse command line, if any.
;	cmp	dword [ebp+%$argc], 3
;	jne	.NoCommandLine
;
;	mov	eax, [ebp+%$argv]
;	add	eax, 4			; argv[1] = IP address
;	mov	edx, [eax]
;	invoke	_gethostbyname, dword edx
;	test	eax, eax
;	jz	.NoCommandLine		; Invalid IP
;	; haddress = ((struct in_addr *) hent->h_addr)->s_addr;
;	mov	edx, [eax+12]
;	mov	eax, [edx]
;	mov	edx, [eax]
;	mov	[ServerIPAddress], edx
;
;	mov	eax, [ebp+%$argv]
;	add	eax, 8			; argv[2] = Port
;	mov	edx, [eax]
;	invoke	_atoi, dword edx
;	mov	[ServerUDPPort], eax
;
;.NoCommandLine:
	
	; Grab a descriptor for textvideo RAM from DPMI
	mov	ax, 02h				; [DPMI] segment -> descriptor
	mov	ebx, 0b800h			; segment to get a descriptor for
	int	31h
	jc	near .error				; exit if error
	mov	[_textdescriptor], ax		; save descriptor
	
	; Alloc & Lock 32-bit Video Block
	invoke	_AllocMem, dword WINDOW_W*WINDOW_H*4
	cmp	ax, 0ffffh
	jz	near .error
	mov	word [_VideoBlock_Handle], ax
	
	invoke	_LockMem, word ax
	cmp	ax, 0
	jz	near .error
	mov	word [_VideoBlock], ax
	mov	gs, ax
	
	; Alloc & Lock "Scratch" Block
	invoke	_AllocMem, dword 1024*1024
	cmp	ax, 0ffffh
	jz	near .error
	mov	word [_ScratchBlock_Handle], ax

	invoke	_LockMem, word ax
	cmp	ax, 0
	jz	near .error
	mov	word [_ScratchBlock], ax

	; Get RM interrupt transfer buffer
	invoke	_AllocTransferBuf	

	; Clear the video block
	call	ClearVideoBlock
	      
	; Run the actual program
	call	_mymain			

	; Free RM interrupt transfer buffer
	invoke	_FreeTransferBuf	

	; Unlock & Free 32-bit Video Block
	invoke	_UnlockMem, word [_VideoBlock_Handle]
	invoke	_FreeMem, word [_VideoBlock_Handle]
	; Unlock & Free "Scratch" Block
	invoke	_UnlockMem, word [_ScratchBlock_Handle]
	invoke	_FreeMem, word [_ScratchBlock_Handle]
	
	; Restore DJGPP startup selectors
	mov	ds, [_djgpp_ds]
	mov	es, [_djgpp_es]
	mov	fs, [_djgpp_fs]
	mov	gs, [_djgpp_gs]

	xor	ax, ax				; Clear any possible error return
	jmp	.leave
.error:
	mov	ax, 1
.leave:

endproc
