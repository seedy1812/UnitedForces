

MMU6: equ $56
MMU7: equ $57

columns_init:
    nextreg $43, %00010001
    nextreg PAL_INDEX,0

    ld b, bars_pal_end-bars_pal
    ld hl,bars_pal
.loop:
    ld a,(hl)
    nextreg PAL_VALUE_8BIT,a
    inc hl
    inc hl
    djnz .loop

    ld a,%0001111
    ld bc, LAYER2_OUT  
	out (c), a

    Nextreg $70,0
    Nextreg $71,0
    Nextreg $72,0


    ld hl, sin
    ld bc, +(sin_end-sin)/2

.lp:
    push bc

    ld e,(hl)
    inc hl
    ld d,(hl)
    dec hl
    push hl
    ld hl, 14
    call mul_hl_de
    ld e,l
    ld d,h
    pop hl

    ld b,4
    bsrl de,b

    ld (hl),e
    inc hl
    ld (hl),d
    inc hl

    pop bc
    dec bc
    ld a,b
    or c
    jr nz,.lp
    ret


// not signed
mul_hl_de:       ; (uint16)HL = (uint16)HL x (uint16)DE
    ld      c,e
    ; HxD xh*yh is not relevant for 16b result at all
    ld      e,l
    mul             ; LxD xl*yh
    ld      a,e     ; part of r:8:15
    ld      e,c
    ld      d,h
    mul             ; HxC xh*yl
    add     a,e     ; second part of r:8:15
    ld      e,c
    ld      d,l
    mul             ; LxC xl*yl (E = r:0:7)
    add     a,d     ; third/last part of r:8:15
    ; result in AE (16 lower bits), put it to HL
    ld      h,a
    ld      l,e
    ret             ; =4+4+8+4+4+4+8+4+4+4+8+4+4+4+10 = 78T



columns_update:
    ld bc,LAYER2_OUT
    in a,(c)
    and %00111111
    out (c),a

    and %11000000
    swapnib


    border 5

    ld b, 192/2
    ld c,0
    ld ix,col_x
.loop1
    push bc

    ld e,7
    ld d,c
    mul             ;val2+7*i
    ld hl,(cnt)
    add hl,de       ;val2 &= $3fff
    ld a,3
    and h
    ld h,a
    add hl,hl       ; 2 bytes per entry
    add hl,sin      ; get sin value

    ld e,(hl)
    inc hl
    ld d,(hl)
    push de         ; save for later

    ld e,10         ; val2 = 10*i
    ld d,c
    mul
    ld hl,(cnt2)
    add hl,de
    ld a,3
    and h
    ld h,a
    add hl,hl
    add hl,sin
    ld e,(hl)
    inc hl
    ld d,(hl)

    pop hl
    add hl,de

    sra h
    rr l

    sra h
    rr l

    ld (ix),l
    inc ix

    pop bc
    inc c

    djnz .loop1


    ld hl,(cnt)
    add hl,3
    ld a,h
    and 3
    ld h,a
    ld (cnt),hl


    ld hl,(cnt2)
    add hl,-5
    ld a,h
    and 3
    ld h,a
    ld (cnt2),hl

///////////////////////////

    border 7

    ld hl,$0000
    ld (hl),CLS_INDEX
    ld de,$0001
    ld bc,256
    call DMA_COPY

    border 2

    ld b,+(63+64+64)/2
    ld c,0
    ld d,$00
    ld ix,col_x
.outer:

    push de
    ld d,23
    ld e,c
    mul
    ld hl,bars_gfx
    add hl,de
    pop de
  
    push de
    ld e,(ix)
    push bc
    ld bc,23
    ldir
    pop bc
    pop de

    ld a,d
    add 2
    and 63
    jr nz , .same_page

.new_third:

    push bc
    push de

    ld a,d

    ld h,a
    ld l,0
    ld de, page_buffer
    ld bc,256*2
    call DMA_COPY       ; cpy to buffer so i can swap the screen thirds

    ld h,a              ; fill in last scanline
    ld l,0
    ld d,h
    inc d
    ld e,l
    ld bc,256*1
    call DMA_COPY

    // swap apage

    ld bc,LAYER2_OUT
    in a,(c)
    add a,%01000000
    out(c),a

    and %11000000
    swapnib
    add 1
    bordera


    ld hl,page_buffer
    ld de,0
    ld bc,256
    call DMA_COPY

    pop de
    pop bc
    ld d,0
    jr .cont
.same_page:
    push bc
    push de
    ld h,d
    inc d
    ld l,0
    ld e,0
    ld bc,256*2
    call DMA_COPY

    pop de
    pop bc
    inc d
    inc d
.cont
    inc c
    inc ix
    ld a,10
    cp c
    jr nz,.ok
    ld c,0
.ok:
    djnz .outer

    border 0

    ld hl,$3e00
    ld (hl),CLS_INDEX
    ld de,$3e01
    ld bc,256+255
    call DMA_COPY

    ret


COPYDMA_Start:
	db $83
	db  %01111101                           ; R0-Transfer mode, A -> B
COPYDMA_SourceAddress:
	dw  $4000                 				; R0-Port A, Start address (source)
COPYDMA_Length
	dw  256*2                               ; R0-Block length

	db  %00010100                    ; R1 - A fixed memory

	db  %00010000                    ; R2 - B incrementing memory

	db      %10101101                 ; R4-Continuous
