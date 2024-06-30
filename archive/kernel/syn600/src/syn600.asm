; SYN600 - OSI multiboard Monitor ROM
; pages banked into address space depending on machine configuration

; page 000 'H/D/M'   maps to $FF00 for a C2/C4 disk system
; page 100 keypoller maps to $FD00 for a C2/C4 system
; page 200 monitor   maps to $FE00 for a C2/C4 system
; page 300 'C/W/M'   maps to $FF00 for a C2/C4 tape system
; page 400 disk boot maps to $FC00 for a C1 system
; page 500 keypoller maps to $FD00 for a C1 system
; page 600 monitor   maps to $FE00 for a C1 system
; page 700 'D/C/W/M' maps to $FF00 for a C1 system

;page 0 @ $FF00	floppy disk support
FF00  A0 00      LDY #$00
FF02  8C 01 C0   STY $C001
FF05  8C 00 C0   STY $C000
FF08  A2 04      LDX #$04
FF0A  8E 01 C0   STX $C001
FF0D  8C 03 C0   STY $C003
FF10  88         DEY
FF11  8C 02 C0   STY $C002
FF14  8E 03 C0   STX $C003
FF17  8C 02 C0   STY $C002
FF1A  A9 FB      LDA #$FB
FF1C  D0 09      BNE $FF27
FF1E  A9 02      LDA #$02
FF20  2C 00 C0   BIT $C000
FF23  F0 1C      BEQ $FF41
FF25  A9 FF      LDA #$FF
FF27  8D 02 C0   STA $C002
FF2A  20 99 FF   JSR $FF99
FF2D  29 F7      AND #$F7
FF2F  8D 02 C0   STA $C002
FF32  20 99 FF   JSR $FF99
FF35  09 08      ORA #$08
FF37  8D 02 C0   STA $C002
FF3A  A2 18      LDX #$18
FF3C  20 85 FF   JSR $FF85
FF3F  F0 DD      BEQ $FF1E
FF41  A2 7F      LDX #$7F
FF43  8E 02 C0   STX $C002
FF46  20 85 FF   JSR $FF85
FF49  AD 00 C0   LDA $C000
FF4C  30 FB      BMI $FF49
FF4E  AD 00 C0   LDA $C000
FF51  10 FB      BPL $FF4E
FF53  A9 03      LDA #$03
FF55  8D 10 C0   STA $C010
FF58  A9 58      LDA #$58
FF5A  8D 10 C0   STA $C010
FF5D  20 90 FF   JSR $FF90
FF60  85 FE      STA $FE
FF62  AA         TAX
FF63  20 90 FF   JSR $FF90
FF66  85 FD      STA $FD
FF68  20 90 FF   JSR $FF90
FF6B  85 FF      STA $FF
FF6D  A0 00      LDY #$00
FF6F  20 90 FF   JSR $FF90
FF72  91 FD      STA ($FD),Y
FF74  C8         INY
FF75  D0 F8      BNE $FF6F
FF77  E6 FE      INC $FE
FF79  C6 FF      DEC $FF
FF7B  D0 F2      BNE $FF6F
FF7D  86 FE      STX $FE
FF7F  A9 FF      LDA #$FF
FF81  8D 02 C0   STA $C002
FF84  60         RTS
FF85  A0 F8      LDY #$F8
FF87  88         DEY
FF88  D0 FD      BNE $FF87
FF8A  55 FF      EOR $FF,X
FF8C  CA         DEX
FF8D  D0 F6      BNE $FF85
FF8F  60         RTS
FF90  AD 10 C0   LDA $C010
FF93  4A         LSR A
FF94  90 FA      BCC $FF90
FF96  AD 11 C0   LDA $C011
FF99  60         RTS
FF9A  48 2F 44   .BYTE 'H/D/M?'
FF9D  2F 4D 3F 
FFA0  D8         CLD
FFA1  A2 D8      LDX #$D8
FFA3  A9 D0      LDA #$D0
FFA5  85 FE      STA $FE
FFA7  A0 00      LDY #$00
FFA9  84 FD      STY $FD
FFAB  A9 20      LDA #$20
FFAD  91 FD      STA ($FD),Y
FFAF  C8         INY
FFB0  D0 FB      BNE $FFAD
FFB2  E6 FE      INC $FE
FFB4  E4 FE      CPX $FE
FFB6  D0 F5      BNE $FFAD
FFB8  A9 03      LDA #$03
FFBA  8D 00 FC   STA $FC00
FFBD  A9 B1      LDA #$B1
FFBF  8D 00 FC   STA $FC00
FFC2  B9 9A FF   LDA $FF9A,Y
FFC5  30 0E      BMI $FFD5
FFC7  99 C6 D0   STA $D0C6,Y
FFCA  AE 01 FE   LDX $FE01
FFCD  D0 03      BNE $FFD2
FFCF  20 0B FE   JSR $FE0B
FFD2  C8         INY
FFD3  D0 ED      BNE $FFC2
FFD5  AD 01 FE   LDA $FE01
FFD8  D0 05      BNE $FFDF
FFDA  20 00 FE   JSR $FE00
FFDD  B0 03      BCS $FFE2
FFDF  20 ED FE   JSR $FEED
FFE2  C9 48      CMP #$48
FFE4  F0 0A      BEQ $FFF0
FFE6  C9 44      CMP #$44
FFE8  D0 0C      BNE $FFF6
FFEA  20 00 FF   JSR $FF00
FFED  4C 00 22   JMP $2200
FFF0  4C 00 FD   JMP $FD00
FFF3  20 00 FF   JSR $FF00
FFF6  6C FC FE   JMP ($FEFC)
FFF9  EA         NOP
FFFA  30 01      .BYTE $30, $01 ; IRQ
FFFC  A0 FF      .BYTE $A0, $FF ; RESET
FFFE  C0 01      .BYTE $C0, $01 ; NMI

