
SCREEN = $d000

    org SCREEN + 6*64

    .rept 256
        .byte #
        .byte ' '
    .endr
