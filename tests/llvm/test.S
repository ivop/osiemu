#include "zif.inc"

SCREEN = 0xd000

    .section .zp, "zax", @nobits

ptr:    .fill 2

zproc _start
    ldy #0
    lda #' '
    zrepeat
        sta SCREEN+0*256,y
        sta SCREEN+1*256,y
        sta SCREEN+2*256,y
        sta SCREEN+3*256,y
        iny
    zuntil_eq

    ldx #end_banner-banner
    zrepeat
        lda banner-1,x
        sta SCREEN-1,x
        dex
    zuntil_eq

    lda #<SCREEN
    sta ptr
    lda #>SCREEN
    sta ptr+1

    jmp .
zendproc

    .data

banner:
    .ascii "Hello, World!"
end_banner:

    .bss

foo:
    .fill 2
