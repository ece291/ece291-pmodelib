; SB16 interface code
;  By Michael Urman, 2001
;
; Code history: 
;  dmaw32.c of the soundblaster development kit
;  soundlib291 (8 bit real mode driver)
;
; $Id: sb16.asm,v 1.3 2001/04/06 02:39:58 mu Exp $
%include "myC32.mac"
%include "constant.inc"

%include "int_wrap.inc"
%include "dpmi_mem.inc"

extern _getenv
_getenv_arglen			equ	4

	GLOBAL	_SB16_Init
	GLOBAL	_SB16_Exit
	GLOBAL	_SB16_Start
	GLOBAL	_SB16_Stop
	GLOBAL	_SB16_SetCallback
	GLOBAL	_SB16_SetFormat
	GLOBAL	_SB16_SetMixers
	GLOBAL	_SB16_GetChannel
	GLOBAL	_SB16_GetEnv
	GLOBAL	_SB16_InstallISR
	GLOBAL	_SB16_EnableInterrupt
	GLOBAL	_SB16_DSPWrite
	GLOBAL	_SB16_Reset

        BITS    32


; SB CONSTANTS
DSP_BLOCK_SIZE                  EQU     0048h
DSP_DATA_AVAIL                  EQU     000Eh
DSP_DATA_AVL16                  EQU     000Fh
DSP_HALT_SINGLE_CYCLE_DMA       EQU     00D0h
DSP_READ_PORT                   EQU     000Ah
DSP_READY                       EQU     00AAh
DSP_RESET                       EQU     0006h
DSP_TIME_CONSTANT               EQU     0040h
DSP_SAMPLE_RATE			EQU	0041h
DSP_WRITE_PORT                  EQU     000Ch
DSP_MIXER_ADDR                  EQU     0004h
DSP_MIXER_DATA                  EQU     0005h
DSP_VERSION                     EQU     00E1h
DSP_IRQ_STAT			EQU	0082h

SB8_AUTOINIT_PLAY	EQU	00C6h
SB8_SINGLECYCLE_PLAY	EQU	00C0h
SB8_PLAY_MONO		EQU	0000h
SB8_PLAY_STEREO		EQU	0020h
SB8_AUTOINIT_STOP	EQU	00DAh

SB16_AUTOINIT_PLAY	EQU	00B6h
SB16_SINGLECYCLE_PLAY	EQU	00B0h
SB16_PLAY_MONO		EQU	0010h
SB16_PLAY_STEREO	EQU	0030h
SB16_AUTOINIT_STOP	EQU	00D9h

SB16_SPEAKER_ON	EQU	00D1h
SB16_SPEAKER_OFF	EQU	00D3h
SB16_VOL_VOICE	EQU	04h
SB16_VOL_MIC	EQU	0Ah
SB16_VOL_MASTER	EQU	22h
SB16_VOL_FM	EQU	26h
SB16_VOL_CD	EQU	28h
SB16_VOL_LINE	EQU	2Eh
SB16_INTR_STAT	EQU	82h

PIC_END_OF_INT  EQU     20h
PIC_MODE        EQU     20h
SLAVE_PIC	EQU    0A0h


; STUFF

SB_UNCONFIGURED		equ	1h
SB_UNINSTALLED		equ	2h
SB_NOENV		equ	4h


	SECTION	.data

_SB16_LockData_Start

SB16_Callback	dd	0

SB16_INT	db	0
SB16_IRQ	db	0
SB16_IO		dw	0
SB16_DMA_Low	db	0
SB16_DMA_High	db	0

; on SB16_STATUS == 0 it's safe to start
SB16_Status	dd	SB_UNCONFIGURED+SB_UNINSTALLED+SB_NOENV
SB16_Active	dd	0	; on zero, safe to change config

SB16_Bits	db	0
SB16_SampleRate	db	0
SB16_Stereo	db	0

SB16_OrigISR
SB16_DSPVer	db	0

_SB16_LockData_End

_BlasterEnv	db	'BLASTER', 0

