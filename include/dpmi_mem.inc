; DPMI Memory Interface header file
;  By Peter Johnson, 1999
;
; $Id: dpmi_mem.inc,v 1.5 2001/03/16 22:44:07 pete Exp $

	EXTERN _AllocSelector
	EXTERN _FreeSelector
        EXTERN _GetPhysicalMapping
        EXTERN _FreePhysicalMapping
        EXTERN _LockArea

_AllocSelector_arglen		equ	4
_FreeSelector_arglen		equ	2
_GetPhysicalMapping_arglen      equ     16
_FreePhysicalMapping_arglen     equ     8
_LockArea_arglen                equ     10
