; MARCH (M)SS memory tester for double page ROM
; by Ivo van Poorten
; BSD-0 license
; This tester does not use any RAM itself and runs fully from ROM, so it
; can test block $00
; assemble for different block with, e.g. block 7:
; mads -o:output.bin -d:block=7 memtestrom512.s

.ifndef block
block = $00
.endif

test = block * $0400
screen = $d000
status = screen + 64*3 + 10

GOOD = '+'
BAD = 'a'+$40        ; big block

    opt h-
;    opt f+
    opt r+

    icl 'zif.s'

    org $fe00

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

; MARCH (M)SS { 🡙(w0); 🡑(r0,r0,w1,w1); 🡑(r1,r1,w0,w0); 🡓(r0,r0,w1,w1);
;             🡓(r1,r1,w0,w0); 🡙(r0) }

    ldx #15

    zloop
        ; 🡙(w0)
        txa
        and #$04
        zif_zero
            zloop
                lda data0,x
                sta test,y
                sta test+$0100,y
                sta test+$0200,y
                sta test+$0300,y
                iny
            zuntil_zero
        zelse
            dey         ; downwards
            zloop
                lda data0,x
                sta test,y
                sta test+$0100,y
                sta test+$0200,y
                sta test+$0300,y
                dey
                cpy #$ff
            zuntil_equal
            iny         ; restore upwards
        zendif

        ; next two Ms are upwards

        ; 🡑(r0,r0,w1,w1)
        zloop
            lda data0,x
            cmp test,y              ; r0
            bne fail_trampoline4
            cmp test+$0100,y
            bne fail_trampoline4
            cmp test+$0200,y
            bne fail_trampoline4
            cmp test+$0300,y
            bne fail_trampoline4
            cmp test,y              ; r0
            bne fail_trampoline4
            cmp test+$0100,y
            bne fail_trampoline4
            cmp test+$0200,y
            bne fail_trampoline4
            cmp test+$0300,y
            bne fail_trampoline4
            lda data1,x
            sta test,y              ; w1
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            sta test,y              ; w1
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            iny
        zuntil_zero

        ; 🡑(r1,r1,w0,w0)
        zloop
            lda data1,x
            cmp test,y              ; r1
fail_trampoline4:
            bne fail_trampoline3
            cmp test+$0100,y
            bne fail_trampoline3
            cmp test+$0200,y
            bne fail_trampoline3
            cmp test+$0300,y
            bne fail_trampoline3
            cmp test,y              ; r1
            bne fail_trampoline3
            cmp test+$0100,y
            bne fail_trampoline3
            cmp test+$0200,y
            bne fail_trampoline3
            cmp test+$0300,y
            bne fail_trampoline3
            lda data0,x
            sta test,y              ; w0
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            sta test,y              ; w0
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            iny
        zuntil_zero

        ; 🡓(r0,r0,w1,w1)
        dey                         ; next two Ms are downwards
        zloop
            lda data0,x
            cmp test,y              ; r0
fail_trampoline3:
            bne fail_trampoline2
            cmp test+$0100,y
            bne fail_trampoline2
            cmp test+$0200,y
            bne fail_trampoline2
            cmp test+$0300,y
            bne fail_trampoline2
            cmp test,y              ; r0
            bne fail_trampoline2
            cmp test+$0100,y
            bne fail_trampoline2
            cmp test+$0200,y
            bne fail_trampoline2
            cmp test+$0300,y
            bne fail_trampoline2
            lda data1,x
            sta test,y              ; w1
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            sta test,y              ; w1
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            dey
            cpy #$ff
        zuntil_equal

        ; 🡓(r1,r1,w0,w0)
        zloop
            lda data1,x
            cmp test,y              ; r1
fail_trampoline2:
            bne fail_trampoline
            cmp test+$0100,y
            bne fail_trampoline
            cmp test+$0200,y
            bne fail_trampoline
            cmp test+$0300,y
            bne fail_trampoline
            cmp test,y              ; r1
            bne fail_trampoline
            cmp test+$0100,y
            bne fail_trampoline
            cmp test+$0200,y
            bne fail_trampoline
            cmp test+$0300,y
            bne fail_trampoline
            lda data0,x
            sta test,y              ; w0
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            sta test,y              ; w0
            sta test+$0100,y
            sta test+$0200,y
            sta test+$0300,y
            dey
            cpy #$ff
        zuntil_equal

        ; 🡙(r0)
        txa
        and #$08
        zif_zero
            iny                         ; restore upwards
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
                iny
            zuntil_zero
        zelse
            zloop
                lda data0,x
                cmp test,y
                bne fail
                cmp test+$0100,y
                bne fail
                cmp test+$0200,y
                bne fail
                cmp test+$0300,y
                bne fail
                dey
                cpy #$ff
            zuntil_equal
            iny                     ; restore upwards
        zendif
    
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

; background data

; four times, for all four combinations of the 🡙 M elements

data0:
    dta %01010101, %00110011, %00001111, %00000000
    dta %01010101, %00110011, %00001111, %00000000
    dta %01010101, %00110011, %00001111, %00000000
    dta %01010101, %00110011, %00001111, %00000000
data1:
    dta %10101010, %11001100, %11110000, %11111111
    dta %10101010, %11001100, %11110000, %11111111
    dta %10101010, %11001100, %11110000, %11111111
    dta %10101010, %11001100, %11110000, %11111111

; exact fit (!)

    dta a(0), a(reset), a(0)