;----------------------------------------
; bool SB16_Init(void(*)(void)Callback)
; Purpose: Probes settings and installs ISR; success must pair with SB16_Exit 
; Inputs:  Callback, address of interrupt callback function
; Outputs: On error, eax=1, else eax=0
;----------------------------------------
proc _SB16_Init
.Callback	arg	4

	invoke	_SB16_GetEnv
	test	eax, eax
	jnz	.fail

	invoke	_SB16_Reset
	test	eax, eax
	jnz	.fail

	invoke	_SB16_InstallISR, dword SB16_ISR
	test	eax, eax
	jnz	.fail

	invoke	_SB16_EnableInterrupt, dword 1
	test	eax, eax
	jnz	.fail

	; set the callback if nonzero
	mov	eax, [ebp+.Callback]
	test	eax, eax
	jz	.succeed

	invoke	_SB16_SetCallback, eax
	xor	eax, eax

.succeed
	; mark installed
	mov	ecx, ~SB_UNINSTALLED
	and	[SB16_Status], ecx
	ret

.fail
	xor	eax, eax
	inc	eax
	ret
endproc
_SB16_Init_arglen		equ	4

;----------------------------------------
; bool SB16_Exit()
; Purpose: Uninstalls ISR and cleans anything else
; Inputs:  none
; Outputs: On error, eax=1, else eax=0
;----------------------------------------
proc _SB16_Exit

	; TODO stop sounds if playing.
	; TODO skip if not installed
	; TODO mute speakers? out(SB16_IO+0Ch, 0D3h)

	mov	ecx, SB_UNINSTALLED
	or	[SB16_Status], ecx

	invoke	_SB16_EnableInterrupt, dword 0
	test	eax, eax
	jnz	.fail

	invoke	_SB16_InstallISR, dword 0
	test	eax, eax
	jnz	.fail

	invoke	_SB16_Reset
	;test	eax, eax
	;jnz	.fail
	ret

.fail
	xor	eax, eax
	inc	eax
	ret
endproc

;----------------------------------------
; bool SB16_Start(int Size, bool AutoInit, bool Write)
; Purpose: Tells the SB to initiate a DMA transfer; do this after DMA_Start
; Inputs:  Size, size in bytes to transfer before generating interrupt
;	   AutoInit, whether to use AutoInit (1) or SingleCycle (0)
;	   Write, whether to Play (1) or Record (0)
; Outputs: On error, eax=1, else eax=0
;----------------------------------------
proc _SB16_Start

.Size		arg	4
.AutoInit	arg	4
.Write		arg	4

	cmp	dword[SB16_Status], 0	; verify SB is ready
	jnz	near .fail
	cmp	dword[SB16_Active], 0
	jnz	near .fail

	dec	dword [ebp+.Size]
	cmp	dword [ebp+.Size], 0FFFFh	; only accept real sizes
	ja	near .fail

%if 0
	; try old way.

	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword DSP_TIME_CONSTANT
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword 165
	
	cmp	dword [ebp+.AutoInit], 0
	jz	.singlecycle

	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword DSP_BLOCK_SIZE
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword [ebp+.Size+0]
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword [ebp+.Size+1]
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword 01Ch
	xor	eax, eax
	jmp	short .ret

.singlecycle
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword 014h
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword [ebp+.Size+0]
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword [ebp+.Size+1]
	xor	eax, eax
	jmp	short .ret

%elif 1
	; set sample rate
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword DSP_SAMPLE_RATE
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword [SB16_SampleRate+1]
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword [SB16_SampleRate]

	; Write Auto/Single 8/16 bit control byte
	mov	al, 0B0h
	cmp	dword [ebp+.AutoInit], 0
	jz	.notAutoInit
	add	al, 006h
.notAutoInit
	cmp	byte [SB16_Bits], 8
	jne	.not8bitsAS
	add	al, 010h
.not8bitsAS
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword eax

	; Write Mono/Stereo 8/16 bit control byte
	mov	al, 000h
	cmp	byte [SB16_Stereo], 0
	je	.notStereo
	add	al, 020h
.notStereo
	cmp	byte [SB16_Bits], 8
	jne	.not8bitsSM
	add	al, 010h
.not8bitsSM
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword eax

	; set length
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword [ebp+.Size+0]
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword [ebp+.Size+1]

	xor	eax, eax
	jmp	.ret
%endif

.fail
	xor	eax, eax
	inc	eax
.ret
	ret
endproc
_SB16_Start_arglen		equ	12