COPYDMA_DestAddress:
	dw      $0000                     ; R4-Block Address

	db      $cf                                                     ; R6 - Load
	db      $87                                                     ; R6 - enable DMA;
COPYDMA_End:



DMA_COPY
    ld (COPYDMA_SourceAddress),hl
    ld (COPYDMA_DestAddress),de
    ld (COPYDMA_Length),bc

	; transfer the DMA "program" to the port
	ld      hl,COPYDMA_Start
	ld      bc,DMA_PORT+(COPYDMA_End - COPYDMA_Start)*256
	otir
	ret




page_buffer: ds 256*2

cnt:    dw 0
cnt2:   dw 0

col_x:  ds  200

sin:    dw 264,264,268,272,276,280,280,284,288,292,296,296,300,304,308,312,312,316,320,324,328,328,332,336,340,340,344,348,352,352,356,360,364,364,368,372,376,376,380,384,388,388,392,396,396,400,404,404,408,412,412,416,420,420,424,428,428,432,436,436,440,440,444,448,448,452,452,456,456,460,460,464,464,468,472,472,472,476,476,480,480,484,484,488,488,488,492,492,496,496,496,500,500,500,504,504,504,508,508,508,512,512,512,512,516,516,516,516,520,520,520,520,520,520,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,520,520,520,520,520,520,516,516,516,516,512,512,512,512,508,508,508,508,504,504,504,500,500,500,496,496,492,492,492,488,488,484,484,480,480,480,476,476,472,472,468,468,464,464,460,456,456,452,452,448,448,444,444,440,436,436,432,428,428,424,424,420,416,416,412,408,408,404,400,400,396,392,388,388,384,380,380,376,372,368,368,364,360,356,356,352,348,344,344,340,336,332,328,328,324,320,316,316,312,308,304,300,300,296,292,288,284,284,280,276,272,268,264,264,264,260,256,252,252,248,244,240,236,236,232,228,224,220,220,216,212,208,204,204,200,196,192,192,188,184,180,176,176,172,168,164,164,160,156,152,152,148,144,144,140,136,132,132,128,124,124,120,116,116,112,108,108,104,100,100,96,96,92,88,88,84,84,80,76,76,72,72,68,68,64,64,60,60,56,56,52,52,48,48,44,44,40,40,40,36,36,32,32,32,28,28,28,24,24,24,20,20,20,16,16,16,16,12,12,12,12,12,8,8,8,8,8,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,8,8,8,8,8,12,12,12,12,12,16,16,16,20,20,20,20,24,24,24,28,28,28,32,32,36,36,36,40,40,44,44,44,48,48,52,52,56,56,60,60,64,64,68,68,72,72,76,80,80,84,84,88,92,92,96,96,100,104,104,108,112,112,116,120,120,124,128,128,132,136,136,140,144,148,148,152,156,156,160,164,168,168,172,176,180,180,184,188,192,196,196,200,204,208,212,212,216,220,224,224,228,232,236,240,244,244,248,252,256,260,260,264,264,268,272,276,280,280,284,288,292,296,296,300,304,308,312,312,316,320,324,328,328,332,336,340,340,344,348,352,352,356,360,364,364,368,372,376,376,380,384,388,388,392,396,396,400,404,404,408,412,412,416,420,420,424,428,428,432,436,436,440,440,444,448,448,452,452,456,456,460,460,464,464,468,472,472,472,476,476,480,480,484,484,488,488,488,492,492,496,496,496,500,500,500,504,504,504,508,508,508,512,512,512,512,516,516,516,516,520,520,520,520,520,520,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,524,520,520,520,520,520,520,516,516,516,516,512,512,512,512,508,508,508,508,504,504,504,500,500,500,496,496,492,492,492,488,488,484,484,480,480,480,476,476,472,472,468,468,464,464,460,456,456,452,452,448,448,444,444,440,436,436,432,428,428,424,424,420,416,416,412,408,408,404,400,400,396,392,388,388,384,380,380,376,372,368,368,364,360,356,356,352,348,344,344,340,336,332,328,328,324,320,316,316,312,308,304,300,300,296,292,288,284,284,280,276,272,268,264,264,264,260,256,252,252,248,244,240,236,236,232,228,224,220,220,216,212,208,204,204,200,196,192,192,188,184,180,176,176,172,168,164,164,160,156,152,152,148,144,144,140,136,132,132,128,124,124,120,116,116,112,108,108,104,100,100,96,96,92,88,88,84,84,80,76,76,72,72,68,68,64,64,60,60,56,56,52,52,48,48,44,44,40,40,40,36,36,32,32,32,28,28,28,24,24,24,20,20,20,16,16,16,16,12,12,12,12,12,8,8,8,8,8,8,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,8,8,8,8,8,8,12,12,12,12,12,16,16,16,20,20,20,20,24,24,24,28,28,28,32,32,36,36,36,40,40,44,44,44,48,48,52,52,56,56,60,60,64,64,68,68,72,72,76,80,80,84,84,88,92,92,96,96,100,104,104,108,112,112,116,120,120,124,128,128,132,136,136,140,144,148,148,152,156,156,160,164,168,168,172,176,180,180,184,188,192,196,196,200,204,208,212,212,216,220,224,224,228,232,236,240,244,244,248,252,256,260,260
sin_end:


bars_gfx:   incbin "gfx/bars.nxi"
bars_pal:   incbin "gfx/bars.nxp"
bars_pal_end:
 