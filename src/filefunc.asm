; File handling functions
;  By Peter Johnson, 1999-2001
;
; $Id: filefunc.asm,v 1.14 2001/03/17 04:45:44 pete Exp $
%include "myC32.mac"
%include "dpmi_int.inc"

	BITS	32

	SECTION .text

;----------------------------------------
; int OpenFile(char *Filename, short WriteTo);
; Purpose: Opens a file for reading or writing.
; Inputs:  Filename, (path)name of the file to read	       
;	   WriteTo, 1 if create & open for writing, 0 for open to read
; Outputs: DOS handle to file
;----------------------------------------
proc _OpenFile

.Filename	arg	4   
.WriteTo	arg	2

	push	edi
	push	esi

	push	es			; First copy filename into transfer buffer
	mov	es, [_Transfer_Buf]
	mov	ax, [_Transfer_Buf_Seg]
	mov	[DPMI_DS], ax
	mov	esi, [ebp + .Filename]
	xor	edi, edi
.Copy:
	mov	al, [esi]
	mov	[es:edi], al
	inc	esi
	inc	edi
	or	al, al
	jnz	.Copy

	; First try using LFN services
	mov	word [DPMI_EAX], 716Ch	; [Windows95] LFN - Create or Open File
	mov	word [DPMI_EBX], 42h	; Commit after every write, read-write
	mov	word [DPMI_ECX], 0	; Attributes
	cmp	word [ebp + .WriteTo], 1
	je	.CreateNewLFN
	mov	word [DPMI_EDX], 1	; Open file
	jmp	short .DoOpenLFN
.CreateNewLFN:
	mov	word [DPMI_EDX], 2	; Truncate if already exists
.DoOpenLFN:
	mov	word [DPMI_ESI], 0	; DS:SI = filename
	mov	word [DPMI_EDI], 0	; Hint number
	mov	bx, 21h
	call	DPMI_Int
	test	word [DPMI_FLAGS], 1	; CF=0 => no error, we're done
	jz	.done

	; Error using LFN, use short FN API instead
	cmp	word [ebp + .WriteTo], 1
	je	.CreateNew
	mov	word [DPMI_EAX], 3D00h	; [DOS] Open Existing File (Read Only)
	jmp	short .DoOpen
.CreateNew:
	mov	word [DPMI_EAX], 3C00h	; [DOS] Create or Truncate File
.DoOpen:
	mov	word [DPMI_ECX], 0
	mov	word [DPMI_EDX], 0
	mov	bx, 21h
	call	DPMI_Int
	test	word [DPMI_FLAGS], 1	; Test the carry flag
	jne	.error

	movzx	eax, word [DPMI_EAX]	; Recover file handle

	jmp	short .done
.error:
	mov	eax, -1
.done:
	pop	esi
	pop	edi
	ret
endproc

;----------------------------------------
; void CloseFile(int Handle);
; Purpose: Closes an open file.
; Inputs:  Handle, DOS handle of the file to close.
; Outputs: None
;----------------------------------------
proc _CloseFile

.Handle		arg	4

	mov	ah, 3Eh			; [DOS] Close File
	mov	ebx, [ebp + .Handle]
	int	21h

	ret
endproc

;----------------------------------------
; int ReadFile(int Handle, void *Buffer, unsigned int Count);
; Purpose: Reads from a file.
; Inputs:  Handle, DOS handle of the file to read from
;	   Buffer, buffer to read into
;	   Count, number of bytes to read into buffer
; Outputs: Number of bytes actually read
;----------------------------------------
proc _ReadFile

.Handle		arg	4
.Buffer		arg	4
.Count		arg	4

	invoke	_ReadFile_Sel, dword [ebp+.Handle], ds, dword [ebp+.Buffer], dword [ebp+.Count]
	ret
endproc

;----------------------------------------
; int ReadFile_Sel(int Handle, short BufSel, void *Buffer, unsigned int Count);
; Purpose: Reads from a file.
; Inputs:  Handle, DOS handle of the file to read from
;	   BufSel, selector in which Buffer resides
;	   Buffer, pointer (into BufSeg) of buffer to read into
;	   Count, number of bytes to read into buffer
; Outputs: Number of bytes actually read
;----------------------------------------
_ReadFile_Sel_arglen	equ	14
proc _ReadFile_Sel

