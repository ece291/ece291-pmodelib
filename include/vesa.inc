; VESA Mode (320x240x32-bit) header file
;  By Peter Johnson, 1999-2000
;
; $Id: vesa.inc,v 1.4 2000/12/14 07:52:21 pete Exp $

	EXTERN _CheckVESA
	EXTERN _SetVESA
	EXTERN _UnsetVESA
	EXTERN _WritePixelVESA
	EXTERN _ReadPixelVESA
	EXTERN _RefreshVideoBufferVESA

_CheckVESA_arglen		equ	4
_WritePixelVESA_arglen		equ	8
_ReadPixelVESA_arglen		equ	4
