; DPMI Memory Interface header file
;  By Peter Johnson, 1999
;
; $Id: dpmi_mem.inc,v 1.4 2000/12/14 07:52:21 pete Exp $

	EXTERN _AllocMem
	EXTERN _FreeMem
        EXTERN _GetPhysicalMapping
        EXTERN _FreePhysicalMapping
        EXTERN _LockArea

_AllocMem_arglen		equ	4
_FreeMem_arglen			equ	2
_GetPhysicalMapping_arglen      equ     16
_FreePhysicalMapping_arglen     equ     8
_LockArea_arglen                equ     10
