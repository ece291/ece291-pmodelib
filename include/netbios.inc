; Include file for NetBIOS
;  Written by Peter Johnson, 2000

        EXTERN _NetInit
        EXTERN _SendPacket
        EXTERN _NetRelease

        EXTERN _NetTransferSel

_NetInit_arglen                 equ     12
_SendPacket_arglen              equ     4


