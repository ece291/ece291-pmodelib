; Various file loading functions
;  By Peter Johnson, 1999

%include "myC32.mac"
%include "constant.inc"
%include "globals.inc"
%include "file_func.inc"

        BITS    32

        EXTERN  _ScratchBlock
        EXTERN  _VideoBlock
        
        SECTION .data

ScreenShot_fn   db      'MP5Out?.raw',0 ; Filename of screenshot file
;ScreenShot_len  equ     $-ScreenShot_fn
ScreenShot_index        db      'A'

        SECTION .text

;----------------------------------------
; bool LoadBMP(char *Name, short Wheresel, void *Where)
; Purpose: Reads a 8 or 24-bit BMP file into a 32-bit buffer.
; Inputs:  Name, (path)name of the BMP file
;          NameLen, length of the Name string (in bytes)
;          Whereseg, selector in which Where resides
;          Where, pointer (in Whereseg) of data area
; Outputs: -1 on error, otherwise 0
;----------------------------------------
proc _LoadBMP

%$Name          arg     4  
%$Wheresel      arg     2
%$Where         arg     4     

.file           equ     -4              ; File handle (4 bytes)
.width          equ     -8              ; Image width (from header)
.height         equ     -12             ; Image height (from header)
.bytewidth      equ     -16             ; Image width (in bytes)

.STACK_FRAME_SIZE       equ     16

        sub     esp, .STACK_FRAME_SIZE  ; allocate space for local vars
        push    esi
        push    edi
        push    ebx

        ; Open File
        invoke  _OpenFile, dword [ebp+%$Name], word 0
        cmp     eax, -1
        jz      near .error
        mov     dword [ebp + .file], eax

        ; Read Header
        invoke  _ReadFile, dword [ebp + .file], word [_ScratchBlock], dword (512*1024), dword 54

        ; Save width and height
        push    gs
        mov     gs, [_ScratchBlock]             ; Point gs at the header

        cmp     word [gs:(512*1024+1Ch)], 24
        je      near .Bitmap24        
        
        mov     eax, [gs:(512*1024+12h)]        ; Get width from header
        mov     [ebp + .width], eax
        mov     eax, [gs:(512*1024+16h)]        ; Get height from header
        mov     [ebp + .height], eax
        
        pop     gs                              ; Restore gs
        
        ; Read Palette
        invoke  _ReadFile, dword [ebp + .file], word [_ScratchBlock], dword (512*1024), dword 1024
        
        ; Read in data a row at a time
        mov     ebx, [ebp+.height]      ; Start offset at lower
        dec     ebx                     ;  left hand corner (bitmap
        imul    ebx, dword [ebp+.width] ;  goes from bottom up)
        xor     edi, edi                ; Start with row 0
.NextRow:
        push    ebx
        invoke  _ReadFile, dword [ebp + .file], word [_ScratchBlock], dword (513*1024), dword [ebp + .width]    ; Read row
        pop     ebx
        xor     esi, esi                ; Start with column 0
        xor     edx, edx

        push    ds                                      ; Redirect ds to avoid using segment offsets
        mov     ds, [_ScratchBlock]
        push    es                                      ; Redirect es to destination area
        mov     es, [ebp + %$Wheresel]

.NextCol:
        xor     ecx, ecx                                ; Clear registers
        xor     eax, eax
        mov     al, [513*1024 + esi]                    ; Get color index from line buffer
        shl     eax, 2                                  ; Load address in palette of bgrx quad
        mov     ecx, [512*1024 + eax]                   ; Get bgrx quad
        mov     eax, [ebp + %$Where]                    ; Get starting address to write to
        mov     [es:eax+ebx*4], ecx                     ; Write to 32-bit buffer

        inc     ebx                             ; Increment byte count
        inc     esi                             ; Increment column count
        cmp     esi, dword [ebp + .width]       ; Done with the column?
        jne     .NextCol

        pop     es                              ; Get back to normal ds and es
        pop     ds

        sub     ebx, [ebp+.width]               ; Get to previous row
        sub     ebx, [ebp+.width]
        inc     edi                             ; Increment row count
        cmp     edi, dword [ebp + .height]      ; Done with the image?
        jne     .NextRow

        jmp     .CloseFile

.Bitmap24:
        mov     eax, [gs:(512*1024+12h)]        ; Get width from header
        mov     [ebp + .width], eax
        imul    eax, 3                          ; 24-bit bitmap -> 3 bytes/pixel
        mov     [ebp + .bytewidth], eax
        mov     eax, [gs:(512*1024+16h)]        ; Get height from header
        mov     [ebp + .height], eax

        pop     gs                              ; Restore gs

        ; Read in data a row at a time
        mov     ebx, [ebp+.height]      ; Start offset at lower
        dec     ebx                     ;  left hand corner (bitmap
        imul    ebx, [ebp+.width]       ;  goes from bottom up)
        xor     edi, edi                ; Start with row 0
.NextRow24:
        push    ebx
        invoke  _ReadFile, dword [ebp + .file], word [_ScratchBlock], dword (513*1024), dword [ebp + .bytewidth]    ; Read row
        pop     ebx
        xor     esi, esi                ; Start with column 0
        xor     edx, edx

        push    ds                                      ; Redirect ds to avoid using segment offsets
        mov     ds, [_ScratchBlock]
        push    es                                      ; Redirect es to destination area
        mov     es, [ebp + %$Wheresel]

.NextCol24:
        xor     ecx, ecx                                ; Clear registers
        xor     eax, eax
        mov     cl, [513*1024 + esi + 2]                ; Get red value from line buffer
        shl     ecx, 8        
        or      cl, [513*1024 + esi + 1]                ; Get green value from line buffer
        shl     ecx, 8
        or      cl, [513*1024 + esi]                    ; Get blue value from line buffer
        mov     eax, [ebp + %$Where]                    ; Get starting address to write to
        mov     [es:eax+ebx*4], ecx                     ; Write to 32-bit buffer

        inc     ebx                             ; Increment dest. pixel count
        add     esi, 3                          ; Increment column count
        cmp     esi, dword [ebp + .bytewidth]   ; Done with the column?
        jne     .NextCol24

        pop     es                              ; Get back to normal ds and es
        pop     ds

        sub     ebx, [ebp+.width]               ; Get to previous row
        sub     ebx, [ebp+.width]
        inc     edi                             ; Increment row count
        cmp     edi, dword [ebp + .height]      ; Done with the image?
        jne     .NextRow24

.CloseFile:
        ; Close File
        invoke  _CloseFile, dword [ebp + .file]

        xor     eax, eax
        jmp     .done
.error:
        mov     eax, -1
.done:
        pop     ebx
        pop     edi
        pop     esi
        mov     esp, ebp                        ; discard storage for local variables

endproc

;----------------------------------------
; void ScreenShot(void);
; Purpose: Saves the backbuffer as a raw graphics file.
; Inputs:  None
; Outputs: None
; Notes:   Uses global variable ScreenShot_fn to determine filename to write to.
;----------------------------------------
proc _ScreenShot

        push    edi

        mov     al, [ScreenShot_index]
        mov     [ScreenShot_fn+7], al
        inc     al
        mov     [ScreenShot_index], al

        invoke  _OpenFile, dword ScreenShot_fn, word 1
        mov     edi, eax

        invoke  _WriteFile, dword edi, word [_VideoBlock], dword 0, dword (WINDOW_W*WINDOW_H*4)

        invoke  _CloseFile, dword edi

        pop     edi

endproc
