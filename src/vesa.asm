; VESA (640x480x32-bit) routines
;  By Peter Johnson, 1999-2000
;
; $Id: vesa.asm,v 1.7 2000/12/18 07:35:18 pete Exp $
%include "myC32.mac"		; C interface macros

%include "globals.inc"
%include "constant.inc"
%include "dpmi_int.inc"
%include "dpmi_mem.inc"

	BITS	32

	SECTION .bss

VESA_LinearAddress	resd	1	; Linear address of video framebuffer
VESA_Selector		resw	1	; Selector used to access framebuffer

VESAInfo		; VESA information block
.Signature		resb	4
.Version		resw	1
.OEMStringPtr		resd	1
.Capabilities		resb	4
.VideoModePtr		resd	1
.TotalMemory		resw	1
.OEMSoftwareRev		resw	1
.OEMVendorNamePtr	resd	1
.OEMProductNamePtr	resd	1
.OEMProductRevPtr	resd	1
.Reserved		resb	222
.OEMData		resb	256

ModeInfo		; VESA information for a mode
.ModeAttributes		resw	1
.WinAAttributes		resb	1
.WinBAttributes		resb	1
.WinGranularity		resw	1
.WinSize		resw	1
.WinASegment		resw	1
.WinBSegment		resw	1
.WinFuncPtr		resd	1
.BytesPerScanLine	resw	1
.XResolution		resw	1
.YResolution		resw	1
.XCharSize		resb	1
.YCharSize		resb	1
.NumberOfPlanes		resb	1
.BitsPerPixel		resb	1
.NumberOfBanks		resb	1
.MemoryModel		resb	1
.BankSize		resb	1
.NumberOfImagePages	resb	1
.Reserved_page		resb	1
.RedMaskSize		resb	1
.RedMaskPos		resb	1
.GreenMaskSize		resb	1
.GreenMaskPos		resb	1
.BlueMaskSize		resb	1
.BlueMaskPos		resb	1
.ReservedMaskSize	resb	1
.ReservedMaskPos	resb	1
.DirectColorModeInfo	resb	1
; VBE 2.0 extensions
.PhysBasePtr		resd	1
.OffScreenMemOffset	resd	1
.OffScreenMemSize	resw	1
; VBE 3.0 extensions
.LinBytesPerScanLine	resw	1
.BnkNumberOfPages	resb	1
.LinNumberOfPages	resb	1
.LinRedMaskSize		resb	1
.LinRedFieldPos		resb	1
.LinGreenMaskSize	resb	1
.LinGreenFieldPos	resb	1
.LinBlueMaskSize	resb	1
.LinBlueFieldPos	resb	1
.LinRsvdMaskSize	resb	1
.LinRsvdFieldPos	resb	1
.MaxPixelClock		resd	1
; Reserved
.Reserved		resb	190	   

ModeSelected	resd	1	; Selected graphics mode, set by CheckVESA, used by SetVESA

	SECTION .data

	GLOBAL VESA_BytesPerScanLine
VESA_BytesPerScanLine		dd	4*WINDOW_W

	SECTION .text

	EXTERN _SetModeC80
