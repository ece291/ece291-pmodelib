; Soundblaster driver. Supports DMA driven sample playback (mixing 
; up to eight samples at a time)
;  By Peter Johnson, 1999.
%include "myC32.mac"
%include "dma.inc"

        BITS 32

        EXTERN  __dos_ds       	; Selector into low 1 MB

; EOI macro
; Clobbers al
%macro EOI 1
        mov     al, 20h
        out     20h, al
        cmp     %{1}, 7
        jle     %%nothigh
        out     0A0h, al
%%nothigh:
%endmacro

%if 0
/* external interface to the digital SB driver */
static int sb_detect(int input);
static int sb_init(int input, int voices);
static void sb_exit(int input);
static int sb_mixer_volume(int volume);
static int sb_rec_cap_rate(int bits, int stereo);
static int sb_rec_cap_parm(int rate, int bits, int stereo);
static int sb_rec_source(int source);
static int sb_rec_start(int rate, int bits, int stereo);
static void sb_rec_stop();
static int sb_rec_read(void *buf);
%endif
        SECTION .data

sb_in_use       db 0            ; is SB being used?
sb_stereo       db 0            ; in stereo mode?
sb_recording    db 0            ; in input mode?
sb_16bit        db 0            ; in 16 bit mode?
sb_int          db -1           ; interrupt vector
sb_dma8         db -1           ; 8-bit DMA channel (SB16)
sb_dma16        db -1           ; 16-bit DMA channel (SB16)
sb_semaphore    db 0            ; reentrant interrupt?
sb_dsp_ver      dw -1           ; SB DSP version
sb_hw_dsp_ver   dw -1           ; as reported by autodetect
sb_dma_size     dd -1           ; size of dma transfer in bytes
sb_dma_mix_size dd -1           ; number of samples to mix
sb_dma_count    dd 0            ; need to resync with dma?

sb_sel          dw 0, 0         ; selectors for the buffers
sb_buf          dd 0, 0         ; pointers to the two buffers
sb_bufnum       db 0            ; the one currently in use
sb_recbufnum    db 0            ; the one to be returned

sb_master_vol   dw -1           ; stored mixer settings
sb_digi_vol     dw -1
sb_fm_vol       dw -1

_sb_freq 	dd -1           ; hardware parameters
_sb_port	dw -1
_sb_dma 	db -1
_sb_irq		db -1

;----------------------------------------
; int SB_Read_DSP(void)
; Purpose: Reads a byte from the SB DSP chip.
; Inputs:  None
; Outputs: The byte retrieved from the DSP, otherwise -1 on timeout
;----------------------------------------
_SB_Read_DSP

        xor     eax, eax
        mov     ecx, 0FFFFh
        mov     dx, [_sb_port]
        add     dx, 0Eh
.waitloop:
        in      al, dx
        and     al, 80h
        jz      .next
        sub     dx, 4           ; _sb_port+0Ah
        in      al, dx
        jmp     short .done
.next:
        dec     ecx
        jnz     .waitloop

        mov     eax, -1
.done:
        ret


;----------------------------------------
; bool SB_Write_DSP(unsigned short Value)
; Purpose: Writes a byte to the SB DSP chip.
; Inputs:  Value, byte to write (low byte of passed word)
; Outputs: 1 on timeout, otherwise 0
;----------------------------------------
_SB_Write_DSP_arglen    equ     2
proc _SB_Write_DSP

%$Value		arg	2

        xor     eax, eax
	mov     ecx, 0FFFFh
        mov     dx, [_sb_port]
        add     dx, 0Ch
.waitloop:
        in      al, dx
        and     al, 80h
        jnz     .next
        mov     ax, [ebp+%$Value]
        out     dx, al
        jmp     short .done
.next:
        dec     ecx
        jnz     .waitloop

        mov     eax, 1
.done:

endproc

;----------------------------------------
; void SB_Voice(bool State)
; Purpose: Turns the SB speaker on or off.
; Inputs:  State, 0 to turn speaker off, 1 to turn speaker on
; Outputs: None
;----------------------------------------
_SB_Voice_arglen        equ     4
proc _SB_Voice

%$State         arg     4

        cmp     dword [ebp+%$State], 0
        jz      near .TurnOff

        invoke  _SB_Write_DSP, word 0D1h

        cmp     word [sb_hw_dsp_ver], 0300h
        jl      near .Done

        ; Set up the mixer
        
        cmp     word [sb_master_vol], 0
        jge     .DontStoreMaster

        ; Store master volume
        xor     ax, ax
	mov     dx, [_sb_port]
        add     dx, 4
        mov     al, 22h
	out     dx, al
        inc     dx
        in      al, dx
        mov     [sb_master_vol], ax

.DontStoreMaster:

        cmp     word [sb_digi_vol], 0
        jge     .DontStoreDigi

        ; Store Digi volume
        xor     ax, ax
	mov     dx, [_sb_port]
        add     dx, 4
        mov     al, 4
	out     dx, al
        inc     dx
        in      al, dx
        mov     [sb_digi_vol], ax

.DontStoreDigi:

        cmp     word [sb_fm_vol], 0
        jge     .Done

        ; Store FM volume
        xor     ax, ax
	mov     dx, [_sb_port]
        add     dx, 4
        mov     al, 26h
	out     dx, al
        inc     dx
        in      al, dx
        mov     [sb_fm_vol], ax

        jmp     short .Done

