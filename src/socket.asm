; Socket (TCP/IP, UDP/IP) functions
;  By Peter Johnson, 2001
;
; NOTE: The descriptions given here do not give full details about the
;  function's behavior under all circumstances.  See the library reference for
;  full documentation.
;
; $Id: socket.asm,v 1.9 2001/04/12 01:07:21 pete Exp $
%include "myC32.mac"
%include "constant.inc"
%include "dpmi_int.inc"
%include "dpmi_mem.inc"
%include "int_wrap.inc"

	BITS	32

; Passes control to the VDD for the specified function
%macro callvdd 1
	clc
	movzx	eax, word [VDD_Handle]
	or	eax, %{1}<<16
	db	0C4h, 0C4h, 058h, 002h
%endmacro

; VDD functions
SOCKET_INIT		equ	5001h
SOCKET_EXIT		equ	5002h
SOCKET_ACCEPT		equ	5003h
SOCKET_BIND		equ	5004h
SOCKET_CLOSE		equ	5005h
SOCKET_CONNECT		equ	5006h
SOCKET_GETPEERNAME	equ	5007h
SOCKET_GETSOCKNAME	equ	5008h
SOCKET_INETADDR		equ	5009h
SOCKET_INETNTOA		equ	500Ah
SOCKET_LISTEN		equ	500Bh
SOCKET_RECV		equ	500Ch
SOCKET_RECVFROM		equ	500Dh
SOCKET_SEND		equ	500Eh
SOCKET_SENDTO		equ	500Fh
SOCKET_SHUTDOWN		equ	5010h
SOCKET_CREATE		equ	5011h
SOCKET_GETHOSTBYADDR	equ	5012h
SOCKET_GETHOSTBYNAME	equ	5013h
SOCKET_GETHOSTNAME	equ	5014h
SOCKET_INSTALLCALLBACK	equ	5015h
SOCKET_REMOVECALLBACK	equ	5016h
SOCKET_ADDCALLBACK	equ	5017h
SOCKET_GETCALLBACKINFO	equ	5018h

; Maximum lengths
STRING_MAX		equ	256
HOSTENT_ALIASES_MAX	equ	16
HOSTENT_ADDRLIST_MAX	equ	16

	SECTION	.bss

Callback_Address	resd	1	; Application callback address
Callback_Int		resb	1	; Callback interrupt number
Multiplex_Handle	resw	1
VDD_Handle		resw	1
LastError		resd	1
NetAddr_static		resb	STRING_MAX
HostEnt_Name_static	resb	STRING_MAX
HostEnt_Aliases_static	resd	HOSTENT_ALIASES_MAX
HostEnt_AddrList_static	resd	HOSTENT_ADDRLIST_MAX
HostEnt_Aliases_data	resb	STRING_MAX*HOSTENT_ALIASES_MAX
HostEnt_AddrList_data	resd	HOSTENT_ADDRLIST_MAX

	SECTION .data

ALTMPX_Signature	db	'ECE291  ', 'EX291   ', 0
ALTMPX_MinVersion	equ	0100h
SOCKET_Version		equ	0100h
HostEnt_static	ISTRUC	HOSTENT
at HOSTENT.Name,	dd	HostEnt_Name_static
at HOSTENT.Aliases,	dd	HostEnt_Aliases_static
at HOSTENT.AddrList,	dd	HostEnt_AddrList_static
	IEND

; Initialization data passed to VDD.  Do NOT reorder.
VDD_InitData
	dw	SOCKET_Version
	dd	STRING_MAX
	dd	HOSTENT_ALIASES_MAX
	dd	HOSTENT_ADDRLIST_MAX
	dd	LastError
	dd	NetAddr_static
	dd	HostEnt_Name_static
	dd	HostEnt_Aliases_static
	dd	HostEnt_AddrList_static
	dd	HostEnt_Aliases_data
	dd	HostEnt_AddrList_data

	SECTION .text

;----------------------------------------
; bool InitSocket(void);
; Purpose: Initializes socket driver.
; Inputs:  None
; Outputs: Returns 1 on error, 0 otherwise.
;----------------------------------------
	GLOBAL	_InitSocket
