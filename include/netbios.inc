; Include file for NetBIOS
;  Written by Peter Johnson, 2000
;
; $Id: netbios.inc,v 1.2 2000/12/14 07:52:21 pete Exp $

        EXTERN _NetInit
        EXTERN _SendPacket
        EXTERN _NetRelease

        EXTERN _NetTransferSel

_NetInit_arglen                 equ     12
_SendPacket_arglen              equ     4


