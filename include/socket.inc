; Socket (TCP/IP, UDP/IP) functions header file
;  By Peter Johnson, 2001
;
; $Id: socket.inc,v 1.2 2001/04/07 08:01:45 pete Exp $

	EXTERN _InitSocket
	EXTERN _ExitSocket
	EXTERN _Socket_InstallCallback
	EXTERN _Socket_accept
	EXTERN _Socket_bind
	EXTERN _Socket_close
	EXTERN _Socket_connect
	EXTERN _Socket_getpeername
	EXTERN _Socket_getsockname
	EXTERN _Socket_ntohl
	EXTERN _Socket_htonl
	EXTERN _Socket_ntohs
	EXTERN _Socket_htons
	EXTERN _Socket_inet_addr
	EXTERN _Socket_inet_ntoa
	EXTERN _Socket_listen
	EXTERN _Socket_recv
	EXTERN _Socket_recvfrom
	EXTERN _Socket_send
	EXTERN _Socket_sendto
	EXTERN _Socket_shutdown
	EXTERN _Socket_create
	EXTERN _Socket_gethostbyaddr
	EXTERN _Socket_gethostbyname
	EXTERN _Socket_gethostname
	EXTERN _Socket_GetLastError

_Socket_InstallCallback_arglen	equ	12
_Socket_accept_arglen		equ	8
_Socket_bind_arglen		equ	8
_Socket_close_arglen		equ	4
_Socket_connect_arglen		equ	8
_Socket_getpeername_arglen	equ	8
_Socket_getsockname_arglen	equ	8
_Socket_ntohl_arglen		equ	4
_Socket_htonl_arglen		equ	4
_Socket_ntohs_arglen		equ	2
_Socket_htons_arglen		equ	2
_Socket_inet_addr_arglen	equ	4
_Socket_inet_ntoa_arglen	equ	4
_Socket_listen_arglen		equ	8
_Socket_recv_arglen		equ	16
_Socket_recvfrom_arglen		equ	20
_Socket_send_arglen		equ	16
_Socket_sendto_arglen		equ	20
_Socket_shutdown_arglen		equ	8
_Socket_create_arglen		equ	4
_Socket_gethostbyaddr_arglen	equ	4
_Socket_gethostbyname_arglen	equ	4
_Socket_gethostname_arglen	equ	8
