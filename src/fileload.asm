; Various file loading functions
;  By Peter Johnson, 1999

%include "myC32.mac"
%include "filefunc.inc"
%include "aura.inc"

	BITS	32

	EXTERN	_ScratchBlock
	EXTERN	_MemBlock1
	EXTERN	_MemBlock2
        EXTERN  _SpritesBlock
        EXTERN  _TextureBlock
        EXTERN  _VideoBlock

        EXTERN  Cells_by_x

        EXTERN  _rand
	
_DecodePCX_arglen       	equ     20
_CalcLight_arglen		equ	16
_LoadBMP_arglen			equ	12
_LoadRIX_arglen			equ	12
_MixTexMap_arglen               equ     26

	SECTION	.data

; Table for VP4 textures (used in LoadHMap)
TexMapping
	times 5	db MY_WATER		; VP4_WATER1-5
	times 1	db MY_BEACH		; VP4_BEACH
	times 4	db MY_NOTREE		; VP4_NOTREE1-4
	times 4	db MY_TREE		; VP4_TREE1-4
	times 4	db MY_BARE		; VP4_BARE1-4
	times 4 db MY_SNOW		; VP4_SNOW1-4
	times 4	db MY_CLIFF		; VP4_CLIFF1-4

NormalConstant	dq	1024.0		; Used in CalcLight to calculate normal
LightHigh	dq	255.0		; Used in CalcLight to keep light value
LightLow	dq	0.0		;  within 8 bits

ShuffleInitDone db      0               ; Flag to indicate whether the Shuffle array
                                        ;  in MixTexMap has been initialized

ScreenShot_fn	db	'AuraOut?.raw',0	; Filename of screenshot file
ScreenShot_len	equ	$-ScreenShot_fn
ScreenShot_index        db      'A'

	SECTION	.text

;----------------------------------------
; int DecodePCX(short SrcSeg, char *Src,
;  short DestSeg, char *Dest, int SrcLen, int DestLen);
; Returns offset of palette in SrcSeg (NOT in Src)
;----------------------------------------
proc _DecodePCX

%$SrcSeg	arg	2		; Segment in which Src resides
%$Src		arg	4		; Offset of Src in SrcSeg
%$DestSeg	arg	2		; Segment in which Dest resides
%$Dest		arg	4		; Offset of Dest in DestSeg
%$SrcLen        arg     4               ; Length of source buffer
%$DestLen       arg     4               ; Length of destination buffer

        push    esi
        push    edi

        push    es
        mov     es, [ebp+%$DestSeg]
        push    ds
        mov     ds, [ebp+%$SrcSeg]

        mov     esi, [ebp+%$Src]
        mov     edi, [ebp+%$Dest]
        mov     edx, edi
        add     edx, [ebp+%$DestLen]
        
	xor     ecx, ecx
        cld
.Loop:
        mov     cl, [esi]
        mov     al, cl
        and     cl, 0C0h
	cmp     cl, 0C0h
        jne     .NoRepeat

        mov     cl, al
	inc     esi
        and     cl, 03Fh
	mov     al, [esi]
        rep stosb
        inc     esi
        cmp     edi, edx
        jb      .Loop
        jmp     .Done

.NoRepeat:
        mov     [es:edi], al
        inc     edi
        inc     esi
        cmp     edi, edx
        jb      .Loop

.Done:
        mov     eax, esi
        inc     eax             ; Get past little header byte thingy :)

        pop     ds
        pop     es

        pop     edi
        pop     esi

endproc

;----------------------------------------
; bool LoadHMap(char *Name, short NameLen,
;  char *Name2, short Name2Len);
;----------------------------------------
proc _LoadHMap

%$Name		arg	4		; Name of File #1 (Height Map)
%$NameLen	arg	2		; Length of Name
%$Name2		arg	4		; Name of File #2 (Texture Index Map)
%$Name2Len	arg	2		; Length of Name2

.File1			equ	-4	; local storage for file handle 1
.File2			equ	-8	; local storage for file handle 2
.i                      equ     -12
.j                      equ     -16
.tmp                    equ     -20
.STACK_FRAME_SIZE	equ	20

	sub	esp, .STACK_FRAME_SIZE	; allocate space for local vars
	push	esi			; preserve caller's register variables
	push	edi

	; Open File #1
	invoke	_OpenFile, dword [ebp + %$Name], word [ebp + %$NameLen], word 0
	cmp	eax, -1
	jz	near .error
	mov	dword [ebp + .File1], eax

	; Open File #2
	invoke	_OpenFile, dword [ebp + %$Name2], word [ebp + %$Name2Len], word 0
	cmp	eax, -1
	jz	near .error
	mov	dword [ebp + .File2], eax
	
	; Load HMap
	invoke	_ReadFile, dword [ebp + .File1], word [_ScratchBlock], dword 0, dword 128	; Skip header
	invoke	_ReadFile, dword [ebp + .File1], word [_ScratchBlock], dword 0, dword MAP_SIZE   ; Read compressed image

        invoke  _DecodePCX, word [_ScratchBlock], dword 0, word [_MemBlock1], dword HMap, dword MAP_SIZE, dword MAP_SIZE

	; Load TMapByte
	invoke	_ReadFile, dword [ebp + .File2], word [_ScratchBlock], dword 0, dword 128	; Skip header
	invoke	_ReadFile, dword [ebp + .File2], word [_ScratchBlock], dword 0, dword MAP_SIZE   ; Read compressed image

        invoke  _DecodePCX, word [_ScratchBlock], dword 0, word [_MemBlock1], dword TMapByte, dword MAP_SIZE, dword MAP_SIZE
	
	; Close File #1
	invoke	_CloseFile, dword [ebp + .File1]

	; Close File #2
	invoke	_CloseFile, dword [ebp + .File2]

	; Invert HMap
	mov	ecx, 0
	mov	edx, MAP_SIZE
	push	ds
	mov	ds, [_MemBlock1]