; page 1 @ $FD00
FD00  8A         TXA
FD01  48         PHA
FD02  98         TYA
FD03  48         PHA
FD04  A9 01      LDA #$01
FD06  8D 00 DF   STA $DF00
FD09  AE 00 DF   LDX $DF00
FD0C  D0 05      BNE $FD13
FD0E  0A         ASL A
FD0F  D0 F5      BNE $FD06
FD11  F0 53      BEQ $FD66
FD13  4A         LSR A
FD14  90 09      BCC $FD1F
FD16  2A         ROL A
FD17  E0 21      CPX #$21
FD19  D0 F3      BNE $FD0E
FD1B  A9 1B      LDA #$1B
FD1D  D0 21      BNE $FD40
FD1F  20 C8 FD   JSR $FDC8
FD22  98         TYA
FD23  8D 13 02   STA $0213
FD26  0A         ASL A
FD27  0A         ASL A
FD28  0A         ASL A
FD29  38         SEC
FD2A  ED 13 02   SBC $0213
FD2D  8D 13 02   STA $0213
FD30  8A         TXA
FD31  4A         LSR A
FD32  20 C8 FD   JSR $FDC8
FD35  D0 2F      BNE $FD66
FD37  18         CLC
FD38  98         TYA
FD39  6D 13 02   ADC $0213
FD3C  A8         TAY
FD3D  B9 CF FD   LDA $FDCF,Y
FD40  CD 15 02   CMP $0215
FD43  D0 26      BNE $FD6B
FD45  CE 14 02   DEC $0214
FD48  F0 2B      BEQ $FD75
FD4A  A0 05      LDY #$05
FD4C  A2 C8      LDX #$C8
FD4E  CA         DEX
FD4F  D0 FD      BNE $FD4E
FD51  88         DEY
FD52  D0 F8      BNE $FD4C
FD54  F0 AE      BEQ $FD04
FD56  C9 01      CMP #$01
FD58  F0 35      BEQ $FD8F
FD5A  A0 00      LDY #$00
FD5C  C9 02      CMP #$02
FD5E  F0 47      BEQ $FDA7
FD60  A0 C0      LDY #$C0
FD62  C9 20      CMP #$20
FD64  F0 41      BEQ $FDA7
FD66  A9 00      LDA #$00
FD68  8D 16 02   STA $0216
FD6B  8D 15 02   STA $0215
FD6E  A9 02      LDA #$02
FD70  8D 14 02   STA $0214
FD73  D0 8F      BNE $FD04
FD75  A2 96      LDX #$96
FD77  CD 16 02   CMP $0216
FD7A  D0 02      BNE $FD7E
FD7C  A2 14      LDX #$14
FD7E  8E 14 02   STX $0214
FD81  8D 16 02   STA $0216
FD84  A9 01      LDA #$01
FD86  8D 00 DF   STA $DF00
FD89  AD 00 DF   LDA $DF00
FD8C  4A         LSR A
FD8D  90 33      BCC $FDC2
FD8F  AA         TAX
FD90  29 03      AND #$03
FD92  F0 0B      BEQ $FD9F
FD94  A0 10      LDY #$10
FD96  AD 15 02   LDA $0215
FD99  10 0C      BPL $FDA7
FD9B  A0 F0      LDY #$F0
FD9D  D0 08      BNE $FDA7
FD9F  A0 00      LDY #$00
FDA1  E0 20      CPX #$20
FDA3  D0 02      BNE $FDA7
FDA5  A0 C0      LDY #$C0
FDA7  AD 15 02   LDA $0215
FDAA  29 7F      AND #$7F
FDAC  C9 20      CMP #$20
FDAE  F0 07      BEQ $FDB7
FDB0  8C 13 02   STY $0213
FDB3  18         CLC
FDB4  6D 13 02   ADC $0213
FDB7  8D 13 02   STA $0213
FDBA  68         PLA
FDBB  A8         TAY
FDBC  68         PLA
FDBD  AA         TAX
FDBE  AD 13 02   LDA $0213
FDC1  60         RTS
FDC2  D0 92      BNE $FD56
FDC4  A0 20      LDY #$20
FDC6  D0 DF      BNE $FDA7
FDC8  A0 08      LDY #$08
FDCA  88         DEY
FDCB  0A         ASL A
FDCC  90 FC      BCC $FDCA
FDCE  60         RTS
FDCF  D0 BB      BNE $FD8C
FDD1  2F         ERR2F
FDD2  20 5A 41   JSR $415A
FDD5  51 2C      EOR ($2C),Y
FDD7  4D 4E 42   EOR $424E
FDDA  56 43      LSR $43,X
FDDC  58         CLI
FDDD  4B         ERR4B
FDDE  4A         LSR A
FDDF  48         PHA
FDE0  47         ERR47
FDE1  46 44      LSR $44
FDE3  53         ERR53
FDE4  49 55      EOR #$55
FDE6  59 54 52   EOR $5254,Y
FDE9  45 57      EOR $57
FDEB  00         BRK
FDEC  00         BRK
FDED  0D 0A 4F   ORA $4F0A
FDF0  4C 2E 00   JMP $002E
FDF3  FF         ERRFF
FDF4  2D BA 30   AND $30BA
FDF7  B9 B8 B7   LDA $B7B8,Y
FDFA  B6 B5      LDX $B5,Y
FDFC  B4 B3      LDY $B3,X
FDFE  B2 B1      ERRB2 #$B1