.TurnOff:

        invoke  _SB_Write_DSP, word 0D3h

        cmp     word [sb_hw_dsp_ver], 0300h
        jl      .Done

        ; Reset previous mixer settings

        ; Restore master volume
        mov     dx, [_sb_port]
        add     dx, 4
        mov     al, 22h
        out     dx, al
        
        inc     dx
	mov     ax, [sb_master_vol]
        out     dx, al

	; Restore Digi volume
        dec     dx
        mov     al, 4
        out     dx, al

        inc     dx
        mov     ax, [sb_digi_vol]
        out     dx, al

        ; Restore FM volume
        dec     dx
        mov     al, 26h
        out     dx, al

        inc     dx
        mov     ax, [sb_fm_vol]
        out     dx, al

.Done:

endproc

;----------------------------------------
; bool SB_Set_Mixer(short digi_volume, short midi_volume)
; Purpose: Alters the SB-Pro hardware mixer.
; Inputs:  digi_volume, volume for Digi, 0-255 (or -1 to leave unchanged)
;          midi_volume, volume for FM, 0-255 (or -1 to leave unchanged)
; Outputs: eax=1 if not SB-Pro, 0 otherwise
;----------------------------------------
_SB_Set_Mixer_arglen    equ     4
proc _SB_Set_Mixer

%$digi_volume	arg	2
%$midi_volume   arg     2

        cmp     word [sb_hw_dsp_ver], 0300h
        jl      .NotSBPro

        mov     cx, [ebp+%$digi_volume]
        cmp     cx, 0
        jl      .DontSetDigi

        ; Set Digi volume
        mov     dx, [_sb_port]
        add     dx, 4
        mov     al, 4
        out     dx, al

        inc     dx
        mov     al, cl          ; swap nibbles of volume
        and     al, 0F0h
        shr     cl, 4
        or      al, cl
        out     dx, al

.DontSetDigi:
        mov     cx, [ebp+%$midi_volume]
        cmp     cx, 0
        jl      .DontSetMidi

        ; Set Digi volume
        mov     dx, [_sb_port]
        add     dx, 4
        mov     al, 26h
        out     dx, al

        inc     dx
        mov     al, cl          ; swap nibbles of volume
        and     al, 0F0h
        shr     cl, 4
        or      al, cl
        out     dx, al

.DontSetMidi:

        xor     eax, eax
        jmp     short .Done
.NotSBPro:
        mov     eax, 1
.Done:

endproc

;----------------------------------------
; bool SB_Mixer_Volume(short Volume)
; Purpose: Sets the SB mixer volume for playing digital samples.
; Inputs:  Volume, volume for Digi, 0-255 (-1 to leave unchanged)
; Outputs: eax=1 if not SB-Pro, 0 otherwise
;----------------------------------------
proc _SB_Mixer_Volume

%$Volume        arg     2

        invoke  _SB_Set_Mixer, word [ebp+%$Volume], word -1

endproc

;----------------------------------------
; void SB_Stereo_Mode(bool Enable)
; Purpose: Enables or disables stereo output for SB-Pro.
; Inputs:  Enable, 1, enables stereo, 0, disables stereo
; Outputs: None
;----------------------------------------
_SB_Stereo_Mode_arglen  equ     4
proc _SB_Stereo_Mode

%$Enable        arg     4

        mov     dx, [_sb_port]
        add     dx, 4
        mov     al, 0Eh
        out     dx, al
        
	inc     dx
        mov     eax, [ebp+%$Enable]
        cmp     al, 0
	jz      .Write
        mov     al, 2
.Write:
        out     dx, al

endproc

;----------------------------------------
; void SB_Input_Stereo_Mode(bool Enable)
; Purpose: Enables or disables stereo input for SB-Pro.
; Inputs:  Enable, 1, enables stereo, 0, disables stereo
; Outputs: None
;----------------------------------------
proc _SB_Input_Stereo_Mode

%$Enable        arg     4

        mov     eax, [ebp+%$Enable]
        cmp     al, 0
        jz      .Zero
        mov     ax, 0A8h
        jmp     short .Write
.Zero:
        mov     ax, 0A0h
.Write:
        invoke  _SB_Write_DSP, ax

endproc

;----------------------------------------
; void SB_Set_Sample_Rate(unsigned int Rate)
; Purpose: Sets the output sampling rate.
; Inputs:  Rate, the rate to set in Hz (samples per second)
; Outputs: None
;----------------------------------------
_SB_Set_Sample_Rate_arglen	equ     4
proc _SB_Set_Sample_Rate

%$Rate  	arg     4

        cmp     byte [sb_16bit], 0
        jz      .Not16bit

        invoke  _SB_Write_DSP, word 41h
        mov     eax, [ebp+%$Rate]
        shr     eax, 8
        invoke  _SB_Write_DSP, ax
        mov     eax, [ebp+%$Rate]
        invoke  _SB_Write_DSP, ax

        jmp     short .Done

.Not16bit:
        cmp     byte [sb_stereo], 0
        jz      .NotStereo
        shl     dword [ebp+%$Rate], 1   ; double the rate for stereo
.NotStereo:
        invoke  _SB_Write_DSP, word 40h
        mov     eax, 1000000
        xor     edx, edx
        div     dword [ebp+%$Rate]
        mov     edx, 256
        sub     edx, eax
        invoke  _SB_Write_DSP, word dx