.InvertLoop:
	not	byte [HMap+ecx]	; Invert 4 bytes at once
	inc	ecx
	cmp	ecx, edx
	jnz	.InvertLoop

	; Find the minimum and maximum HMap values
	mov	eax, 0FFh	; Minimum = 255
	xor	ebx, ebx	; Maximum = 0
	xor	ecx, ecx	; Counter = 0
	xor	edx, edx	; Value = 0
.MinMaxLoop:
	mov	dl, [HMap+ecx]	; Get the value
	cmp	edx, eax
	jge	.NotNewMin		; Set new min if less than old min
	mov	eax, edx
.NotNewMin:
	cmp	edx, ebx
	jle	.NotNewMax		; Set new max if greater than old max
	mov	ebx, edx
.NotNewMax:
	inc	ecx
	cmp	ecx, MAP_SIZE
	jb	.MinMaxLoop		; Loop though entire array

	; Normalize HMap to the minimum (subtract out the minimum value)
	xor	ecx, ecx	; Counter = 0
	xor	edx, edx	; Value = 0
.NormMinLoop:
	sub	[HMap+ecx], al
	inc	ecx
	cmp	ecx, MAP_SIZE
	jb	.NormMinLoop		; Loop through entire array

	pop	ds

	sub	ebx, eax		; Set new maximum
;	mov	[_HMap_Max], ebx	; Save new maximum

	; Break down texture map groups
	push	es
	mov	es, [_MemBlock1]
	mov	eax, TMapByte		; Pointer to TMapByte
.TexLoopH:
	mov	esi, TMAP_W
.TexLoopW:
	xor	ecx, ecx
	mov	cl, byte [es:eax]
	sub	ecx, 2
	cmp	ecx, 25
	ja	.DefaultTex				; Not in mapping table, just go with default
	
	xor	edx, edx
	mov	dl, byte [TexMapping + ecx]		; Get mapped value from table
	mov	byte [es:eax], dl                       ; Save mapped value back into array
	jmp	.TexEndTable

.DefaultTex:
	mov	byte [es:eax], MY_BUILD

.TexEndTable:
	inc	eax			; Advance pointer
	dec	esi			; Decrease W counter
	jnz	.TexLoopW		;  and jump if not done with line
	cmp	eax, TMapByte + MAP_SIZE
	jb	.TexLoopH		; Keep going until entire map is done
	pop	es

	; Fill TMap from TMapByte
	; Basically what this does is store, for each pixel on the map,
	;  a dword-aligned structure containing the height of the pixel
	;  and the 3 other pixels adjacant to it.  This preprocessing will
	;  give a major speedup to the animation code.
	push	fs					; Save and set segment
	push	gs					;  registers
	mov	fs, [_MemBlock1]
	mov	gs, [_MemBlock2]
%if 1
	xor	esi, esi
	mov	edi, TMap
	mov	edx, TMapByte
.FillLoopH:
	lea	ecx, [esi+1]
	mov	[ebp+.j], ecx
	and	ecx, TMAP_HM
	xor	eax, eax
	shl	ecx, TMAP_WS
	mov	[ebp+.tmp], ecx
	mov	[ebp+.i], edi
	jmp	.FillLoopWInner
.FillLoopW:
	mov	ecx, [ebp+.tmp]
.FillLoopWInner:
	xor	ebx, ebx
	lea	edi, [eax+1]
	mov	esi, edi
	and	esi, TMAP_WM
	mov	bh, [fs:TMapByte+esi+ecx]
	mov	bl, [fs:TMapByte+eax+ecx]
	xor	ecx, ecx
	mov	cl, [fs:esi+edx]
	shl	ebx, 8
	or	ebx, ecx
	xor	ecx, ecx
	mov	cl, [fs:eax+edx]
	shl	ebx, 8
	mov	eax, edi
	or	ebx, ecx
	mov	ecx, [ebp+.i]

	mov	[gs:ecx], ebx			; Store into TMap dword

	add	ecx, 4
	cmp	eax, TMAP_W
	mov	[ebp+.i], ecx
	jb	.FillLoopW

	mov	esi, [ebp+.j]
	add	edx, TMAP_H
	cmp	edx, TMapByte + MAP_SIZE
	mov	edi, ecx

	jb	.FillLoopH				; Loop until done with bitmap

