; VBE/AF loadable graphics driver routines
;  By Peter Johnson, 2001
;
; $Id: vbeaf.asm,v 1.7 2001/03/17 20:29:33 pete Exp $
%include "myC32.mac"		; C interface macros

%include "filefunc.inc"

	BITS	32

; Define libc functions used for driver loading
	EXTERN ___sbrk
	EXTERN _getenv

___sbrk_arglen	equ	4
_getenv_arglen	equ	4

; Selectors used by C code
EXTERN _djgpp_es, _djgpp_fs, _djgpp_gs

; Program argv[] array
EXTERN ___dos_argv0

; FreeBE/AF API extensions use 32 bit magic numbers
%define	FAF_ID(a,b,c,d)	((a<<24) | (b<<16) | (c<<8) | d)

; ID code and magic return value for initialising the extensions
%define FAFEXT_INIT	FAF_ID('I','N','I','T')
%define	FAFEXT_MAGIC	FAF_ID('E','X', 0,  0)

; function exporting extensions (needed for Nucleus compatibility)
;  TODO: Currently not supported in code
%define	FAFEXT_LIBC	FAF_ID('L','I','B','C')
%define	FAFEXT_PMODE	FAF_ID('P','M','O','D')

; extension providing a hardware-specific way to access video memory
;  TODO: Currently not supported in code
%define	FAFEXT_HWPTR	FAF_ID('H','P','T','R')

; extension for remapped keyboard
%define	FAFEXT_KEYBOARD	FAF_ID('K','E','Y','S')

; extension for DispatchCall function (needed for EX291 driver)
%define	FAFEXT_DISPATCHCALL	FAF_ID('D','I','C','L')

; EX291-specific emulation flag for video capabilities
%define EX291_EMULATED	FAF_ID('E','M','U','L')

; mode attribute flags
afHaveMultiBuffer	equ	0001h	; multiple buffers
afHaveVirtualScroll	equ	0002h	; virtual scrolling
afHaveBankedBuffer	equ	0004h	; supports banked framebuffer
afHaveLinearBuffer	equ	0008h	; supports linear framebuffer
afHaveAccel2D		equ	0010h	; supports 2D acceleration
afHaveDualBuffers	equ	0020h	; uses dual buffers
afHaveHWCursor		equ	0040h	; supports a hardware cursor
afHave8BitDAC		equ	0080h	; 8 bit palette DAC
afNonVGAMode		equ	0100h	; not a VGA mode
afHaveDoubleScan	equ	0200h	; supports double scanning
afHaveInterlaced	equ	0400h	; supports interlacing
afHaveTripleBuffer	equ	0800h	; supports triple buffering
afHaveStereo		equ	1000h	; supports stereo LCD glasses
afHaveROP2		equ	2000h	; supports ROP2 mix codes
afHaveHWStereoSync	equ	4000h	; hardware stereo signalling
afHaveEVCStereoSync	equ	8000h	; HW stereo sync via EVC connector

; VBE/AF mode information structure
	STRUC AF_MODE_INFO
.Attributes		resw	1
.XResolution		resw	1
.YResolution		resw	1
.BytesPerScanLine	resw	1
.BitsPerPixel		resw	1
.MaxBuffers		resw	1
.RedMaskSize		resb	1
.RedFieldPosition	resb	1
.GreenMaskSize		resb	1
.GreenFieldPosition	resb	1
.BlueMaskSize		resb	1
.BlueFieldPosition	resb	1
.RsvdMaskSize		resb	1
.RsvdFieldPosition	resb	1
.MaxBytesPerScanLine	resw	1
.MaxScanLineWidth	resw	1
; VBE/AF 2.0 extensions
.LinBytesPerScanLine	resw	1
.BnkMaxBuffers		resb	1
.LinMaxBuffers		resb	1
.LinRedMaskSize		resb	1
.LinRedFieldPosition	resb	1
.LinGreenMaskSize	resb	1
.LinGreenFieldPosition	resb	1
.LinBlueMaskSize	resb	1
.LinBlueFieldPosition	resb	1
.LinRsvdMaskSize	resb	1
.LinRsvdFieldPosition	resb	1
.MaxPixelClock		resd	1
.VideoCapabilities	resd	1
.VideoMinXScale		resw	1
.VideoMinYScale		resw	1
.VideoMaxXScale		resw	1
.VideoMaxYScale		resw	1
.Reserved		resb	76
	ENDSTRUC

