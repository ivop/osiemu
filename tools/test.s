; Mad-Assembler (mads) format
; Exports Atari binary format, each block is:
;   FFFF        optional marker, except for first block
;   LLHH        HHLL start address
;   LLHH        end address
;
; Special block: 02E0-02E1 contains RUN address
;
; Assemble with: mads -o:test.xex test.s
; Convert with: xex2lod < test.xex > test.lod

SCREEN = $d000

    org $0200

; clear screen

start:
    ldy #0
    lda #' '
@:
    .rept 8
        sta SCREEN+#*256,y
    .endr
    iny
    bne @-

; Display message

    ldy #message_end-message-1
@:
    lda message,y
    sta SCREEN,y
    dey
    bpl @-

    jmp *

message:
    .byte 'Hello, world!'
message_end:

    run start