;page 2 @ FE00

FE00  A2 28      LDX #$28
FE02  9A         TXS
FE03  D8         CLD
FE04  AD 06 FB   LDA $FB06
FE07  A9 FF      LDA #$FF
FE09  8D 05 FB   STA $FB05
FE0C  A2 D8      LDX #$D8
FE0E  A9 D0      LDA #$D0
FE10  85 FF      STA $FF
FE12  A9 00      LDA #$00
FE14  85 FE      STA $FE
FE16  85 FB      STA $FB
FE18  A8         TAY
FE19  A9 20      LDA #$20
FE1B  91 FE      STA ($FE),Y
FE1D  C8         INY
FE1E  D0 FB      BNE $FE1B
FE20  E6 FF      INC $FF
FE22  E4 FF      CPX $FF
FE24  D0 F5      BNE $FE1B
FE26  84 FF      STY $FF
FE28  F0 19      BEQ $FE43
FE2A  20 E9 FE   JSR $FEE9
FE2D  C9 2F      CMP #$2F
FE2F  F0 1E      BEQ $FE4F
FE31  C9 47      CMP #$47
FE33  F0 17      BEQ $FE4C
FE35  C9 4C      CMP #$4C
FE37  F0 43      BEQ $FE7C
FE39  20 93 FE   JSR $FE93
FE3C  30 EC      BMI $FE2A
FE3E  A2 02      LDX #$02
FE40  20 DA FE   JSR $FEDA
FE43  B1 FE      LDA ($FE),Y
FE45  85 FC      STA $FC
FE47  20 AC FE   JSR $FEAC
FE4A  D0 DE      BNE $FE2A
FE4C  6C FE 00   JMP ($00FE)
FE4F  20 E9 FE   JSR $FEE9
FE52  C9 2E      CMP #$2E
FE54  F0 D4      BEQ $FE2A
FE56  C9 0D      CMP #$0D
FE58  D0 0F      BNE $FE69
FE5A  E6 FE      INC $FE
FE5C  D0 02      BNE $FE60
FE5E  E6 FF      INC $FF
FE60  A0 00      LDY #$00
FE62  B1 FE      LDA ($FE),Y
FE64  85 FC      STA $FC
FE66  4C 77 FE   JMP $FE77
FE69  20 93 FE   JSR $FE93
FE6C  30 E1      BMI $FE4F
FE6E  A2 00      LDX #$00
FE70  20 DA FE   JSR $FEDA
FE73  A5 FC      LDA $FC
FE75  91 FE      STA ($FE),Y
FE77  20 AC FE   JSR $FEAC
FE7A  D0 D3      BNE $FE4F
FE7C  85 FB      STA $FB
FE7E  F0 CF      BEQ $FE4F
FE80  AD 00 FC   LDA $FC00
FE83  4A         LSR A
FE84  90 FA      BCC $FE80
FE86  AD 01 FC   LDA $FC01
FE89  EA         NOP
FE8A  EA         NOP
FE8B  EA         NOP
FE8C  29 7F      AND #$7F
FE8E  60         RTS
FE8F  00         BRK
FE90  00         BRK
FE91  00         BRK
FE92  00         BRK
FE93  C9 30      CMP #$30
FE95  30 12      BMI $FEA9
FE97  C9 3A      CMP #$3A
FE99  30 0B      BMI $FEA6
FE9B  C9 41      CMP #$41
FE9D  30 0A      BMI $FEA9
FE9F  C9 47      CMP #$47
FEA1  10 06      BPL $FEA9
FEA3  38         SEC
FEA4  E9 07      SBC #$07
FEA6  29 0F      AND #$0F
FEA8  60         RTS
FEA9  A9 80      LDA #$80
FEAB  60         RTS
FEAC  A2 03      LDX #$03
FEAE  A0 00      LDY #$00
FEB0  B5 FC      LDA $FC,X
FEB2  4A         LSR A
FEB3  4A         LSR A
FEB4  4A         LSR A
FEB5  4A         LSR A
FEB6  20 CA FE   JSR $FECA
FEB9  B5 FC      LDA $FC,X
FEBB  20 CA FE   JSR $FECA
FEBE  CA         DEX
FEBF  10 EF      BPL $FEB0
FEC1  A9 20      LDA #$20
FEC3  8D CA D0   STA $D0CA
FEC6  8D CB D0   STA $D0CB
FEC9  60         RTS
FECA  29 0F      AND #$0F
FECC  09 30      ORA #$30
FECE  C9 3A      CMP #$3A
FED0  30 03      BMI $FED5
FED2  18         CLC
FED3  69 07      ADC #$07
FED5  99 C6 D0   STA $D0C6,Y
FED8  C8         INY
FED9  60         RTS
FEDA  A0 04      LDY #$04
FEDC  0A         ASL A
FEDD  0A         ASL A
FEDE  0A         ASL A
FEDF  0A         ASL A
FEE0  2A         ROL A
FEE1  36 FC      ROL $FC,X
FEE3  36 FD      ROL $FD,X
FEE5  88         DEY
FEE6  D0 F8      BNE $FEE0
FEE8  60         RTS
FEE9  A5 FB      LDA $FB
FEEB  D0 91      BNE $FE7E
FEED  4C 00 FD   JMP $FD00
FEF0  A9 FF      LDA #$FF
FEF2  8D 00 DF   STA $DF00
FEF5  AD 00 DF   LDA $DF00
FEF8  60         RTS
FEF9  EA         NOP
FEFA  30 01      .BYTE $03, $01 ;IRQ
FEFC  00 FE      .BYTE $00, $FE ;Reset
FEFE  C0 01      .BYTE $C0, $01 ;NMI