; main VBE/AF driver structure
	STRUC AF_DRIVER 
; header
.Signature		resb	12
.Version		resd	1
.DriverRev		resd	1
.OemVendorName		resb	80
.OemCopyright		resb	80
.AvailableModes		resd	1
.TotalMemory		resd	1
.Attributes		resd	1
.BankSize		resd	1
.BankedBasePtr		resd	1
.LinearSize		resd	1
.LinearBasePtr		resd	1
.LinearGranularity	resd	1
.IOPortsTable		resd	1
.IOMemoryBase		resd	4
.IOMemoryLen		resd	4
.LinearStridePad	resd	1
.PCIVendorID		resw	1
.PCIDeviceID		resw	1
.PCISubSysVendorID	resw	1
.PCISubSysID		resw	1
.Checksum		resd	1
.res2			resd	6
; near pointers mapped by the application
.IOMemMaps		resd	4
.BankedMem		resd	1
.LinearMem		resd	1
.res3			resd	5
; driver state variables
.BufferEndX		resd	1
.BufferEndY		resd	1
.OriginOffset		resd	1
.OffscreenOffset	resd	1
.OffscreenStartY	resd	1
.OffscreenEndY		resd	1
.res4			resd	10
; relocatable 32 bit bank switch routine, for Windows (ugh!)
.SetBank32Len		resd	1
.SetBank32		resd	1
; callback functions provided by the application
.Int86			resd	1
.CallRealMode		resd	1
; main driver setup routine
.InitDriver		resd	1
; VBE/AF 1.0 asm interface (obsolete and not supported by Allegro)
.af10Funcs		resd	40
; VBE/AF 2.0 extensions
.PlugAndPlayInit	resd	1
; extension query function, specific to FreeBE/AF
.OemExt			resd	1
; extension hook for implementing additional VESA interfaces
.SupplementalExt	resd	1
; device driver functions
.GetVideoModeInfo	resd	1
.SetVideoMode		resd	1
.RestoreTextMode	resd	1
.GetClosestPixelClock	resd	1
.SaveRestoreState	resd	1
.SetDisplayStart	resd	1
.SetActiveBuffer	resd	1
.SetVisibleBuffer	resd	1
.GetDisplayStartStatus	resd	1
.EnableStereoMode	resd	1
.SetPaletteData		resd	1
.SetGammaCorrectData	resd	1
.SetBank		resd	1
; hardware cursor functions
.SetCursor		resd	1
.SetCursorPos		resd	1
.SetCursorColor		resd	1
.ShowCursor		resd	1
; 2D rendering functions
.WaitTillIdle		resd	1
.EnableDirectAccess	resd	1
.DisableDirectAccess	resd	1
.SetMix			resd	1
.Set8x8MonoPattern	resd	1
.Set8x8ColorPattern	resd	1
.Use8x8ColorPattern	resd	1
.SetLineStipple		resd	1
.SetLineStippleCount	resd	1
.SetClipRect		resd	1
.DrawScan		resd	1
.DrawPattScan		resd	1
.DrawColorPattScan	resd	1
.DrawScanList		resd	1
.DrawPattScanList	resd	1
.DrawColorPattScanList	resd	1
.DrawRect		resd	1
.DrawPattRect		resd	1
.DrawColorPattRect	resd	1
.DrawLine		resd	1
.DrawStippleLine	resd	1
.DrawTrap		resd	1
.DrawTri		resd	1
.DrawQuad		resd	1
.PutMonoImage		resd	1
.PutMonoImageLin	resd	1
.PutMonoImageBM		resd	1
.BitBlt			resd	1
.BitBltSys		resd	1
.BitBltLin		resd	1
.BitBltBM		resd	1
.SrcTransBlt		resd	1
.SrcTransBltSys		resd	1
.SrcTransBltLin		resd	1
.SrcTransBltBM		resd	1
.DstTransBlt		resd	1
.DstTransBltSys		resd	1
.DstTransBltLin		resd	1
.DstTransBltBM		resd	1
.StretchBlt		resd	1
.StretchBltSys		resd	1
.StretchBltLin		resd	1
.StretchBltBM		resd	1
.SrcTransStretchBlt	resd	1
.SrcTransStretchBltSys	resd	1
.SrcTransStretchBltLin	resd	1
.SrcTransStretchBltBM	resd	1
.DstTransStretchBlt	resd	1
.DstTransStretchBltSys	resd	1
.DstTransStretchBltLin	resd	1
.DstTransStretchBltBM	resd	1
; hardware video functions
.SetVideoInput		resd	1
.SetVideoOutput		resd	1
.StartVideoFrame	resd	1
.EndVideoFrame		resd	1
	ENDSTRUC

