; NETBIOS Network Library Functions
; Multicast Datagram Transmit and Reception Funtions
; Copyright 1997, John Lockwood, All rights reserved
; Department of Electrical and Computer Engineering
; University of Illinois at Urbana/Champaign
; lockwood@ipoint.vlsi.uiuc.edu
;
; Ported to DJGPP/NASM by Peter Johnson
;
; Version 2.0, Mar, 2000
;
; $Id: netbios.asm,v 1.2 2000/12/14 07:52:21 pete Exp $
%include "myC32.mac"            ; C interface macros

%include "globals.inc"
%include "constant.inc"
%include "dpmi_int.inc"
%include "dpmi_mem.inc"
%include "rmcbwrap.inc"

        BITS 32

        GLOBAL _NetInit
        GLOBAL _SendPacket
        GLOBAL _NetRelease

        GLOBAL _NetTransferSel

; ===== NetBIOS Network Control Block structure ===========================

STRUC NCB
.command        resb    1       ; command code
.retcode        resb    1       ; error return code
.lsn            resb    1       ; session number
.num            resb    1       ; name number
.buf_off        resw    1       ; ptr to send/receive data offset
.buf_seg        resw    1       ; ptr to send/receive data segment
.buflen         resw    1       ; length of data
.callname       resb    16      ; remote name
.name           resb    16      ; local name
.rto            resb    1       ; receive timeout
.sto            resb    1       ; send timeout
.post_off       resw    1       ; async command complete post offset
.post_seg       resw    1       ; async command complete post segment
.lana_num       resb    1       ; adapter number
.cmd_done       resb    1       ; 0FFh until command completed
.res            resb    14      ; reserved
ENDSTRUC

; ===== NetBIOS command constants =========================================

        RESET                 equ 032h
        CANCEL                equ 035h
        STATUS                equ 0B3h
        STATUS_WAIT           equ 034h
        TRACE                 equ 0F9h
        UNLINK                equ 070h
        ADD_NAME              equ 0B0h
        ADD_NAME_WAIT         equ 030h
        ADD_GROUP_NAME        equ 0B6h
        ADD_GROUP_NAME_WAIT   equ 036h
        DELETE_NAME           equ 0B1h
        DELETE_NAME_WAIT      equ 031h
        CALL_                 equ 090h
        LISTEN                equ 091h
        HANG_UP               equ 092h
        SEND                  equ 094h
        CHAIN_SEND            equ 097h
        RECEIVE               equ 095h
        RECEIVE_ANY           equ 096h
        SESSION_STATUS        equ 0B4h
        SEND_DATAGRAM         equ 0A0h
        SEND_BCST             equ 0A2h
        RECEIVE_DATA          equ 0A1h
        RECEIVE_BCST_DATA     equ 0A3h

; ===== Handy NetBios MACROs ==============================================

; INT5C NCB_Address
; Purpose: Call NetBIOS Interrupt 
; Inputs:  NCB_Address, address of NCB structure to pass to NetBIOS
; Outputs: None
; Notes:   Clobbers ALL general-purpose registers (ax,bx,cx,dx)
%macro INT5C 1          

        push    word [DPMI_ES]
        mov     bx, [_NetTransferSeg]
        mov     [DPMI_ES], bx
        mov     dword [DPMI_EBX], %1
        mov     bx, 05Ch        ; NetBIOS interrupt
        call    DPMI_Int
        pop     word [DPMI_ES]

%endmacro

;====== Declare variables ======================================

GroupSendNCB    equ     NET_BUFFER_SIZE*2               ; Send Network Control Block
GroupReceiveNCB equ     NET_BUFFER_SIZE*2+NCB_size      ; Receive Network Control Block

NetTransferSize equ     NET_BUFFER_SIZE*2+NCB_size*2


        SECTION .bss

_NetTransferSel resw    1       ; selector of real-mode area
_NetTransferSeg resw    1       ; RM segment of real-mode area

PostSeg         resw    1       ; Segment of RMCB for Post callback
PostOff         resw    1       ; Offset of RMCB for Post callback

GroupName       resb    16      ; 16-byte name like: 'ECE291LibTest$$$'
MyName          resb    16      ; 16-byte name like: 'ECE291Tester00$$'

GroupNum        resb    1       ; Determined by NetBIOS at runtime
MyNum           resb    1       ; Determined by NetBIOS at runtime

UserCallback    resd    1       ; Callback address of main program POST handler

; Packet counters
ReceiveCount    resd    1
SendCount       resd    1
ReceiveBadPost  resd    1

        SECTION .text