_InitSocket
	push	esi
	push	edi
	push	es

	; Find if EX291 network driver is installed
	; Based on AMIS 0.92 code by Ralf Brown (Public Domain 1992, 1995)
	cld

	; First get a descriptor so we can map to the various signature strings
	xor	eax, eax		; [DPMI 0.9] Allocate LDT Descriptors
	mov	cx, 1			; Allocate 1 descriptor
	int	31h
	jc	near .error
	mov	bx, ax			; Save selector in bx

	; Set its limit to 64K
	mov	ax, 0008h		; [DPMI 0.9] Set Segment Limit
	xor	ecx, ecx
	mov	dx, 0FFFFh
	int	31h
	jc	near .errorfree

	xor	eax, eax		; AH=mpx #00h, AL=func 00h (instlchk)

.loop:
	mov	esi, eax		; Save ax
	mov	[DPMI_EAX], eax
	push	bx
	mov	bx, 2Dh			; check if INT 2D/AH=xx is in use
	call	DPMI_Int
	pop	bx
	cmp	byte [DPMI_EAX], 0FFh	; multiplex number in use?
	jne	.next

	; Check version
	cmp	word [DPMI_ECX], ALTMPX_MinVersion
	jb	.next

	; DX:DI holds segment:offset of signature string
	mov	ax, 0007h		; [DPMI 0.9] Set Segment Base Address
	movzx	edx, word [DPMI_EDX]	; convert segment to linear addr CX:DX
	shl	edx, 4
	mov	ecx, edx
	shr	ecx, 16
	int	31h
	jc	.errorfree

	mov	es, ebx			; reload selector just in case
	movzx	edi, word [DPMI_EDI]	; zero top half of edi for cmpsw
	mov	ecx, 16/2		; length of signature string
	mov	esi, ALTMPX_Signature
	rep	cmpsw			; did we get our signature?
	jz	.foundmpx		; yes, we found it

.next:
	inc	ah
	jnz	.loop
	; not installed
	jmp	short .errorfree

.foundmpx:
	; Free the descriptor
	mov	ax, 0001h		; [DPMI 0.9] Free LDT Descriptor
	int	31h

	; Get VDD handle
	mov	eax, [DPMI_EAX]
	mov	[Multiplex_Handle], ax
	mov	al, 10h			; [EX291 MPX] Get VDD Handle
	mov	[DPMI_EAX], ax
	push	bx
	mov	bx, 2Dh
	call	DPMI_Int
	pop	bx
	cmp	byte [DPMI_EAX], 1
	jne	.error
	mov	dx, [DPMI_EDX]
	mov	[VDD_Handle], dx

	; Initialize WinSock
	mov	ecx, VDD_InitData
	callvdd	SOCKET_INIT
	jc	.error

	xor	eax, eax
	jmp	short .exit

.errorfree:
	mov	ax, 0001h		; [DPMI 0.9] Free LDT Descriptor
	int	31h

.error:
	xor	eax, eax
	inc	eax

.exit:
	pop	es
	pop	edi
	pop	esi
	ret

;----------------------------------------
; void ExitSocket(void);
; Purpose: Shuts down socket driver.
; Inputs:  None
; Outputs: None
;----------------------------------------
	GLOBAL	_ExitSocket
_ExitSocket

	callvdd	SOCKET_EXIT
	ret

;----------------------------------------
; bool Socket_SetCallback(unsigned int HandlerAddress);
; Purpose: Sets up a callback for socket events.
; Inputs:  HandlerAddress, address of callback procedure, called as:
;           void Callback(unsigned int Socket, unsigned int Event),
;           where Event is the bitmask (as described in Socket_InstallCallback)
;           of the event triggering the callback.
; Outputs: Returns 1 on error, 0 otherwise.
; Notes:   To uninstall the callback, call this function with HandlerAddress=0.
;----------------------------------------
proc _Socket_SetCallback