; interface structure containing remapped keyboard data
	STRUC FAF_KEYBOARD_DATA
.INT	resb	1
.IRQ	resb	1
.Port	resw	1
	ENDSTRUC

	SECTION .bss

DriverOffset	resd	1	; Offset of sbrk()'ed VBE/AF driver
DriverSize	resd	1	; Size of driver
InGraphicsMode	resb	1	; Are we in graphics mode?
ModeInfo	resb	AF_MODE_INFO_size
Filename	resb	256	; Driver filename (used in InitGraphics)
FreeBEExt	resb	1	; FreeBE/AF extensions available?

	SECTION	.data

VBEAFName	db	'VBEAF.DRV', 0
VBEAFEnv	db	'VBEAF_PATH', 0

	SECTION .text

;----------------------------------------
; bool LoadGraphicsDriver(char *Filename);
; Purpose: Loads and initializes the specified VBE/AF graphics driver.
; Inputs:  Filename, full pathname of the driver to load
; Outputs: 1 on error, 0 otherwise
;----------------------------------------
_LoadGraphicsDriver_arglen	equ	4
proc _LoadGraphicsDriver

.Filename	arg	4

.file		equ	-4		; file handle
.STACK_FRAME_SIZE	equ	4

	sub	esp, .STACK_FRAME_SIZE	; allocate space for local vars
	push	es			; Set up selectors C code expects
	push	fs
	push	gs
	mov	gs, [_djgpp_gs]
	mov	fs, [_djgpp_fs]
	mov	es, [_djgpp_es]

	; Open driver file
	invoke	_OpenFile, dword [ebp+.Filename], word 0
	cmp	eax, -1
	je	near .error
	mov	[ebp+.file], eax

	; Determine file size
	invoke	_SeekFile, dword [ebp+.file], dword 0, word 2
	cmp	eax, -1
	je	.error
	mov	[DriverSize], eax

	; Seek back to start of file
	invoke	_SeekFile, dword [ebp+.file], dword 0, word 0
	cmp	eax, -1
	je	.error

	; Allocate memory, using sbrk() so it's in our main segment
	; FIXME: Should we do this ourselves rather than using libc?
	;  Probably not--sbrk uses some nasty DPMI tricks and a 16-bit p-mode 
	;  (yuck :) function to accomplish the magic of extending the CS
	;  selector limit.
	invoke	___sbrk, dword [DriverSize]
	test	eax, eax
	jz	.error
	mov	[DriverOffset], eax

	; Read in driver
	invoke	_ReadFile, dword [ebp+.file], dword [DriverOffset], dword [DriverSize]
	cmp	eax, [DriverSize]
	jne	.errorfree

	; Close driver file
	invoke	_CloseFile, dword [ebp+.file]

	xor	eax, eax
	jmp	short .done

.errorfree:
	mov	eax, [DriverSize]	; Do a negative sbrk to free memory
	neg	eax
	invoke	___sbrk, eax
	mov	dword [DriverOffset], 0
.error:
	xor	eax, eax
	inc	eax	
.done:
	pop	gs			; Restore old selectors
	pop	fs
	pop	es
	mov	esp, ebp
	ret
endproc