;====== Send Packet Function =============================================
; void SendPacket(int Length);
; Purpose: Sends a packet out using NetBIOS.
; Inputs:  TXBuffer filled with data to transmit
;          Length, Data Length of data to transmit
; Outputs: None (data transmitted out port)
proc _SendPacket
%$Length        arg     4

        push    esi
        push    edi
        push    es
        mov     es, [_NetTransferSel]
        
        mov     byte [es:GroupSendNCB+NCB.command], SEND_DATAGRAM
        mov     byte [es:GroupSendNCB+NCB.lana_num], 0  ; LAN Adapter 0

        mov     cl, [GroupNum]
        mov     [es:GroupSendNCB+NCB.num], cl           ; Group Number

        ; Group Name
        mov     esi, GroupName
        mov     edi, GroupSendNCB+NCB.callname
        mov     ecx, 4
        rep movsd

        mov     word [es:GroupSendNCB+NCB.buf_off], TXBuffer    ; What to Send

        mov     cx, [_NetTransferSeg]
        mov     [es:GroupSendNCB+NCB.buf_seg], cx
        mov     eax, [ebp+%$Length]
        mov     [es:GroupSendNCB+NCB.buflen], ax 

        mov     word [es:GroupSendNCB+NCB.post_off], 0          ; No post after sending
        mov     word [es:GroupSendNCB+NCB.post_seg], 0

        INT5C   GroupSendNCB
        
        inc     dword [SendCount]               ; Increment sent packet counter

        pop     es
        pop     edi
        pop     esi

endproc

;====== Receive Interrupt (Post Function) ================================

PostCallback

        push    es
        mov     es, [_NetTransferSel]

        inc     dword [ReceiveCount]    ; Count Number of received packets
        cmp     byte [es:GroupReceiveNCB+NCB.retcode], 0
        je      .noerror

        inc     dword [ReceiveBadPost]
        jmp     .done

.noerror:

        xor     eax, eax
        mov     ax, [es:GroupReceiveNCB+NCB.buflen]             ; Set EAX = Packet Length

        push    eax
        push    dword RXBuffer
        call    [UserCallback]                                  ; User Function
        add     esp, 8
        
.done:

        mov     byte [es:GroupReceiveNCB+NCB.command], RECEIVE_DATA     ; Command
        mov     word [es:GroupReceiveNCB+NCB.buflen], NET_BUFFER_SIZE   ; Max Message Length

        INT5C   GroupReceiveNCB

        pop     es
        ret

PostCallback_end

;====== Network INIT ====================================================
; char NetInit(unsigned int PostAddress, char *GroupName, char *MyName);
; Purpose: Initializes NetBIOS and sets up the Post callback procedure
; Inputs:  PostAddress, Callback procedure; called as: void Callback(unsigned int RXBuffer, unsigned int Length);
;          GroupName, 16-byte string containing group name to use
;          MyName, 16-byte string containing machine name to use (may be modified)
; Outputs: Returns -1 on error, otherwise:
;          Returns player number assigned and
;          MyName is changed to reflect actual machine name.

proc _NetInit
%$PostAddress   arg     4
%$GroupName     arg     4
%$MyName        arg     4

        push    esi
        push    edi
        push    es

        ; First copy GroupName and MyName parameters to library storage
        mov     ax, ds
        mov     es, ax

        mov     esi, [ebp+%$GroupName]
        mov     edi, GroupName
        mov     ecx, 4
        rep movsd
        
        mov     esi, [ebp+%$MyName]
        mov     edi, MyName
        mov     ecx, 4
        rep movsd

        ; Save callback address
        mov     eax, [ebp+%$PostAddress]
        mov     [UserCallback], eax
        
        ; Alloc NetTransfer
        mov     ax, 0100h                       ; [DPMI 0.9] Allocate DOS Memory Block
        mov     bx, NetTransferSize/16+1        ; Allocate 16-byte paragraphs
        int     31h
        jc      near .error

        mov     word [_NetTransferSeg], ax      ; Store selector and RM segment
        mov     word [_NetTransferSel], dx

        mov     es, dx

        ; Zero out memory block
        xor     eax, eax
        mov     ecx, NetTransferSize/4+1
        xor     edi, edi
        rep stosd

;       PRINTMSG 'NetINIT: Initializing NetBIOS'
;       PRINTSTR 'Adding NCB Group Name: ',grp_name

        mov     byte [es:GroupSendNCB+NCB.command], ADD_GROUP_NAME_WAIT
        
        mov     esi, GroupName
        mov     edi, GroupSendNCB+NCB.name
        mov     ecx, 4
        rep movsd

        INT5C   GroupSendNCB

        cmp     byte [es:GroupSendNCB+NCB.retcode], 0
        je      .NIok1 

;       PRINTMSG 'Group name already in use on this machine'
        jmp     .error

.NIok1:
        ; Save group number
        mov     al, [es:GroupSendNCB+NCB.num]
        mov     [GroupNum], al            

.NInext:
        mov     byte [es:GroupSendNCB+NCB.command], ADD_NAME_WAIT

        mov     esi, MyName
        mov     edi, GroupSendNCB+NCB.name
        mov     ecx, 4
        rep movsd
        