.Handle		arg	4
.BufSel		arg	2
.Buffer		arg	4
.Count		arg	4

.NGot		equ	-4		; local storage for total number of bytes read
.STACK_FRAME_SIZE	equ	4

	sub	esp, .STACK_FRAME_SIZE	; allocate space for local vars
	push	esi			; preserve caller's register variables
	push	edi
	push	es
        
	mov	ax, [_Transfer_Buf_Seg]
	mov	[DPMI_DS], ax

	mov	es, [ebp + .BufSel]	; Set segment to write to (PM data area)
	mov	edi, [ebp + .Count]	; Move count (of bytes to copy) into register
	mov	dword [ebp + .NGot], 0	; Set the number of bytes read = 0
.NextBlock:
	mov	esi, edi		; If the number of bytes remaining
	cmp	esi, 16*2048		;  to be read is less than the buffer size,
	jbe	.DoRead			;  only read that many bytes, otherwise
	mov	esi, 16*2048		;  read as much as we can (32k)
.DoRead:
	mov	dword [DPMI_EAX], 3F00h	; [DOS] Read from file
	mov	edx, [ebp + .Handle]
	mov	[DPMI_EBX], edx		; Handle to read from
	mov	[DPMI_ECX], esi		; Number of bytes to read
	mov	dword [DPMI_EDX], 0	; Read into transfer buffer starting at 0
	mov	bx, 21h
	call	DPMI_Int
	test	word [DPMI_FLAGS], 1	; Test the carry flag
	je	.UpdateCounts

	mov	eax, -1			; Return with error
	jmp	short .Done

.UpdateCounts:
	sub	edi, esi		; subtract bytes copied from total yet to read
	mov	ebx, [DPMI_EAX]		; get the actual # of bytes read
	add	[ebp + .NGot], ebx	; add to total read

	; Copy into PM memory from RM transfer buffer
	mov	edx, [ebp + .Buffer]	; Get current pointer into PM destination buffer
	push	ds
	mov	ds, [_Transfer_Buf]	; Set segment to read from (RM transfer buffer)
	push	edi			; Save registers
	push	esi

	mov	ecx, ebx		; Grab counter and divide by 4
	shr	ecx, 1
	shr	ecx, 1
	xor	esi, esi		; Start from address 0 in transfer buffer
	mov	edi, edx		; Pointer into PM destination buffer
	cld				; Make sure we count upward :)
	rep	movsd			; Copy 4 bytes at a time!

	; Finish last 1-3 bytes
	mov	ecx, ebx
	and	ecx, 3h
	rep	movsb

	pop	esi			; Restore registers
	pop	edi
	pop	ds

	add	[ebp + .Buffer], ebx	; Advance PM buffer pointer

	test	edi, edi		; Any bytes left to read? If not, then stop
	je	.CopyFinish
	cmp	ebx, esi		; Hit EOF? If not, then read the next block
	je	near .NextBlock

.CopyFinish:
	mov	eax, [ebp + .NGot]	; Return the number of bytes read
        
.Done:
	pop	es
	pop	edi			; restore caller's register variables
	pop	esi
	mov	esp,ebp			; discard storage for local variables
	ret
endproc

;----------------------------------------
; int WriteFile(int Handle, void *Buffer, unsigned int Count);
; Purpose: Writes to a file.
; Inputs:  Handle, DOS handle of the file to write to
;	   Buffer, buffer to read from
;	   Count, number of bytes to write out to the file
; Outputs: Number of bytes actually written
;----------------------------------------
proc _WriteFile

.Handle		arg	4
.Buffer		arg	4
.Count		arg	4

	invoke	_WriteFile_Sel, dword [ebp+.Handle], ds, dword [ebp+.Buffer], dword [ebp+.Count]
	ret
endproc

;----------------------------------------
; int WriteFile_Sel(int Handle, short BufSel, void *Buffer, unsigned int Count);
; Purpose: Writes to a file.
; Inputs:  Handle, DOS handle of the file to write to
;	   BufSel, selector in which Buffer resides
;	   Buffer, pointer (in BufSeg) of buffer to read from
;	   Count, number of bytes to write out to the file
; Outputs: Number of bytes actually written
;----------------------------------------
_WriteFile_Sel_arglen	equ	14
proc _WriteFile_Sel