;----------------------------------------
; bool InitGraphics(char *kbINT, char *kbIRQ, unsigned short *kbPort);
; Purpose: Initializes VBE/AF graphics driver.
; Inputs:  None
; Outputs: 1 on error, 0 otherwise
;          kbINT, kbIRQ, and kbPort values set to current keyboard settings
;           (9, 1, and 60h if no VBE/AF keyboard extension present)
;----------------------------------------
proc _InitGraphics

.kbIRQ		arg	4
.kbINT		arg	4
.kbPort		arg	4

	push	es			; Set up selectors C code expects
	push	fs
	push	gs
	mov	gs, [_djgpp_gs]
	mov	fs, [_djgpp_fs]
	mov	es, [_djgpp_es]
	push	esi
	push	edi

	; Check if driver was loaded already (eg, by program selection screen)
	mov	esi, [DriverOffset]
	test	esi, esi
	jnz	near .foundit

	; Try to load "vbeaf.drv" driver from a couple different locations:

	; Same directory as program
	;  - Grab argv[0] and replace filename part with "vbeaf.drv"
	mov	ecx, 256		; Maximum filename length
	mov	esi, [___dos_argv0]
	mov	edi, Filename
.argv0copy:
	mov	al, [esi]
	mov	[edi], al
	inc	esi
	inc	edi
	or	al, al
	jnz	.argv0copy
	; Find trailing slash before the filename
.findlastslash:
	cmp	byte [edi], '/'
	je	.lastslashfound
	cmp	byte [edi], '\'
	je	.lastslashfound
	cmp	edi, Filename
	je	.lastslashnotfound
	dec	edi
	jmp	short .findlastslash
.lastslashfound:
	inc	edi
	; Replace filename with "vbeaf.drv", and terminate
	mov	ecx, 10
	mov	esi, VBEAFName
	rep	movsb

	; Try loading it from there
	invoke	_LoadGraphicsDriver, dword Filename
	test	eax, eax
	jz	near .foundit	; Loaded successfully!

.lastslashnotfound:
	; Default location (C:\vbeaf.drv)
	mov	edi, Filename
	mov	dword [edi], 'C:\v'
	add	edi, 3
	mov	esi, VBEAFName
	mov	ecx, 10
	rep	movsb

	invoke	_LoadGraphicsDriver, dword Filename
	test	eax, eax
	jz	.foundit

	; Get VBEAF_PATH environment variable
	invoke	_getenv, dword VBEAFEnv
	test	eax, eax
	jz	near .error

	; Copy it to Filename
	mov	ecx, 256
	mov	esi, eax
	mov	edi, Filename
	rep	movsb

	; Append / if no ending slash present
	dec	edi
	cmp	byte [edi], '/'
	je	.slashpresent
	cmp	byte [edi], '\'
	je	.slashpresent
	inc	edi
	mov	byte [edi], '/'
.slashpresent:
	; Append "vbeaf.drv"
	inc	edi
	mov	esi, VBEAFName
	mov	ecx, 10
	rep	movsb

	invoke	_LoadGraphicsDriver, dword Filename
	test	eax, eax
	jz	.foundit

	jmp	.error			; Not found!
.foundit:
	mov	esi, [DriverOffset]

	; Check driver ID string
	cmp	dword [esi+AF_DRIVER.Signature], 'VBEA'
	jne	near .errorfree
	cmp	dword [esi+AF_DRIVER.Signature+4], 'F.DR'
	jne	near .errorfree
	cmp	byte [esi+AF_DRIVER.Signature+8], 'V'
	jne	near .errorfree

	; Check version number
	cmp	word [esi+AF_DRIVER.Version], 0200h
	jb	near .errorfree

	; Extension init (C-style call)
	mov	edi, [esi+AF_DRIVER.OemExt]
	add	edi, esi
	push	dword FAFEXT_INIT		; id parameter
	push	esi				; af_driver parameter
	call	edi
	add	esp, 8				; discard parameters

	; Check for nice magic number return value:
	; version bytes ASCII digits?
	cmp	al, '0'
	jb	.noext
	cmp	al, '9'
	ja	.noext
	cmp	ah, '0'
	jb	.noext
	cmp	al, '9'
	ja	.noext
	; top 16 bits match magic number?
	and	eax, 0FFFF0000h
	cmp	eax, FAFEXT_MAGIC
	jne	.noext

	; Indicate extensions present
	mov	byte [FreeBEExt], 1

	; Export DispatchCall if the driver wants it
	push	dword FAFEXT_DISPATCHCALL
	push	esi
	call	[esi+AF_DRIVER.OemExt]
	add	esp, 8
	test	eax, eax		; Not wanted
	jz	.noext

	mov	dword [eax], _DispatchCall

