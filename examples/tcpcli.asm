; A simple TCP client (connects to tcpsrv example)
;  By Peter Johnson, 2001
;
; $Id: tcpcli.asm,v 1.2 2001/04/11 21:10:23 pete Exp $
%include "lib291.inc"

        BITS 32


        GLOBAL _main

SECTION .data

_message	db	"Hello World!",13,10,0	; message to send to server
message_len	equ	$-_message
_port		dw	12345			; port number (host order)

SECTION .bss

_socket		resd	1
_address	resb	SOCKADDR_size	; SOCKADDR structure
buf_len		equ	16*1024
_buf		resb	buf_len

SECTION .text

proc _main

.argc	arg	4
.argv	arg	4

        call    _LibInit

	; Initialize the socket library
	call	_InitSocket
	test	eax, eax
	jnz	near .done

	; Create a socket
	invoke	_Socket_create, dword SOCK_STREAM
	test	eax, eax
	js	near .exit
	mov	[_socket], eax

	; Set up address structure:
	;  First the port
	invoke	_Socket_htons, word [_port]
	mov	[_address+SOCKADDR.Port], ax
	;  Then the address: if commandline argument, connect to that hostname,
	;   otherwise connect to localhost (lookback address)
	cmp	dword [ebp+.argc], 1
	jbe	.uselocalhost

	mov	eax, [ebp+.argv]		; Get pointer to argv
	invoke	_Socket_gethostbyname, dword [eax+4]	; use argv[1]
	test	eax, eax
	jz	near .close
	mov	eax, [eax+HOSTENT.AddrList]	; Get pointer to address list
	mov	eax, [eax]			; Get pointer to first address
	test	eax, eax			; Valid pointer?
	jz	near .close
	mov	eax, [eax]			; Get first address

	jmp	short .doconnect
.uselocalhost:
	invoke	_Socket_htonl, dword INADDR_LOOPBACK

.doconnect:
	mov	[_address+SOCKADDR.Address], eax

	; Connect to the remote host
	invoke	_Socket_connect, dword [_socket], dword _address
	test	eax, eax
	jnz	near .close

	; Send a little message (the server will print it out)
	invoke	_Socket_send, dword [_socket], dword _message, dword message_len, dword 0
	test	eax, eax
	js	.close		; error on send
.close:
	invoke	_Socket_close, dword [_socket]
.exit:
	call	_ExitSocket
.done:
        call    _LibExit
        ret
endproc

