; VBE/AF loadable graphics driver header file
;  By Peter Johnson, 2001
;
; $Id: vbeaf.inc,v 1.1 2001/03/02 08:03:39 pete Exp $

	EXTERN _LoadGraphicsDriver
	EXTERN _InitGraphics
	EXTERN _ExitGraphics
	EXTERN _FindGraphicsMode
	EXTERN _SetGraphicsMode
	EXTERN _UnsetGraphicsMode
	EXTERN _CopyToScreen

_LoadGraphicsDriver_arglen	equ	4
_InitGraphics_arglen		equ	12
_FindGraphicsMode_arglen	equ	10
_SetGraphicsMode_arglen		equ	2
_CopyToScreen_arglen		equ	32