%else
	push	ebp
	xor	ecx, ecx
	mov	ebp, TMap
        mov     edx, TMapByte
.FillLoopH2:
	xor	eax, eax				; i = 0
	inc	ecx
	mov	edi, ecx				; j1 = (j+1) % TMAP_H
	and	edi, TMAP_HM
	shl	edi, TMAP_WS				; * TMAP_W
.FillLoopW2:
	mov	esi, eax				; i1 = (i+1) % TMAP_W
	inc	esi
	and	esi, TMAP_WM
	mov	bh, byte [fs:TMapByte + edi+esi]	; = j1 * TMAP_W + i1	(j+1,i+1) >> 24
	mov	bl, byte [fs:TMapByte + edi+eax]	; = j1 * TMAP_W + i	(j+1,i  ) >> 16
	mov	dh, byte [fs:ebp + esi]			; = j  * TMAP_W + i1	(j  ,i+1) >> 8
	mov	dl, byte [fs:ebp + eax]			; = j  * TMAP_W + i	(j  ,i  )
	shl	ebx, 16
	mov	bx, dx

	inc	eax
	cmp	eax, TMAP_W
	mov	dword [gs:TMap], ebx			; Store into TMap dword
	jb	.FillLoopW2				; Loop until done with line

	add	ebp, TMAP_W
	cmp	ebp, TMapByte+MAP_SIZE
	jb	.FillLoopH2				; Loop until done with bitmap
	pop	ebp					; Restore registers
%endif	
	pop	gs
	pop	fs

	; Precalculate lighting values
	invoke	_CalcLight, dword 0, dword 0, dword (MAP_W-1), dword (MAP_H-1)
	
	xor	eax, eax			; Return success
	jmp	.done
.error:
	mov	ax, 1				; Return error
.done:
	pop	edi				; restore caller's register variables
	pop	esi
	mov     esp,ebp				; discard storage for local variables

endproc

;----------------------------------------
; void CalcLight(int x1, int y1, int x2, int y2);
; Calculates lighting values for (x1,y1)-(x2,y2) HMap array
;----------------------------------------
proc _CalcLight

%$x1		arg	4		; Starting x location
%$y1		arg	4		; Starting y location
%$x2		arg	4		; Ending x location
%$y2		arg	4		; Ending y location

.max			equ	-4		; local storage for maximum distance (pass 1)
.d			equ	-8		; local storage for distance (pass 2)
.STACK_FRAME_SIZE	equ	8

	sub	esp, .STACK_FRAME_SIZE	; allocate space for local vars

	mov	ebx, dword [ebp + %$x1]
	push	esi			; Save registers
	push	edi
	push	es			; Point es to LMap segment			
	mov	es, [_MemBlock1]
	
	;
	; Pass #1: Find maximum distance
	;
	xor	eax, eax
	mov	ecx, MAP_SIZE/4		; Zero out LMap 4 bytes at a time
	mov	edi, LMap
	rep stosd

	mov	ecx, dword [ebp + %$y1]
	mov	esi, dword [ebp + %$y2]
	mov	dword [ebp + .max], 0	; max = 0 at start

	mov	edx, ecx				; startptr = y1
	shl	edx, MAP_WS				; startptr *= MAP_W
	add	edx, ebx				; startptr += x1
	sub	esi, ecx				; height = y2 - y1
	inc	esi					; height++
	push	esi					; Save row counter on stack

.Loop1Row:
	mov	esi, dword [ebp + %$x2]			; width = x2 - x1
	sub	esi, ebx
	inc	esi					; width++
.Loop1Col:
	; Get 4 surrounding pixels (h00,h01,h10,h11) and calculate vertical distance
	;  (Clobbers eax, ebx, ecx, edi)
	xor	ecx, ecx				; Zero high 24 bits of ecx
	lea	eax, [edx+(MAP_W+1)]			; Load address for h11
	and	eax, MAP_MASK				; Don't overrun
	mov	cl, byte [es:HMap+eax]			; h11 = HMap[ ((i+1) * MAP_W + (j+1)) & MAP_MASK ]

	xor	ebx, ebx				; Zero high 24 bits of ebx
	lea	edi, [edx+(MAP_W-1)]			; Load address for h10
	and	edi, MAP_MASK				; Don't overrun

	mov	eax, ecx				; Move h11 into eax

	lea	ecx, [edx-(MAP_W+1)]			; Load address for h00
	and	ecx, MAP_MASK				; Don't overrun
	mov	bl, byte [es:HMap+ecx]			; h00 = HMap[ ((i-1) * MAP_W + (j-1)) & MAP_MASK ]

	lea	ecx, [edx-(MAP_W-1)]			; Load address for h01
	and	ecx, MAP_MASK				; Don't overrun

	sub	eax, ebx				; dx = h11 - h00

	; Calculate distance (d = dx^2 + dy^2);
	imul	eax, eax				; d = dx^2

	mov	bl, byte [es:HMap+ecx]			; h01 = HMap[ ((i-1) * MAP_W + (j+1)) & MAP_MASK ]

	xor	ecx, ecx				; Zero high 24 bits of ecx
	mov	cl, byte [es:HMap+edi]			; h10 = HMap[ ((i+1) * MAP_W + (j-1)) & MAP_MASK ]

	sub	ecx, ebx				; dy = h10 - h01

	imul	ecx, ecx				; dy = dy^2

	mov	edi, dword [ebp + .max]			; Fetch max while waiting for imul

	add	eax, ecx				; d += dy

	cmp	edi, eax				; New maximum?
	jge	.NotNewMax
	mov	dword [ebp + .max], eax			; Yes, save it.