.Handle		arg	4
.BufSel		arg	2
.Buffer		arg	4
.Count		arg	4

.NPut		equ	-4		; local storage for total number of bytes written
.STACK_FRAME_SIZE	equ	4

	sub	esp, .STACK_FRAME_SIZE	; allocate space for local vars
	push	esi			; preserve caller's register variables
	push	edi
	push	es

	mov	ax, [_Transfer_Buf_Seg]
	mov	[DPMI_DS], ax

	mov	es, [_Transfer_Buf]	; Set segment to write to (PM data area)
	mov	edi, [ebp + .Count]	; Move count (of bytes to copy) into register
	mov	dword [ebp + .NPut], 0	; Set the number of bytes written = 0
.NextBlock:
	mov	esi, edi		; If the number of bytes remaining
	cmp	esi, 16*2048		;  to be written is less than the buffer size,
	jbe	.DoWrite		;  only write that many bytes, otherwise
	mov	esi, 16*2048		;  write as much as we can (32k)
.DoWrite:
	; Copy into RM transfer buffer from PM memory
	mov	edx, [ebp + .Buffer]	; Get current pointer into PM destination buffer
	push	ds
	mov	ds, [ebp + .BufSel]	; Set segment to read from (PM memory)
	push	edi			; Save registers
	push	esi

	mov	ecx, esi		; Grab counter and divide by 4
	shr	ecx, 1
	shr	ecx, 1
	xor	edi, edi		; Start from address 0 in transfer buffer
	mov	esi, edx		; Pointer into PM destination buffer
	cld				; Make sure we count upward :)
	rep	movsd			; Copy 4 bytes at a time!

	pop	esi			; Restore registers
	pop	edi
	pop	ds

	mov	dword [DPMI_EAX], 4000h	; [DOS] Write to file
	mov	edx, [ebp + .Handle]
	mov	[DPMI_EBX], edx		; Handle to write to
	mov	[DPMI_ECX], esi		; Number of bytes to write
	mov	dword [DPMI_EDX], 0	; Write out of transfer buffer starting at 0
	mov	bx, 21h
	call	DPMI_Int
	test	word [DPMI_FLAGS], 1	; Test the carry flag
	je	.UpdateCounts

	mov	eax, -1			; Return with error
	jmp	short .Done

.UpdateCounts:
	sub	edi, esi		; subtract bytes copied from total yet to write
	mov	ebx, [DPMI_EAX]		; get the actual # of bytes write
	add	[ebp + .NPut], ebx	; add to total written
	add	[ebp + .Buffer], ebx	; Advance PM buffer pointer

	test	edi, edi		; Any bytes left to write? If not, then stop
	je	.CopyFinish
	cmp	ebx, esi		; Error? If not, then write the next block
	je	near .NextBlock

.CopyFinish:
	mov	eax, [ebp + .NPut]	; Return the number of bytes written

.Done:
	pop	es
	pop	edi			; restore caller's register variables
	pop	esi
	mov	esp,ebp			; discard storage for local variables
	ret
endproc

;----------------------------------------
; int SeekFile(int Handle, int Count, short From);
; Purpose: Moves current file position.
; Inputs:  Handle, DOS handle of the file to seek within
;	   Count, number of bytes to seek from position
;	   From, position to seek from: 0=start, 1=current, 2=end
; Outputs: New file position (in bytes, from start of file), -1 on error
;----------------------------------------
proc _SeekFile

.Handle		arg	4
.Count		arg	4
.From		arg	2

	mov	ah, 42h			; [DOS] Set Current File Position
	mov	al, [ebp+.From]
	mov	bx, [ebp+.Handle]
	mov	edx, [ebp+.Count]
	mov	ecx, edx		; Convert Count to CX:DX
	shr	ecx, 16
	int	21h
	jc	.error
	shl	edx, 16			; Convert DX:AX -> EAX
	mov	dx, ax
	mov	eax, edx
	ret
.error:
	xor	eax, eax
	dec	eax
	ret
endproc