.Done:

endproc

;----------------------------------------
; void SB_Set_Input_Sample_Rate(unsigned int Rate, bool Stereo)
; Purpose: Sets the input sampling rate.
; Inputs:  Rate, the rate to set in Hz (samples per second)
;          Stereo, 1=stereo input, 0=mono input
; Outputs: None
;----------------------------------------
proc _SB_Set_Input_Sample_Rate

%$Rate		arg	4
%$Stereo        arg     4

        cmp     byte [sb_16bit], 0
        jz      .Not16bit

        invoke  _SB_Write_DSP, word 42h
        mov     eax, [ebp+%$Rate]
        shr     eax, 8
        invoke  _SB_Write_DSP, ax
        mov     eax, [ebp+%$Rate]
        invoke  _SB_Write_DSP, ax

        jmp     short .Done

.Not16bit:
        cmp     dword [ebp+%$Stereo], 0
        jz      .NotStereo
        shl     dword [ebp+%$Rate], 1   ; double the rate for stereo
.NotStereo:
        invoke  _SB_Write_DSP, word 40h
        mov     eax, 1000000
        xor     edx, edx
        div     dword [ebp+%$Rate]
        mov     edx, 256
        sub     edx, eax
        invoke  _SB_Write_DSP, word dx

.Done:

endproc

;----------------------------------------
; bool SB_Reset_DSP(short Data)
; Purpose: Resets the SB DSP chip.
; Inputs:  Data, data to write out
; Outputs: eax=1 on error, 0 otherwise
;----------------------------------------
_SB_Reset_DSP_arglen    equ     2
proc _SB_Reset_DSP

%$Data          arg     2

        mov     dx, [_sb_port]
        add     dx, 6
        mov     ax, [ebp+%$Data]
        out     dx, al

        mov     ecx, 8
.delay:        
	in      al, dx
        dec     ecx
        jnz     .delay

        xor     al, al
        out     dx, al

        invoke  _SB_Read_DSP
        cmp     al, 0AAh
        jne     .error

        xor     eax, eax
        jmp     short .done
.error:
        mov     eax, 1
.done:

endproc

;----------------------------------------
; short SB_Read_DSP_Version(void)
; Purpose: Reads the version number of the SB DSP chip.
; Inputs:  None
; Outputs: ax=-1 on error, otherwise version number.
;----------------------------------------
        GLOBAL  _SB_Read_DSP_Version
_SB_Read_DSP_Version

        cmp	word [sb_hw_dsp_ver], 0
        jle     .NotAlreadyDetected

        xor     eax, eax
        mov     ax, [sb_hw_dsp_ver]
        jmp     short .Done

.NotAlreadyDetected:
        cmp     word [_sb_port], 0
        jg      .PortAlreadySet

        mov     word [_sb_port], 220h

.PortAlreadySet:
        invoke  _SB_Reset_DSP, word 1
        cmp     al, 0
        jne     .ProblemWithReset

        invoke  _SB_Write_DSP, word 0E1h
        invoke  _SB_Read_DSP
        push    ax
        invoke  _SB_Read_DSP
        shl     ax, 8
        pop     bx
        mov     al, bl
        jmp     .Done

.ProblemWithReset:
        mov     ax, -1

.Done:
        mov     [sb_hw_dsp_ver], ax
        ret



;----------------------------------------
; void SB_Play_Buffer(int Size)
; Purpose: Starts a DMA transfer of size bytes. On cards capable of it, the
;          transfer will use auto-initialised dma, so there is no need to call
;          this routine more than once. On older cards it must be called from
;          the end-of-buffer handler to switch to the new buffer.
; Inputs:  Size, the size of the DMA transfer to make, in bytes
; Outputs: None
;----------------------------------------
_SB_Play_Buffer_arglen  equ     4
proc _SB_Play_Buffer

%$Size          arg     4

        mov     ax, [sb_dsp_ver]
        cmp     ax, 0200h
        jg      .NotSB

        ; 8-bit single-shot, yuck!
        invoke  _SB_Write_DSP, word 14h
        mov     eax, [ebp+%$Size]
        dec     eax
        invoke  _SB_Write_DSP, word ax
        mov     eax, [ebp+%$Size]
        dec     eax
        shr     eax, 8
        invoke  _SB_Write_DSP, word ax

        jmp     short .Done
.NotSB:
        cmp     ax, 0400h
        jge     .NotSBPro

        ; 8-bit, auto-initialized
        invoke  _SB_Write_DSP, word 48h
        mov     eax, [ebp+%$Size]
        dec     eax
        invoke  _SB_Write_DSP, word ax
        mov     eax, [ebp+%$Size]
        dec     eax
        shr     eax, 8
        invoke  _SB_Write_DSP, word ax
        invoke  _SB_Write_DSP, word 90h

        jmp     short .Done
.NotSBPro:

        ; 16-bit
        shr     dword [ebp+%$Size], 1

        invoke  _SB_Write_DSP, word 0B6h
        invoke  _SB_Write_DSP, word 030h
        mov     eax, [ebp+%$Size]
        dec     eax
        invoke  _SB_Write_DSP, word ax
        mov     eax, [ebp+%$Size]
        dec     eax
        shr     eax, 8
        invoke  _SB_Write_DSP, word ax

.Done:

endproc

