; Graphics (640x480x32-bit) header file
;  By Peter Johnson, 2000

	EXTERN _SetGraphics
	EXTERN _UnsetGraphics
	EXTERN _WritePixel
	EXTERN _ReadPixel
	EXTERN _RefreshVideoBuffer

_SetGraphics_arglen		equ	4
_WritePixel_arglen		equ	8
_ReadPixel_arglen		equ	4
