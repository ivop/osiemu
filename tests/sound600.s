
    org $0300

start:
    lda #$10        ; enable DAC
    sta $d800

@:
    stx $df00
    .rept 8
        nop
    .endr
    dex             ; saw tooth
    bne @-

    jmp @-

    run start