;----------------------------------------
; void SB_Record_Buffer(int Size, bool Stereo, short Bits)
; Purpose: Starts a dma transfer of size bytes. On cards capable of it, the
;          transfer will use auto-initialised dma, so there is no need to call
;          this routine more than once. On older cards it must be called from
;          the end-of-buffer handler to switch to the new buffer.
; Inputs:  Size, the size of the DMA transfer in bytes
;          Stereo, 1=stereo, 0=mono
;          Bits, 16 or 8
; Outputs: None
;----------------------------------------
_SB_Record_Buffer_arglen        equ     10
proc _SB_Record_Buffer

%$Size		arg	4
%$Stereo	arg	4
%$Bits		arg	2

        mov     ax, [sb_dsp_ver]
        cmp     ax, 0200h
        jg      .NotSB

        ; 8-bit single-shot, yuck!
        invoke  _SB_Write_DSP, word 24h
        mov     eax, [ebp+%$Size]
        dec     eax
        invoke  _SB_Write_DSP, word ax
        mov     eax, [ebp+%$Size]
        dec     eax
        shr     eax, 8
        invoke  _SB_Write_DSP, word ax

        jmp     .Done
.NotSB:
        cmp     ax, 0400h
        jge     .NotSBPro

        ; 8-bit, auto-initialized
        invoke  _SB_Write_DSP, word 48h
        mov     eax, [ebp+%$Size]
        dec     eax
        invoke  _SB_Write_DSP, word ax
        mov     eax, [ebp+%$Size]
        dec     eax
        shr     eax, 8
        invoke  _SB_Write_DSP, word ax
        invoke  _SB_Write_DSP, word 98h

        jmp     short .Done
.NotSBPro:

        cmp     word [ebp+%$Bits], 8
        jg      .Mode16bit
        ; 8-bit
        invoke  _SB_Write_DSP, word 0CEh
        jmp     short .DoneModeSel
.Mode16bit:	
	; 16-bit
        shr     dword [ebp+%$Size], 1
        invoke  _SB_Write_DSP, word 0BEh
.DoneModeSel:
        cmp     dword [ebp+%$Stereo], 0
        jz      .NotStereo
        mov     ax, 20h
        jmp     short .DoneStereo
.NotStereo:
        xor     ax, ax
.DoneStereo:
	invoke  _SB_Write_DSP, word ax

        mov     eax, [ebp+%$Size]
        dec     eax
        invoke  _SB_Write_DSP, word ax
        mov     eax, [ebp+%$Size]
        dec     eax
        shr     eax, 8
        invoke  _SB_Write_DSP, word ax

.Done:

endproc

;----------------------------------------
; int SB_Interrupt(void)
; Purpose: The SB end-of-buffer interrupt handler. Swaps to the other buffer 
;	   if the card doesn't have auto-initialised dma, and then refills the
;	   buffer that just finished playing.
; Inputs:  None
; Outputs: 0 (always)
; Notes:   Do not call directly!!
;----------------------------------------
_SB_Interrupt

        cmp     word [sb_dsp_ver], 0400h
        jl      .NotSB16

        ; Read SB16 ISR mask
        mov     dx, [_sb_port]
        add     dx, 4
        mov     al, 82h
        out     dx, al
        inc     dx
        in      al, dx
        and     al, 7

        test    al, 4
        jz      .NotMPU401

        ; MPU-401 interrupt
;        call    _mpu_poll
        jmp     .Done

.NotMPU401:
        test    al, 3
        jnz     .NotUnknown

        ; Unknown interrupt
        jmp     .Done

.NotUnknown:
.NotSB16:
        cmp     word [sb_dsp_ver], 0200h
        jle     .NotAutoInitialized

        ; Poll DMA position
        mov     eax, [sb_dma_count]
        inc     eax
        mov     [sb_dma_count], eax
        cmp     eax, 16
        jle     near .DoneDMA

        xor     eax, eax
        mov     al, [_sb_dma]
	invoke  _DMA_Todo, eax
        cmp     [sb_dma_size], eax
        salc                            ; Load AL from carry flag
        and     al, 1
        mov     [sb_bufnum], al
        xor     eax, eax
        mov     [sb_dma_count], eax

        jmp     short .DoneDMA
.NotAutoInitialized:

        xor     eax, eax
        mov     al, [_sb_dma]
        xor     edx, edx
        mov     dl, 1
        sub     dl, [sb_bufnum]
        mov     edx, [sb_buf+edx*4]
        invoke  _DMA_Start, eax, edx, dword [sb_dma_size], dword 0, dword 0
        
	cmp     byte [sb_recording], 0
        jnz     .RecordBuffer
        invoke  _SB_Play_Buffer, dword [sb_dma_size]
        jmp     short .DoneDMA
.RecordBuffer:
        invoke  _SB_Record_Buffer, dword [sb_dma_size], dword 0, word 8

.DoneDMA:
        cmp     byte [sb_semaphore], 0
        jnz     .DontMix
        cmp     byte [sb_recording], 0
        jnz     .DontMix

        ; Mix some more samples
        mov     byte [sb_semaphore], 1
        sti
        xor     edx, edx
        mov     dl, [sb_bufnum]
        mov     edx, [sb_buf+edx*4]
;        invoke  _mix_some_samples, edx, word [__dos_ds], dword 1
        cli
        mov     byte [sb_semaphore], 0

.DontMix:
        ; Swap buffers
        mov     al, 1
        sub     al, [sb_bufnum]
        mov     [sb_bufnum], al

        cmp     byte [sb_recording], 0
        jz      .DontSample
