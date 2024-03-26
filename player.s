
LINE_INT_LSB		 equ $23
LAYER_2_Y_OFFSET 	 equ $17
LAYER2_CLIP_WINDOW   equ $18
PAL_INDEX            equ $40
PAL_VALUE_8BIT       equ $41
DMA_PORT    	     equ $6b ;//: zxnDMA

LAYER2_OUT			 equ $123B

CLS_INDEX equ $ff

bordera macro
          out ($fe),a
        endm

border macro
           ld a,\0
           bordera
        endm

MY_BREAK	macro
        db $dd,01
		endm


	OPT Z80
	OPT ZXNEXTREG    

    seg     CODE_SEG, 			 4:$0000,$8000

    seg     CODE_SEG

include "irq.s"

start:
;; set the stack pointer
	ld sp , StackStart

	call columns_init

	call video_setup

	call init_vbl

	nextreg 7,%11 ; 28mhz
	nextreg $4c,CLS_INDEX ; set transparent colour outside the 0 to 9
    nextreg $68,%00000000   ;ula disable
    nextreg $15,%00000111 ; no low rez , LSU , no sprites , no over border
 
frame_loop:

	call columns_update

	call wait_vbl
	call swap_frames
	jp frame_loop

StackEnd:
	ds	128
StackStart:
	ds  2


include "video.s"
include "columns.s"

    seg     CODE_SEG

THE_END:

 	savenex "player.nex",start

