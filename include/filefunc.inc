; File handling functions header file
;  By Peter Johnson, 1999
;
; $Id: filefunc.inc,v 1.4 2001/02/25 20:00:46 pete Exp $

	EXTERN _OpenFile
	EXTERN _CloseFile
	EXTERN _ReadFile
	EXTERN _WriteFile
	EXTERN _SeekFile

_OpenFile_arglen	equ	6
_CloseFile_arglen	equ	4
_ReadFile_arglen	equ	14
_WriteFile_arglen	equ	14
_SeekFile_arglen	equ	10
