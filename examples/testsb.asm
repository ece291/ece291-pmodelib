; SB16 test code
;  By Michael Urman, 2001
;
; Code history: 
;  Original Code - only tests 8bit code.  See testsb16 for 16bit test.
;
; $Id: testsb.asm,v 1.6 2001/11/15 03:58:48 mu Exp $
;
; Note - the various _getchar, _printf calls are for example/testing
; convenience.  They are still not for use in final projects.

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

;sine16	times 410 dw 10<<7,10<<7,25<<7,50<<7,75<<7,90<<7,90<<7,75<<7,50<<7,25<<7
sine8	times SIZE/10 db 10,10,25,50,75,90,90,75,50,25

; Simple ISR - counts number of times it's called
_SoundISR
	inc	dword [ISR_Called]
	ret

; Program Start
_main
	call	_LibInit

	push	dword .dmalloc
	call	_printf
	add	esp, 4
	invoke	_DMA_Allocate_Mem, dword SIZE, dword DMASel, dword DMAAddr
	cmp	[DMASel], word 0
	je	near .error
	push	dword .done
	call	_printf
	add	esp, 4
	invoke	_DMA_Lock_Mem

	mov	es, [DMASel]
	mov	ecx, SIZE/4
	mov	edi, 0
	mov	esi, sine8
	rep	movsd

	push	dword .sbinit
	call	_printf
	add	esp, 4
	invoke	_SB16_Init, dword _SoundISR
	test	eax, eax
	jnz	near .error
	push	dword .done
	call	_printf
	add	esp, 4

	push	dword .sbgetch
	call	_printf
	add	esp, 4
	invoke	_SB16_GetChannel
	mov	[DMAChan], al
	movzx	ecx, al
	movzx	edx, ah
	push	edx
	push	ecx
	push	dword .info
		push	dword .done
		call	_printf
		add	esp, 4
	call	_printf
	add	esp, 12

	; 8 bit 11kHz mono sound:
	push	dword .sbsetf
	call	_printf
	add	esp, 4
	invoke	_SB16_SetFormat, dword 8, dword 11025, dword 0 
	test	eax, eax
	jnz	near .error
	push	dword .done
	call	_printf
	add	esp, 4

	push	dword .sbsetmix
	call	_printf
	add	esp, 4
	invoke	_SB16_SetMixers, word 07fh, word 07fh, word 07fh, word 07fh
	test	eax, eax
	jnz	near .error
	push	dword .done
	call	_printf
	add	esp, 4

	push	dword .dmastart
	call	_printf
	add	esp, 4
	movzx	eax, byte [DMAChan]
	invoke	_DMA_Start, eax, dword [DMAAddr], dword SIZE, dword 1, dword 1
	; DMA_Start doesn't report error
	push	dword .done
	call	_printf
	add	esp, 4
	push	dword .sbstart
	call	_printf
	add	esp, 4
	invoke	_SB16_Start, dword SIZE/2, dword 1, dword 1
	test	eax, eax
	jnz	near .error
	push	dword .done
	call	_printf
	add	esp, 4

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
	push	eax
	push	dword .dmatodo
	call	_printf
	add	esp, 8
	jmp	near .waitmore

.stopit
	push	dword .sbstartsc
	call	_printf
	add	esp, 4
	invoke	_SB16_Start, dword SIZE/4, dword 0, dword 1
	test	eax, eax
	jnz	near .error
	push	dword .done
	call	_printf
	add	esp, 4

	push	dword .dmastop
	call	_printf
	add	esp, 4
	movzx	eax, byte [DMAChan]
	invoke	_DMA_Stop, eax
	; DMA_Stop doesn't report error
	push	dword .done
	call	_printf
	add	esp, 4

	push	dword .sbstop
	call	_printf
	add	esp, 4
	invoke	_SB16_Stop
	; SB16_Stop doesn't report error
	push	dword .done
	call	_printf
	add	esp, 4

	push	dword .sbsetmix
	call	_printf
	add	esp, 4
	invoke	_SB16_SetMixers, word 0, word 0, word 0, word 0
	test	eax, eax
	jnz	near .error
	push	dword .done
	call	_printf
	add	esp, 4

	push	dword .sbexit
	call	_printf
	add	esp, 4
	invoke	_SB16_Exit
	test	eax, eax
	jnz	near .error
	push	dword .done
	call	_printf
	add	esp, 4

	call	_getchar

	push	dword [ISR_Called]
	push	dword .times
	call	_printf
	add	esp, 8
	call	_LibExit
	ret

.error
	push	dword .errmsg
	call	_printf
	add	esp, 4
	mov	ax, 10
	call	_LibExit
	ret

.errmsg		db	" Failed!]", 13,10,"Error", 13, 10, 0
.dmalloc	db	"[DMA_Alloc_Mem...", 0
.dmastart	db	"[DMA_Start...", 0
.sbstart	db	"[SB16_Start...", 0
.sbstartsc	db	"[SB16_Start (Single Cycle)...", 0
.sbinit		db	"[SB16_Init...", 0
.sbgetch	db	"[SB16_GetChannel...", 0
.sbsetf		db	"[SB16_SetFormat...", 0
.sbsetmix	db	"[SB16_SetMixers...", 0
.dmastop	db	"[DMA_Stop...",0
.sbstop		db	"[SB16_Stop...",0
.sbexit		db	"[SB16_Exit...",0
.done		db	" Done]", 13, 10, 0
.info		db	"[D%d H%d]", 13, 10, 0
.ver		db	"[V%d]", 13, 10, 0
.times		db	"[Interrupted %d times]", 13, 10, 0
.dmatodo	db	"**: DMA Todo: %d", 13, 10, 0