;        cmp     byte [_digi_recorder], 0
;        jz      .DontSample

        ; Sample input callback
        mov     byte [sb_semaphore], 1
        sti
;        call    [_digi_recorder]
        cli
        mov     byte [sb_semaphore], 0

.DontSample:
        ; Acknowledge SB
        mov     dx, [_sb_port]
        cmp     byte [sb_16bit], 0
        jz      .Not16bit
        add     dx, 0Fh
        in      al, dx
        jmp     short .Done
.Not16bit:
        add     dx, 0Eh
        in      al, dx

.Done:
        EOI     byte [_sb_irq]          ; EOI
        xor     eax, eax
        ret


;----------------------------------------
; void SB_Start(void)
; Purpose: Starts up the sound output.
; Inputs:  None
; Outputs: None
;----------------------------------------
        GLOBAL  _SB_Start
_SB_Start

        mov     byte [sb_bufnum], 0
        
	invoke  _SB_Voice, dword 1
        invoke  _SB_Set_Sample_Rate, dword [_sb_freq]

        cmp     word [sb_hw_dsp_ver], 0300h
        jl      .DontSetStereo
        cmp     word [sb_dsp_ver], 0400h
        jge     .DontSetStereo

        xor     eax, eax
        mov     al, [sb_stereo]
	invoke  _SB_Stereo_Mode, eax

.DontSetStereo:
        xor     edx, edx
	cmp     word [sb_dsp_ver], 0200h
        jle     .NotAutoInit

        mov     eax, [sb_dma_size]
        shl     eax, 1
        inc     edx
        jmp     short .StartDMA
.NotAutoInit:
        mov     eax, [sb_dma_size]
.StartDMA:
        xor     ecx, ecx
        mov     cl, [_sb_dma]
        invoke  _DMA_Start, ecx, dword [sb_buf], eax, edx, dword 0

        invoke  _SB_Play_Buffer, dword [sb_dma_size]

        ret


%if 0

/* sb_stop:
 *  Stops the sound output.
 */
static void sb_stop()
{
   /* halt sound output */
   _sb_voice(0);

   /* stop dma transfer */
   _dma_stop(_sb_dma);

   if (sb_dsp_ver <= 0x0200)
      sb_write_dsp(0xD0); 

   _sb_reset_dsp(1);
}



/* sb_detect:
 *  SB detection routine. Uses the BLASTER environment variable,
 *  or 'sensible' guesses if that doesn't exist.
 */
