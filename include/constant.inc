; General constants
;  By Peter Johnson, 2001
;
; $Id: constant.inc,v 1.7 2001/12/14 19:31:20 pete Exp $

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
;  Protocols:
IPPROTO_IP		equ	0
IPPROTO_ICMP		equ	1
IPPROTO_TCP		equ	6
IPPROTO_UDP		equ	17
SOL_SOCKET		equ	0FFFFh
;  Options
SOCKOPT_DEBUG		equ	0001h
SOCKOPT_ACCEPTCONN	equ	0002h
SOCKOPT_REUSEADDR	equ	0004h
SOCKOPT_KEEPALIVE	equ	0008h
SOCKOPT_DONTROUTE	equ	0010h
SOCKOPT_BROADCAST	equ	0020h
SOCKOPT_USELOOPBACK	equ	0040h
SOCKOPT_LINGER		equ	0080h
SOCKOPT_DONTLINGER	equ	~0080h
SOCKOPT_OOBINLINE	equ	0100h
SOCKOPT_SNDBUF		equ	1001h
SOCKOPT_RCVBUF		equ	1002h
SOCKOPT_SNDLOWAT	equ	1003h
SOCKOPT_RCVLOWAT	equ	1004h
SOCKOPT_SNDTIMEOUT	equ	1005h
SOCKOPT_RCVTIMEOUT	equ	1006h
SOCKOPT_ERROR		equ	1007h
SOCKOPT_TYPE		equ	1008h
TCP_NODELAY		equ	0001h

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

