
SCREEN = $d000
COLORS = $e000
CONTROL_540B = $de00

    org $0300

start:

; clear screen

    ldy #0
@:
    .rept 8
        lda #' '
        sta SCREEN+#*256,y
        lda #$0e
        sta COLORS+#*256,y
    .endr
    iny
    bne @-

; copy test data

    ldy #15

@:
    lda screen_test,y
    sta SCREEN,y
    lda colors_test,y
    sta COLORS,y
    dey
    bpl @-

    lda #$04
    sta CONTROL_540B

    jmp *

screen_test:
    .byte '0123456789ABCDEF'
colors_test:
    .byte 0,1,2,3,4,5,6,7,8,9,$a,$b,$c,$d,$e,$f

    run start