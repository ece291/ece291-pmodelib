; Graphics (640x480x32-bit) header file
;  By Peter Johnson, 2000
;
; $Id: graphics.inc,v 1.2 2000/12/14 07:52:21 pete Exp $

	EXTERN _SetGraphics
	EXTERN _UnsetGraphics
	EXTERN _WritePixel
	EXTERN _ReadPixel
	EXTERN _RefreshVideoBuffer

_SetGraphics_arglen		equ	4
_WritePixel_arglen		equ	8
_ReadPixel_arglen		equ	4
