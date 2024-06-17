
    org $0300

start:
    lda #2          ; enable tone
    sta $de00
    ldx #255
@:
    stx $df01
    jsr wait
    dex             ; slide up
    bne @-

    lda #0          ; disable tone
    sta $de00

@:
    stx $df01
    .rept 8
        nop
    .endr
    dex             ; saw tooth
    bne @-

    jmp @-

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
