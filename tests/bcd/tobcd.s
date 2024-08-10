
; We'll need binary to BCD for track numbers.
; Shortest code I could come up with --Ivo August 2024
;
; Build with:
; mads -o:tobcd.xex tobcd.s && ../../tools/xex2lod < tobcd.xex > tobcd.lod

tmp = $f0

    org $0300

test:
    ldy #99

@:
    tya
    jsr tobcd
    sta $0400,y

    dey
    bpl @-

    jmp *

; ----------------------------------------------------------------------------

; convert binary to BCD (0-99 max.)
; code size: 21 bytes

tobcd:
    ldx #0
@:
    cmp #10
    bcc final_step

    inx

; carry is always set
    sbc #10
    bcs @-

final_step:
    sta tmp

    txa
    asl
    asl
    asl
    asl

; carry is always clear
    adc tmp
    rts

    .print "size tobcd() = ", *-tobcd

; ----------------------------------------------------------------------------

    run test