static int sb_detect(int input)
{
   char *blaster = getenv("BLASTER");
   char *msg;
   int cmask;
   int max_freq;
   int default_freq;

   /* input mode only works on the top of an existing output driver */
   if (input) {
      if (digi_driver != &digi_sb) {
	 strcpy(allegro_error, get_config_text("SB output driver must be installed before input can be read"));
	 return FALSE;
      }
      return TRUE;
   }

   /* what breed of SB are we looking for? */
   switch (digi_card) {

      case DIGI_SB10:
	 sb_dsp_ver = 0x100;
	 break;

      case DIGI_SB15:
	 sb_dsp_ver = 0x200;
	 break;

      case DIGI_SB20:
	 sb_dsp_ver = 0x201;
	 break;

      case DIGI_SBPRO:
	 sb_dsp_ver = 0x300;
	 break;

      case DIGI_SB16:
	 sb_dsp_ver = 0x400;
	 break;

      default:
	 sb_dsp_ver = -1;
	 break;
   } 

   /* parse BLASTER env */
   if (blaster) { 
      while (*blaster) {
	 while ((*blaster == ' ') || (*blaster == '\t'))
	    blaster++;

	 if (*blaster) {
	    switch (*blaster) {

	       case 'a': case 'A':
		  if (_sb_port < 0)
		     _sb_port = strtol(blaster+1, NULL, 16);
		  break;

	       case 'i': case 'I':
		  if (_sb_irq < 0)
		     _sb_irq = strtol(blaster+1, NULL, 10);
		  break;

	       case 'd': case 'D':
		  sb_dma8 = strtol(blaster+1, NULL, 10);
		  break;

	       case 'h': case 'H':
		  sb_dma16 = strtol(blaster+1, NULL, 10);
		  break;
	    }

	    while ((*blaster) && (*blaster != ' ') && (*blaster != '\t'))
	       blaster++;
	 }
      }
   }

   if (_sb_port < 0)
      _sb_port = 0x220;

   /* make sure we got a good port address */
   if (_sb_reset_dsp(1) != 0) { 
      static int bases[] = { 0x210, 0x220, 0x230, 0x240, 0x250, 0x260, 0 };
      int i;

      for (i=0; bases[i]; i++) {
	 _sb_port = bases[i];
	 if (_sb_reset_dsp(1) == 0)
	    break;
      }
   }

   /* check if the card really exists */
   _sb_read_dsp_version();
   if (sb_hw_dsp_ver < 0) {
      strcpy(allegro_error, get_config_text("Sound Blaster not found"));
      return FALSE;
   }

   if (sb_dsp_ver < 0) {
      sb_dsp_ver = sb_hw_dsp_ver;
   }
   else {
      if (sb_dsp_ver > sb_hw_dsp_ver) {
	 sb_hw_dsp_ver = sb_dsp_ver = -1;
	 strcpy(allegro_error, get_config_text("Older SB version detected"));
	 return FALSE;
      }
   }

   if (sb_dsp_ver >= 0x400) {
      /* read configuration from SB16 card */
      if (_sb_irq < 0) {
	 outportb(_sb_port+4, 0x80);
	 cmask = inportb(_sb_port+5);
	 if (cmask&1) _sb_irq = 2; /* or 9? */
	 if (cmask&2) _sb_irq = 5;
	 if (cmask&4) _sb_irq = 7;
	 if (cmask&8) _sb_irq = 10;
      }
      if ((sb_dma8 < 0) || (sb_dma16 < 0)) {
	 outportb(_sb_port+4, 0x81);
	 cmask = inportb(_sb_port+5);
	 if (sb_dma8 < 0) {
	    if (cmask&1) sb_dma8 = 0;
	    if (cmask&2) sb_dma8 = 1;
	    if (cmask&8) sb_dma8 = 3;
	 }
	 if (sb_dma16 < 0) {
	    sb_dma16 = sb_dma8;
	    if (cmask&0x20) sb_dma16 = 5;
	    if (cmask&0x40) sb_dma16 = 6;
	    if (cmask&0x80) sb_dma16 = 7;
	 }
      }
   }

   /* if nothing else works */
   if (_sb_irq < 0)
      _sb_irq = 7;

   if (sb_dma8 < 0)
      sb_dma8 = 1;

   if (sb_dma16 < 0)
      sb_dma16 = 5;

   /* figure out the hardware interrupt number */
   sb_int = _map_irq(_sb_irq);

   /* what breed of SB? */
   if (sb_dsp_ver >= 0x400) {
      msg = "SB 16";
      max_freq = 45454;
      default_freq = 22727;
   }
   else if (sb_dsp_ver >= 0x300) {
      msg = "SB Pro";
      max_freq = 22727;
      default_freq = 22727;
   }
   else if (sb_dsp_ver >= 0x201) {
      msg = "SB 2.0";
      max_freq = 45454;
      default_freq = 22727;
   }
   else if (sb_dsp_ver >= 0x200) {
      msg = "SB 1.5";
      max_freq = 16129;
      default_freq = 16129;
   }
   else {
      msg = "SB 1.0";
      max_freq = 16129;
      default_freq = 16129;
   }

   /* set up the playback frequency */
   if (_sb_freq <= 0)
      _sb_freq = default_freq;

   if (_sb_freq < 15000) {
      _sb_freq = 11906;
      sb_dma_size = 128;
   }
   else if (MIN(_sb_freq, max_freq) < 20000) {
      _sb_freq = 16129;
      sb_dma_size = 128;
   }
   else if (MIN(_sb_freq, max_freq) < 40000) {
      _sb_freq = 22727;
      sb_dma_size = 256;
   }
   else {
      _sb_freq = 45454;
      sb_dma_size = 512;
   }

   if (sb_dsp_ver <= 0x200)
      sb_dma_size *= 4;

   sb_dma_mix_size = sb_dma_size;

   /* can we handle 16 bit sound? */
   if (sb_dsp_ver >= 0x400) { 
      if (_sb_dma < 0)
	 _sb_dma = sb_dma16;
      else
	 sb_dma16 = _sb_dma;
      sb_16bit = TRUE;
      digi_sb.rec_cap_bits = 24;
      sb_dma_size <<= 1;
   }
   else { 
      if (_sb_dma < 0)
	 _sb_dma = sb_dma8;
      else
	 sb_dma8 = _sb_dma;
      sb_16bit = FALSE;
      digi_sb.rec_cap_bits = 8;
   }

   /* can we handle stereo? */
   if (sb_dsp_ver >= 0x300) {
      sb_stereo = TRUE;
      digi_sb.rec_cap_stereo = TRUE;
      sb_dma_size <<= 1;
      sb_dma_mix_size <<= 1;
   }
   else {
      sb_stereo = FALSE;
      digi_sb.rec_cap_stereo = FALSE;
   }

   /* set up the card description */
   sprintf(sb_desc, get_config_text("%s (%d hz) on port %X, using IRQ %d and DMA channel %d"),
			msg, _sb_freq, _sb_port, _sb_irq, _sb_dma);

   return TRUE;
}



/* sb_init:
 *  SB init routine: returns zero on success, -1 on failure.
 */
static int sb_init(int input, int voices)
{
   if (input)
      return 0;

   if (sb_in_use) {
      strcpy(allegro_error, get_config_text("Can't use SB MIDI interface and DSP at the same time"));
      return -1;
   }

   if ((digi_card == DIGI_SB) || (digi_card == DIGI_AUTODETECT)) {
      if (sb_dsp_ver <= 0x100)
	 digi_card = DIGI_SB10;
      else if (sb_dsp_ver <= 0x200)
	 digi_card = DIGI_SB15;
      else if (sb_dsp_ver < 0x300)
	 digi_card = DIGI_SB20;
      else if (sb_dsp_ver < 0x400)
	 digi_card = DIGI_SBPRO;
      else
	 digi_card = DIGI_SB16;
   }

   digi_sb.id = digi_card;

   if (sb_dsp_ver <= 0x200) {       /* two conventional mem buffers */
      if ((_dma_allocate_mem(sb_dma_size, &sb_sel[0], &sb_buf[0]) != 0) ||
	  (_dma_allocate_mem(sb_dma_size, &sb_sel[1], &sb_buf[1]) != 0))
	 return -1;
   }
   else {                           /* auto-init dma, one big buffer */
      if (_dma_allocate_mem(sb_dma_size*2, &sb_sel[0], &sb_buf[0]) != 0)
	 return -1;

      sb_sel[1] = sb_sel[0];
      sb_buf[1] = sb_buf[0] + sb_dma_size;
   }

   sb_lock_mem();

   digi_sb.voices = voices;

   if (_mixer_init(sb_dma_mix_size, _sb_freq, sb_stereo, sb_16bit, &digi_sb.voices) != 0)
      return -1;

   _mix_some_samples(sb_buf[0], _dos_ds, TRUE);
   _mix_some_samples(sb_buf[1], _dos_ds, TRUE);

   _enable_irq(_sb_irq);
   _install_irq(sb_int, sb_interrupt);

   sb_start();

   sb_in_use = TRUE;
   return 0;
}



