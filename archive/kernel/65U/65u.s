; OSI 65U PROM MONITOR MOD 2
;
; From 65V Primer Manual, OCR'd with tesseract
; Cleanup by Ivo van Poorten, August 2024
; Assemble with Mad-Assembler
;
; mads -o:65u.rom 65u.s

FLAG=$FB
DAT=$FC
PNTL=$FE
PNTH=$FF

    opt h-

    org $FE00

VM:
    LDX #$28                ; INITIALIZATION
    TXS
    CLD
    LDA $FB06
    LDA #$FF
    STA $FB05
    LDX #$D8
    LDA #$D0
    STA PNTH
    LDA #0
    STA PNTL
    STA FLAG
    TAY
    LDA #' '

VM1:
    STA (PNTL),Y
    INY
    BNE VM1
    INC PNTH
    CPX PNTH
    BNE VM1
    STY PNTH
    BEQ IN

ADDR:
    JSR INPUT               ; ADDRESS MODE
    CMP #'/'
    BEQ DATA
    CMP #'G'
    BEQ GO
    CMP #'L'
    BEQ LOAD
    JSR LEGAL
    BMI ADDR
    LDX #2
    JSR ROLL

IN:
    LDA (PNTL),Y
    STA DAT
    JSR OUTPUT
    BNE ADDR

GO:
    JMP (PNTL)

DATA:
    JSR INPUT               ; DATA MODE
    CMP #'.'
    BEQ ADDR
    CMP #$D
    BNE DAT4
    INC PNTL
    BNE DAT3
    INC PNTH

DAT3:
    LDY #0
    LDA (PNTL),Y
    STA DAT
    JMP INNER

DAT4:
    JSR LEGAL
    BMI DATA
    LDX #0
    JSR ROLL
    LDA DAT
    STA (PNTL),Y

INNER:
    JSR OUTPUT
    BNE DATA

LOAD:
    STA FLAG                ; KICK INPUT DEVICE FLAG
LOAD2:                      ; label missing in manual
    BEQ DATA

OTHER:
    LDA $FC00               ; SERIAL INPUT SUB.
    LSR                     ; (FOR AUDIO CASSETTE)
    BCC OTHER
    LDA $FC01
    NOP
    NOP
    NOP
    AND #$7F
    RTS

    .BYTE 0,0,0,0           ; EXCESS ROOM

LEGAL:
    CMP #'0'                ; IGNORE NON HEX CHAR.
    BMI FAIL
    CMP #':'
    BMI OK
    CMP #'A'
    BMI FAIL
    CMP #'G'
    BPL FAIL
    SEC
    SBC #7

OK:
    AND #$F
    RTS

FAIL:
    LDA #$80
    RTS

OUTPUT:
    LDX #3                  ; OUTPUT LLLL DD
    LDY #0                  ; ONTO SCREEN
OUI:
    LDA DAT,X
    LSR
    LSR
    LSR
    LSR
    JSR DIGIT
    LDA DAT,X
    JSR DIGIT
    DEX
    BPL OUI

    LDA #' '
    STA  $D0CA
    STA  $D0CB
    RTS

DIGIT:
    AND #$F                 ; OUTPUT 1 DIGIT TO SCREEN
    ORA #$30
    CMP #$3A
    BMI HA1
    CLC
    ADC #7
HA1:
    STA  $D0C6,Y
    INY
    RTS

ROLL:
    LDY #4                  ; MOVE LSD IN AC TO
    ASL                     ; LSD IN 2 BYTE NUM.
    ASL
    ASL
    ASL
R01:
    ROL
    ROL DAT,X
    ROL DAT+1,X
    DEY
    BNE R01
    RTS

INPUT:                      ; label missing in manual
    LDA FLAG                ; CASSETTE IN?
    BNE LOAD2               ; YES-GO DO ACIA INPUT
    JMP $FD00               ; NO-GO POLL KB

KBTEST:
    LDA #$FF                ; KB TEST SUBR.
    STA $DF00
    LDA $DF00
    RTS

    NOP

    .WORD $130              ; NMI VECTOR
    .WORD $FE00             ; RESET VECTOR
    .WORD $1C0              ; IRQ VECTOR