.noext:

	; Set up plug and play hardware
	mov	edi, [esi+AF_DRIVER.PlugAndPlayInit]	; Calculate proc address
	add	edi, esi
	mov	ebx, esi		; driver pointer in ebx
	call	edi
	test	eax, eax
	jnz	near .errorfree

	mov	esi, [DriverOffset]	; Assume esi was clobbered

	; TODO: Memory initialization (for non-EX291 drivers)

	; Low level driver init
	mov	edi, [esi+AF_DRIVER.InitDriver]
	add	edi, esi
	mov	ebx, esi
	call	edi
	test	eax, eax
	jnz	near .errorfree

	mov	esi, [DriverOffset]

	; No extensions -> don't try to initialize keyboard
	cmp	byte [FreeBEExt], 0
	jz	.defaultkb

	; Initialize keyboard settings
	push	dword FAFEXT_KEYBOARD
	push	esi
	call	[esi+AF_DRIVER.OemExt]
	add	esp, 8

	; Extension present?  If not, set defaults
	test	eax, eax
	jz	.defaultkb

	; Okay, copy values out of structure
	mov	edi, eax
	mov	al, [edi+FAF_KEYBOARD_DATA.INT]
	mov	ebx, [ebp+.kbINT]
	mov	[ebx], al
	mov	al, [edi+FAF_KEYBOARD_DATA.IRQ]
	mov	ebx, [ebp+.kbIRQ]
	mov	[ebx], al
	mov	ax, [edi+FAF_KEYBOARD_DATA.Port]
	mov	ebx, [ebp+.kbPort]
	mov	[ebx], ax

	jmp	short .retokay

.defaultkb:
	; Set default keyboard settings (INT 9, IRQ 1, Port 60h)
	mov	edi, [ebp+.kbINT]
	mov	byte [edi], 9
	mov	edi, [ebp+.kbIRQ]
	mov	byte [edi], 1
	mov	edi, [ebp+.kbPort]
	mov	word [edi], 60h

.retokay:
	xor	eax, eax
	jmp	short .done

.errorfree:
	mov	eax, [DriverSize]	; Do a negative sbrk to free memory
	neg	eax
	invoke	___sbrk, eax
	mov	dword [DriverOffset], 0
.error:
	xor	eax, eax
	inc	eax
.done:
	pop	edi
	pop	esi
	pop	gs			; Restore old selectors
	pop	fs
	pop	es
	ret
endproc

;----------------------------------------
; void ExitGraphics(void);
; Purpose: Shuts down graphics driver.
; Inputs:  None
; Outputs: None
;----------------------------------------
	GLOBAL	_ExitGraphics
_ExitGraphics

	invoke	_UnsetGraphicsMode	; First get out of graphics mode

	push	es			; Set up selectors C code expects
	push	fs
	push	gs
	mov	gs, [_djgpp_gs]
	mov	fs, [_djgpp_fs]
	mov	es, [_djgpp_es]
	push	esi

	; Free driver memory
	mov	esi, [DriverOffset]
	test	esi, esi
	jz	.notloaded
	mov	eax, [DriverSize]	; Do a negative sbrk to free memory
	neg	eax
	invoke	___sbrk, eax
	mov	dword [DriverOffset], 0
.notloaded:

	pop	esi
	pop	gs			; Restore old selectors
	pop	fs
	pop	es
	ret

