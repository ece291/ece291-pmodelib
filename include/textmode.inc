; Text Mode (80x25x16) header file
;  By Peter Johnson, 1999
;
; $Id: textmode.inc,v 1.3 2000/12/14 07:52:21 pete Exp $

        EXTERN _SetModeC80
        EXTERN _TextSetPage
	EXTERN _TextClearScreen
	EXTERN _TextWriteChar
	EXTERN _TextWriteString

_TextSetPage_arglen             equ     2
_TextWriteChar_arglen		equ	8
_TextWriteString_arglen		equ	10