; page 3 $FF00
FF00  D8         CLD
FF01  A2 28      LDX #$28
FF03  9A         TXS
FF04  20 22 BF   JSR $BF22
FF07  A0 00      LDY #$00
FF09  8C 12 02   STY $0212
FF0C  8C 03 02   STY $0203
FF0F  8C 05 02   STY $0205
FF12  8C 06 02   STY $0206
FF15  AD E0 FF   LDA $FFE0
FF18  8D 00 02   STA $0200
FF1B  A9 20      LDA #$20
FF1D  99 00 D7   STA $D700,Y
FF20  99 00 D6   STA $D600,Y
FF23  99 00 D5   STA $D500,Y
FF26  99 00 D4   STA $D400,Y
FF29  99 00 D3   STA $D300,Y
FF2C  99 00 D2   STA $D200,Y
FF2F  99 00 D1   STA $D100,Y
FF32  99 00 D0   STA $D000,Y
FF35  C8         INY
FF36  D0 E5      BNE $FF1D
FF38  B9 5F FF   LDA $FF5F,Y
FF3B  F0 06      BEQ $FF43
FF3D  20 2D BF   JSR $BF2D
FF40  C8         INY
FF41  D0 F5      BNE $FF38
FF43  20 B8 FF   JSR $FFB8
FF46  C9 4D      CMP #$4D
FF48  D0 03      BNE $FF4D
FF4A  4C 00 FE   JMP $FE00
FF4D  C9 57      CMP #$57
FF4F  D0 03      BNE $FF54
FF51  4C 00 00   JMP $0000
FF54  C9 43      CMP #$43
FF56  D0 A8      BNE $FF00
FF58  A9 00      LDA #$00
FF5A  AA         TAX
FF5B  A8         TAY
FF5C  4C 11 BD   JMP $BD11
FF5F  43         ERR43
FF60  2F         ERR2F
FF61  57         ERR57
FF62  2F         ERR2F
FF63  4D 20 3F   EOR $3F20
FF66  00         BRK
FF67  20 2D BF   JSR $BF2D
FF6A  48         PHA
FF6B  AD 05 02   LDA $0205
FF6E  F0 22      BEQ $FF92
FF70  68         PLA
FF71  20 15 BF   JSR $BF15
FF74  C9 0D      CMP #$0D
FF76  D0 1B      BNE $FF93
FF78  48         PHA
FF79  8A         TXA
FF7A  48         PHA
FF7B  A2 0A      LDX #$0A
FF7D  A9 00      LDA #$00
FF7F  20 15 BF   JSR $BF15
FF82  CA         DEX
FF83  D0 FA      BNE $FF7F
FF85  68         PLA
FF86  AA         TAX
FF87  68         PLA
FF88  60         RTS
FF89  48         PHA
FF8A  CE 03 02   DEC $0203
FF8D  A9 00      LDA #$00
FF8F  8D 05 02   STA $0205
FF92  68         PLA
FF93  60         RTS
FF94  48         PHA
FF95  A9 01      LDA #$01
FF97  D0 F6      BNE $FF8F
FF99  AD 12 02   LDA $0212
FF9C  D0 19      BNE $FFB7
FF9E  A9 01      LDA #$01
FFA0  8D 00 DF   STA $DF00
FFA3  2C 00 DF   BIT $DF00
FFA6  50 0F      BVC $FFB7
FFA8  A9 04      LDA #$04
FFAA  8D 00 DF   STA $DF00
FFAD  2C 00 DF   BIT $DF00
FFB0  50 05      BVC $FFB7
FFB2  A9 03      LDA #$03
FFB4  4C 36 A6   JMP $A636
FFB7  60         RTS
FFB8  2C 03 02   BIT $0203
FFBB  10 19      BPL $FFD6
FFBD  A9 02      LDA #$02
FFBF  8D 00 DF   STA $DF00
FFC2  A9 10      LDA #$10
FFC4  2C 00 DF   BIT $DF00
FFC7  D0 0A      BNE $FFD3
FFC9  AD 00 FC   LDA $FC00
FFCC  4A         LSR A
FFCD  90 EE      BCC $FFBD
FFCF  AD 01 FC   LDA $FC01
FFD2  60         RTS
FFD3  EE 03 02   INC $0203
FFD6  4C ED FE   JMP $FEED
FFD9  00         BRK
FFDA  00         BRK
FFDB  00         BRK
FFDC  00         BRK
FFDD  00         BRK
FFDE  00         BRK
FFDF  00         BRK
FFE0  40 3F 01  .BYTE $40, $3F, $01   ;cursor @ $40, line len $3F, 2K video
FFE3  00         BRK
FFE4  03         ERR03
FFE5  FF         ERRFF
FFE6  3F         ERR3F
FFE7  00         BRK
FFE8  03         ERR03
FFE9  FF         ERRFF
FFEA  3F         ERR3F
FFEB  4C B8 FF   JMP $FFB8
FFEE  4C 67 FF   JMP $FF67
FFF1  4C 99 FF   JMP $FF99
FFF4  4C 89 FF   JMP $FF89
FFF7  4C 94 FF   JMP $FF94
FFFA  30 01      .BYTE $30, $01 ; IRQ
FFFC  00         .BYTE $00, $FF ; RESET
FFFE  C0 01      .BYTE $C0, $01 ; NMI

;page 4 $FC00  floppy disk support C1