;       PRINTSTR 'Adding my NCB name: ',grpsnd.ncb_name
        INT5C   GroupSendNCB

        cmp     byte [es:GroupSendNCB+NCB.retcode], 0
        jne     near .NIplus

;       PRINTMSG 'Registering Post Function to receive datagrams: '
        mov     byte [es:GroupReceiveNCB+NCB.command],  RECEIVE_DATA    ; Command
        mov     byte [es:GroupReceiveNCB+NCB.lana_num], 0               ; LAN Adapter
        mov     word [es:GroupReceiveNCB+NCB.buf_off], RXBuffer         ; Buffer
        mov     cx, [_NetTransferSeg]
        mov     word [es:GroupReceiveNCB+NCB.buf_seg], cx               ; Buffer segment
        mov     word [es:GroupReceiveNCB+NCB.buflen], NET_BUFFER_SIZE   ; Max Message Length
        
        mov     cl, [GroupNum]
        mov     byte [es:GroupReceiveNCB+NCB.num], cl                   ; Group Number
        
        ; Lock up areas interrupt will access
        invoke  _LockArea, ds, dword _NetTransferSel, dword 2
        invoke  _LockArea, ds, dword _NetTransferSeg, dword 2
        invoke  _LockArea, ds, dword ReceiveCount, dword 4
        invoke  _LockArea, ds, dword ReceiveBadPost, dword 4
        invoke  _LockArea, ds, dword UserCallback, dword 4
        invoke  _LockArea, cs, dword PostCallback, dword PostCallback_end-PostCallback

        ; Get real-mode callback address
        invoke  _Get_RMCB, dword PostSeg, dword PostOff, dword PostCallback, dword 1
        cmp     eax, 0
        jnz     near .error

        mov     ax, [PostOff]
        mov     word [es:GroupReceiveNCB+NCB.post_off], ax      ; POST Routine called
        mov     ax, [PostSeg]
        mov     [es:GroupReceiveNCB+NCB.post_seg], ax           ;  on Packet arrival
        
        INT5C   GroupReceiveNCB

        ; Return with EAX = My Player Number 
        xor     eax, eax
        mov     al, [MyName+12]
        sub     eax, '0'
        lea     eax, [eax+eax*4]        ; *=5
        shl     eax, 1                  ; *=2
        add     al, [MyName+13]
        sub     al, '0'

        ; Copy library MyName to passed MyName
        mov     dx, ds
        mov     es, dx
        mov     esi, MyName
        mov     edi, [ebp+%$MyName]
        mov     ecx, 4
        rep movsd

;       PRINTMSG 'Network Ready!'
        jmp     .done


; Generates 'ECE291Player00$$'..'ECE291Player31$$' string

.NIplus:
        cmp     byte [MyName+12], '3'
        jb      .NIok2
        cmp     byte [MyName+13], '2'
        jb      .NIok2
;       PRINTMSG 'All Player Names in use'
        jmp     .error

.NIok2:
        inc     byte [MyName+13]
        cmp     byte [MyName+13], '9'+1 ; invalid digit
        jne     near .NInext

        inc     byte [MyName+12]
        mov     byte [MyName+13], '0'
        jmp     .NInext
.error:
        mov     eax, -1
.done:
        pop     es
        pop     edi
        pop     esi
endproc

;====== Network Release =================================================
; void NetRelease(void);
; Purpose: Releases NetBIOS names and resources.
; Inputs:  None
; Outputs: None
; Notes:   Assumes NetInit() has been called!
_NetRelease

        push    esi
        push    edi
        push    es
        mov     es, [_NetTransferSel]
;       PRINTMSG  'NetRelease: Free NetBIOS Names & Resources'

;       PRINTMSG  'Releasing Name..'
        mov     byte [es:GroupSendNCB+NCB.command], DELETE_NAME_WAIT
        mov     esi, MyName
        mov     edi, GroupSendNCB+NCB.name
        mov     ecx, 4
        rep movsd
        
        INT5C   GroupSendNCB

;       PRINTMSG  'Releasing Group ..'
        mov     byte [es:GroupSendNCB+NCB.command], DELETE_NAME_WAIT
        mov     esi, GroupName
        mov     edi, GroupSendNCB+NCB.name
        mov     ecx, 4
        rep movsd
        
        INT5C   GroupSendNCB

;       PRINTNUM 'Total Packets Sent: ' ,     sndcnt
;       PRINTNUM 'Total Packets Received: ' , rcvcnt
;       PRINTNUM 'Errored Packets Received: ' , rcvbadpost

        pop     es

        ; Free real-mode callback
        invoke  _Free_RMCB, word [PostSeg], word [PostOff]

        ; Free real-mode memory buffer
        mov     ax, 0101h       ; [DPMI 0.9] Free DOS Memory Block
        mov     dx, [_NetTransferSel]
        int     31h

        pop     edi
        pop     esi
        ret