.NotNewMax:
	inc	edx					; Next pixel
	dec	esi					; Decrement column counter
	jne	.Loop1Col				; Loop if not done with row

	pop	esi					; Retrieve row counter

	mov	ebx, dword [ebp + %$x1]
	add	edx, ebx				; Jump to next row (startptr += x1)

	dec	esi					; Decrement row counter
	push	esi					; Save again on stack
	jne	.Loop1Row				; Loop if not done with bitmap

	fild	dword [ebp + .max]			; norm = 1024.0 / sqrt(max);
	fsqrt
	pop	esi					; Get row counter off the stack while fsqrt is running
	fdivr	qword [NormalConstant]

	;
	; Pass #2: Calculate lightmap using normal
	;
	mov	ecx, dword [ebp + %$y1]
	mov	esi, dword [ebp + %$y2]

	mov	edx, ecx				; startptr = y1
	shl	edx, MAP_WS				; startptr *= MAP_W
	add	edx, ebx				; startptr += x1
	sub	esi, ecx				; height = y2 - y1
	inc	esi					; height++
	push	esi					; Save row counter on stack

.Loop2Row:
	mov	esi, dword [ebp + %$x2]			; width = x2 - x1
	sub	esi, ebx
	inc	esi					; width++
.Loop2Col:
	; Get 4 surrounding pixels (h00,h01,h10,h11) and calculate vertical distance
	;  (Clobbers eax, ebx, ecx, edi)
	xor	ecx, ecx				; Zero high 24 bits of ecx
	lea	eax, [edx+(MAP_W+1)]			; Load address for h11
	and	eax, MAP_MASK				; Don't overrun
	mov	cl, byte [es:HMap+eax]			; h11 = HMap[ ((i+1) * MAP_W + (j+1)) & MAP_MASK ]

	xor	ebx, ebx				; Zero high 24 bits of ebx
	lea	edi, [edx+(MAP_W-1)]			; Load address for h10
	and	edi, MAP_MASK				; Don't overrun

	mov	eax, ecx				; Move h11 into eax

	lea	ecx, [edx-(MAP_W+1)]			; Load address for h00
	and	ecx, MAP_MASK				; Don't overrun
	mov	bl, byte [es:HMap+ecx]			; h00 = HMap[ ((i-1) * MAP_W + (j-1)) & MAP_MASK ]

	lea	ecx, [edx-(MAP_W-1)]			; Load address for h01
	and	ecx, MAP_MASK				; Don't overrun

	sub	eax, ebx				; dx = h11 - h00

	; Calculate distance (d = dx^2 + dy^2);
	imul	eax, eax				; d = dx^2

	mov	bl, byte [es:HMap+ecx]			; h01 = HMap[ ((i-1) * MAP_W + (j+1)) & MAP_MASK ]

	xor	ecx, ecx				; Zero high 24 bits of ecx
	mov	cl, byte [es:HMap+edi]			; h10 = HMap[ ((i+1) * MAP_W + (j-1)) & MAP_MASK ]

	sub	ecx, ebx				; dy = h10 - h01

	imul	ecx, ecx				; dy = dy^2

	mov	edi, dword [ebp + .max]			; Fetch max while waiting for imul

	add	eax, ecx				; d += dy

	mov	dword [ebp + .d], eax			; Transfer d into FPU
	fild	dword [ebp + .d]
	fsqrt						; t = sqrt(d) * norm
	fmul	ST0, ST1

	fcom	qword [LightHigh]			; If t > 255.0
	fnstsw	ax
	test	ah, 65
	jne	.NotTooHigh
	fstp	ST0
	fld	qword [LightHigh]			; t = 255.0

.NotTooHigh:
	fcom	qword [LightLow]			; If t < 0.0
	fnstsw	ax
	test	ah, 1
	je	.NotTooLow
	fstp	ST0
	fld	qword [LightLow]			; t = 0.0

