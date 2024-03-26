    seg     CODE_SEG



video_setup:
       nextreg $68,%00000000   ;ula disable
 
       nextreg $15,%00000111 ; no low rez , LSU , no sprites , no over border

       ret


 ReadNextReg:
       push bc
       ld bc,$243b
       out (c),a
       inc b
       in a,(c)
       pop bc
       ret


;; Detect current video mode:
;; 0, 1, 2, 3 = HDMI, ZX48, ZX128, Pentagon (all 50Hz), add +4 for 60Hz modes
;; (Pentagon 60Hz is not a valid mode => value 7 shouldn't be returned in A)
DetectMode:
       ld      a,$05 ; PERIPHERAL_1_NR_05
       call    ReadNextReg
       and     $04             ; bit 2 = 50Hz/60Hz configuration
       ld      b,a             ; remember the 50/60 as +0/+4 value in B
       ; read HDMI vs VGA info
       ld      a,$11 ; VIDEO_TIMING_NR_11
       call    ReadNextReg
       inc     a               ; HDMI is value %111 in bits 2-0 -> zero it
       and     $07
       jr      z,.hdmiDetected
       ; if VGA mode, read particular zx48/zx128/pentagon setting
       ld      a,$03
       call    ReadNextReg
       ; a = bits 6-4: %00x zx48, %01x zx128, %100 pentagon
       swapnib
       rra
       inc     a
       and     $03             ; A = 1/2/3 for zx48/zx128/pentagon
.hdmiDetected:
       add     a,b             ; add 50/60Hz value to final result
       ret

VideoScanLines: ; 1st copper ,2nd irq
       dw 312-32                           ; hdmi_50
       dw 312-32                           ; zx48_50
       dw 311-32                           ; zx128_50
       dw 320-32                           ; pentagon_50

       dw 262-32                           ; hdmi_60
       dw 262-32                            ; zx48_60
       dw 261-32                            ; zx128_60
       dw 262-32                            ; pentagon_60

GetMaxScanline:
       call DetectMode:
       ld hl, VideoScanLines
       add a,a
       add hl,a
       ret

if 0
StartCopper:


	ld      hl,copper_line_start
	ld      bc,+(copper_the_end-copper_line_start+2)
 
do_copper:
	nextreg $61,0   ; LSB = 0
	nextreg $62,0   ;// copper stop | MSBs = 00

@lp1:	ld	a,(hl)  ;// write the bytes of the copper
	nextreg $60,a
	inc	hl
       dec bc
	ld	a,b
	or	c
	jr	nz,@lp1		

;       border 1

	nextreg $62,%01000000 ;// copper start | MSBs = 00

	ret
endif 

swap_frames:
              ld a,$13
              call ReadNextReg
              push af
              ld a,$12
              call ReadNextReg
              nextreg $13,a
              pop af
              nextreg $12,a
              ret


  
		// copper WAIT  VPOS,HPOS
COPPER_WAIT	macro
		db	HI($8000+(\0&$1ff)+(( (\1/8) &$3f)<<9))
		db	LO($8000+(\0&$1ff)+(( ((\1/8) >>3) &$3f)<<9))
		endm
		// copper MOVE reg,val
COPPER_MOVE		macro
		db	HI($0000+((\0&$ff)<<8)+(\1&$ff))
		db	LO($0000+((\0&$ff)<<8)+(\1&$ff))
		endm
COPPER_NOP	macro
		db	0,0
		endm

COPPER_HALT     macro
                db 255,255
                endm

COPPER_SET_PAL_INDEX macro
                     COPPER_MOVE(PAL_INDEX,\0)
                     endm

COPPER_SET_COLOR     macro
                     COPPER_MOVE(PAL_VALUE_8BIT,\0)
                     endm

PAL_LAYER2  macro
             COPPER_MOVE($43,%10010001)
              endm

PAL_LAYER2_PAL2  macro
             COPPER_MOVE($43,%01010101)
              endm


PAL_LAYER3  macro
             COPPER_MOVE($43,%10110001)
              endm

PAL_LAYER3_2  macro
             COPPER_MOVE($43,%10110101)
              endm