;----------------------------------------
; bool CheckVESA(unsigned int mode);
; Purpose: Checks to see if VESA is available and if the desired mode is
;	   available.
; Inputs:  None
; Outputs: VESAInfo and ModeInfo structures filled (if successful)
;	   VESA_BytesPerScanLine set to proper value (if VESA 3 installed)
;	   Returns 1 on error, otherwise 0
;----------------------------------------
proc _CheckVESA
.mode		arg	4

	push	esi		; preserve C register vars
	push	edi		;  (don't count on BIOS preserving anything)
        push    ebx
        push    es

        ; Get SVGA info/presence
        
        mov     es, [_Transfer_Buf]
        mov     ax, [_Transfer_Buf_Seg]
        mov     [DPMI_DS], ax
        mov     [DPMI_ES], ax
        mov     ecx, 128        ; 128 dwords = 512 bytes
        xor     edi, edi
        xor     eax, eax
        rep     stosd           ; Clear transfer buffer

        mov     dword [DPMI_EAX], 4F00h ; [VESA] Get SVGA information
        mov     dword [DPMI_EDI], 0     ; ES:DI = Buffer for SVGA info
        mov     bx, 10h
        call    DPMI_Int
        mov     eax, [DPMI_EAX] ; Grab return value

        test    ah, ah
        jnz     near .error             ; VESA SVGA not installed

        push    ds
        mov     ax, ds
        mov     ds, [_Transfer_Buf]
        xor     esi, esi
        mov     es, ax
        mov     edi, VESAInfo
        mov     ecx, 128        ; 128 dwords = 512 bytes
        rep     movsd           ; Copy into local structure from transfer buffer
        pop     ds

        cmp     dword [VESAInfo.Signature], 'VESA'
        jne     .error          ; VESA not installed (invalid info block)

        cmp     byte [VESAInfo.Version+1], 2
        jb      .error          ; VESA version below 2.0

        ; Try to get a 640x480x32-bit mode.
        ;  Fail out if not found.
        ; FIXME: Perhaps add search routine instead of hardcoded numbers?
        mov     es, [_Transfer_Buf]
        mov     ecx, 64         ; 64 dwords = 256 bytes
        xor     edi, edi
        xor     eax, eax
        rep     stosd           ; Clear transfer buffer

        mov     dword [DPMI_EAX], 4F01h ; [VESA] Get SVGA Mode information
        mov     dword [DPMI_EDI], 0     ; ES:DI = Buffer for SVGA info
        mov     eax, [ebp+.mode]
        mov     [ModeSelected], eax     ; Save selected mode
        mov     dword [DPMI_ECX], eax   ; CX = SVGA mode
        mov     bx, 10h
        call    DPMI_Int
        mov     eax, [DPMI_EAX] ; Grab return value
        
        test    ah, ah
        jnz     .error          ; Mode not found

        push    ds
        mov     ax, ds
        mov     ds, [_Transfer_Buf]
        xor     esi, esi
        mov     es, ax
        mov     edi, ModeInfo
        mov     ecx, 64         ; 64 dwords = 256 bytes
        rep     movsd           ; Copy into local structure from transfer buffer
        pop     ds

        xor     eax, eax
        mov     ax, [ModeInfo.BytesPerScanLine]
        mov     [VESA_BytesPerScanLine], eax

        xor     eax, eax
        jmp     .done
.error:
        mov     ax, 1
.done:

        pop     es
        pop     ebx
        pop     edi             ; restore C register vars
        pop     esi

	ret
endproc

;----------------------------------------
; bool SetVESA(void);
; Purpose: Sets the graphics mode.
; Inputs:  VESAInfo and ModeInfo structures
; Outputs: 1 on error, 0 otherwise
;          ES = VESA selector
; Notes:   Assumes CheckVESA() has been called to determine if VESA is
;          available and to fill the various structures necessary for
;          this function to work.
;----------------------------------------
        GLOBAL  _SetVESA
_SetVESA

        ; Actually get into the graphics mode
        mov     dword [DPMI_EAX], 4F02h ; [VESA] Set SVGA Mode
        mov     ebx, [ModeSelected]
        or      ebx, 4000h
        mov     dword [DPMI_EBX], ebx   ; BX = SVGA mode
        xor     ebx, ebx
        mov     bx, 10h
        call    DPMI_Int
        mov     eax, [DPMI_EAX] ; Grab return value
        cmp     ax, 1
        je      .done
        
        ; Get the memory mapping
        xor     eax, eax
        mov     ax, word [VESAInfo.TotalMemory]
        shl     eax, 16
        invoke  _GetPhysicalMapping, dword VESA_LinearAddress, dword VESA_Selector, dword [ModeInfo.PhysBasePtr], dword eax
        cmp     ax, 1
        je     .done

        mov     es, [VESA_Selector]

        xor     eax, eax
.done:

        ret

;----------------------------------------
; void UnsetVESA(void);
; Purpose: Gets out of VESA mode.
; Inputs:  None
; Outputs: None
; Notes:   If es is still set to VESA_Selector, it will become invalid.
;----------------------------------------
        GLOBAL  _UnsetVESA
_UnsetVESA

        ; First free the memory mapping
        invoke  _FreePhysicalMapping, dword VESA_LinearAddress, dword VESA_Selector

        ; Go into the most basic mode to fix color problems
        mov     dword [DPMI_EAX], 4F02h ; [VESA] Set SVGA Mode
        mov     dword [DPMI_EBX], 101h  ; BX = SVGA mode
        mov     bx, 10h
        call    DPMI_Int

        call    _SetModeC80     ; Go back to 80x25 text

        xor     eax, eax
.done:
        ret

;----------------------------------------
; void WritePixelVESA(short X, short Y, unsigned int Color);
; Purpose: Draws a pixel on the screen.
; Inputs:  X, the x coordinate of the point to draw
;          Y, the y coordinate of the point to draw
;          Color, the 32-bit color value to draw
; Outputs: None
; Notes:   Assumes es=[VESA_Selector]
;----------------------------------------
proc _WritePixelVESA

.X              arg     2
.Y              arg     2
.Color          arg     4

        xor     eax, eax
        mov     ax, [ebp+.Y]
        xor     ebx, ebx
        mov     bx, [ModeInfo.BytesPerScanLine]
        imul    eax, ebx
        xor     ebx, ebx
        mov     bx, [ebp+.X]
        shl     ebx, 2
        add     ebx, eax

        mov     eax, [ebp+.Color]
        mov     [es:ebx], eax           ; draw the pixel in the desired color

	ret
endproc

;----------------------------------------
; unsigned int ReadPixelVESA(short X, short Y);
; Purpose: Reads the color value of a pixel on the screen.
; Inputs:  X, the x coordinate of the point to read
;          Y, the y coordinate of the point to read
; Outputs: The 32-bit color value of the pixel
; Notes:   Assumes es=[VESA_Selector]
;----------------------------------------
proc _ReadPixelVESA

.X              arg     2
.Y              arg     2

        xor     eax, eax
        mov     ax, [ebp+.Y]
        xor     ebx, ebx
        mov     bx, [ModeInfo.BytesPerScanLine]
        imul    eax, ebx
        xor     ebx, ebx
        mov     bx, [ebp+.X]
        shl     ebx, 2
        add     ebx, eax

        mov     eax, [es:ebx]           ; get the pixel color

	ret
endproc

;----------------------------------------
; void RefreshVideoBufferVESA(void);
; Purpose: Copies the backbuffer to the display memory.
; Inputs:  _VideoBlock filled with new screen data.
; Outputs: None
; Notes:   Assumes es=[VESA_Selector]
;;----------------------------------------
	GLOBAL	_RefreshVideoBufferVESA
_RefreshVideoBufferVESA
	
	push	esi
	push	edi

	xor	esi, esi
	xor	edi, edi
	mov	ecx, WINDOW_W
	mov	ebx, [VESA_BytesPerScanLine]
	sub	ebx, WINDOW_W*4		; Find offset from one line to next

	push	ds
	mov	ds, [_VideoBlock]
;	 mov	 ebx, 2048-(320*4)

	cld

	; Wait for display enable to be active (status is active low), to be
	;  sure both halves of the start address will take in the same frame.
	mov	dx, 03dah
.WaitDE:
	in	al, dx
	test	al, 01h
	jnz	.WaitDE			; display enable is active low (0 = active)
;	cli
	mov	eax, WINDOW_H
.InnerLoop:
	rep movsd
	mov	ecx, WINDOW_W
	add	edi, ebx
	dec	eax
	jnz	.InnerLoop
;	sti
	; Now wait for vertical sync, so the other page will be invisible when
	;  we start drawing to it.
	mov	dx, 03dah
.WaitVS:
	in	al, dx
	test	al, 08h
	jz	.WaitVS				; vertical sync is active high (1 = active)

	pop	ds
	pop	edi
	pop	esi

	ret
