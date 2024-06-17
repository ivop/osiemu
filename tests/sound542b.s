
    org $0300

start:
    lda #2
    sta $de00
    ldx #255
@:
    stx $df01
    jsr wait
    dex
    bne @-

    jmp *

wait:
    ldy #0
@:
    dey
    .rept 16
        nop
    .endr
    bne @-
    rts

    run start