/* sb_exit:
 *  SB driver cleanup routine, removes ints, stops dma, frees buffers, etc.
 */
static void sb_exit(int input)
{
   if (input)
      return;

   sb_stop();
   _remove_irq(sb_int);
   _restore_irq(_sb_irq);

   __dpmi_free_dos_memory(sb_sel[0]);
   if (sb_sel[1] != sb_sel[0])
      __dpmi_free_dos_memory(sb_sel[1]);

   _mixer_exit();

   sb_hw_dsp_ver = sb_dsp_ver = -1;
   sb_in_use = FALSE;
}



/* sb_rec_cap_rate:
 *  Returns maximum input sampling rate.
 */
static int sb_rec_cap_rate(int bits, int stereo)
{
   if (sb_dsp_ver < 0)
      return 0;

   if (sb_dsp_ver >= 0x400)
      /* SB16 can handle 45kHz under all circumstances */
      return 45454;

   /* lesser SB cards can't handle 16-bit */
   if (bits != 8)
      return 0;

   if (sb_dsp_ver >= 0x300)
      /* SB Pro can handle 45kHz, but only half that in stereo */
      return (stereo) ? 22727 : 45454;

   /* lesser SB cards can't handle stereo */
   if (stereo)
      return 0;

   if (sb_dsp_ver >= 0x201)
      /* SB 2.0 supports 15kHz */
      return 15151;

   /* SB 1.x supports 13kHz */
   return 13157;
}



/* sb_rec_cap_parm:
 *  Returns whether the specified parameters can be set.
 */
static int sb_rec_cap_parm(int rate, int bits, int stereo)
{
   int c, r;

   if ((r = sb_rec_cap_rate(bits, stereo)) <= 0)
      return 0;

   if (r < rate)
      return -r;

   if (sb_dsp_ver >= 0x400) {
      /* if bits==8 and rate==_sb_freq, bidirectional is possible,
	 but that's not implemented yet */
      return 1;
   }

   if (stereo)
      rate *= 2;

   c = 1000000/rate;
   r = 1000000/c;
   if (r != rate)
      return -r;

   return 1;
}



/* sb_rec_source:
 *  Sets the sampling source for audio recording.
 */
static int sb_rec_source(int source)
{
   int v1, v2;

   if (sb_hw_dsp_ver >= 0x400) {
      /* SB16 */
      switch (source) {

	 case SOUND_INPUT_MIC:
	    v1 = 1;
	    v2 = 1;
	    break;

	 case SOUND_INPUT_LINE:
	    v1 = 16;
	    v2 = 8;
	    break;

	 case SOUND_INPUT_CD:
	    v1 = 4;
	    v2 = 2;
	    break;

	 default:
	    return -1;
      }

      outportb(_sb_port+4, 0x3D);
      outportb(_sb_port+5, v1);

      outportb(_sb_port+4, 0x3E);
      outportb(_sb_port+5, v2);

      return 0;
   }
   else if (sb_hw_dsp_ver >= 0x300) {
      /* SB Pro */
      outportb(_sb_port+4, 0xC);
      v1 = inportb(_sb_port+5);

      switch (source) {

	 case SOUND_INPUT_MIC:
	    v1 = (v1 & 0xF9);
	    break;

	 case SOUND_INPUT_LINE:
	    v1 = (v1 & 0xF9) | 6;
	    break;

	 case SOUND_INPUT_CD:
	    v1 = (v1 & 0xF9) | 2;
	    break;

	 default:
	    return -1;
      }

      outportb(_sb_port+4, 0xC);
      outportb(_sb_port+5, v1);

      return 0;
   }

   return -1;
}



/* sb_rec_start:
 *  Stops playback, switches the SB to A/D mode, and starts recording.
 *  Returns the DMA buffer size if successful.
 */
static int sb_rec_start(int rate, int bits, int stereo)
{
   if (sb_rec_cap_parm(rate, bits, stereo) <= 0)
      return 0;

   sb_stop();

   sb_16bit = (bits>8);
   _sb_dma = (sb_16bit) ? sb_dma16 : sb_dma8;
   sb_recording = TRUE;
   sb_recbufnum = sb_bufnum = 0;

   _sb_voice(1);
   sb_set_input_sample_rate(rate, stereo);

   if ((sb_hw_dsp_ver >= 0x300) && (sb_dsp_ver < 0x400))
      sb_input_stereo_mode(stereo);

   if (sb_dsp_ver <= 0x200)
      _dma_start(_sb_dma, sb_buf[0], sb_dma_size, FALSE, TRUE);
   else
      _dma_start(_sb_dma, sb_buf[0], sb_dma_size*2, TRUE, TRUE);

   sb_record_buffer(sb_dma_size, stereo, bits);

   return sb_dma_size;
}



