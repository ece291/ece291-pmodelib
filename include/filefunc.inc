; File handling functions header file
;  By Peter Johnson, 1999-2001
;
; $Id: filefunc.inc,v 1.5 2001/03/16 22:58:36 pete Exp $

	EXTERN _OpenFile
	EXTERN _CloseFile
	EXTERN _ReadFile
	EXTERN _ReadFile_Sel
	EXTERN _WriteFile
	EXTERN _WriteFile_Sel
	EXTERN _SeekFile

_OpenFile_arglen	equ	6
_CloseFile_arglen	equ	4
_ReadFile_arglen	equ	12
_ReadFile_Sel_arglen	equ	14
_WriteFile_arglen	equ	12
_WriteFile_Sel_arglen	equ	14
_SeekFile_arglen	equ	10
