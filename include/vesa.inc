; VESA Mode (320x240x32-bit) header file
;  By Peter Johnson, 1999-2000

	EXTERN _CheckVESA
	EXTERN _SetVESA
	EXTERN _UnsetVESA
	EXTERN _WritePixelVESA
	EXTERN _ReadPixelVESA
	EXTERN _RefreshVideoBufferVESA

_CheckVESA_arglen		equ	4
_WritePixelVESA_arglen		equ	8
_ReadPixelVESA_arglen		equ	4
