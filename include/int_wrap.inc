; IRQ Wrappers and handling functions header file
;  By Peter Johnson, 1999
;
; $Id: int_wrap.inc,v 1.2 2000/12/14 07:52:21 pete Exp $

        EXTERN  _Install_Int
        EXTERN  _Remove_Int
        EXTERN  _Exit_IRQ
        EXTERN  _Init_IRQ
        EXTERN  _Restore_IRQ
        EXTERN  _Enable_IRQ
        EXTERN  _Disable_IRQ

_Install_Int_arglen             equ     8
_Remove_Int_arglen              equ     4
_Restore_IRQ_arglen             equ     4
_Enable_IRQ_arglen              equ     4
_Disable_IRQ_arglen             equ     4