FC00  20 0C FC   JSR $FC0C
FC03  6C FD 00   JMP ($00FD)
FC06  20 0C FC   JSR $FC0C
FC09  4C 00 FE   JMP $FE00
FC0C  A0 00      LDY #$00
FC0E  8C 01 C0   STY $C001
FC11  8C 00 C0   STY $C000
FC14  A2 04      LDX #$04
FC16  8E 01 C0   STX $C001
FC19  8C 03 C0   STY $C003
FC1C  88         DEY
FC1D  8C 02 C0   STY $C002
FC20  8E 03 C0   STX $C003
FC23  8C 02 C0   STY $C002
FC26  A9 FB      LDA #$FB
FC28  D0 09      BNE $FC33
FC2A  A9 02      LDA #$02
FC2C  2C 00 C0   BIT $C000
FC2F  F0 1C      BEQ $FC4D
FC31  A9 FF      LDA #$FF
FC33  8D 02 C0   STA $C002
FC36  20 A5 FC   JSR $FCA5
FC39  29 F7      AND #$F7
FC3B  8D 02 C0   STA $C002
FC3E  20 A5 FC   JSR $FCA5
FC41  09 08      ORA #$08
FC43  8D 02 C0   STA $C002
FC46  A2 18      LDX #$18
FC48  20 91 FC   JSR $FC91
FC4B  F0 DD      BEQ $FC2A
FC4D  A2 7F      LDX #$7F
FC4F  8E 02 C0   STX $C002
FC52  20 91 FC   JSR $FC91
FC55  AD 00 C0   LDA $C000
FC58  30 FB      BMI $FC55
FC5A  AD 00 C0   LDA $C000
FC5D  10 FB      BPL $FC5A
FC5F  A9 03      LDA #$03
FC61  8D 10 C0   STA $C010
FC64  A9 58      LDA #$58
FC66  8D 10 C0   STA $C010
FC69  20 9C FC   JSR $FC9C
FC6C  85 FE      STA $FE
FC6E  AA         TAX
FC6F  20 9C FC   JSR $FC9C
FC72  85 FD      STA $FD
FC74  20 9C FC   JSR $FC9C
FC77  85 FF      STA $FF
FC79  A0 00      LDY #$00
FC7B  20 9C FC   JSR $FC9C
FC7E  91 FD      STA ($FD),Y
FC80  C8         INY
FC81  D0 F8      BNE $FC7B
FC83  E6 FE      INC $FE
FC85  C6 FF      DFC $FF
FC87  D0 F2      BNE $FC7B
FC89  86 FE      STX $FE
FC8B  A9 FF      LDA #$FF
FC8D  8D 02 C0   STA $C002
FC90  60         RTS
FC91  A0 F8      LDY #$F8
FC93  88         DEY
FC94  D0 FD      BNE $FC93
FC96  55 FF      EOR $FF,X
FC98  CA         DEX
FC99  D0 F6      BNE $FC91
FC9B  60         RTS
FC9C  AD 10 C0   LDA $C010
FC9F  4A         LSR A
FCA0  90 FA      BCC $FC9C
FCA2  AD 11 C0   LDA $C011
FCA5  60         RTS
FCA6  A9 03      LDA #$03    ;ACIA @ $F000?
FCA8  8D 00 F0   STA $F000
FCAB  A9 11      LDA #$11
FCAD  8D 00 F0   STA $F000
FCB0  60         RTS
FCB1  48         PHA
FCB2  AD 00 F0   LDA $F000
FCB5  4A         LSR A
FCB6  4A         LSR A
FCB7  90 F9      BCC $FCB2
FCB9  68         PLA
FCBA  8D 01 F0   STA $F001
FCBD  60         RTS
FCBE  49 FF      EOR #$FF	 ;Set KB ROW 
FCC0  8D 00 DF   STA $DF00
FCC3  49 FF      EOR #$FF
FCC5  60         RTS
FCC6  48         PHA
FCC7  20 CF FC   JSR $FCCF
FCCA  AA         TAX
FCCB  68         PLA
FCCC  CA         DEX
FCCD  E8         INX
FCCE  60         RTS
FCCF  AD 00 DF   LDA $DF00     ;load KB Col
FCD2  49 FF      EOR #$FF
FCD4  60         RTS
FCD5  FF         ERRFF
FCD6  FF         ERRFF
FCD7  FF         ERRFF
FCD8  FF         ERRFF
FCD9  FF         ERRFF
FCDA  FF         ERRFF
FCDB  FF         ERRFF
FCDC  FF         ERRFF
FCDD  FF         ERRFF
FCDE  FF         ERRFF
FCDF  FF         ERRFF
FCE0  FF         ERRFF
FCE1  FF         ERRFF
FCE2  FF         ERRFF
FCE3  FF         ERRFF
FCE4  FF         ERRFF
FCE5  FF         ERRFF
FCE6  FF         ERRFF
FCE7  FF         ERRFF
FCE8  FF         ERRFF
FCE9  FF         ERRFF
FCEA  FF         ERRFF
FCEB  FF         ERRFF
FCEC  FF         ERRFF
FCED  FF         ERRFF
FCEE  FF         ERRFF
FCEF  FF         ERRFF
FCF0  FF         ERRFF
FCF1  FF         ERRFF
FCF2  FF         ERRFF
FCF3  FF         ERRFF
FCF4  FF         ERRFF
FCF5  FF         ERRFF
FCF6  FF         ERRFF
FCF7  FF         ERRFF
FCF8  FF         ERRFF
FCF9  FF         ERRFF
FCFA  FF         ERRFF
FCFB  FF         ERRFF
FCFC  FF         ERRFF
FCFD  FF         ERRFF
FCFE  FF         ERRFF
FCFF  FF         ERRFF

