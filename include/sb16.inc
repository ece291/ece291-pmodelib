; SB16 interface code
;  By Michael Urman, 2001
;
; $Id: sb16.inc,v 1.1 2001/04/03 04:39:34 mu Exp $

	EXTERN	_SB16_Init
	EXTERN	_SB16_Exit
	EXTERN	_SB16_Start
	EXTERN	_SB16_Stop
	EXTERN	_SB16_SetCallback
	EXTERN	_SB16_SetFormat
	EXTERN	_SB16_SetMixers
	EXTERN	_SB16_GetChannel


_SB16_Init_arglen		equ	4
_SB16_Start_arglen		equ	12
_SB16_SetCallback_arglen	equ	4
_SB16_SetFormat_arglen		equ	12
_SB16_SetMixers_arglen		equ	12
