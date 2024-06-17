
    org $0300

start:
    lda #2
    sta $de00

restart:
    ldx #0

@:
    lda melody,x
    bmi end
    tay
    lda notes,y
    sta $df01
    jsr wait

    inx
    bne @-

end:
    lda #0
    sta $de00
    jmp *

; ----------------------------------------------------------------------------

wait:
    lda #$c0
    sta outer
    ldy #0
@:
    dey
    bne @-
    dec outer
    bne @-
    rts

outer:
    .byte 0

; ----------------------------------------------------------------------------

; Pictures At An Exhibition - Modest Mussorgsky

melody:
    .byte G4, G4, F4, F4, As4, As4, C5, F5, D5, D5          ; bar 1 5/4
    .byte C5, F5, D5, D5, As4, As4, C5, C5, G4, G4, F4, F4  ; bar 2 6/4
    .byte -1

; ----------------------------------------------------------------------------

G3  = $07
Gs3 = $08
A3  = $09
As3 = $0a
B3  = $0b

C4  = $0c
Cs4 = $0d
D4  = $0e
Ds4 = $0f
E4  = $10
F4  = $11
Fs4 = $12
G4  = $13
Gs4 = $14
A4  = $15
As4 = $16
B4  = $17

C5  = $18
Cs5 = $19
D5  = $1a
Ds5 = $1b
E5  = $1c
F5  = $1d
Fs5 = $1e
G5  = $1f
Gs5 = $20
A5  = $21
As5 = $22
B5  = $23

C6  = $24
Cs6 = $25
D6  = $26
Ds6 = $27
E6  = $28
F6  = $29
Fs6 = $2a
G6  = $2b
Gs6 = $2c
A6  = $2d
As6 = $2e
B6  = $2f

C7  = $30

; ----------------------------------------------------------------------------

; offset is (octave-3) * 12 + note
; note ∈ [0..11]

notes:
oct3:
    .byte 0,0,0,0,0,0,0     ; padding
    ; G-3 .. B-3
    .byte 250, 236, 222, 210, 198
oct4:
    ; C-4 .. B-4
    .byte 187, 176, 166, 157, 148, 140, 132, 124, 117, 111, 104, 99
oct5:
    ; C-5 .. B-5
    .byte 93, 88, 83, 78, 74, 69, 65, 62, 58, 55, 52, 49
oct6:
    ; C-6 .. B-6    (major detuning starts here)
    .byte 46, 43, 41, 38, 36, 34, 32, 30, 29, 27, 25, 24
oct7:
    ; C-7
    .byte 22

; ----------------------------------------------------------------------------

    run start
