; Test program to get a webpage from a TCP server
;  By Peter Johnson, 2001
;
; $Id: tcpweb.asm,v 1.3 2001/04/11 21:09:24 pete Exp $
%include "lib291.inc"

        BITS 32


        GLOBAL _main

SECTION .data

_website	db	"courses.ece.uiuc.edu",0
_getstring	db	"GET /ece291/",13,10,0
getstring_len	equ	$-_getstring

SECTION .bss

_socket		resd	1
_address	resb	SOCKADDR_size	; SOCKADDR structure
recvbuf_len	equ	16*1024
_recvbuf	resb	recvbuf_len

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
	invoke	_Socket_htons, word 80		; HTTP port
	mov	[_address+SOCKADDR.Port], ax
	;  Then the address
	invoke	_Socket_gethostbyname, dword _website
	test	eax, eax
	jz	near .close
	mov	eax, [eax+HOSTENT.AddrList]	; Get pointer to address list
	mov	eax, [eax]			; Get pointer to first address
	test	eax, eax			; Valid pointer?
	jz	near .close
	mov	eax, [eax]			; Get first address
	mov	[_address+SOCKADDR.Address], eax

	; Connect to the remote host
	invoke	_Socket_connect, dword [_socket], dword _address
	test	eax, eax
	jnz	near .close

	; Send GET string
	invoke	_Socket_send, dword [_socket], dword _getstring, dword getstring_len, dword 0
	test	eax, eax
	js	.close

	; Receive data until no data left
.getmore:
	invoke	_Socket_recv, dword [_socket], dword _recvbuf, dword recvbuf_len-1, dword 0
	test	eax, eax
	js	.close
	jz	.close

	; Print out the data
	mov	ecx, eax
	xor	ebx, ebx
.printloop:
	mov	ah, 06h
	mov	dl, [_recvbuf+ebx]
	int	21h
	inc	ebx
	cmp	ebx, ecx
	jb	.printloop

	jmp	short .getmore
.close:
	invoke	_Socket_close, dword [_socket]
.exit:
	call	_ExitSocket
.done:
        call    _LibExit
        ret
        

