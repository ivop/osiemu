
SCREEN = $d000
TITPOS  = SCREEN
JOY1TIT = SCREEN+128
JOY2TIT = SCREEN+256
JOY1POSUD = JOY1TIT+6
JOY2POSUD = JOY2TIT+6
JOY1POSLR = JOY1TIT+6+5
JOY2POSLR = JOY2TIT+6+5
JOY1TRG = JOY1TIT+18
JOY2TRG = JOY2TIT+18

KEYB = $df00
ROW7 = 0x80
ROW4 = 0x10

    org $2000

start:

; determine keyboard type (this fails if you keep a key pressed)

    ldy #$ff
    lda KEYB
    bne @+
    iny
@:
    sty mask

; clear screen

    ldy #0
    lda #' '
@:
    .rept 8
        sta SCREEN+#*256,y
    .endr
    dey
    bne @-

    .macro print message location
        ldy #0
@:
        lda :message,y
        beq @+
        sta :location,y
        iny
        bne @-
@:
    .endm

    print title TITPOS
    print joy1 JOY1TIT
    print joy2 JOY2TIT

loop:

    .macro trigger row bit loc
        lda #:row
        eor mask
        sta KEYB
        lda KEYB
        eor mask

        and #:bit
        beq notrg

        print fire :loc
        jmp done
notrg:
        print clear :loc
done:
    .endm

    trigger ROW7 $01 JOY1TRG
    trigger ROW4 $80 JOY2TRG

    .macro direction row bit1 bit2 msg1 msg2 loc
        lda #:row
        eor mask
        sta KEYB
        lda KEYB
        eor mask
        tax         ; save

        and #:bit1
        beq noup

        print :msg1 :loc
        jmp updowndone

noup:
        txa
        and #:bit2
        beq nodown
    
        print :msg2 :loc
        jmp updowndone

nodown:
        print clear :loc

updowndone:
    .endm

    direction ROW7 $10 $08 joyup joydown JOY1POSUD
    direction ROW7 $04 $02 joyright joyleft JOY1POSLR

    direction ROW4 $20 $40 joyup joydown JOY2POSUD
    direction ROW4 $10 $08 joyright joyleft JOY2POSLR

    jmp loop

title:
    .byte 'JOYSTICK TESTER', 0

joy1:
    .byte 'JOY1:',0

joy2:
    .byte 'JOY2:',0

fire:
    .byte 'FIRE',0
clear:
    .byte '     ',0

joyup:
    .byte 'UP',0
joydown:
    .byte 'DOWN',0
joyleft:
    .byte 'LEFT',0
joyright:
    .byte 'RIGHT',0

mask:
    .byte 0

    run start
