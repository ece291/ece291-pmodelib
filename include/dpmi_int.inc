; DPMI Interrupt Interface header file
;  By Peter Johnson, 1999
;
; $Id: dpmi_int.inc,v 1.3 2000/12/14 07:52:21 pete Exp $

	EXTERN DPMI_Int
	EXTERN _AllocTransferBuf
	EXTERN _FreeTransferBuf

	EXTERN	DPMI_Regs
	EXTERN	DPMI_EDI
	EXTERN	DPMI_ESI
	EXTERN	DPMI_EBP
	EXTERN	DPMI_EBX
	EXTERN	DPMI_EDX
	EXTERN	DPMI_ECX
	EXTERN	DPMI_EAX
	EXTERN	DPMI_FLAGS
	EXTERN	DPMI_ES
	EXTERN	DPMI_DS
	EXTERN	DPMI_FS
	EXTERN	DPMI_GS
	EXTERN	DPMI_SP
	EXTERN	DPMI_SS

	EXTERN	_Transfer_Buf
	EXTERN	_Transfer_Buf_Seg
	EXTERN	_Transfer_Buf_Size

DPMI_EDI_off    equ     00h
DPMI_ESI_off    equ     04h
DPMI_EBP_off    equ     08h
;DPMI_RES0_off  equ     0Ch
DPMI_EBX_off    equ     10h
DPMI_EDX_off    equ     14h
DPMI_ECX_off    equ     18h
DPMI_EAX_off    equ     1Ch
DPMI_FLAGS_off  equ     20h
DPMI_ES_off     equ     22h
DPMI_DS_off     equ     24h
DPMI_FS_off     equ     26h
DPMI_GS_off     equ     28h
DPMI_IP_off     equ     2Ah
DPMI_CS_off     equ     2Ch
DPMI_SP_off     equ     2Eh
DPMI_SS_off     equ     30h