;page 5 $FD00  key poller for C1
FD00  8A         TXA
FD01  48         PHA
FD02  98         TYA
FD03  48         PHA
FD04  A9 01      LDA #$01
FD06  20 BE FC   JSR $FCBE
FD09  20 C6 FC   JSR $FCC6
FD0C  D0 05      BNE $FD13
FD0E  0A         ASL A
FD0F  D0 F5      BNE $FD06
FD11  F0 53      BEQ $FD66
FD13  4A         LSR A
FD14  90 09      BCC $FD1F
FD16  2A         ROL A
FD17  E0 21      CPX #$21
FD19  D0 F3      BNE $FD0E
FD1B  A9 1B      LDA #$1B
FD1D  D0 21      BNE $FD40
FD1F  20 C8 FD   JSR $FDC8
FD22  98         TYA
FD23  8D 13 02   STA $0213
FD26  0A         ASL A
FD27  0A         ASL A
FD28  0A         ASL A
FD29  38         SEC
FD2A  ED 13 02   SBC $0213
FD2D  8D 13 02   STA $0213
FD30  8A         TXA
FD31  4A         LSR A
FD32  20 C8 FD   JSR $FDC8
FD35  D0 2F      BNE $FD66
FD37  18         CLC
FD38  98         TYA
FD39  6D 13 02   ADC $0213
FD3C  A8         TAY
FD3D  B9 CF FD   LDA $FDCF,Y
FD40  CD 15 02   CMP $0215
FD43  D0 26      BNE $FD6B
FD45  CE 14 02   DEC $0214
FD48  F0 2B      BEQ $FD75
FD4A  A0 05      LDY #$05
FD4C  A2 C8      LDX #$C8
FD4E  CA         DEX
FD4F  D0 FD      BNE $FD4E
FD51  88         DEY
FD52  D0 F8      BNE $FD4C
FD54  F0 AE      BEQ $FD04
FD56  C9 01      CMP #$01
FD58  F0 35      BEQ $FD8F
FD5A  A0 00      LDY #$00
FD5C  C9 02      CMP #$02
FD5E  F0 47      BEQ $FDA7
FD60  A0 C0      LDY #$C0
FD62  C9 20      CMP #$20
FD64  F0 41      BEQ $FDA7
FD66  A9 00      LDA #$00
FD68  8D 16 02   STA $0216
FD6B  8D 15 02   STA $0215
FD6E  A9 02      LDA #$02
FD70  8D 14 02   STA $0214
FD73  D0 8F      BNE $FD04
FD75  A2 96      LDX #$96
FD77  CD 16 02   CMP $0216
FD7A  D0 02      BNE $FD7E
FD7C  A2 14      LDX #$14
FD7E  8E 14 02   STX $0214
FD81  8D 16 02   STA $0216
FD84  A9 01      LDA #$01
FD86  20 BE FC   JSR $FCBE
FD89  20 CF FC   JSR $FCCF
FD8C  4A         LSR A
FD8D  90 33      BCC $FDC2
FD8F  AA         TAX
FD90  29 03      AND #$03
FD92  F0 0B      BEQ $FD9F
FD94  A0 10      LDY #$10
FD96  AD 15 02   LDA $0215
FD99  10 0C      BPL $FDA7
FD9B  A0 F0      LDY #$F0
FD9D  D0 08      BNE $FDA7
FD9F  A0 00      LDY #$00
FDA1  E0 20      CPX #$20
FDA3  D0 02      BNE $FDA7
FDA5  A0 C0      LDY #$C0
FDA7  AD 15 02   LDA $0215
FDAA  29 7F      AND #$7F
FDAC  C9 20      CMP #$20
FDAE  F0 07      BEQ $FDB7
FDB0  8C 13 02   STY $0213
FDB3  18         CLC
FDB4  6D 13 02   ADC $0213
FDB7  8D 13 02   STA $0213
FDBA  68         PLA
FDBB  A8         TAY
FDBC  68         PLA
FDBD  AA         TAX
FDBE  AD 13 02   LDA $0213
FDC1  60         RTS
FDC2  D0 92      BNE $FD56
FDC4  A0 20      LDY #$20
FDC6  D0 DF      BNE $FDA7
FDC8  A0 08      LDY #$08
FDCA  88         DEY
FDCB  0A         ASL A
FDCC  90 FC      BCC $FDCA
FDCE  60         RTS
FDCF  D0 BB      BNE $FD8C
FDD1  2F         .BYTE '/ ZAQ,MNBVCXKJHGFDSIUYTREW',0,0
FDED             .BYTE $0D,$0A,$4F,$4C,$2E,$00,$FF,$2D,$BA,$30
                 .BYTE $B9,$B8,$B7,$B6,$B5,$B4,$B3,$B2,$B1


