; VESA Mode (320x240x32-bit) header file
;  By Peter Johnson, 1999

	EXTERN _CheckVESA
        EXTERN _SetVESA
	EXTERN _UnsetVESA
	EXTERN _WritePixelVESA
	EXTERN _ReadPixelVESA
	EXTERN _FillRectangleVESA
	EXTERN _CopyScreenToScreenVESA
	EXTERN _CopySystemToScreenVESA
	EXTERN _ShowPageVESA

_WritePixelVESA_arglen		equ	10
_ReadPixelVESA_arglen		equ	6
_FillRectangleVESA_arglen	equ	12
_CopyScreenToScreenVESA_arglen	equ	20
_CopySystemToScreenVESA_arglen	equ	20
_ShowPageVESA_arglen		equ	2

        EXTERN VESA_BytesPerScanLine
