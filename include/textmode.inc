; Text Mode (80x25x16) header file
;  By Peter Johnson, 1999

        EXTERN _TextSetPage
	EXTERN _TextClearScreen
	EXTERN _TextWriteChar
	EXTERN _TextWriteString

_TextSetPage_arglen             equ     2
_TextWriteChar_arglen		equ	8
_TextWriteString_arglen		equ	10
