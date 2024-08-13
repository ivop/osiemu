
    org $0300

SCREEN=$d000
CONTROL=$d800

start:

; Clear screen

    ldy #0
    sty CONTROL
    lda #' '
@:
    .rept 8
        sta SCREEN+#*256,y
    .endr
    dey
    bne @-

@:
    lda text1,y
    beq end_of_text1
    sta SCREEN,y
    iny
    bne @-

end_of_text1:

    ldy #0
@:
    lda text2,y
    beq end_of_text2
    sta SCREEN+64,y
    iny
    bne @-

    tya
    tax

end_of_text2:

; Just wait a while...

@:
    dex
    bne @-
    dey
    bne @-

    clc
    adc #1
    cmp #10
    bne @-

; Set n32 --> 64x16

    lda #$01
    sta CONTROL

    jmp *

text1:
    dta 'Hello, world!',0
text2:
    dta 'Goodbye, cruel world...',0

    run start

