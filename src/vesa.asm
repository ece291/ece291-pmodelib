; VESA (320x240x32-bit) routines
;  By Peter Johnson, 1999

%include "myC32.mac"		; C interface macros

%include "globals.inc"
%include "constant.inc"
%include "dpmi_int.inc"
%include "dpmi_mem.inc"

	BITS	32

	SECTION .bss

VESA_LinearAddress	resd	1	; Linear address of video framebuffer
VESA_Selector		resw	1	; Selector used to access framebuffer

VESA_Info		; VESA information block
VESAInfo_Signature		resb	4
VESAInfo_Version		resw	1
VESAInfo_OEMStringPtr		resd	1
VESAInfo_Capabilities		resb	4
VESAInfo_VideoModePtr		resd	1
VESAInfo_TotalMemory		resw	1
VESAInfo_OEMSoftwareRev		resw	1
VESAInfo_OEMVendorNamePtr	resd	1
VESAInfo_OEMProductNamePtr	resd	1
VESAInfo_OEMProductRevPtr	resd	1
VESAInfo_Reserved		resb	222
VESAInfo_OEMData		resb	256

Mode_Info		; VESA information for a mode
ModeInfo_ModeAttributes		resw	1
ModeInfo_WinAAttributes		resb	1
ModeInfo_WinBAttributes		resb	1
ModeInfo_WinGranularity		resw	1
ModeInfo_WinSize		resw	1
ModeInfo_WinASegment		resw	1
ModeInfo_WinBSegment		resw	1
ModeInfo_WinFuncPtr		resd	1
ModeInfo_BytesPerScanLine	resw	1
ModeInfo_XResolution		resw	1
ModeInfo_YResolution		resw	1
ModeInfo_XCharSize		resb	1
ModeInfo_YCharSize		resb	1
ModeInfo_NumberOfPlanes		resb	1
ModeInfo_BitsPerPixel		resb	1
ModeInfo_NumberOfBanks		resb	1
ModeInfo_MemoryModel		resb	1
ModeInfo_BankSize		resb	1
ModeInfo_NumberOfImagePages	resb	1
ModeInfo_Reserved_page		resb	1
ModeInfo_RedMaskSize		resb	1
ModeInfo_RedMaskPos		resb	1
ModeInfo_GreenMaskSize		resb	1
ModeInfo_GreenMaskPos		resb	1
ModeInfo_BlueMaskSize		resb	1
ModeInfo_BlueMaskPos		resb	1
ModeInfo_ReservedMaskSize	resb	1
ModeInfo_ReservedMaskPos	resb	1
ModeInfo_DirectColorModeInfo	resb	1
; VBE 2.0 extensions
ModeInfo_PhysBasePtr		resd	1
ModeInfo_OffScreenMemOffset	resd	1
ModeInfo_OffScreenMemSize	resw	1
; VBE 3.0 extensions
ModeInfo_LinBytesPerScanLine	resw	1
ModeInfo_BnkNumberOfPages	resb	1
ModeInfo_LinNumberOfPages	resb	1
ModeInfo_LinRedMaskSize		resb	1
ModeInfo_LinRedFieldPos		resb	1
ModeInfo_LinGreenMaskSize	resb	1
ModeInfo_LinGreenFieldPos	resb	1
ModeInfo_LinBlueMaskSize	resb	1
ModeInfo_LinBlueFieldPos	resb	1
ModeInfo_LinRsvdMaskSize	resb	1
ModeInfo_LinRsvdFieldPos	resb	1
ModeInfo_MaxPixelClock		resd	1
; Reserved
ModeInfo_Reserved		resb	190	   

ModeSelected	resd	1	; Selected graphics mode, set by CheckVESA, used by SetVESA

	SECTION .data

VESA_BytesPerScanLine		dd	4*WINDOW_W

	SECTION .text

	EXTERN _SetModeC80
;----------------------------------------
; bool CheckVESA(unsigned int mode);
; Purpose: Checks to see if VESA is available and if the desired mode is
;	   available.
; Inputs:  dword mode -- the VESA mode to set it to.
; Outputs: VESAInfo and ModeInfo structures filled (if successful)
;	   VESA_BytesPerScanLine set to proper value (if VESA 3 installed)
;	   Returns 1 on error, otherwise 0
;----------------------------------------
proc _CheckVESA
%$mode		arg	4

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
        mov     edi, VESA_Info
        mov     ecx, 128        ; 128 dwords = 512 bytes
        rep     movsd           ; Copy into local structure from transfer buffer
        pop     ds

        cmp     dword [VESAInfo_Signature], 'VESA'
        jne     .error          ; VESA not installed (invalid info block)

        cmp     byte [VESAInfo_Version+1], 2
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
        mov     eax, [ebp+%$mode]
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
        mov     edi, Mode_Info
        mov     ecx, 64         ; 64 dwords = 256 bytes
        rep     movsd           ; Copy into local structure from transfer buffer
        pop     ds

        xor     eax, eax
        mov     ax, [ModeInfo_BytesPerScanLine]
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
        mov     ax, word [VESAInfo_TotalMemory]
        shl     eax, 16
        invoke  _GetPhysicalMapping, dword VESA_LinearAddress, dword VESA_Selector, dword [ModeInfo_PhysBasePtr], dword eax
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