;----------------------------------------
; bool SB16_Stop()
; Purpose: Tells the SB to cease DMA transfer
; Inputs:  none
; Outputs: On error, eax=1, else eax=0
;----------------------------------------
proc _SB16_Stop

	; TODO: FIXME
	cmp	byte [SB16_Bits], 8
	jne	.16bits
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword SB8_AUTOINIT_STOP
	jmp	.done
.16bits
	invoke	_SB16_DSPWrite, dword DSP_WRITE_PORT, dword SB16_AUTOINIT_STOP

.done
	; dword 0D0h

	ret
endproc

;----------------------------------------
; void SB16_SetCallback(void*(void)Callback)
; Purpose: Sets the interrupt callback
; Inputs:  Callback, address of LOCKED interrupt callback function
; Outputs: none
;----------------------------------------
proc _SB16_SetCallback

.Callback	arg	4

	mov	eax, [ebp+.Callback]
	mov	[SB16_Callback], eax

	ret
endproc
_SB16_SetCallback_arglen	equ	4

;----------------------------------------
; bool SB16_SetFormat(int Bits, int SampleRate, bool Stereo)
; Purpose: Sets the format of the sound stream
; Inputs:  Bits, number of bits per sample (8 or 16)
;	   SampleRate, in samples per second
;	   Stereo, whether stream is mono or stereo
; Outputs: On error, eax=1, else eax=0
;----------------------------------------
proc _SB16_SetFormat

.Bits		arg	4
.SampleRate	arg	4
.Stereo		arg	4

	; TODO: consider
	;  - removing the sanity checks

	mov	eax, [SB16_Active]
	test	eax, eax
	jnz	.fail

	mov	eax, [ebp+.Bits]
	mov	ebx, [ebp+.SampleRate]
	mov	ecx, [ebp+.Stereo]

	; accept 8 or 16
	cmp	eax, 8
	je	.bits
	cmp	eax, 16
	jne	.fail
.bits
	mov	[SB16_Bits], al

	; accept < 65536
	cmp	ebx, 0FFFFh
	ja	.fail
	mov	[SB16_SampleRate], ebx

	; treat as zero=mono/nonzero=stereo
	test	ecx, ecx
	jz	.mono
	mov	byte[SB16_Stereo], 1
	jmp	.done
.mono
	mov	byte[SB16_Stereo], 0
.done
	and	dword[SB16_Status], ~SB_UNCONFIGURED
	xor	eax, eax
	ret

.fail
	xor	eax, eax
	inc	eax
	ret
endproc
_SB16_SetFormat_arglen		equ	12

;----------------------------------------
; bool SB16_SetMixers(short Master, short PCM, short FM, short CD, short Line, short Mic)
; Purpose: Sets the mixers to provided volume levels
; Inputs:  Master, overall volume.  Speakers off if zero.
;	   PCM, volume for pcm data (wavs)
;	   FM, volume for fm synth (midi)
;	   CD, volume for CD audio
;	   Line, volume for data line
;	   Mic, volume for Mic input
;	   0 is minimum volume, 63 is maximum.	; TODO: checkme
;	   If MSB (80h) set, that mixer will not be changed.
; Outputs: On error, eax=1, else eax=0
;----------------------------------------
proc _SB16_SetMixers

	;TODO: FIXME: WRITEME
.Master		arg	2
.PCM		arg	2
.FM		arg	2
.CD		arg	2
.Line		arg	2
.Mic		arg	2

	mov	al, [ebp+.Master]
	test	al, 80h
	jnz	.pcm
	test	al, al
	jz	.master_off
	mov	dx, [SB16_IO]
	add	dx, DSP_WRITE_PORT
	mov	al, SB16_SPEAKER_ON
	out	dx, al
	jmp	short .master

.master_off
	mov	dx, [SB16_IO]
	add	dx, DSP_WRITE_PORT
	mov	al, SB16_SPEAKER_OFF
	out	dx, al

.master
	push	ax
	mov	dx, [SB16_IO]
	add	dx, DSP_MIXER_ADDR
	mov	al, SB16_VOL_MASTER
	out	dx, al
	pop	ax
	add	dx, DSP_MIXER_DATA-DSP_MIXER_ADDR
	out	dx, al
.pcm
	mov	al, [ebp+.PCM]
	test	al, 80h
	jnz	.fm
	push	ax
	invoke	_SB16_DSPWrite, dword DSP_MIXER_ADDR, dword SB16_VOL_VOICE
	pop	ax
	invoke	_SB16_DSPWrite, dword DSP_MIXER_DATA, eax