.HandlerAddress	arg	4

	; Find out what mouse interrupt (IRQ) is on from multiplex driver
	; We'll override it and chain to the multiplex driver handler
	mov	ax, [Multiplex_Handle]
	mov	al, 11h			; [EX291 MPX] Get Socket Interrupt
	mov	[DPMI_EAX], ax
	mov	bx, 2Dh
	call	DPMI_Int
	cmp	byte [DPMI_EAX], 1	; Not implemented!
	jne	near .error

	movzx	edx, byte [DPMI_EDX]	; Grab interrupt value
	mov	[Callback_Int], dl	; and save

	mov	ecx, [Callback_Address]	; save old callback address
	mov	eax, [ebp+.HandlerAddress]
	mov	[Callback_Address], eax
	test	eax, eax		; 0 callback address -> deinstall
	jz	near .deinstall

	test	ecx, ecx		; old callback present, just update adr
	jnz	near .ok

	; Install our interrupt handler on mouse interrupt (IRQ)
	invoke	_LockArea, ds, dword Callback_Address, dword 4
	invoke	_LockArea, ds, dword Callback_Int, dword 1
	invoke	_LockArea, cs, dword Socket_InterruptHandler, dword Socket_InterruptHandler_end-Socket_InterruptHandler
	movzx	edx, byte [DPMI_EDX]
	invoke	_Install_Int, edx, dword Socket_InterruptHandler
	test	eax, eax
	jnz	.error

	movzx	edx, byte [Callback_Int]
	callvdd	SOCKET_INSTALLCALLBACK
	test	eax, eax
	jz	.end

	mov	dword [Callback_Address], 0
	invoke	_Remove_Int, edx
	jmp	short .error

.deinstall:
	callvdd	SOCKET_REMOVECALLBACK
	invoke	_Remove_Int, edx
	xor	eax, eax
	jmp	short .end

.ok:
	xor	eax, eax
	ret
.error:
	xor	eax, eax
	inc	eax
.end:
	ret
endproc

;----------------------------------------
; bool Socket_AddCallback(unsigned int Socket, unsigned int EventMask);
; Purpose: Requests event notification for a socket.
; Inputs:  Socket, the socket to get notification for.
;          EventMask, bitmask designating which events to trigger the
;           callback for on that socket:
;           Bit 0 = READ: ready for reading
;           Bit 1 = WRITE: ready for writing
;           Bit 2 = OOB: received out-of-band data
;           Bit 3 = ACCEPT: incoming connection
;           Bit 4 = CONNECT: completed connection
;           Bit 5 = CLOSE: socket closed
; Outputs: Returns 1 on error, 0 otherwise.
; Notes:   If called more than once for a particular socket, only the last
;          call's eventmask is active.  To disable the callback for a single
;          socket, set EventMask=0.
;----------------------------------------
proc _Socket_AddCallback

.Socket		arg	4
.EventMask	arg	4

	callvdd	SOCKET_ADDCALLBACK
	ret
endproc

Socket_InterruptHandler

	mov	eax, [Callback_Address]
	test	eax, eax
	jz	.chain

	callvdd	SOCKET_GETCALLBACKINFO
	test	eax, eax
	jnz	.chain

	push	edx		; Event
	push	ecx		; Socket
	call	dword [Callback_Address]	; call hander function
	add	esp, byte 8	; clear stack

.done:
	; ack IRQ and don't chain if we did a callback
	mov	al, 20h
	cmp	byte [Callback_Int], 50h
	jb	.lowirq
	out	0A0h, al
.lowirq:
	out	20h, al

	xor	eax, eax
	ret

.chain:
	mov	eax, 1		; chain to the old interrupt (back to driver)
	ret
Socket_InterruptHandler_end

;----------------------------------------
; unsigned int Socket_accept(unsigned int Socket, SOCKADDR *Name);
; Purpose: Accepts a connection on a socket.
; Inputs:  Socket, a socket which is listening for connections after a
;           Socket_Listen().
;          Name, an optional (may be 0) pointer to a structure which receives
;           the network address of the connecting entity.
; Outputs: Returns the socket for the accepted connection, or 0FFFFFFFFh (-1)
;           if an error occurs.
;----------------------------------------
proc _Socket_accept

.Socket		arg	4
.Name		arg	4

	callvdd	SOCKET_ACCEPT
	ret
endproc

