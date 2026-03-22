; MATS++ memory tester for single page ROM
; by Ivo van Poorten
; BSD-0 license
; This tester does not use any RAM itself and runs fully from ROM, so it
; can test block $00
; assemble for different block with, e.g. block 7:
; mads -o:output.bin -d:block=7 memtestrom256.s

.ifndef block
block = $00
.endif

test = block * $0400
screen = $d000
status = screen + 64*3 + 10

GOOD = '+'
BAD = 'a'+$40        ; big block

    opt h-
    opt f+
    opt r+

    icl 'zif.s'

    org $ff00

reset:
    cld
    ldy #0
    lda #' '
    zloop
        sta screen,y
        sta screen+$0100,y
        sta screen+$0200,y
        sta screen+$0300,y
        dey
    zuntil_zero

; unrolled MATS++ { 🡑(w0); 🡑(r0,w1); 🡓(r1,w0); 🡓(r0,w1); 🡑(r1) }

    ldx #3

    zloop
        nop
        ; 🡑(w0)
        zloop
            lda data0,x
            sta test,y
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            iny
        zuntil_zero

        ; 🡑(r0,w1)
        zloop
            lda data0,x
            cmp test,y
            bne fail_trampoline
            cmp test+$0100,y
            bne fail_trampoline
            cmp test+$0200,y
            bne fail_trampoline
            cmp test+$0300,y
            bne fail_trampoline
            lda data1,x
            sta test,y
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            iny
        zuntil_zero

        ; 🡓(r1,w0)
        dey
        zloop
            lda data1,x
            cmp test,y
            bne fail_trampoline
            cmp test+$0100,y
            bne fail_trampoline
            cmp test+$0200,y
            bne fail_trampoline
            cmp test+$0300,y
            bne fail_trampoline
            lda data0,x
            sta test,y
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            dey
            cpy #$ff
        zuntil_equal

        ; 🡓(r0,w1)
        zloop
            lda data0,x
            cmp test,y
    fail_trampoline:
            bne fail
            cmp test+$0100,y
            bne fail
            cmp test+$0200,y
            bne fail
            cmp test+$0300,y
            bne fail
            lda data1,x
            sta test,y
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            dey
            cpy #$ff
        zuntil_equal

        ; 🡑(r1)
        iny
        zloop
            lda data1,x
            cmp test,y
            bne fail
            cmp test+$0100,y
            bne fail
            cmp test+$0200,y
            bne fail
            cmp test+$0300,y
            bne fail
            iny
        zuntil_zero
    
        dex
    zuntil_mi

ok:
    lda #'P'
    sta status
    lda #'S'
    sta status+2
    sta status+3

both:
    lda #'A'
    sta status+1
    bne *

fail:
    lda #'F'
    sta status
    lda #'I'
    sta status+2
    lda #'L'
    sta status+3
    bne both

.ifdef SHORT_STATUS
ok:
    lda #GOOD
print:
    sta status
    bne *

fail:
    lda #BAD
    bne print
.endif

; background data

data0:
    dta %01010101, %00110011, %00001111, %00000000
data1:
    dta %10101010, %11001100, %11110000, %11111111

    org $fffa

    dta a(0), a(reset), a(0)