.NotTooLow:
	fistp	dword [ebp + .d]			; Overwrites .d but we don't care
	mov	eax, edx				; Load address to write to
	and	eax, MAP_MASK				; Don't overrun
	mov	ebx, dword [ebp + .d]			; Get data
	mov	byte [es:LMap+eax], bl			; Write data to LMap

	inc	edx					; Next pixel
	dec	esi					; Decrement column counter
	jne	near .Loop2Col				; Loop if not done with row

	pop	esi					; Retrieve row counter

	mov	ebx, dword [ebp + %$x1]
	add	edx, ebx				; Jump to next row (startptr += x1)

	dec	esi					; Decrement row counter
	push	esi					; Save again on stack
	jne	near .Loop2Row				; Loop if not done with bitmap

	pop	esi					; Get row counter off the stack

	pop	es

	push	edi
	push	esi
	mov     esp, ebp				; discard storage for local variables

endproc

;----------------------------------------
; bool LoadBMP(char *Name, short NameLen,
;  short Whereseg, void *Where)
; Reads a 8-bit BMP file into a 32-bit buffer.
;----------------------------------------
proc _LoadBMP

%$Name		arg	4		; Pointer (in DS) to the name of the file to open
%$NameLen	arg	2		; Length of the filename, in bytes
%$Whereseg	arg	2		; The selector in which *where is located
%$Where		arg	4		; Pointer (in whereseg) to where to load the data

.file		equ	-4		; File handle (4 bytes)
.width		equ	-8		; Image width (from header)
.height		equ	-12		; Image height (from header)

.STACK_FRAME_SIZE	equ	12

	sub	esp, .STACK_FRAME_SIZE	; allocate space for local vars
	push	esi
	push	edi
        push    ebx

	; Open File
	invoke	_OpenFile, dword [ebp+%$Name], word [ebp+%$NameLen], word 0
	cmp	eax, -1
	jz	near .error
	mov	dword [ebp + .file], eax

	; Read Header
	invoke	_ReadFile, dword [ebp + .file], word [_ScratchBlock], dword (512*1024), dword 54

	; Save width and height
	push	gs
	mov	gs, [_ScratchBlock]		; Point gs at the header

	mov	eax, [gs:(512*1024+12h)]	; Get width from header
	mov	[ebp + .width], eax
	mov	eax, [gs:(512*1024+16h)]	; Get height from header
	mov	[ebp + .height], eax
	
	pop	gs				; Restore gs
	
	; Read Palette
	invoke	_ReadFile, dword [ebp + .file], word [_ScratchBlock], dword (512*1024), dword 1024
	
	; Read in data a row at a time
	mov	ebx, [ebp+.height]	; Start offset at lower
        dec     ebx                     ;  left hand corner (bitmap
        imul    ebx, dword [ebp+.width] ;  goes from bottom up)
	xor	edi, edi		; Start with row 0
.NextRow:
	push	ebx
	invoke	_ReadFile, dword [ebp + .file], word [_ScratchBlock], dword (513*1024), dword [ebp + .width]	; Read row
	pop	ebx
	xor	esi, esi		; Start with column 0
	xor	edx, edx

	push	ds					; Redirect ds to avoid using segment offsets
	mov	ds, [_ScratchBlock]
	push	es					; Redirect es to destination area
	mov	es, [ebp + %$Whereseg]

.NextCol:
	xor	ecx, ecx				; Clear registers
	xor	eax, eax
	mov	al, [513*1024 + esi]			; Get color index from line buffer
	shl	eax, 2					; Load address in palette of bgrx quad
	mov	ecx, [512*1024 + eax]			; Get bgrx quad
	mov	eax, [ebp + %$Where]			; Get starting address to write to
	mov	[es:eax+ebx*4], ecx			; Write to 32-bit buffer

	inc	ebx				; Increment byte count
	inc	esi				; Increment column count
	cmp	esi, dword [ebp + .width]	; Done with the column?
	jne	.NextCol

	pop	es				; Get back to normal ds and es
	pop	ds

        sub     ebx, [ebp+.width]               ; Get to previous row
        sub     ebx, [ebp+.width]
	inc	edi				; Increment row count
	cmp	edi, dword [ebp + .height]      ; Done with the image?
	jne	.NextRow

	; Close File
	invoke	_CloseFile, dword [ebp + .file]

	xor	eax, eax
	jmp	.done
.error:
	mov	eax, -1
.done:
	pop     ebx
	pop	edi
	pop	esi
	mov     esp, ebp			; discard storage for local variables

endproc

;----------------------------------------
; bool MixTexMap(char *src, short srcSeg,
;  char *Texture, short TextureSeg, short TexNum,
;  int TILE_W_SH, int TILE_H_SH, int shift)
; Mixes the loading image into the texture
;  format used by the renderer.
;----------------------------------------
proc _MixTexMap

%$src		arg	4		; Pointer (in srcSeg) to the source image
%$srcSeg	arg	2		; The selector in which *src is located
%$Texture	arg	4		; Pointer (in TextureSeg) to where to save the texture
%$TextureSeg	arg	2		; The selector in which *Texture is located
%$TexNum        arg     2               ; The texture the image is for
%$TILE_W_SH     arg     4               ; The texture width (in powers of 2)
%$TILE_H_SH     arg     4               ; The texture height (in powers of 2)
%$shift         arg     4               ; The shift size (should be 8-(width_sh=height_sh))