;----------------------------------------
; bool Socket_bind(unsigned int Socket, SOCKADDR *Name);
; Purpose: Associates a local address with a socket.
; Inputs:  Socket, an unbound socket.
;          Name, the structure containing the network address to assign to the
;           socket.
; Outputs: Returns 1 on error, 0 otherwise.
;----------------------------------------
proc _Socket_bind

.Socket		arg	4
.Name		arg	4

	callvdd	SOCKET_BIND
	ret
endproc

;----------------------------------------
; bool Socket_close(unsigned int Socket);
; Purpose: Closes a socket.
; Inputs:  Socket, the socket to close.
; Outputs: Returns 1 on error, 0 otherwise.
;----------------------------------------
proc _Socket_close

.Socket		arg	4

	callvdd	SOCKET_CLOSE
	ret
endproc

;----------------------------------------
; bool Socket_connect(unsigned int Socket, SOCKADDR *Name);
; Purpose: Establishes a connection to a peer.
; Inputs:  Socket, an unconnected socket.
;          Name, the structure containing the network address of the peer to
;           which the socket is to be connected.
; Outputs: Returns 1 on error, 0 otherwise.
;----------------------------------------
proc _Socket_connect

.Socket		arg	4
.Name		arg	4

	callvdd	SOCKET_CONNECT
	ret
endproc

;----------------------------------------
; bool Socket_getpeername(unsigned int Socket, SOCKADDR *Name);
; Purpose: Gets the address of the peer to which a socket is connected.
; Inputs:  Socket, a connected socket.
;          Name, the structure which is to receive the network address of the
;           peer.
; Outputs: Returns 1 on error, 0 otherwise.
;----------------------------------------
proc _Socket_getpeername

.Socket		arg	4
.Name		arg	4

	callvdd	SOCKET_GETPEERNAME
	ret
endproc

;----------------------------------------
; bool Socket_getsockname(unsigned int Socket, SOCKADDR *Name);
; Purpose: Gets the local name for a socket.
; Inputs:  Socket, a bound socket.
;          Name, the structure which is to receive the network address of the
;           socket.
; Outputs: Returns 1 on error, 0 otherwise.
;----------------------------------------
proc _Socket_getsockname

.Socket		arg	4
.Name		arg	4

	callvdd	SOCKET_GETSOCKNAME
	ret
endproc

;----------------------------------------
; unsigned int Socket_ntohl(unsigned int NetVal);
; Purpose: Converts an unsigned int from network to host byte order.
; Inputs:  NetVal, a 32-bit number in network byte order.
; Outputs: Returns the NetVal in host byte order.
;----------------------------------------
	GLOBAL	_Socket_ntohl
_Socket_ntohl		; same as _Socket_htonl, fall through

;----------------------------------------
; unsigned int Socket_htonl(unsigned int HostVal);
; Purpose: Converts an unsigned int from host to network byte order.
; Inputs:  HostVal, a 32-bit number in host byte order.
; Outputs: Returns the HostVal in network byte order.
;----------------------------------------
proc _Socket_htonl

.HostVal	arg	4

	mov	eax, [ebp+.HostVal]
	bswap	eax

	ret
endproc

;----------------------------------------
; unsigned short Socket_ntohs(unsigned short NetVal);
; Purpose: Converts an unsigned short from network to host byte order.
; Inputs:  NetVal, a 16-bit number in network byte order.
; Outputs: Returns the NetVal in host byte order.
;----------------------------------------
	GLOBAL	_Socket_ntohs
_Socket_ntohs		; same as _Socket_htons, fall through

;----------------------------------------
; unsigned short Socket_htons(unsigned short HostVal);
; Purpose: Converts an unsigned short from host to network byte order.
; Inputs:  HostVal, a 16-bit number in host byte order.
; Outputs: Returns the HostVal in network byte order.
;----------------------------------------
proc _Socket_htons

.HostVal	arg	2

	mov	ax, [ebp+.HostVal]
	xchg	al, ah
	ret
endproc

;----------------------------------------
; unsigned int Socket_inet_addr(char *DottedAddress);
; Purpose: Converts a string containing a dotted address into a 32-bit address.
; Inputs:  DottedAddress, string representing a number expressed in the
;           Internet standard "." notation.
; Outputs: Returns the Internet address corresponding to DottedAddress in
;           network byte order.  Returns 0 if DottedAddress is invalid.
;----------------------------------------
proc _Socket_inet_addr