%$X             arg     2
%$Y             arg     2
%$Color         arg     4

        xor     eax, eax
        mov     ax, [ebp+%$Y]
        xor     ebx, ebx
        mov     bx, [ModeInfo_BytesPerScanLine]
        imul    eax, ebx
        xor     ebx, ebx
        mov     bx, [ebp+%$X]
        shl     ebx, 2
        add     ebx, eax

        mov     eax, [ebp+%$Color]
        mov     [es:ebx], eax           ; draw the pixel in the desired color

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

%$X             arg     2
%$Y             arg     2

        xor     eax, eax
        mov     ax, [ebp+%$Y]
        xor     ebx, ebx
        mov     bx, [ModeInfo_BytesPerScanLine]
        imul    eax, ebx
        xor     ebx, ebx
        mov     bx, [ebp+%$X]
        shl     ebx, 2
        add     ebx, eax

        mov     eax, [es:ebx]           ; get the pixel color

endproc

;----------------------------------------
; void CopySystemToScreenVESA(short SourceStartX, short SourceStartY,
;  short SourceEndX, short SourceEndY, short DestStartX,
;  short DestStartY, short SourceBitmapWidth, char *SourcePtr);
; Purpose: Copies an area of a source bitmap to the screen.
; Inputs:  SourceStartX, X coordinate of upper left corner of source
;          SourceStartY, Y coordinate of upper left corner of source
;          SourceEndX, X coordinate of lower right corner of source (exclusive)
;          SourceEndY, Y coordinate of lower right corner of source (exclusive)
;          DestStartX, X coordinate of upper left corner of dest
;          DestStartY, Y coordinate of upper left corner of dest
;          SourceBitmapWidth, # of pixels across source bitmap
;          SourcePtr, pointer in GS to start of source bitmap
; Outputs: None
; Notes:   Assumes es=[VESA_Selector], SourcePtr in gs.
;----------------------------------------
proc _CopySystemToScreenVESA

%$SourceStartX          arg     2
%$SourceStartY          arg     2
%$SourceEndX            arg     2
%$SourceEndY            arg     2
%$DestStartX            arg     2
%$DestStartY            arg     2
%$SourceBitmapWidth     arg     2
%$SourcePtr             arg     4

        push    esi                             ; preserve caller's register variables
	push	edi
	push	ds

	mov	ax, gs				; Copy the segment to a local one
	mov	ds, ax

	cld
	
	mov	ax, [ebp + %$SourceBitmapWidth]
	mul	word [ebp + %$SourceStartY]	; top source rect scan line
	add	ax, [ebp + %$SourceStartX]
	xor	esi, esi
	mov	si, ax
	add	esi, [ebp + %$SourcePtr]	; offset of first source rect pixel

	xor	eax, eax
	mov	ax, [ebp+%$DestStartY]
	lea	eax, [eax+eax*4]	; Y*320=Y*5*2^6
	shl	eax, 6
	xor	edi, edi
	mov	di, [ebp+%$DestStartX]
	add	edi, eax		; Offset=Y*320+X
	
	xor	ecx, ecx
	mov	cx, [ebp + %$SourceEndX]	; calculate # of pixels across
	sub	cx, [ebp + %$SourceStartX]	;  rect
	mov	edx, ecx

	jle	.CopyDone			; skip if 0 or negative width
	
	xor	ebx, ebx
	mov	bx, [ebp + %$SourceEndY]
	sub	bx, [ebp + %$SourceStartY]	; calc height of rectangle

	jle	.CopyDone			; skip if 0 or negative height

.CopyRowsLoop:
	mov	eax, esi

	rep

	mov	esi, eax			; retrieve the dest start offset
	xor	eax, eax
	mov	ax, [ebp + %$SourceBitmapWidth] ; point to the start of the
	add	esi, eax			;  next scan line of the source
	
	dec	ebx				; count down rows
	jnz	.CopyRowsLoop
.CopyDone:
	pop	ds
	pop	edi				; restore caller's register variables
	pop	esi

endproc

;----------------------------------------
; void RefreshVideoBuffer(void);
; Purpose: Copies the backbuffer to the display memory.
; Inputs:  _VideoBlock filled with new screen data.
; Outputs: None
; Notes:   Assumes es=[VESA_Selector]
;----------------------------------------
	GLOBAL	_RefreshVideoBuffer
_RefreshVideoBuffer
	
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