.i		equ	-4		; loop vars
.j		equ	-8
.RANGE          equ     -12
.TILE_W		equ	-16             ; Tile Width (2^TILE_W_SH)
.TILE_H         equ     -20             ; Tile Height (2^TILE_H_SH)
.r              equ     -21             ; color components
.g              equ     -22
.b              equ     -23
.a              equ     -24
.c00            equ     -28             ; 4 color quads to store
.c01            equ     -32
.c10            equ     -36
.c11            equ     -40

.Shuffle        equ     512*1024        ; Offset of Shuffle array in ScratchBlock

.STACK_FRAME_SIZE	equ	40

	sub	esp, .STACK_FRAME_SIZE	; allocate space for local vars
	push	esi
	push	edi

        push    es
        mov     es, [_ScratchBlock]

        mov     eax, 1
        mov     ecx, [ebp+%$TILE_W_SH]
        shl     eax, cl
        mov     [ebp+.TILE_W], eax

        mov     eax, 1
        mov     ecx, [ebp+%$TILE_H_SH]
        shl     eax, cl
        mov     [ebp+.TILE_H], eax

        cmp     byte [ShuffleInitDone], 1
        je      near .NoShuffleInitNeeded

        mov     byte [ShuffleInitDone], 1

        ; for(j=0;j<TILE_H;j++)
	; for(i=0;i<TILE_W;i++)
	;  shuffle[ j*TILE_W + i ] = (j<<8) | i;

	xor	ebx, ebx
        mov     edi, .Shuffle
	mov	ecx, [ebp+.TILE_W]

.ShuffleLoop1j:

	xor	eax, eax

.ShuffleLoop1i:

	mov	edx, ebx
	shl	edx, 8
	or	edx, eax

	mov	[es:edi+eax*2], dx

	inc	eax

	cmp	eax, ecx

	jne	.ShuffleLoop1i

	inc	ebx
	lea	edi, [edi+ecx*2]

	cmp	ebx, [ebp+.TILE_H]

	jne	.ShuffleLoop1j

; for(RANGE=4;RANGE>=1;RANGE--)
; for(j=RANGE;j<TILE_H-RANGE;j++)
; for(i=RANGE;i<TILE_W-RANGE;i++)

	mov	edx, 4
	mov	[ebp+.RANGE], edx

.ShuffleLoop2r:

	mov	[ebp+.j], edx

.ShuffleLoop2j:

	mov	ebx, [ebp+.RANGE]

.ShuffleLoop2i:

; uint16 x;
; unsigned ri = i + rand()%(RANGE*2+1) - RANGE;
; unsigned rj = j + rand()%(RANGE*2+1) - RANGE;
; x = shuffle[ j*TILE_W + i ];
; shuffle[ j*TILE_W + i ] = shuffle[ rj*TILE_W + ri ];
; shuffle[ rj*TILE_W + ri ] = x;

	mov	esi, [ebp+.j]
	mov	edi, esi
	mov	ecx, [ebp+%$TILE_W_SH]
	shl	esi, cl
	add	esi, ebx

	mov	ecx, [ebp+.RANGE]
	shl	ecx, 1
	inc	ecx

	push	ebx
	push	ecx
	call	_rand
	pop	ecx
	pop	ebx
	cdq
	idiv	ecx

	add	edi, edx
	sub	edi, [ebp+.RANGE]
	mov	ecx, [ebp+%$TILE_W_SH]
	shl	edi, cl
	add	edi, ebx
	add	edi, edx
	sub	edi, [ebp+.RANGE]

	shl	esi, 1			; 2-byte array elements
	shl	edi, 1

	add	esi, .Shuffle	; Point into shuffle array
	add	edi, .Shuffle

	; Now swap array values
	xor	eax, eax
	mov	ax, [es:esi]
	xor	edx, edx
	mov	dx, [es:edi]
	mov	[es:esi], dx
	mov	[es:edi], ax

	inc	ebx
	mov	eax, [ebp+.TILE_W]
	mov	edx, [ebp+.RANGE]
	sub	eax, edx
	cmp	ebx, eax
	jl	.ShuffleLoop2i

	mov	ebx, [ebp+.j]
	mov	eax, [ebp+.TILE_H]
	inc	ebx
	sub	eax, edx
	mov	[ebp+.j], ebx
	cmp	ebx, eax
	jl	.ShuffleLoop2j

	dec	edx
	mov	[ebp+.RANGE], edx
	cmp	edx, 1
	jge	near .ShuffleLoop2r

.NoShuffleInitNeeded:

        push    fs
        push    gs
        mov     fs, [ebp+%$srcSeg]
        mov     gs, [ebp+%$TextureSeg]

; shift += shift

	shl	dword [ebp+%$shift], 1

; for( adr = j = 0; j < TILE_H; j ++ )
; for( i = 0; i < TILE_W; i ++, adr ++ )

	xor	edi, edi

	mov	dword [ebp+.j], 0

.ColorLoop_j:

	mov	dword [ebp+.i], 0

