; DPMI Memory Interface header file
;  By Peter Johnson, 1999-2001
;
; $Id: dpmi_mem.inc,v 1.6 2001/03/16 23:52:18 pete Exp $

	EXTERN _AllocMem
	EXTERN _AllocSelector
	EXTERN _FreeSelector
        EXTERN _GetPhysicalMapping
        EXTERN _FreePhysicalMapping
        EXTERN _LockArea

_AllocMem_arglen		equ	4
_AllocSelector_arglen		equ	4
_FreeSelector_arglen		equ	2
_GetPhysicalMapping_arglen      equ     16
_FreePhysicalMapping_arglen     equ     8
_LockArea_arglen                equ     10