;----------------------------------------
; short FindGraphicsMode(short Width, short Height, short Depth, bool Emulated);
; Purpose: Tries to find a graphics mode matching the desired settings.
; Inputs:  Width, width of desired resolution (in pixels)
;          Height, height of desired resolution (in pixels)
;          Depth, bits per pixel (8, 16, 24, 32)
;          Emulated, include driver-emulated modes (EX291)? (1=Yes, 0=No)
; Outputs: Returns the mode number, or -1 if no matching mode found.
;----------------------------------------
proc _FindGraphicsMode
.Width		arg	2
.Height		arg	2
.Depth		arg	2
.Emulated	arg	4

	push	es			; Set up selectors C code expects
	push	fs
	push	gs
	mov	gs, [_djgpp_gs]
	mov	fs, [_djgpp_fs]
	mov	es, [_djgpp_es]
	push	esi
	push	edi

	mov	esi, [DriverOffset]

	; Loop through available modes
	mov	edi, [esi+AF_DRIVER.AvailableModes]
.modeloop:
	cmp	word [edi], -1		; Mode list terminator
	je	.notfound

	; Get mode info block
	mov	ebx, [esi+AF_DRIVER.GetVideoModeInfo]
	push	dword ModeInfo
	push	word [edi]
	push	esi
	call	[ebx]
	add	esp, 10
	test	eax, eax
	jnz	.nextmode		; Error retrieving, go to next mode

	; Check resolution, depth
	mov	ax, [ebp+.Width]
	cmp	[ModeInfo+AF_MODE_INFO.XResolution], ax
	jne	.nextmode

	mov	ax, [ebp+.Height]
	cmp	[ModeInfo+AF_MODE_INFO.YResolution], ax
	jne	.nextmode

	mov	ax, [ebp+.Depth]	; Yeah, it's really a dword..
	cmp	[ModeInfo+AF_MODE_INFO.BitsPerPixel], ax
	jne	.nextmode

	; If we're including driver-emulated modes, we're done.
	mov	eax, [ebp+.Emulated]
	test	eax, eax
	jnz	.foundit

	; Accept only non-emulated modes.
	mov	eax, [ModeInfo+AF_MODE_INFO.VideoCapabilities]
	cmp	eax, EX291_EMULATED
	jne	.foundit

.nextmode:
	add	edi, byte 2		; Next mode
	jmp	short .modeloop

.foundit:
	movzx	eax, word [edi]
	jmp	short .done
.notfound:
	xor	eax, eax
.done:
	pop	edi
	pop	esi
	pop	gs			; Restore old selectors
	pop	fs
	pop	es
	ret
endproc

;----------------------------------------
; bool SetGraphicsMode(short Mode);
; Purpose: Sets a new graphics mode.
; Inputs:  Mode, mode number returned by FindGraphicsMode()
; Outputs: nonzero on error, 0 otherwise
;----------------------------------------
proc _SetGraphicsMode
.Mode		arg	2
	
	push	es			; Set up selectors C code expects
	push	fs
	push	gs
	mov	gs, [_djgpp_gs]
	mov	fs, [_djgpp_fs]
	mov	es, [_djgpp_es]

	mov	eax, [DriverOffset]
	mov	ebx, [eax+AF_DRIVER.SetVideoMode]
	xor	ecx, ecx
	push	ecx			; NULL for crtc pointer
	inc	ecx
	push	ecx			; 1 buffer
	push	dword ModeInfo+AF_MODE_INFO.BytesPerScanLine
	movzx	ecx, word [ModeInfo+AF_MODE_INFO.YResolution]
	push	ecx			; virtual height
	movzx	ecx, word [ModeInfo+AF_MODE_INFO.XResolution]
	push	ecx			; virtual width
	push	word [ebp+.Mode]	; mode
	push	eax			; af_driver
	call	[ebx]
	add	esp, 26

	; Use value returned from SetVideoMode() as our return value

	pop	gs			; Restore old selectors
	pop	fs
	pop	es
	ret
endproc

;----------------------------------------
; void UnsetGraphicsMode(void);
; Purpose: Gets out of current graphics mode.
; Inputs:  None
; Outputs: None
;----------------------------------------
        GLOBAL  _UnsetGraphicsMode