;page 6	 $FE00	 65V monitor for C1
FE00  A2 28      LDX #$28
FE02  9A         TXS
FE03  D8         CLD
FE04  EA         NOP
FE05  EA         NOP
FE06  EA         NOP
FE07  EA         NOP
FE08  EA         NOP
FE09  EA         NOP
FE0A  EA         NOP
FE0B  EA         NOP
FE0C  A2 D4      LDX #$D4
FE0E  A9 D0      LDA #$D0
FE10  85 FF      STA $FF
FE12  A9 00      LDA #$00
FE14  85 FE      STA $FE
FE16  85 FB      STA $FB
FE18  A8         TAY
FE19  A9 20      LDA #$20
FE1B  91 FE      STA ($FE),Y
FE1D  C8         INY
FE1E  D0 FB      BNE $FE1B
FE20  E6 FF      INC $FF
FE22  E4 FF      CPX $FF
FE24  D0 F5      BNE $FE1B
FE26  84 FF      STY $FF
FE28  F0 19      BEQ $FE43
FE2A  20 E9 FE   JSR $FEE9
FE2D  C9 2F      CMP #$2F
FE2F  F0 1E      BEQ $FE4F
FE31  C9 47      CMP #$47
FE33  F0 17      BEQ $FE4C
FE35  C9 4C      CMP #$4C
FE37  F0 43      BEQ $FE7C
FE39  20 93 FE   JSR $FE93
FE3C  30 EC      BMI $FE2A
FE3E  A2 02      LDX #$02
FE40  20 DA FE   JSR $FEDA
FE43  B1 FE      LDA ($FE),Y
FE45  85 FC      STA $FC
FE47  20 AC FE   JSR $FEAC
FE4A  D0 DE      BNE $FE2A
FE4C  6C FE 00   JMP ($00FE)
FE4F  20 E9 FE   JSR $FEE9
FE52  C9 2E      CMP #$2E
FE54  F0 D4      BEQ $FE2A
FE56  C9 0D      CMP #$0D
FE58  D0 0F      BNE $FE69
FE5A  E6 FE      INC $FE
FE5C  D0 02      BNE $FE60
FE5E  E6 FF      INC $FF
FE60  A0 00      LDY #$00
FE62  B1 FE      LDA ($FE),Y
FE64  85 FC      STA $FC
FE66  4C 77 FE   JMP $FE77
FE69  20 93 FE   JSR $FE93
FE6C  30 E1      BMI $FE4F
FE6E  A2 00      LDX #$00
FE70  20 DA FE   JSR $FEDA
FE73  A5 FC      LDA $FC
FE75  91 FE      STA ($FE),Y
FE77  20 AC FE   JSR $FEAC
FE7A  D0 D3      BNE $FE4F
FE7C  85 FB      STA $FB
FE7E  F0 CF      BEQ $FE4F
FE80  AD 00 F0   LDA $F000
FE83  4A         LSR A
FE84  90 FA      BCC $FE80
FE86  AD 01 F0   LDA $F001
FE89  EA         NOP
FE8A  EA         NOP
FE8B  EA         NOP
FE8C  29 7F      AND #$7F
FE8E  60         RTS
FE8F  00         BRK
FE90  00         BRK
FE91  00         BRK
FE92  00         BRK
FE93  C9 30      CMP #$30
FE95  30 12      BMI $FEA9
FE97  C9 3A      CMP #$3A
FE99  30 0B      BMI $FEA6
FE9B  C9 41      CMP #$41
FE9D  30 0A      BMI $FEA9
FE9F  C9 47      CMP #$47
FEA1  10 06      BPL $FEA9
FEA3  38         SEC
FEA4  E9 07      SBC #$07
FEA6  29 0F      AND #$0F
FEA8  60         RTS
FEA9  A9 80      LDA #$80
FEAB  60         RTS
FEAC  A2 03      LDX #$03
FEAE  A0 00      LDY #$00
FEB0  B5 FC      LDA $FC,X
FEB2  4A         LSR A
FEB3  4A         LSR A
FEB4  4A         LSR A
FEB5  4A         LSR A
FEB6  20 CA FE   JSR $FECA
FEB9  B5 FC      LDA $FC,X
FEBB  20 CA FE   JSR $FECA
FEBE  CA         DEX
FEBF  10 EF      BPL $FEB0
FEC1  A9 20      LDA #$20
FEC3  8D CA D0   STA $D0CA
FEC6  8D CB D0   STA $D0CB
FEC9  60         RTS
FECA  29 0F      AND #$0F
FECC  09 30      ORA #$30
FECE  C9 3A      CMP #$3A
FED0  30 03      BMI $FED5
FED2  18         CLC
FED3  69 07      ADC #$07
FED5  99 C6 D0   STA $D0C6,Y
FED8  C8         INY
FED9  60         RTS
FEDA  A0 04      LDY #$04
FEDC  0A         ASL A
FEDD  0A         ASL A
FEDE  0A         ASL A
FEDF  0A         ASL A
FEE0  2A         ROL A
FEE1  36 FC      ROL $FC,X
FEE3  36 FD      ROL $FD,X
FEE5  88         DEY
FEE6  D0 F8      BNE $FEE0
FEE8  60         RTS
FEE9  A5 FB      LDA $FB
FEEB  D0 93      BNE $FE80
FEED  4C 00 FD   JMP $FD00
FEF0  BA         TSX
FEF1  FF         ERRFF
FEF2  69 FF      ADC #$FF
FEF4  9B         ERR9B
FEF5  FF         ERRFF
FEF6  8B         ERR8B
FEF7  FF         ERRFF
FEF8  96 FF      STX $FF,Y
FEFA  30 01      .BYTE $30, $01 ; IRQ when mapped to $FFxx
FEFC  00 FF      .BYTE $00, $FF ; RESET when mapped to $FFxx
FEFE  C0 01      .BYTE $C0, $01 ; NMI when mapped to $FFxx


