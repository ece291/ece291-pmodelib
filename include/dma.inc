; DMA interface code (used primarily by sound routines)
;  By Peter Johnson, 1999
;
; $Id: dma.inc,v 1.2 2000/12/14 07:52:21 pete Exp $

        EXTERN  _DMA_Allocate_Mem
        EXTERN  _DMA_Start
        EXTERN  _DMA_Stop
        EXTERN  _DMA_Todo
        EXTERN  _DMA_Lock_Mem

_DMA_Allocate_Mem_arglen        equ     12
_DMA_Start_arglen               equ     20
_DMA_Stop_arglen                equ     4
_DMA_Todo_arglen                equ     4