.DottedAddress	arg	4

	callvdd	SOCKET_INETADDR
	ret
endproc

;----------------------------------------
; char *Socket_inet_ntoa(unsigned int Address);
; Purpose: Converts a 32-bit network address into a string in dotted format.
; Inputs:  Address, Internet address to convert.
; Outputs: Returns pointer to a static buffer containing the network address in
;           standard "." notation.  This buffer is overwritten on subsequent
;           calls to this function.
;----------------------------------------
proc _Socket_inet_ntoa

.Address	arg	4

	callvdd	SOCKET_INETNTOA
	mov	eax, NetAddr_static
	ret
endproc

;----------------------------------------
; bool Socket_listen(unsigned int Socket, int BackLog);
; Purpose: Establishes a socket to listen for incoming connections.
; Inputs:  Socket, a bound, unconnected socket.
;          BackLog, the maximum length to which the queue of pending
;           connections may grow.
; Outputs: Returns 1 on error, 0 otherwise.
; Notes:   BackLog is silently limited to between 1 and 5.
;----------------------------------------
proc _Socket_listen

.Socket		arg	4
.BackLog	arg	4

	callvdd	SOCKET_LISTEN
	ret
endproc

;----------------------------------------
; int Socket_recv(unsigned int Socket, unsigned char *Buf, int MaxLen,
;  unsigned int Flags);
; Purpose: Receives data from a connected socket.
; Inputs:  Socket, a connected socket.
;          Buf, the buffer for the incoming data.
;          MaxLen, the maximum number of bytes to receive.
;          Flags, bitmask specifying special operation for the function:
;           Bit 0 = PEEK: peek at the incoming data.  The data is copied into
;            the buffer but is not removed from the input queue.
;           Bit 1 = OOB: get out-of-band data.
; Outputs: Returns the number of bytes received.  Returns 0 if the connection
;          has been closed, and -1 on error.
;----------------------------------------
proc _Socket_recv

.Socket		arg	4
.Buf		arg	4
.MaxLen		arg	4
.Flags		arg	4

	callvdd	SOCKET_RECV
	ret
endproc

;----------------------------------------
; int Socket_recvfrom(unsigned int Socket, unsigned char *Buf, int MaxLen,
;  unsigned int Flags, SOCKADDR *From);
; Purpose: Receives a datagram and stores the source address.
; Inputs:  Socket, a bound socket.
;          Buf, the buffer for the incoming data.
;          MaxLen, the maximum number of bytes to receive.
;          Flags, bitmask specifying special operation for the function:
;           Bit 0 = PEEK: peek at the incoming data.  The data is copied into
;            the buffer but is not removed from the input queue.
;           Bit 1 = OOB: get out-of-band data.
;          From, the structure which is to receive the source network address.
;           Optional (may be 0).
; Outputs: Returns the number of bytes received.  Returns 0 if the connection
;           has been closed, and -1 on error.
;----------------------------------------
proc _Socket_recvfrom

.Socket		arg	4
.Buf		arg	4
.MaxLen		arg	4
.Flags		arg	4
.From		arg	4

	callvdd	SOCKET_RECVFROM
	ret
endproc

;----------------------------------------
; int Socket_send(unsigned int Socket, unsigned char *Buf, int Len,
;  unsigned int Flags);
; Purpose: Transmits data on a connected socket.
; Inputs:  Socket, a connected socket.
;          Buf, the buffer containing the data to be transmitted.
;          Len, the amount of data to transmit.
;          Flags, bitmask specifying special operation for the function:
;           Bit 0 = OOB: send out-of-band data (stream sockets only).
; Outputs: Returns the number of bytes actually transmitted, or -1 on error.
;----------------------------------------
proc _Socket_send

.Socket		arg	4
.Buf		arg	4
.Len		arg	4
.Flags		arg	4

	callvdd	SOCKET_SEND
	ret
endproc