;page 7	 $FF00 ROM for C1 'D/C/W/M ?'
FF00  D8         CLD
FF01  A2 28      LDX #$28
FF03  9A         TXS
FF04  A0 0A      LDY #$0A
FF06  B9 EF FE   LDA $FEEF,Y
FF09  99 17 02   STA $0217,Y
FF0C  88         DEY
FF0D  D0 F7      BNE $FF06
FF0F  20 A6 FC   JSR $FCA6	;reset ACIA @ $F000
FF12  8C 12 02   STY $0212
FF15  8C 03 02   STY $0203
FF18  8C 05 02   STY $0205
FF1B  8C 06 02   STY $0206
FF1E  AD E0 FF   LDA $FFE0
FF21  8D 00 02   STA $0200
FF24  A9 20      LDA #$20      ;1K screen clear
FF26  99 00 D3   STA $D300,Y
FF29  99 00 D2   STA $D200,Y
FF2C  99 00 D1   STA $D100,Y
FF2F  99 00 D0   STA $D000,Y
FF32  C8         INY
FF33  D0 F1      BNE $FF26
FF35  B9 5F FF   LDA $FF5F,Y   ;D/C/W/M ?
FF38  F0 06      BEQ $FF40
FF3A  20 2D BF   JSR $BF2D
FF3D  C8         INY
FF3E  D0 F5      BNE $FF35
FF40  20 BA FF   JSR $FFBA
FF43  C9 4D      CMP #'M    
FF45  D0 03      BNE $FF4A
FF47  4C 00 FE   JMP $FE00    ;jump to monitor
FF4A  C9 57      CMP #'W
FF4C  D0 03      BNE $FF51
FF4E  4C 00 00   JMP $0000    ;jump to warm start
FF51  C9 43      CMP #'C
FF53  D0 03      BNE $FF58
FF55  4C 11 BD   JMP $BD11    ;jump to cold start
FF58  C9 44      CMP #'D
FF5A  D0 A4      BNE $FF00
FF5C  4C 00 FC   JMP $FC00    ;jump to disk boot
FF5F  44 2F 43  .BYTE 'D/C/W/M ?',0
FF62  2F 57 2f    
FF65  4D 20 3F  
FF68  00     
FF69  20 2D BF   JSR $BF2D
FF6C  48         PHA
FF6D  AD 05 02   LDA $0205
FF70  F0 22      BEQ $FF94
FF72  68         PLA
FF73  20 B1 FC   JSR $FCB1
FF76  C9 0D      CMP #$0D
FF78  D0 1B      BNE $FF95
FF7A  48         PHA
FF7B  8A         TXA
FF7C  48         PHA
FF7D  A2 0A      LDX #$0A
FF7F  A9 00      LDA #$00
FF81  20 B1 FC   JSR $FCB1
FF84  CA         DEX
FF85  D0 FA      BNE $FF81
FF87  68         PLA
FF88  AA         TAX
FF89  68         PLA
FF8A  60         RTS
FF8B  48         PHA
FF8C  CE 03 02   DEC $0203
FF8F  A9 00      LDA #$00
FF91  8D 05 02   STA $0205
FF94  68         PLA
FF95  60         RTS
FF96  48         PHA
FF97  A9 01      LDA #$01
FF99  D0 F6      BNE $FF91
FF9B  AD 12 02   LDA $0212   ;test CTRL-C check disabled?
FF9E  D0 19      BNE $FFB9
FFA0  A9 FE      LDA #$FE
FFA2  8D 00 DF   STA $DF00   ;sel row 0
FFA5  2C 00 DF   BIT $DF00   ;test for CTRL key pressed
FFA8  70 0F      BVS $FFB9   ;not pressed, branch
FFAA  A9 FB      LDA #$FB
FFAC  8D 00 DF   STA $DF00   ;sel row 2
FFAF  2C 00 DF   BIT $DF00   ;test for 'C' key?
FFB2  70 05      BVS $FFB9   ;not pressed, branch
FFB4  A9 03      LDA #$03
FFB6  4C 36 A6   JMP $A636
FFB9  60         RTS
FFBA  2C 03 02   BIT $0203   ;test input from serial?
FFBD  10 19      BPL $FFD8   ;no, branch
FFBF  A9 FD      LDA #$FD
FFC1  8D 00 DF   STA $DF00   ;sel row 1
FFC4  A9 10      LDA #$10
FFC6  2C 00 DF   BIT $DF00   ;test for space-bar
FFC9  F0 0A      BEQ $FFD5
FFCB  AD 00 F0   LDA $F000   ;wait for ACIA char
FFCE  4A         LSR A
FFCF  90 EE      BCC $FFBF
FFD1  AD 01 F0   LDA $F001   ;load from ACIA 
FFD4  60         RTS
FFD5  EE 03 02   INC $0203
FFD8  4C 00 FD   JMP $FD00   ;jump to keyboard scan
FFDB  FF         ERRFF
FFDC  FF         ERRFF
FFDD  FF         ERRFF
FFDE  FF         ERRFF
FFDF  FF         ERRFF
FFE0  65 17 00  .BYTE $65, $17, $00   ;cursor @ $65, line len $17, 1K video
FFE3  00         BRK
FFE4  03         ERR03
FFE5  FF         ERRFF
FFE6  9F         ERR9F
FFE7  00         BRK
FFE8  03         ERR03
FFE9  FF         ERRFF
FFEA  9F         ERR9F
FFEB  6C 18 02   JMP ($0218)
FFEE  6C 1A 02   JMP ($021A)
FFF1  6C 1C 02   JMP ($021C)
FFF4  6C 1E 02   JMP ($021E)
FFF7  6C 20 02   JMP ($0220)
FFFA  30 01      .BYTE $30, $01 ; IRQ
FFFC  00 FF      .BYTE $00, $FF ; RESET
FFFE  C0 01      .BYTE $C0, $01 ; NMI

