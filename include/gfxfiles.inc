; File loading functions header file
;  By Peter Johnson, 1999-2001
;
; $Id: gfxfiles.inc,v 1.6 2001/10/17 21:02:27 pete Exp $

	EXTERN _LoadPNG
	EXTERN _LoadPNG_Sel
	EXTERN _LoadJPG
	EXTERN _LoadBMP
	EXTERN _LoadBMP_Sel
        EXTERN _SaveBMP
        EXTERN _SaveBMP_Sel
	
_LoadPNG_arglen 	equ     16
_LoadPNG_Sel_arglen 	equ     18
_LoadJPG_arglen 	equ     16
_LoadBMP_arglen		equ	8
_LoadBMP_Sel_arglen	equ	10
_SaveBMP_arglen 	equ     16
_SaveBMP_Sel_arglen 	equ     18