.fm
	;mov	al, [ebp+.FM]
	;test	al, 80h
	;jnz	.cd
	;push	ax
	;invoke	_SB16_DSPWrite, dword DSP_MIXER_ADDR, dword SB16_VOL_FM
	;pop	ax
	;invoke	_SB16_DSPWrite, dword DSP_MIXER_DATA, eax
;.cd
	;mov	al, [ebp+.CD]
	;test	al, 80h
	;jnz	.line
	;push	ax
;invoke	_SB16_DSPWrite, dword DSP_MIXER_ADDR, dword SB16_VOL_CD
	;pop	ax
	;invoke	_SB16_DSPWrite, dword DSP_MIXER_DATA, eax
.;line
	mov	al, [ebp+.Line]
	test	al, 80h
	jnz	.mic
	push	ax
	invoke	_SB16_DSPWrite, dword DSP_MIXER_ADDR, dword SB16_VOL_LINE
	pop	ax
	invoke	_SB16_DSPWrite, dword DSP_MIXER_DATA, eax
.mic
	mov	al, [ebp+.Mic]
	test	al, 80h
	jnz	.done
	push	ax
	invoke	_SB16_DSPWrite, dword DSP_MIXER_ADDR, dword SB16_VOL_MIC
	pop	ax
	invoke	_SB16_DSPWrite, dword DSP_MIXER_DATA, eax
.done
	xor	eax, eax
	ret
endproc
_SB16_SetMixers_arglen		equ	12

;----------------------------------------
; long SB16_GetChannel()
; Purpose: Returns SB16 DMA as probed.
; Inputs:  None
; Outputs: On error, eax=FFFFFFFF, else ah=16 bit DMA, al=8 bit DMA
;----------------------------------------
proc _SB16_GetChannel

	test	dword [SB16_Status], dword SB_NOENV
	jnz	.error

	mov	ah, [SB16_DMA_High]
	mov	al, [SB16_DMA_Low]
	jmp	.ret

.error
	xor	eax, eax
	dec	eax
.ret
	ret
endproc

;----------------------------------------
; bool SB16_GetEnv()
; Purpose: Reads the SB16 Settings from the environment BLASTER variable
; Inputs:  None
; Outputs: On error, eax=1, else eax-0
;----------------------------------------
proc _SB16_GetEnv

	invoke	_getenv, dword _BlasterEnv
	test	eax, eax
	jz	.fail
	xor	ebx, ebx

.FindSettingsLoop:	; loop for A220 I5 H1 D5 or similar
	mov	dl, [eax]
	cmp	dl, 'A'
	je	.IObase
	cmp	dl, 'a'
	je	.IObase

	cmp	dl, 'I'
	je	near .IRQ
	cmp	dl, 'i'
	je	near .IRQ

	cmp	dl, 'D'
	je	near .lowDMA
	cmp	dl, 'd'
	je	near .lowDMA

	cmp	dl, 'H'
	je	near .highDMA
	cmp	dl, 'h'
	je	near .highDMA

	cmp	bl, 0Fh
	je	.done
	cmp	dl, ' '
	jne	.fail

	inc	eax
	jmp	.FindSettingsLoop

.done
	xor	eax, eax
	and	dword [SB16_Status], dword ~SB_NOENV
	ret

.fail
	xor	eax, eax
	inc	eax
	ret

.IObase			; Read things like A220 as hex numbers
	xor	ecx, ecx
	xor	edx, edx
.IOloop
	inc	eax
	mov	dl, [eax]
	cmp	dl, ' '
	jne	.IOfind
	mov	[SB16_IO], cx
	or	bl, 1h
	inc	eax
	jmp	.FindSettingsLoop
.IOfind
	cmp	dl, '0'
	jb	.fail
	cmp	dl, '9'
	ja	.IOletter
	sub	dl, '0'
	jmp	.IOadd
.IOletter
	cmp	dl, 'A'
	jb	.fail
	cmp	dl, 'F'
	ja	.IOlc
	sub	dl, 'A'-10
	jmp	.IOadd
.IOlc
	cmp	dl, 'a'
	jb	.fail
	cmp	dl, 'a'
	ja	.fail
	sub	dl, 'a'-10
	;jmp	.IOadd

