;Monitor ROM for 440 board 65V monitor (ASCII KB)

*=$FE00
MONITOR
       LDX #$28
       TXS          ;set stack ptr, clear decimal
       CLD
       LDA $FB06    ; reset address of 430 board UART
       LDA #$FF
       STA $FB05    ; set UART S1883 8N2
       LDX #$D4     ;end page of screen blank
       LDA #$D0     ;start page of screen blank
       STA $FF
       LDA #$00
       STA $FE
       STA $FB      ;turn off serial input (use KB)
       TAY
       LDA #$20     ;fill 2K screen $D000-$D7FF with $20 ' '
LFE1B  STA ($FE),Y
       INY
       BNE LFE1B
       INC $FF
       CPX $FF
       BNE LFE1B
       STY $FF      ;zero $FF
       BEQ LFE43    ;always branch
LFE2A  JSR SFEE9    ;get char from ascii kb/serial
       CMP #$2F
       BEQ LFE4F    ;cmd '/'
       CMP #$47
       BEQ LFE4C    ;cmd 'G'
       CMP #$4C
       BEQ LFE7C    ;cmd 'L'
       JSR SFE93
       BMI LFE2A
       LDX #$02
       JSR SFEDA
LFE43  LDA ($FE),Y  ;(initially points to $0000)
       STA $FC
       JSR SFEAC    ;display monitor address & data
       BNE LFE2A    ;always branch
LFE4C  JMP ($00FE)

LFE4F  JSR SFEE9    ;process '/' cmd -- get char from ascii kb/serial
       CMP #$2E
       BEQ LFE2A    ;'.' exits
       CMP #$0D
       BNE LFE69    ;<CR> increments monitor address
       INC $FE
       BNE LFE60
       INC $FF
LFE60  LDY #$00
       LDA ($FE),Y
       STA $FC
       JMP LFE77

LFE69  JSR SFE93    ;hex char is stored, others ignored
       BMI LFE4F
       LDX #$00
       JSR SFEDA
       LDA $FC
       STA ($FE),Y
LFE77  JSR SFEAC
       BNE LFE4F
LFE7C  STA $FB
LFE7E  BEQ LFE4F    ;*read 7bit byte from ACIA
LFE80  LDA $FC00
       LSR A
       BCC LFE80    ;wait for byte ready
       LDA $FC01
       NOP
       NOP
       NOP
       AND #$7F
       RTS

       BRK
       BRK
       BRK
       BRK
SFE93  CMP #$30     ;< 0?  *ascii char to hex value
       BMI LFEA9
       CMP #$3A     ;<':' ?
       BMI LFEA6
       CMP #$41     ;< 'A' ?
       BMI LFEA9
       CMP #$47     ;>= 'G' >
       BPL LFEA9
       SEC
       SBC #$07
LFEA6  AND #$0F
       RTS

LFEA9  LDA #$80
       RTS

SFEAC  LDX #$03      ;hex output 4 bytes @ $FF to $FC
       LDY #$00      ;display bytes in $FF, $FE, $FD, $FC
LFEB0  LDA $FC,X
       LSR A
       LSR A
       LSR A
       LSR A
       JSR SFECA
       LDA $FC,X
       JSR SFECA
       DEX
       BPL LFEB0
       LDA #$20      ;blank  extra chars on display (from $FD)
       STA $D0CA
       STA $D0CB
       RTS

SFECA  AND #$0F      ;display hex nibble @D0C6+
       ORA #$30
       CMP #$3A
       BMI LFED5
       CLC
       ADC #$07
LFED5  STA $D0C6,Y
       INY
       RTS

SFEDA  LDY #$04      ;shift nibble into memory
       ASL A
       ASL A
       ASL A
       ASL A
LFEE0  ROL A
       ROL $FC,X
       ROL $FD,X
       DEY
       BNE LFEE0
       RTS

SFEE9  LDA $FB      ;controls ASCII KB or serial input
       BNE LFE7E
LFEED  LDA $DF01    ;entry for chr-in
       BMI LFEED    ;wait for msb bit to go low signaling character present
       PHA          ;save KB value
LFEF3  LDA $DF01    ;wait for msb to go hi, indicating no keypress
       BPL LFEF3
       PLA          ;return KB value
       RTS
        .BYTE $30, $01 ;NMI vector (unused at current address)
        .BYTE $00, $FE ;Reset vector
        .BYTE $C0, $01 ;IRQ vector
