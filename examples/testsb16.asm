; SB16 test code
;  By Michael Urman, 2001
;
; Code history: 
;  Update - 16bit works fine since VDMSound 2; reworked to use printf
;	macro, which shortens the code considerably.
;  Original Code - only tests 8bit code, as sb16.asm doesn't yet do 16bit
;	testsb16 - tests 16bit code
;
; $Id: testsb16.asm,v 1.4 2003/04/18 21:53:04 mu Exp $
;
; Note - the various _getchar, _printf calls are for example/testing
; convenience.  They are still not for use in final projects.


; Mini "invoke _printf" that handles multiple arguments, all dwords
; Note - you are probably not allowed to use _printf in your projects
%macro printf 1-*
	%rotate -1
	%rep %0
		%ifstr %1   ; handle strings
			jmp	short %%endstr
			%%str	db %1, 0
			%%endstr
			push	dword %%str
		%else
			push	dword %1
		%endif
		%rotate	-1
	%endrep
	call	_printf
	add	esp, 4*%0
%endmacro

%include "lib291.inc"

SIZE		equ	8200

	BITS 32

	GLOBAL _main

EXTERN	_getchar
EXTERN	_printf
_printf_arglen	equ	4

	SECTION .bss

DMASel	resw	1
DMAAddr	resd	1
DMAChan	resb	1

	SECTION .data
	
; Required image files
ISR_Called  dd	0


	SECTION .text

sine16	times SIZE/20 dw 10<<7,10<<7,25<<7,50<<7,75<<7,90<<7,90<<7,75<<7,50<<7,25<<7
;sine16	times SIZE/20 dw 0,0,0,0,0,0,0,0,0,0
sine8	times SIZE/10 db 10,10,25,50,75,90,90,75,50,25

; Simple ISR - counts number of times it's called
_SoundISR
	inc	dword [ISR_Called]
	ret

; Program Start
_main
	call	_LibInit

	printf	"[DMA_Alloc_Mem..."
	invoke	_DMA_Allocate_Mem, dword SIZE, dword DMASel, dword DMAAddr
	cmp	[DMASel], word 0
	je	near .error
	printf	dword .done
	invoke	_DMA_Lock_Mem

	invoke	_LockArea, word [DMASel], dword 0, dword SIZE

	mov	es, [DMASel]
	mov	ecx, SIZE/4
	mov	edi, 0
	mov	esi, sine16
	rep	movsd

	printf	"[SB16_Init..."
	invoke	_SB16_Init, dword _SoundISR
	test	eax, eax
	jnz	near .error
	printf	dword .done

	printf	"[SB16_GetChannel..."
	invoke	_SB16_GetChannel
	mov	[DMAChan], ah
	push	eax
	printf	dword .done
	pop	eax
	movzx	ecx, al
	movzx	edx, ah
	printf	"[D%d H%d]%c%c", ecx, edx, 13, 10

	; 8 bit 11kHz mono sound:
	printf	"[SB16_GetChannel..."
	invoke	_SB16_SetFormat, dword 16, dword 11025, dword 0 
	test	eax, eax
	jnz	near .error
	printf	dword .done

	printf	"[SB16_SetMixers..."
	invoke	_SB16_SetMixers, word 07fh, word 07fh, word 07fh, word 07fh
	test	eax, eax
	jnz	near .error
	printf	dword .done

	printf	"[DMA_Start..."
	movzx	eax, byte [DMAChan]
	invoke	_DMA_Start, eax, dword [DMAAddr], dword SIZE, dword 1, dword 1
	; DMA_Start doesn't report error
	printf	dword .done
	printf	"[SB16_Start..."
	invoke	_SB16_Start, dword SIZE/2, dword 1, dword 1
	test	eax, eax
	jnz	near .error
	printf	dword .done

	; here's where you'd normally wait to see if a full half buffer
	; has been transferred (by probing a variable the ISR sets), and
	; refilling the buffer if necessary.  Note - this checking and
	; filling should be something that the main loop calls
	; periodically unless you really want to hang your program
	; during the playback of a long sound.

.waitmore
	call	_getchar
	cmp	al, ' '
	je	.stopit

	movzx	eax, byte [DMAChan]
	invoke	_DMA_Todo, eax
	printf	"**: DMA Todo: %d%c%c", eax, 13, 10
	jmp	near .waitmore

.stopit
	printf	"[SB16_Start (Single Cycle)..."
	invoke	_SB16_Start, dword SIZE/4, dword 0, dword 1
	test	eax, eax
	jnz	near .error
	printf	dword .done

	printf	"[DMA_Stop..."
	movzx	eax, byte [DMAChan]
	invoke	_DMA_Stop, eax
	; DMA_Stop doesn't report error
	printf	dword .done

	printf	"[SB16_Stop..."
	invoke	_SB16_Stop
	; SB16_Stop doesn't report error
	printf	dword .done

	printf	"[SB16_SetMixers..."
	invoke	_SB16_SetMixers, word 0, word 0, word 0, word 0
	test	eax, eax
	jnz	near .error
	printf	dword .done

	printf	"[SB16_Exit..."
	invoke	_SB16_Exit
	test	eax, eax
	jnz	near .error
	printf	dword .done

	call	_getchar

	printf	"[Interrupted %d times]", dword [ISR_Called]
	call	_LibExit
	ret

.error
	printf	"Failed!] Exiting..."
	mov	ax, 10
	call	_LibExit
	ret

.done		db	" Done]", 13, 10, 0