.IOadd
	shl	ecx, 4
	add	ecx, edx
	jmp	.IOloop


.IRQ		; read I[1-15] as decimals
	xor	ecx, ecx
	xor	edx, edx
.IRQloop
	inc	eax
	mov	dl, [eax]
	cmp	dl, ' '
	je	.IRQdone
	cmp	dl, 0
	jne	.IRQfind
.IRQdone
	cmp	cl, 0Fh
	ja	.fail
	mov	[SB16_IRQ], cl
	cmp	cl, 8
	jb	.lowirq
	add	cl, 70h-8h-8h	; pre-subtract to account for following add
.lowirq
	add	cl, 8h
	mov	[SB16_INT], cl
	or	bl, 2h
	inc	eax
	jmp	.FindSettingsLoop
.IRQfind
	cmp	dl, '0'
	jb	near .fail
	cmp	dl, '9'
	ja	near .fail
	sub	dl, '0'
	lea	ecx, [ecx+4*ecx]
	shl	ecx, 1
	add	ecx, edx
	jmp	.IRQloop

.lowDMA		; read D[0-7] as digit
	inc	eax
	mov	dl, [eax]
	cmp	dl, '0'
	jb	near .fail
	cmp	dl, '9'
	ja	near .fail
	sub	dl, '0'
	mov	[SB16_DMA_Low], dl
	or	bl, 4h
	inc	eax
	jmp	.FindSettingsLoop

.highDMA	; read H[0-7] as digit
	inc	eax
	mov	dl, [eax]
	cmp	dl, '0'
	jb	near .fail
	cmp	dl, '9'
	ja	near .fail
	sub	dl, '0'
	mov	[SB16_DMA_High], dl
	or	bl, 8h
	inc	eax
	jmp	.FindSettingsLoop

endproc

;----------------------------------------
; bool SB16_InstallISR(void(*)(void)ISR)
; Purpose: Lock ISR data and Install or remove the ISR
; Inputs:  ISR address to use, or 0 to remove
; Outputs: On error, eax=1, else eax=0
;----------------------------------------
proc _SB16_InstallISR
.ISR	arg	4
	; TODO: FIXME: check returns and set eax appropriately (for fail
	; case)

	mov	edx, [ebp+.ISR]
	test	edx, edx
	jz	.Remove

	invoke	_LockArea, word cs, dword SB16_ISR, dword SB16_ISR_End-SB16_ISR
	invoke	_LockArea, word ds, dword _SB16_LockData_Start, dword _SB16_LockData_End-_SB16_LockData_Start

	; Install the ISR
	xor	eax, eax
	xor	ebx, ebx
	mov	al, [SB16_INT]
	mov	edx, [ebp+.ISR]
	invoke	_Install_Int, eax, edx
	jmp	short .succeed

	; or Remove it
.Remove
	xor	eax, eax
	mov	al, [SB16_INT]
	invoke	_Remove_Int, eax
.succeed
	xor	eax, eax
	ret
.fail
	xor	eax, eax
	inc	eax
	ret
endproc
_SB16_InstallISR_arglen		equ	4

;----------------------------------------
; void interrupt SB16_ISR
; Purpose: Service the SB interrupt; call callback if provided.
; Inputs:  none
; Outputs: none
;----------------------------------------
SB16_ISR
	cmp	byte [SB16_Bits], 16
	jne	.8bitack
	mov	dx, [SB16_IO]
	add	dx, DSP_IRQ_STAT
	mov	al, SB16_INTR_STAT
	out	dx, al
	add	dx, DSP_MIXER_DATA-DSP_IRQ_STAT
	in	al, dx
	test	al, 02h
	jz	.SBdoneack
	add	dx, DSP_DATA_AVL16-DSP_MIXER_DATA
	in	al, dx	; acknowledge 16bit interrupt
	jmp	short .SBdoneack
.8bitack
	mov	dx, [SB16_IO]
	add	dx, DSP_DATA_AVAIL	; ack SB
	in	al, dx
.SBdoneack

        mov     al, PIC_END_OF_INT
        out     PIC_MODE, al            ; ack PIC
	cmp	byte [SB16_IRQ], 8
	jb	.donePicAck
	mov	dx, SLAVE_PIC
	out	dx, al
.donePicAck

        cmp     dword [SB16_Callback], 0
        je      .done
	; TODO: CHECKME (call)
        call    dword [SB16_Callback]	; call user callback