_UnsetGraphicsMode

	; Don't bother if we're not in a graphics mode.
	cmp	byte [InGraphicsMode], 0
	jz	.notingraphics

	push	es			; Set up selectors C code expects
	push	fs
	push	gs
	mov	gs, [_djgpp_gs]
	mov	fs, [_djgpp_fs]
	mov	es, [_djgpp_es]
	push	esi
	push	edi

	; Shutdown VBE/AF driver:
	mov	esi, [DriverOffset]

	; Enable Direct Access
	mov	edi, [esi+AF_DRIVER.EnableDirectAccess]
	test	edi, edi
	jz	.noEDA
	push	esi
	call	[edi]
	add	esp, 4
.noEDA:
	; Wait Until Idle
	mov	edi, [esi+AF_DRIVER.WaitTillIdle]
	test	edi, edi
	jz	.noWTI
	push	esi
	call	[edi]
	add	esp, 4
.noWTI:
	; Restore Text Mode
	push	esi
	call	[esi+AF_DRIVER.RestoreTextMode]
	add	esp, 4

	; Clear InGraphicsMode flag
	mov	byte [InGraphicsMode], 0

	pop	edi
	pop	esi
	pop	gs			; Restore old selectors
	pop	fs
	pop	es

.notingraphics:
	ret

;----------------------------------------
; void CopyToScreen(void *Source, int SourcePitch, int SourceLeft,
;  int SourceTop, int Width, int Height, int DestLeft, int DestTop);
; Purpose: Copies a portion of the source image to the display memory.
; Inputs:  Source, start address of source linear bitmap image
;          SourcePitch, total width of source image (in bytes)
;          SourceLeft, starting x coordinate of source area
;          SourceTop, starting y coordinate of source area
;          Width, width of area to copy (in pixels)
;          Height, height of area to copy (in pixels)
;          DestLeft, starting x coordinate of destination area
;          DestTop, starting y coordinate of destination area
; Outputs: None
; Notes:   Source must have the same pixel format as the current video mode.
;----------------------------------------
proc _CopyToScreen

.Source		arg	4
.SourcePitch	arg	4
.SourceLeft	arg	4
.SourceTop	arg	4
.Width		arg	4
.Height		arg	4
.DestLeft	arg	4
.DestTop	arg	4

	push	es			; Set up selectors C code expects
	push	fs
	push	gs
	mov	gs, [_djgpp_gs]
	mov	fs, [_djgpp_fs]
	mov	es, [_djgpp_es]
	push	esi

	mov	esi, [DriverOffset]
	cmp	dword [esi+AF_DRIVER.BitBltSys], 0
	jz	.NoBitBltSys

	; Do C-style function call to VBE/AF driver
	; FIXME: Is there a better/faster way to do this?
	push	dword 0			; REPLACE mix mode
	push	dword [ebp+.DestTop]
	push	dword [ebp+.DestLeft]
	push	dword [ebp+.Height]
	push	dword [ebp+.Width]
	push	dword [ebp+.SourceTop]
	push	dword [ebp+.SourceLeft]
	push	dword [ebp+.SourcePitch]
	push	dword [ebp+.Source]
	push	esi			; af_driver parameter
	call	[esi+AF_DRIVER.BitBltSys]
	add	esp, 40			; discard parameters
	jmp	short .done

.NoBitBltSys:
	; TODO: Implement a fast framebuffer version if non-accelerated driver

.done:
	pop	esi
	pop	gs			; Restore old selectors
	pop	fs
	pop	es
	ret
endproc

;----------------------------------------
; unsigned int DispatchCall(unsigned int Handle, unsigned int Command,
;  DISPATCH_DATA *Data);
; Purpose: Passes control to the VDD, with parameters.
; Inputs:  Handle, 16-bit VDD DLL Handle
;          Command, 16-bit command ID
;          Data, data to pass to VDD in FS:ESI
; Outputs: Returns nonzero on error, zero otherwise.
;----------------------------------------
proc _DispatchCall

.Handle		arg	4
.Command	arg	4
.Data		arg	4

	push	fs
	push	esi

	mov	eax, ds
	mov	fs, eax

	mov	eax, [ebp+.Command]
	shl	eax, 16
	mov	ax, [ebp+.Handle]
	clc
	mov	esi, [ebp+.Data]
	db	0C4h, 0C4h, 058h, 002h
	xor	eax, eax
	salc

	pop	esi
	pop	fs
	ret
endproc

