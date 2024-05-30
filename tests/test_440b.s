
SCREEN = $d000

    org $e000

    ins 'logo-128x128.dat'

    org $0300

start:

; clear screen

    ldy #0
    lda #' '
@:
    .rept 8
        sta SCREEN+#*256,y
    .endr
    dey
    bne @-

    ldy #4
@:
    lda white,y
    sta SCREEN,y
    dey
    bpl @-

    ldy #2
@:
    lda red,y
    sta SCREEN+64,y
    dey
    bpl @-

    ldy #4
@:
    lda green,y
    sta SCREEN+128,y
    dey
    bpl @-

    ldy #5
@:
    lda yellow,y
    sta SCREEN+192,y
    dey
    bpl @-

    jmp *

white:
    .by -$40 'WHITE'
red:
    .by      'RED'
green:
    .by +$40 'GREEN'
yellow:
    .by +$80 'YELLOW'

    run start