.ColorLoop_i:

	mov	edx, edi
	shl	edx, 2			; 4-byte array entries
	add	edx, [ebp+%$src]
	mov	ecx, [fs:edx]

	; Get r,g,b,a components
	mov	[ebp+.r], cl
	mov	[ebp+.g], ch
	shr	ecx, 16
	mov	[ebp+.b], cl
	mov	[ebp+.a], ch

; [ebx] iii = (i << cells_by_x) % TILE_W;
; [edx] jjj = (j << cells_by_x) % TILE_H;

	mov	ecx, [Cells_by_x]
	mov	eax, [ebp+.i]
	mov	ebx, [ebp+.j]
	shl	eax, cl
	shl	ebx, cl
	cdq
	idiv	dword [ebp+.TILE_W]
	mov	eax, ebx
	mov	ebx, edx
	cdq
	idiv	dword [ebp+.TILE_H]

; [edx] ii = shuffle[ jjj * TILE_W + iii ] & 0xFF;
; [ecx] jj = shuffle[ jjj * TILE_W + iii ] >> 8;

	imul	edx, [ebp+.TILE_W]
	add	edx, ebx
	shl	edx, 1			; 2-byte array elements
	add	edx, .Shuffle
	xor	ebx, ebx
	mov	bx, [es:edx]

	xor	edx, edx
	mov	dl, bl
	xor	ecx, ecx
	mov	cl, bh

; [edx] f00 = (TILE_W*TILE_H - TILE_W * ii - TILE_H * jj + ii * jj)<<shift;
; [eax] f01 = (TILE_W * ii - ii * jj)<<shift;
; [ebx] f10 = (TILE_H * jj - ii * jj)<<shift;
; [esi] f11 = (ii * jj)<<shift;

	mov	eax, [ebp+.TILE_W]
	imul	eax, edx
	mov	ebx, [ebp+.TILE_H]
	imul	ebx, ecx
	mov	esi, edx
	imul	esi, ecx

	mov	edx, [ebp+.TILE_W]
	imul	edx, [ebp+.TILE_H]
	sub	edx, eax
	sub	edx, ebx
	add	edx, esi

	sub	eax, esi

	sub	ebx, esi

	mov	ecx, [ebp+%$shift]
	shl	edx, cl
	shl	eax, cl
	shl	ebx, cl
	shl	esi, cl

	push	esi			; push fxx values onto stack to
	push	ebx			;  free up registers for color
	push	eax			;  processing

	mov	esi, edx		; Get f00

; [eax] r00 = (f00 * r) >> 16;
; [ebx] g00 = (f00 * g) >> 16;
; [ecx] b00 = (f00 * b) >> 16;
; [edx] a00 = (f00 * a) >> 16;
; [eax] c00 = r00 | (g00<<8) | (b00<<16) | (a00<<24) ;
	xor	eax, eax
	mov	al, [ebp+.r]
	imul	eax, esi
	xor	ebx, ebx
	mov	bl, [ebp+.g]
	imul	ebx, esi
	xor	ecx, ecx
	mov	cl, [ebp+.b]
	imul	ecx, esi
	xor	edx, edx
	mov	dl, [ebp+.a]
	imul	edx, esi

	shr	eax, 16
	shr	ebx, 16
	shr	ecx, 16
	shr	edx, 16

	or	ah, bl
	or	ch, dl
	shl	ecx, 16
	or	eax, ecx

	mov	[ebp+.c00], eax

	pop	esi			; Get f01

; [eax] r01 = (f01 * r) >> 16;
; [ebx] g01 = (f01 * g) >> 16;
; [ecx] b01 = (f01 * b) >> 16;
; [edx] a01 = (f01 * a) >> 16;
; [eax] c01 = r01 | (g01<<8) | (b01<<16) | (a01<<24) ;
	xor	eax, eax
	mov	al, [ebp+.r]
	imul	eax, esi
	xor	ebx, ebx
	mov	bl, [ebp+.g]
	imul	ebx, esi
	xor	ecx, ecx
	mov	cl, [ebp+.b]
	imul	ecx, esi
	xor	edx, edx
	mov	dl, [ebp+.a]
	imul	edx, esi

	shr	eax, 16
	shr	ebx, 16
	shr	ecx, 16
	shr	edx, 16

	or	ah, bl
	or	ch, dl
	shl	ecx, 16
	or	eax, ecx

	mov	[ebp+.c01], eax

	pop	esi				; Get f10

; [eax] r10 = (f10 * r) >> 16;
; [ebx] g10 = (f10 * g) >> 16;
; [ecx] b10 = (f10 * b) >> 16;
; [edx] a10 = (f10 * a) >> 16;
; [eax] c10 = r10 | (g10<<8) | (b10<<16) | (a10<<24) ;
	xor	eax, eax
	mov	al, [ebp+.r]
	imul	eax, esi
	xor	ebx, ebx
	mov	bl, [ebp+.g]
	imul	ebx, esi
	xor	ecx, ecx
	mov	cl, [ebp+.b]
	imul	ecx, esi
	xor	edx, edx
	mov	dl, [ebp+.a]
	imul	edx, esi

	shr	eax, 16
	shr	ebx, 16
	shr	ecx, 16
	shr	edx, 16

	or	ah, bl
	or	ch, dl
	shl	ecx, 16
	or	eax, ecx

	mov	[ebp+.c10], eax

	pop		esi			; Get f11

