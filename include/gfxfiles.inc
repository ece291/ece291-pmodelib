; File loading functions header file
;  By Peter Johnson, 1999-2001
;
; $Id: gfxfiles.inc,v 1.5 2001/03/16 22:58:36 pete Exp $

	EXTERN _LoadBMP
	EXTERN _LoadBMP_Sel
        EXTERN _SaveBMP
        EXTERN _SaveBMP_Sel
	
_LoadBMP_arglen		equ	8
_LoadBMP_Sel_arglen	equ	10
_SaveBMP_arglen 	equ     16
_SaveBMP_Sel_arglen 	equ     18