.done
	xor	eax, eax		; don't chain interrupts
	ret
SB16_ISR_End

;----------------------------------------
; void SB16_EnableInterrupt(bool Enable)
; Purpose: Enable/Disable SB16's IRQ
; Inputs:  Enable, nonzero to enable, zero to disable the IRQ
; Outputs: none
;----------------------------------------
proc _SB16_EnableInterrupt

.Enable		arg	4

	mov	eax, [ebp+.Enable]
	test	eax, eax
	jz	.Disable

	; Unmask the Interrupt
	xor	eax, eax
	mov	al, [SB16_IRQ]
	invoke	_Init_IRQ
	xor	eax, eax
	mov	al, [SB16_IRQ]
	invoke	_Enable_IRQ, eax

	xor	eax, eax
	jmp	.success

.Disable
	; Mask the Interrupt
	xor	eax, eax
	mov	al, [SB16_IRQ]
	; invoke	_Disable_IRQ, eax	; unnecessary?
	invoke	_Exit_IRQ

.success
	ret
endproc
_SB16_EnableInterrupt_arglen	equ	4

;----------------------------------------
; void SB16_DSPWrite(int Port, dword Value)
; Purpose: Write Value to Port, after delaying for old cards
; Inputs:  Port, add IOBASE to this for chosen IO port
;	   Value, lowest byte of value to be written to DSP
; Outputs: None
;----------------------------------------
proc _SB16_DSPWrite

.Port	arg	4
.Value	arg	4

	mov	dx, [SB16_IO]
	add	dx, DSP_WRITE_PORT
.wait
	;mov ax, 1680h		; yield scheduling to windows
	;int 2Fh		; (don't take 100% cpu for no reason)

	in	al, dx
	test	al, 80h
	jnz	.wait

	sub	dx, DSP_WRITE_PORT
	add	dx, [ebp+.Port]
	mov	al, [ebp+.Value]
	out	dx, al

	ret
endproc
_SB16_DSPWrite_arglen		equ	8

;----------------------------------------
; unsigned char SB16_DSPRead(int Port)
; Purpose: Read Value to Port, after delaying for old cards
; Inputs:  Port, add IOBASE to this for chosen IO port
;	   Value, lowest byte of value to be written to DSP
; Outputs: al=data
;----------------------------------------
proc _SB16_DSPRead

.Port	arg	4

	mov	dx, [SB16_IO]
	add	dx, DSP_DATA_AVAIL
.wait
	;mov ax, 1680h		; yield scheduling to windows
	;int 2Fh		; (don't take 100% cpu for no reason)

	in	al, dx
	test	al, 80h
	jz	.wait

	sub	dx, DSP_DATA_AVAIL
	add	dx, [ebp+.Port]
	in	al, dx

	ret
endproc
_SB16_DSPRead_arglen		equ	4

;----------------------------------------
; bool SB16_Reset()
; Purpose: Reset the DSP, setting SB16_DSPVer
; Inputs:  None
; Outputs: On error, eax=1, else eax=0
;----------------------------------------
proc _SB16_Reset

	;write a '1' to the Reset port 2x6h and wait for 3us
	mov dx, word[SB16_IO]
	add dx, DSP_RESET       ; in SBcons.inc     
	mov al, 1
	out dx, al

	add dx, DSP_DATA_AVAIL - DSP_RESET
	mov cx, 8
.burn1:
	in  al, dx          ; wait for 3us
	loop    .burn1

	; write a '0' to the Reset port
	add dx, DSP_RESET - DSP_DATA_AVAIL
	mov al, 0
	out dx, al

	add dx, DSP_DATA_AVAIL - DSP_RESET
	mov cx, 400
.burn2:
	in  al, dx          ; wait 100+us
	loop    .burn2

	; check Read_Buf Status to ensure there is data b4 reading Read Data port
	in  al, dx
	test    al, 80h
	mov al, 0
	jz  .rstdn

	; read from READ DATA port
	mov dx, word[SB16_IO]
	add dx, DSP_READ_PORT
.agn:
	in  al, dx
	cmp al, DSP_READY
	jne .rstdn
	xor eax, eax
	jmp .beenReset

.rstdn:
	xor	eax, eax
	inc	eax
.beenReset:
	ret
endproc
