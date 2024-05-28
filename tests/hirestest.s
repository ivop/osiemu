
SCREEN = $d000
HIRES  = $8000

    org $0300

start:
    ldy #0
    lda #' '
@:
    .rept 8
        sta SCREEN+#*256,y
    .endr
    iny
    bne @-

    jmp *

    org HIRES

    ins 'logo-256x256.dat'

    run start
