
    org $0300

SCREEN=$d000
CONTROL=$de00

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

; Set bit 0, switch from 32x32s64 (stride/pitch of 64 bytes) to 64x32

    lda #$01
    sta CONTROL

    jmp *

text1:
    dta 'Hello, world!',0
text2:
    dta 'Goodbye, cruel world...',0

    run start