;----------------------------------------
; int Socket_sendto(unsigned int Socket, unsigned char *Buf, int Len,
;  unsigned int Flags, SOCKADDR *To);
; Purpose: Sends a datagram to a specific destination.
; Inputs:  Socket, a socket.
;          Buf, the buffer containing the data to be transmitted.
;          Len, the amount of data to transmit.
;          Flags, bitmask specifying special operation for the function:
;           Bit 0 = OOB: send out-of-band data (stream sockets only).
;          To, the structure containing the network address of the destination.
; Outputs: Returns the number of bytes actually transmitted, or -1 on error.
;----------------------------------------
proc _Socket_sendto

.Socket		arg	4
.Buf		arg	4
.Len		arg	4
.Flags		arg	4
.To		arg	4

	callvdd	SOCKET_SENDTO
	ret
endproc

;----------------------------------------
; bool Socket_shutdown(unsigned int Socket, unsigned int Flags);
; Purpose: Disables sends and/or receives on a socket.
; Inputs:  Socket, a socket.
;          Flags, a bitmask specifying what to disable:
;           Bit 0 = subsequent receives on the socket will be disallowed.
;           Bit 1 = subsequent sends will be disallowed (a FIN is sent for TCP
;            stream sockets).
; Outputs: Returns 1 on error, 0 otherwise.
; Notes:   Flags=0 has no effect.  Flags=3 (both bits set) disables both sends
;           and receives; however, the socket will not be closed and resources
;           used by the socket will not be freed until Socket_close() is called.
;----------------------------------------
proc _Socket_shutdown

.Socket		arg	4
.Flags		arg	4

	mov	eax, [ebp+.Flags]
	test	eax, eax
	jz	.done

	callvdd	SOCKET_SHUTDOWN
.done:
	ret
endproc

;----------------------------------------
; unsigned int Socket_create(int Type);
; Purpose: Creates a socket.
; Inputs:  Type, type of socket to create:
;           1 = stream socket (TCP)
;           2 = datagram socket (UDP)
; Outputs: Returns socket, or 0FFFFFFFFh (-1) if an error occurs.
;----------------------------------------
proc _Socket_create

.Type		arg	4

	callvdd	SOCKET_CREATE
	ret
endproc

;----------------------------------------
; HOSTENT *Socket_gethostbyaddr(unsigned int Address);
; Purpose: Gets host information corresponding to an address.
; Inputs:  Address, the network address to retreive information about, in
;           network byte order.
; Outputs: Returns a pointer to a static HOSTENT structure.  This buffer is
;           overwritten on subsequent calls to this function.
;----------------------------------------
proc _Socket_gethostbyaddr

.Address	arg	4

	callvdd	SOCKET_GETHOSTBYADDR
	test	eax, eax
	jz	.done
	mov	eax, HostEnt_static
.done:
	ret
endproc

;----------------------------------------
; HOSTENT *Socket_gethostbyname(char *Name);
; Purpose: Gets host information corresponding to a hostname.
; Inputs:  Name, a pointer to the name of the host.
; Outputs: Returns a pointer to a static HOSTENT structure.  This buffer is
;           overwritten on subsequent calls to this function.
;----------------------------------------
proc _Socket_gethostbyname

.Name		arg	4

	callvdd	SOCKET_GETHOSTBYNAME
	test	eax, eax
	jz	.done
	mov	eax, HostEnt_static
.done:
	ret
endproc

;----------------------------------------
; bool Socket_gethostname(char *Name, int NameLen);
; Purpose: Gets the standard host name for the local machine.
; Inputs:  Name, a pointer to a buffer that will receive the host name.
;          NameLen, the length of the buffer.
; Outputs: Returns 1 on error, otherwise 0.
;          Name filled with the host name of the local machine.
;----------------------------------------
proc _Socket_gethostname

.Name		arg	4
.NameLen	arg	4

	callvdd	SOCKET_GETHOSTNAME
	ret
endproc

;----------------------------------------
; int Socket_GetLastError(void);
; Purpose: Get the error status for the last operation which failed.
; Inputs:  None
; Outputs: Returns the error code.
;----------------------------------------
	GLOBAL	_Socket_GetLastError
_Socket_GetLastError

	mov	eax, [LastError]
	ret

