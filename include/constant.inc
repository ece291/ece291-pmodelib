; General constants
;  By Peter Johnson, 2001
;
; $Id: constant.inc,v 1.6 2001/04/07 08:02:14 pete Exp $

; Socket constants:
;  Addresses:
INADDR_ANY		equ	0
INADDR_LOOPBACK		equ	7F000001h
INADDR_BROADCAST	equ	0FFFFFFFFh
INADDR_NONE		equ	0FFFFFFFFh
;  Types:
SOCK_STREAM		equ	1
SOCK_DGRAM		equ	2
;  Events:
SOCKEVENT_READ		equ	01h
SOCKEVENT_WRITE		equ	02h
SOCKEVENT_OOB		equ	04h
SOCKEVENT_ACCEPT	equ	08h
SOCKEVENT_CONNECT	equ	10h
SOCKEVENT_CLOSE		equ	20h

; Socket structures
	STRUC	SOCKADDR
.Port		resw	1	; Port number
.Address	resd	1	; Network address
	ENDSTRUC

	STRUC	HOSTENT
.Name		resd	1	; Pointer to official name of host
.Aliases	resd	1	; Pointer to 0-terminated array of pointers to
				;  alias names
.AddrList	resd	1	; Pointer to 0-terminated array of pointers to
				;  addresses
	ENDSTRUC

