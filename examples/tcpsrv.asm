; A simple TCP server (tcpcli connects to this).  Runs until a key is pressed
;  By Peter Johnson, 2001
;
; $Id: tcpsrv.asm,v 1.1 2001/04/10 09:08:53 pete Exp $
%include "lib291.inc"

        BITS 32

        GLOBAL _main

SECTION .data

_port		dw	12345			; port number (host order)

SECTION .bss

_socket		resd	1		; listening socket
_connsocket	resd	1		; connection socket
_gotaccept	resb	1
_address	resb	SOCKADDR_size	; SOCKADDR structure
buf_len		equ	16*1024
_buf		resb	buf_len

SECTION .text

_main:
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
	;  Then the address - INADDR_ANY means any address (don't care)
	mov	dword [_address+SOCKADDR.Address], INADDR_ANY

	; Bind socket to that address and port
	invoke	_Socket_bind, dword [_socket], dword _address
	test	eax, eax
	jnz	near .close

	; Install a callback for incoming connections on the socket
	invoke	_LockArea, ds, dword _gotaccept, dword 1
	invoke	_LockArea, cs, dword _SocketHandler, dword _SocketHandler_end-_SocketHandler
	invoke	_Socket_SetCallback, dword _SocketHandler
	test	eax, eax
	jnz	near .close

	invoke	_Socket_AddCallback, dword [_socket], dword SOCKEVENT_ACCEPT
	test	eax, eax
	jnz	near .close

	; Start accepting connections
	invoke	_Socket_listen, dword [_socket], dword 5
	test	eax, eax
	jnz	near .deinstall

.notdone:
	; loop until keypress (exit) or new connection (process it)
	mov	ah, 1		; [BIOS] check for keystroke
	int	16h
	jnz	.quit

	cmp	byte [_gotaccept], 1
	je	.gotconn

	jmp	short .notdone

.gotconn:
	; accept the connection: returns a socket for the connection
	; we don't care about the remote address, so don't get it
	; this blocks (waits for a connection) unless one is waiting for us
	invoke	_Socket_accept, dword [_socket], dword 0
	test	eax, eax
	js	.notdone		; didn't accept successfully?
	mov	[_connsocket], eax	; save connection socket

	; clear accept ready flag
	mov	byte [_gotaccept], 0

	; Get bytes until connection closed (no data remaining)
.getmore:
	invoke	_Socket_recv, dword [_connsocket], dword _buf, dword buf_len-1, dword 0
	test	eax, eax
	js	.closeconn	; error on receive
	jz	.closeconn	; no data left

	; Print out the data
	mov	ecx, eax
	xor	ebx, ebx
.printloop:
	mov	ah, 06h
	mov	dl, [_buf+ebx]
	int	21h
	inc	ebx
	cmp	ebx, ecx
	jb	.printloop

	jmp	short .getmore

.closeconn:
	; close the connection socket
	invoke	_Socket_close, dword [_connsocket]

	jmp	short .notdone

.quit:
	; grab the keypress so it doesn't print out after the program exits
	xor	eax, eax
	int	16h
.deinstall:
	invoke	_Socket_SetCallback, dword 0
.close:
	invoke	_Socket_close, dword [_socket]
.exit:
	call	_ExitSocket
.done:
        call    _LibExit
        ret
        
proc _SocketHandler
.Socket		arg	4
.Event		arg	4

	; make sure we're getting an accept on the socket we're interested in!
	mov	eax, [ebp+.Socket]
	cmp	eax, [_socket]
	jne	.done

	mov	eax, [ebp+.Event]
	cmp	eax, SOCKEVENT_ACCEPT
	jne	.done

	mov	byte [_gotaccept], 1
.done:
	ret
endproc
_SocketHandler_end
