; A simple UDP server (udpcli connects to this).  Runs until a key is pressed
;  By Peter Johnson, 2001
;
; $Id: udpsrv.asm,v 1.1 2001/04/12 02:03:18 pete Exp $
%include "lib291.inc"

        BITS 32

        GLOBAL _main

SECTION .data

_port		dw	12345		; port number (host order)

SECTION .bss

_socket		resd	1
_gotdatagram	resb	1
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

	; Create a datagram socket
	invoke	_Socket_create, dword SOCK_DGRAM
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

	; Install a callback for incoming datagrams on the socket
	invoke	_LockArea, ds, dword _gotdatagram, dword 1
	invoke	_LockArea, cs, dword _SocketHandler, dword _SocketHandler_end-_SocketHandler
	invoke	_Socket_SetCallback, dword _SocketHandler
	test	eax, eax
	jnz	near .close

	invoke	_Socket_AddCallback, dword [_socket], dword SOCKEVENT_READ
	test	eax, eax
	jnz	near .close

.notdone:
	; loop until keypress (exit) or incoming datagram (process it)
	mov	ah, 1		; [BIOS] check for keystroke
	int	16h
	jnz	.quit

	cmp	byte [_gotdatagram], 1
	je	.gotconn

	jmp	short .notdone

.gotconn:
	; clear data ready flag
	mov	byte [_gotdatagram], 0

	; Get the datagram; we don't care about the source address
	invoke	_Socket_recvfrom, dword [_socket], dword _buf, dword buf_len-1, dword 0, dword 0
	test	eax, eax
	js	.notdone	; error on receive
	jz	.notdone	; no data?

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

	; make sure we're getting an event on the socket we're interested in!
	mov	eax, [ebp+.Socket]
	cmp	eax, [_socket]
	jne	.done

	mov	eax, [ebp+.Event]
	cmp	eax, SOCKEVENT_READ
	jne	.done

	mov	byte [_gotdatagram], 1
.done:
	ret
endproc
_SocketHandler_end
