; Generic loader code for DJGPP/NASM
;  By Peter Johnson, 1999
;
; Program entry point, allocates descriptor to video RAM
%include "myC32.mac"

	BITS 32

	GLOBAL _main
        GLOBAL _djgpp_ds
        GLOBAL _djgpp_es
        GLOBAL _djgpp_fs
        GLOBAL _djgpp_gs
	GLOBAL _viddescriptor
        GLOBAL _textdescriptor

	EXTERN _mymain

        EXTERN ServerIPAddress
        EXTERN ServerUDPPort

        EXTERN _gethostbyname
        EXTERN _atoi
_gethostbyname_arglen   equ     4
_atoi_arglen            equ     4

        SECTION .bss

_djgpp_ds       resw    1               ; Saved selectors from djgpp startup
_djgpp_es       resw    1
_djgpp_fs       resw    1
_djgpp_gs       resw    1

	SECTION .data

_viddescriptor	dw	0h		; 16-bit storage for video descriptor
_textdescriptor dw      0h              ; 16-bit storage for text descriptor

	SECTION .text

;----------------------------------------
; main function
;----------------------------------------
proc _main

%$argc  arg     4
%$argv  arg     4

        ; Save DJGPP startup selectors
        mov     [_djgpp_ds], ds
        mov     [_djgpp_es], es
        mov     [_djgpp_fs], fs
        mov     [_djgpp_gs], gs
	
        ; Parse command line, if any.
        cmp     dword [ebp+%$argc], 3
        jne     .NoCommandLine

	mov	eax, [ebp+%$argv]
	add	eax, 4                  ; argv[1] = IP address
	mov	edx, [eax]
        invoke  _gethostbyname, dword edx
        test    eax, eax
        jz      .NoCommandLine          ; Invalid IP
	; haddress = ((struct in_addr *) hent->h_addr)->s_addr;
	mov	edx, [eax+12]
	mov	eax, [edx]
	mov	edx, [eax]
        mov     [ServerIPAddress], edx

	mov	eax, [ebp+%$argv]
        add     eax, 8                  ; argv[2] = Port
	mov	edx, [eax]
        invoke  _atoi, dword edx
        mov     [ServerUDPPort], eax

.NoCommandLine:

	; Grab a descriptor for video RAM from DPMI
	mov	ax, 02h				; [DPMI] segment -> descriptor
	mov	ebx, 0a000h			; segment to get a descriptor for
	int	31h
	jc	.leave				; exit if error
	mov	[_viddescriptor], ax		; save descriptor
	
	; Grab a descriptor for textvideo RAM from DPMI
	mov	ax, 02h				; [DPMI] segment -> descriptor
	mov	ebx, 0b800h			; segment to get a descriptor for
	int	31h
	jc	.leave				; exit if error
	mov	[_textdescriptor], ax		; save descriptor
	
	call	_mymain				; Run the actual program

	xor	ax, ax				; Clear any possible error return

.leave:

endproc