/* sb_rec_stop:
 *  Stops recording, switches the SB back to D/A mode, and restarts playback.
 */
static void sb_rec_stop()
{
   if (!sb_recording)
      return;

   sb_stop();

   sb_recording = FALSE;
   sb_16bit = (sb_dsp_ver >= 0x400);
   _sb_dma = (sb_16bit) ? sb_dma16 : sb_dma8;

   _mix_some_samples(sb_buf[0], _dos_ds, TRUE);
   _mix_some_samples(sb_buf[1], _dos_ds, TRUE);

   sb_start();
}



/* sb_rec_read:
 *  Retrieves the just recorded DMA buffer, if there is one.
 */
static int sb_rec_read(void *buf)
{
   if (!sb_recording)
      return 0;

   if (sb_bufnum == sb_recbufnum)
      return 0;

   dosmemget(sb_buf[sb_recbufnum], sb_dma_size, buf);
   sb_recbufnum = 1-sb_recbufnum;

   return 1;
}

static END_OF_FUNCTION(sb_rec_read);



/* sb_midi_interrupt:
 *  Interrupt handler for the SB MIDI input.
 */
static int sb_midi_interrupt()
{
   int c = sb_read_dsp();

   if ((c >= 0) && (midi_recorder))
      midi_recorder(c);

   _eoi(_sb_irq);
   return 0;
}

static END_OF_FUNCTION(sb_midi_interrupt);



/* sb_midi_output:
 *  Writes a byte to the SB midi interface.
 */
static void sb_midi_output(unsigned char data)
{
   sb_write_dsp(data);
}

static END_OF_FUNCTION(sb_midi_output);



/* sb_midi_detect:
 *  Detection routine for the SB MIDI interface.
 */
static int sb_midi_detect(int input)
{
   if ((input) && (sb_midi_out_mode))
      return TRUE;

   return sb_detect(FALSE);
}



/* sb_midi_init:
 *  Initialises the SB midi interface, returning zero on success.
 */
static int sb_midi_init(int input, int voices)
{
   if ((sb_in_use) && (!sb_midi_out_mode)) {
      strcpy(allegro_error, get_config_text("Can't use SB MIDI interface and DSP at the same time"));
      return -1;
   }

   sb_dsp_ver = -1;
   sb_lock_mem();
   sprintf(sb_midi_desc, get_config_text("Sound Blaster MIDI interface on port %X"), _sb_port);

   if (input) {
      _enable_irq(_sb_irq);
      _install_irq(sb_int, sb_midi_interrupt);
      sb_midi_in_mode = TRUE;
   }
   else
      sb_midi_out_mode = TRUE;

   sb_write_dsp(0x35);

   sb_in_use = TRUE;
   return 0;
}



/* sb_midi_exit:
 *  Resets the SB midi interface when we are finished.
 */
static void sb_midi_exit(int input)
{
   if (input) {
      _remove_irq(sb_int);
      _restore_irq(_sb_irq);
      sb_midi_in_mode = FALSE;
   }
   else
      sb_midi_out_mode = FALSE;

   if ((!sb_midi_in_mode) && (!sb_midi_out_mode)) {
      _sb_reset_dsp(1);
      sb_in_use = FALSE;
   }
}



/* sb_lock_mem:
 *  Locks all the memory touched by parts of the SB code that are executed
 *  in an interrupt context.
 */
static void sb_lock_mem()
{
   extern void _mpu_poll_end();

   LOCK_VARIABLE(digi_sb);
   LOCK_VARIABLE(midi_sb_out);
   LOCK_VARIABLE(_sb_freq);
   LOCK_VARIABLE(_sb_port);
   LOCK_VARIABLE(_sb_dma);
   LOCK_VARIABLE(_sb_irq);
   LOCK_VARIABLE(sb_int);
   LOCK_VARIABLE(sb_in_use);
   LOCK_VARIABLE(sb_recording);
   LOCK_VARIABLE(sb_16bit);
   LOCK_VARIABLE(sb_midi_out_mode);
   LOCK_VARIABLE(sb_midi_in_mode);
   LOCK_VARIABLE(sb_dsp_ver);
   LOCK_VARIABLE(sb_hw_dsp_ver);
   LOCK_VARIABLE(sb_dma_size);
   LOCK_VARIABLE(sb_dma_mix_size);
   LOCK_VARIABLE(sb_sel);
   LOCK_VARIABLE(sb_buf);
   LOCK_VARIABLE(sb_bufnum);
   LOCK_VARIABLE(sb_recbufnum);
   LOCK_VARIABLE(sb_dma_count);
   LOCK_VARIABLE(sb_semaphore);
   LOCK_VARIABLE(sb_recording);
   LOCK_FUNCTION(sb_play_buffer);
   LOCK_FUNCTION(sb_interrupt);
   LOCK_FUNCTION(sb_rec_read);
   LOCK_FUNCTION(sb_midi_interrupt);
   LOCK_FUNCTION(sb_midi_output);
   LOCK_FUNCTION(sb_record_buffer);
   LOCK_FUNCTION(_mpu_poll);
}

%endif