; [eax] r11 = (f11 * r) >> 16;
; [ebx] g11 = (f11 * g) >> 16;
; [ecx] b11 = (f11 * b) >> 16;
; [edx] a11 = (f11 * a) >> 16;
; [eax] c11 = r11 | (g11<<8) | (b11<<16) | (a11<<24) ;
	xor	eax, eax
	mov	al, [ebp+.r]
	imul	eax, esi
	xor	ebx, ebx
	mov	bl, [ebp+.g]
	imul	ebx, esi
	xor	ecx, ecx
	mov	cl, [ebp+.b]
	imul	ecx, esi
	xor	edx, edx
	mov	dl, [ebp+.a]
	imul	edx, esi

	shr	eax, 16
	shr	ebx, 16
	shr	ecx, 16
	shr	edx, 16

	or	ah, bl
	or	ch, dl
	shl	ecx, 16
	or	eax, ecx

	mov	[ebp+.c11], eax

; textures[ adr ][ tc ][ 0 ] = c00;
; textures[ adr ][ tc ][ 1 ] = c01;
; textures[ adr ][ tc ][ 2 ] = c10;
; textures[ adr ][ tc ][ 3 ] = c11;

        xor     eax, eax
	mov	ax, [ebp+%$TexNum]
	mov	ecx, [ebp+%$Texture]
	shl	eax, 4
	lea	esi, [eax+ecx]
	mov	eax, edi
	shl	eax, 7
	add	esi, eax

	mov	eax, [ebp+.c00]
	mov	ebx, [ebp+.c01]
	mov	ecx, [ebp+.c10]
	mov	edx, [ebp+.c11]
	mov	[gs:esi], eax
	mov	[gs:esi+4], ebx
	mov	[gs:esi+8], ecx
	mov	[gs:esi+12], edx

	mov	eax, [ebp+.i]
	inc	edi
	inc	eax
	cmp	eax, [ebp+.TILE_W]
	mov	[ebp+.i], eax
	jl	near .ColorLoop_i

	mov	eax, [ebp+.j]
	inc	eax
	cmp	eax, [ebp+.TILE_H]
	mov	[ebp+.j], eax
	jl	near .ColorLoop_j

        pop     gs
        pop     fs

	pop     es

	pop	edi
	pop	esi
	mov     esp, ebp			; discard storage for local variables

endproc

;----------------------------------------
; bool LoadTEX(char *Name, short NameLen, short TexNum)
; Loads and prepares a texture by calling
;  LoadBMP and MixTexMap.
;----------------------------------------
proc _LoadTEX

%$Name		arg	4			; Base name of the texture to load (pointer into DS)
%$NameLen	arg	2			; Length of the base name, in bytes
%$TexNum	arg	2			; Number of the texture to load (index into texture array)

	invoke	_LoadBMP, dword [ebp+%$Name], word [ebp+%$NameLen], word [_ScratchBlock], dword 0	; Load the image
	cmp	eax, -1
	jz	.error

        invoke  _MixTexMap, dword 0, word [_ScratchBlock], dword 0, word [_TextureBlock], word [ebp+%$TexNum], dword 8, dword 8, dword 0

	xor	ax, ax
	jmp	.done
.error:
	mov	ax, 1
.done:

endproc

;----------------------------------------
; bool LoadSprite(char *Name, short NameLen, short SpriteNum)
; Loads a sprite by calling LoadBMP.
;----------------------------------------
proc _LoadSprite

%$Name		arg	4			; Filename of the sprite to load (pointer into DS)
%$NameLen	arg	2			; Length of the base name, in bytes
%$TexNum	arg	2			; Number of the sprite to load (index into sprite array)

        xor     eax, eax
        mov     ax, [ebp+%$TexNum]
        shl     eax, 18                 ; Each sprite is 256*256*4 bytes in size
	invoke	_LoadBMP, dword [ebp+%$Name], word [ebp+%$NameLen], word [_SpritesBlock], dword eax	; Load the image
	cmp	eax, -1
	jz	.error

	xor	ax, ax
	jmp	.done
.error:
	mov	ax, 1
.done:

endproc

;----------------------------------------
; void ScreenShot(void);
;----------------------------------------
proc _ScreenShot

        push    edi

	mov     al, [ScreenShot_index]
        mov     [ScreenShot_fn+7], al
        inc     al
        mov     [ScreenShot_index], al

        invoke  _OpenFile, dword ScreenShot_fn, word ScreenShot_len, word 1
	mov     edi, eax

        invoke  _WriteFile, dword edi, word [_VideoBlock], dword Video, dword (WINDOW_W*240*4)

        invoke  _CloseFile, dword edi
        
	pop     edi

endproc
