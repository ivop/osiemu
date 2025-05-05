; MARCH MEMTEST
; Copyright © 2025 by Ivo van Poorten
; BSD-0 License
; Ref. paper https://www.ijvdcs.org/uploads/524361IJVDCS2672-94.pdf

    icl 'zif.s'

; 32x32 --> 24x26, hidden 6L, 2R, 3T, 3B

TMARGIN = 3
BMARGIN = 3
LMARGIN = 6
RMARGIN = 2

STRIDE = 32
;STRIDE = 64

.ifndef STRIDE
STRIDE = 32
.endif

SCRMEM = $d000

TITLEPOS = SCRMEM + TMARGIN * STRIDE + LMARGIN
STARTPOS = TITLEPOS + STRIDE

GOOD = '+'
BAD = 'a'+$40        ; big block

zp  = $80
scr = $82
start = $84
end   = $86

block   = $a0
nblocks = $a1
xpos    = $a2

; ----------------------------------------------------------------------------

    org $0200

; ----------------------------------------------------------------------------

main:
    ldy #0
    sty zp
    lda #$d0
    sta zp+1
    lda #' '

    zrepeat
        sta (zp),y
        inw zp
        ldx zp+1
        cpx #$d8
    zuntil_eq

; ----------------------------------------------------------------------------

    ldx #msg_title_end-msg_title-1

    zrepeat
        lda msg_title,x
        sta TITLEPOS,x
        dex
    zuntil_mi
    
; ----------------------------------------------------------------------------

; Detect size of memory

    mwa #$0300 zp

    zrepeat
        inc zp+1
        lda zp+1
        cmp #$c0
        zbreakif_eq
        lda #$03
        sta (zp),y
        cmp (zp),y
    zuntil_ne

    lda zp+1
:2  lsr             // divide by 4
    sta nblocks

; ----------------------------------------------------------------------------

; MAIN testing loop

RESTART:
    mwa #STARTPOS scr

    mva #0 block
    mwa #0 start
    sta end+1
    sta xpos

    zloop
        lda #'B'
        jsr putchar
        lda block
        jsr printhex
        lda #':'
        jsr putchar
        ldy xpos
        lda (scr),y
        cmp #BAD
        zif_eq
            inc xpos
            jmp skip_block
        zendif

        lda #'?'
        jsr putchar
        dec xpos

        lda block
        zif_zero
            lda #'-'
            jsr putchar
            jmp skip_block
        zendif

; determine end of block

        lda start+1
        clc
        adc #4
        sta end+1

; start MARCH

; MATS++ { 🡙(w0); 🡑(r0; w1); 🡓(r1; w0; r0); }

        ldy #0

        ; 🡑(w0)

        mwa start zp
        tya
        zloop
            sta (zp),y              ; w0
            inw zp
            ldx zp+1
            cpx end+1
        zuntil_eq

        ; 🡑(r0; w1)

        mwa start zp

        zloop
            lda (zp),y              ; r0
            jne ERROR
            lda #$ff                ; w1
            sta (zp),y

            inw zp
            ldx zp+1
            cpx end+1
        zuntil_eq

        ; 🡓(r1; w0; r0)

        mwa end zp

        zloop
            dew zp

            lda (zp),y              ; r1
            cmp #$ff
            jne ERROR

            tya                     ; w0
            sta (zp),y

            lda (zp),y
            jne ERROR

            lda zp+1
            cmp start+1
            zcontinueif_ne
            lda zp
            cmp start
            zbreakif_eq
        zendloop

; end MARCH

OK:
        lda #GOOD
        jsr putchar
        jmp no_error

ERROR:
        lda #BAD
        jsr putchar

no_error:
skip_block:
        lda #' '
        jsr putchar

        lda start+1
        clc
        adc #4
        sta start+1

        inc block
        lda block
        cmp nblocks
        zbreakif_eq

        and #3
        zif_zero
            jsr nextline
        zendif
    zendloop

    jmp RESTART

; ----------------------------------------------------------------------------

printhex:
    pha
:4    lsr
    jsr bin2ascii_putchar
    pla
    and #15
    jmp bin2ascii_putchar

bin2ascii_putchar:
    sed
    cmp #10
    adc #$30
    cld

putchar:
    ldy xpos
    sta (scr),y
    inc xpos
    rts


nextline:
    adw scr #STRIDE
    ldy #0
    sty xpos
    rts

; ----------------------------------------------------------------------------

msg_title:
    dta 'MARCH MEMTEST'
msg_title_end:

maskup:
    dta 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40        ; , 0x80
maskdown:
    dta 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01

; ----------------------------------------------------------------------------

    run main
