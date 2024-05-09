; Contents of SYNMON1 OSI system ROM
; pages banked into address space depending on machine configuration
;
; SYNMON1 OSI 440/540/Serial boot notes
;
; Page 0  FE00 OSI 440 board 65V monitor (ASCII KB)
; Page 1  FF00 OSI 440 board C/W/M  BASIC boot (ASCII KB)
; Page 2  *FD00 C2/540 Polled Keyboard routine
; Page 3  *FE00 C2/540 65V Monitor
; Page 4  *FF00 C2/540 BASIC Boot (C/W/M?)
; Page 5  FD00 initializes HDisk controller (CD74 winchester HD)
; Page 6  FE00/FF00 OSI 65A Serial Monitor
;         Cmds 'R' reset, 
;              'P' <address> - dump data at supplied address until keypress
;              'L' <address><data> - read hex data from acia until 'R' encountered
;              'G' go (address stored at $0129+)
; Page 7  *FF00 C2/540 disk boot (H/D/M?) works with serial or video
; *(same as SYN600)

; So it can support: 
;  440 video/ASCII KB, BASIC in ROM  (C/W/M)(FF00-pg1, FE00-pg0)
;  440 video/ASCII KB, Disk/HD system(H/D/M)(FF00-pg7, FE00-pg0, FD00-pg5-if HD) 
;  540 video/Polled KB, BASIC in ROM (C/W/M)(FF00-pg4, FE00-pg3, FD00-pg2)
;  540 video/Polled KB, Disk, noHD   (H/D/M)(FF00-pg7, FE00-pg3, FD00-pg2)
;  C3 Serial Disk/HD system          (H/D/M)(FF00-pg7, FE00-pg6  FD00-pg5-if HD)

; OSI BASIC-IN-ROM memory locations
; $200 current screen cursor pos
; $201 temp storage for char to be printed
; $202 temp storage for CRT	driver -not used here
; $203 BASIC LOAD flag, not 0 = input from tape
; $204 temp X storage serial out
; $205 BASIC SAVE flag, 0 = not save mode
; $206 (time delay for CRT driver -not used here)
; $210 output enable flag, 0 = output to ACIA (console)
; $211 current match position for <LF>OK<CR> message 
; $212 CTRL-C flag, not 0 = ignore Ctrl-C
;

;
; $FExx 65V ROM Monitor for system with ASCII KB @ $DF01 & ACIA @ $FC00
; Page 0  FE00 OSI 440 board 65V monitor (ASCII KB)
FE00  A2 28      LDX #$28
FE02  9A         TXS	    ;set stack ptr, clear decimal
FE03  D8         CLD
FE04  AD 06 FB   LDA $FB06  ; reset address of 430 board UART 
FE07  A9 FF      LDA #$FF
FE09  8D 05 FB   STA $FB05  ; set UART S1883 8N2
FE0C  A2 D8      LDX #$D8   ;end page of screen blank
FE0E  A9 D0      LDA #$D0   ;start page of screen blank
FE10  85 FF      STA $FF
FE12  A9 00      LDA #$00
FE14  85 FE      STA $FE
FE16  85 FB      STA $FB     ;turn off serial input (use KB)
FE18  A8         TAY
FE19  A9 20      LDA #$20    ;fill 2K screen $D000-$D7FF with $20 ' '
FE1B  91 FE      STA ($FE),Y
FE1D  C8         INY
FE1E  D0 FB      BNE $FE1B
FE20  E6 FF      INC $FF
FE22  E4 FF      CPX $FF
FE24  D0 F5      BNE $FE1B
FE26  84 FF      STY $FF      ;zero $FF
FE28  F0 19      BEQ $FE43    ;always branch
FE2A  20 E9 FE   JSR $FEE9	  ;get char from ascii kb/serial
FE2D  C9 2F      CMP #'/
FE2F  F0 1E      BEQ $FE4F	  ;cmd '/'
FE31  C9 47      CMP #'G
FE33  F0 17      BEQ $FE4C	  ;cmd 'G'
FE35  C9 4C      CMP #'L
FE37  F0 43      BEQ $FE7C	  ;cmd 'L'
FE39  20 93 FE   JSR $FE93
FE3C  30 EC      BMI $FE2A
FE3E  A2 02      LDX #$02
FE40  20 DA FE   JSR $FEDA
FE43  B1 FE      LDA ($FE),Y   ;(initially points to $0000) 
FE45  85 FC      STA $FC
FE47  20 AC FE   JSR $FEAC     ;display monitor address & data
FE4A  D0 DE      BNE $FE2A	   ;always branch
FE4C  6C FE 00   JMP ($00FE)
FE4F  20 E9 FE   JSR $FEE9	   ;process '/' cmd -- get char from ascii kb/serial
FE52  C9 2E      CMP #'.
FE54  F0 D4      BEQ $FE2A	   ;'.' exits
FE56  C9 0D      CMP #$0D
FE58  D0 0F      BNE $FE69	   ;<CR> increments monitor address
FE5A  E6 FE      INC $FE
FE5C  D0 02      BNE $FE60
FE5E  E6 FF      INC $FF
FE60  A0 00      LDY #$00
FE62  B1 FE      LDA ($FE),Y
FE64  85 FC      STA $FC
FE66  4C 77 FE   JMP $FE77
FE69  20 93 FE   JSR $FE93	   ;hex char is stored, others ignored
FE6C  30 E1      BMI $FE4F
FE6E  A2 00      LDX #$00
FE70  20 DA FE   JSR $FEDA
FE73  A5 FC      LDA $FC
FE75  91 FE      STA ($FE),Y
FE77  20 AC FE   JSR $FEAC
FE7A  D0 D3      BNE $FE4F
FE7C  85 FB      STA $FB
FE7E  F0 CF      BEQ $FE4F     ;*read 7bit byte from ACIA
FE80  AD 00 FC   LDA $FC00
FE83  4A         LSR A
FE84  90 FA      BCC $FE80     ;wait for byte ready
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
FE93  C9 30      CMP #$30     ;< 0?  *ascii char to hex value
FE95  30 12      BMI $FEA9
FE97  C9 3A      CMP #$3A	  ;<':' ?
FE99  30 0B      BMI $FEA6
FE9B  C9 41      CMP #$41	  ;< 'A' ?
FE9D  30 0A      BMI $FEA9
FE9F  C9 47      CMP #$47	  ;>= 'G' >
FEA1  10 06      BPL $FEA9
FEA3  38         SEC
FEA4  E9 07      SBC #$07
FEA6  29 0F      AND #$0F
FEA8  60         RTS
FEA9  A9 80      LDA #$80
FEAB  60         RTS
FEAC  A2 03      LDX #$03    ;hex output 4 bytes @ $FF to $FC
FEAE  A0 00      LDY #$00	 ;display bytes in $FF, $FE, $FD, $FC
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
FEC1  A9 20      LDA #$20    ;blank  extra chars on display (from $FD)
FEC3  8D CA D0   STA $D0CA
FEC6  8D CB D0   STA $D0CB
FEC9  60         RTS
FECA  29 0F      AND #$0F    ;display hex nibble @D0C6+
FECC  09 30      ORA #$30
FECE  C9 3A      CMP #$3A
FED0  30 03      BMI $FED5
FED2  18         CLC
FED3  69 07      ADC #$07
FED5  99 C6 D0   STA $D0C6,Y
FED8  C8         INY
FED9  60         RTS
FEDA  A0 04      LDY #$04    ;shift nibble into memory
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
FEE9  A5 FB      LDA $FB     ;controls ASCII KB or serial
FEEB  D0 91      BNE $FE7E
FEED  AD 01 DF   LDA $DF01   ;entry for chr-in
FEF0  30 FB      BMI $FEED   ;wait for msb bit to go low
FEF2  48         PHA         ;save KB value
FEF3  AD 01 DF   LDA $DF01   ;wait for msb to go hi
FEF6  10 FB      BPL $FEF3
FEF8  68         PLA         ;return KB value
FEF9  60         RTS
FEFA  30 01      .BYTE $30, $01 ;NMI vector (unused at current address)
FEFC  00 FE      .BYTE $00, $FE ;Monitor vector "
FEFE  C0 01      .BYTE $C0, $01 ;IRQ vector     "

;Page 1  FF00  C/W/M  BASIC boot ASCII KB but 2K video? not correct flags for 440
;$FF00 block for Basic in ROM machine (C/W/M?) with ASCII keyboard  @ $DF01
; 2K video size
FF00  D8         CLD
FF01  A2 28      LDX #$28
FF03  9A         TXS
FF04  20 22 BF   JSR $BF22
FF07  A0 00      LDY #$00
FF09  8C 12 02   STY $0212
FF0C  8C 03 02   STY $0203
FF0F  8C 05 02   STY $0205
FF12  8C 06 02   STY $0206
FF15  AD E0 FF   LDA $FFE0  ;#$40
FF18  8D 00 02   STA $0200
FF1B  A9 20      LDA #$20   ;clear 2K screen
FF1D  8D 01 02   STA $0201
FF20  8D 0F 02   STA $020F
FF23  99 00 D7   STA $D700,Y
FF26  99 00 D6   STA $D600,Y
FF29  99 00 D5   STA $D500,Y
FF2C  99 00 D4   STA $D400,Y
FF2F  99 00 D3   STA $D300,Y
FF32  99 00 D2   STA $D200,Y
FF35  99 00 D1   STA $D100,Y
FF38  99 00 D0   STA $D000,Y
FF3B  C8         INY
FF3C  D0 E5      BNE $FF23
FF3E  B9 65 FF   LDA $FF65,Y  ;'C/W/M?'
FF41  F0 06      BEQ $FF49
FF43  20 2D BF   JSR $BF2D    ;basic screen chrout
FF46  C8         INY
FF47  D0 F5      BNE $FF3E
FF49  20 AB FF   JSR $FFAB
FF4C  C9 4D      CMP #$4D  ;'M
FF4E  D0 03      BNE $FF53
FF50  4C 00 FE   JMP $FE00
FF53  C9 57      CMP #$57  ;'W
FF55  D0 03      BNE $FF5A
FF57  4C 00 00   JMP $0000
FF5A  C9 43      CMP #$43  ;'C
FF5C  D0 A2      BNE $FF00
FF5E  A9 00      LDA #$00
FF60  AA         TAX
FF61  A8         TAY
FF62  4C 11 BD   JMP $BD11  ;BASIC Cold Start
FF65  43 2F 57   .BYTE 'C/W'
FF68  2F 4D 3F   .BYTE '/M?' 
FF6B  00         BRK
FF6C  20 2D BF   JSR $BF2D  ;Output routine entry
FF6F  48         PHA
FF70  AD 05 02   LDA $0205
FF73  F0 24      BEQ $FF99
FF75  68         PLA
FF76  20 15 BF   JSR $BF15
FF79  C9 0D      CMP #$0D
FF7B  D0 1D      BNE $FF9A
FF7D  48         PHA
FF7E  8A         TXA
FF7F  48         PHA
FF80  A2 0A      LDX #$0A
FF82  A9 00      LDA #$00
FF84  20 15 BF   JSR $BF15
FF87  CA         DEX
FF88  D0 FA      BNE $FF84
FF8A  68         PLA
FF8B  AA         TAX
FF8C  68         PLA
FF8D  60         RTS
FF8E  48         PHA		;Load routine entry
FF8F  A9 01      LDA #$01
FF91  8D 03 02   STA $0203
FF94  A9 00      LDA #$00
FF96  8D 05 02   STA $0205
FF99  68         PLA
FF9A  60         RTS
FF9B  48         PHA		;Save routine entry
FF9C  A9 01      LDA #$01
FF9E  D0 F6      BNE $FF96
FFA0  AD 12 02   LDA $0212  ;CTRL-C check routine entry
FFA3  D0 03      BNE $FFA8
FFA5  4C AE FF   JMP $FFAE
FFA8  4C 28 A6   JMP $A628
FFAB  4C C0 FF   JMP $FFC0	;Input routine entry
FFAE  AD 01 DF   LDA $DF01
FFB1  30 F5      BMI $FFA8
FFB3  4C 33 A6   JMP $A633
FFB6  AD 01 FC   LDA $FC01  ;read 7bit char from ACIA
FFB9  29 7F      AND #$7F
FFBB  60         RTS
FFBC  68         PLA
FFBD  A8         TAY
FFBE  68         PLA
FFBF  AA         TAX
FFC0  AD 01 DF   LDA $DF01  ;input char from KB or ACIA
FFC3  30 0D      BMI $FFD2
FFC5  48         PHA
FFC6  A9 00      LDA #$00
FFC8  8D 03 02   STA $0203
FFCB  AD 01 DF   LDA $DF01  ;wait for KB strobe to raise
FFCE  10 FB      BPL $FFCB
FFD0  68         PLA
FFD1  60         RTS
FFD2  AD 03 02   LDA $0203  ;is serial load flag set?
FFD5  F0 D4      BEQ $FFAB  ;no, branch
FFD7  AD 00 FC   LDA $FC00
FFDA  4A         LSR A
FFDB  90 CE      BCC $FFAB  ;branch, no char from serial yet
FFDD  4C B6 FF   JMP $FFB6
FFE0  40         .BYT $40       ;initial cursor pos after CR, LF ($64 for OSI440/C1P,$40 for OSI540)
FFE1  3F         .BYT $3F		;default terminal width/characters per line -1
FFE2  01         .BYT $01       ;screen memory size 00 = 1K otherwise 2K
FFE3  00 03      .BYT $00,$03	;default BASIC workspace lower bounds
FFE5  FF 3F      .BYT $FF,$3F	;default BASIC workspace upper bounds
FFE7  00 03      .BYT $00,$03   ;variable workspace lower bounds
FFE9  FF 3F      .BYT $FF,$3F   ;variable workspace upper bounds
FFEB  4C AB FF   JMP $FFAB		;Input routine jump
FFEE  4C 6C FF   JMP $FF6C		;Output routine jump
FFF1  4C A0 FF   JMP $FFA0		;CTRL-C check routine jump
FFF4  4C 8E FF   JMP $FF8E      ;Load routine jump
FFF7  4C 9B FF   JMP $FF9B		;Save routine jump
FFFA  30 01      .BYTE $30, $01 ;NMI vector
FFFC  00 FF      .BYTE $00, $FF ;Reset vector
FFFE  C0 01      .BYTE $C0, $01 ;IRQ vector

; Page 2
; $FD00 Polled Keyboard routine (C2/C4)	KB @ $DF00, $DF01
; Note endless loop bug when Row 7 Col 0 is pressed
;OSI keyboard decode table reference
;  Columns read from $DF00, Rows selected by writing to $DF00
;  C2/C4 series has noninverted values (bit set when key pressed)
;
;     7    6    5    4    3    2    1    0
; -----------------------------------------
; 7- 1/!  2/"  3/#  4/$  5/%  6/&  7/'
;
; 6- 8/(  9/)  0/@  :/*  -/=  rub
;
; 5- ./>   L    O    lf   cr
; 
; 4-  W    E    R    T	  Y    U    I
; 					 
; 3-  S    D    F    G	  H    J    K
; 
; 2-  X    C    V    B    N    M   ,/<
;
; 1-  Q    A    Z   spc  //?  ;/+   P
; 
; 0- rpt  ctl  esc            lsh  rsh  caps

; Joysticks
;
;Joystick A = enable row 7	 returns bits 4-0
;Joystick B = enable row 4	 returns bits 7-3
;
;
;     7    6    5    4    3    2    1    0
;   -----------------------------------------
; 7-                 UP   DN   RI   LE   FIRE (Joy A)
; 4- FIRE  DN   UP   RI   LE                  (Joy B)
;
 
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
FDCF  D0 BB      .BYT $D0, $BB
FDD1  2F 20 5A   .BYT $2F, $20, $5A
FDD4  41 51 2C   .BYT $41, $51, $2C
FDD7  4D 4E 42   .BYT $4D, $4E, $42
FDDA  56 43 58   .BYT $56, $43, $58
FDDD  4B 5A 48   .BYT $4B, $4A, $48
FDE0  47 46 44   .BYT $47, $46, $44
FDE3  53 49 55   .BYT $53, $49, $55
FDE6  59 54 52   .BYT $59, $54, $52
FDE9  45 57 00   .BYT $45, $57, $00
FDEC  00 0D 0A   .BYT $00, $0D, $0A
FDEF  4F 4C 2E   .BYT $4F, $4C, $2E
FDF2  00 FF 2D   .BYT $00, $FF, $2D
FDF5  BA 30 B9   .BYT $BA, $30, $B9
FDF8  B8 B7 B6   .BYT $B8, $B7, $B6
FDFB  B5 B4 B3   .BYT $B5, $B4, $B3
FDFE  B2 B1      .BYT $B2, $B1

; Page 3
; $FE00/$FF00 65V C2/C4 65V Rom Monitor for polled keyboard uses ACIA $FC00
; S1883 UART at $FB03+
;
FE00  A2 28      LDX #$28
FE02  9A         TXS
FE03  D8         CLD
FE04  AD 06 FB   LDA $FB06  ;reset S1883
FE07  A9 FF      LDA #$FF
FE09  8D 05 FB   STA $FB05  ;set 8N2
FE0C  A2 D8      LDX #$D8   ;screen clear end address
FE0E  A9 D0      LDA #$D0   ;screen clear start address
FE10  85 FF      STA $FF
FE12  A9 00      LDA #$00
FE14  85 FE      STA $FE
FE16  85 FB      STA $FB
FE18  A8         TAY
FE19  A9 20      LDA #$20    ;clear screen $D000-$D7FF = ' '
FE1B  91 FE      STA ($FE),Y
FE1D  C8         INY
FE1E  D0 FB      BNE $FE1B
FE20  E6 FF      INC $FF
FE22  E4 FF      CPX $FF
FE24  D0 F5      BNE $FE1B
FE26  84 FF      STY $FF
FE28  F0 19      BEQ $FE43   ;always branch
FE2A  20 E9 FE   JSR $FEE9
FE2D  C9 2F      CMP #$2F        ;'/'
FE2F  F0 1E      BEQ $FE4F
FE31  C9 47      CMP #$47	 ;'G'
FE33  F0 17      BEQ $FE4C
FE35  C9 4C      CMP #$4C	 ;'L'
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
FE52  C9 2E      CMP #$2E	   ;'.'
FE54  F0 D4      BEQ $FE2A
FE56  C9 0D      CMP #$0D	   ;<CR>
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
FE93  C9 30      CMP #$30	  ;'0'
FE95  30 12      BMI $FEA9
FE97  C9 3A      CMP #$3A	  ;':'
FE99  30 0B      BMI $FEA6
FE9B  C9 41      CMP #$41	  ;'A'
FE9D  30 0A      BMI $FEA9
FE9F  C9 47      CMP #$47	  ;'G'
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
FEED  4C 00 FD   JMP $FD00  ;entry for chr-in
FEF0  A9 FF      LDA #$FF
FEF2  8D 00 DF   STA $DF00
FEF5  AD 00 DF   LDA $DF00
FEF8  60         RTS
FEF9  EA         NOP
FEFA  30 01      .BYTE $30, $01  ;NMI vector copy (unused)
FEFC  00 FE      .BYTE $00, $FE  ;This is vector address of monitor used on H/D/M $FFxx ROM
FEFE  C0 01      .BYTE $C0, $01  ;IRQ vector  copy (unused)

; Page 4
; $FF00 Std Basic Boot (C/W/M?) for OSI 540 2K video 
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
FF1B  A9 20      LDA #$20	  ;clear screen
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
FF38  B9 5F FF   LDA $FF5F,Y ;show C/W/M ? prompt
FF3B  F0 06      BEQ $FF43
FF3D  20 2D BF   JSR $BF2D	 
FF40  C8         INY
FF41  D0 F5      BNE $FF38
FF43  20 B8 FF   JSR $FFB8
FF46  C9 4D      CMP #$4D	;'M'
FF48  D0 03      BNE $FF4D
FF4A  4C 00 FE   JMP $FE00
FF4D  C9 57      CMP #$57	;'W'
FF4F  D0 03      BNE $FF54
FF51  4C 00 00   JMP $0000
FF54  C9 43      CMP #$43	;'C'
FF56  D0 A8      BNE $FF00
FF58  A9 00      LDA #$00
FF5A  AA         TAX
FF5B  A8         TAY
FF5C  4C 11 BD   JMP $BD11
FF5F  43 2F 57   .BYTE 'C/W/M ?',0
FF62  2F 4D 20
FF65  3F 00
FF67  20 2D BF   JSR $BF2D	 ;send char in A to screen
FF6A  48         PHA
FF6B  AD 05 02   LDA $0205	 ;check save flag
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
FFA0  8D 00 DF   STA $DF00 ;sel row 0
FFA3  2C 00 DF   BIT $DF00 
FFA6  50 0F      BVC $FFB7 ;branch if CTRL not pressed
FFA8  A9 04      LDA #$04
FFAA  8D 00 DF   STA $DF00 ;sel row  2
FFAD  2C 00 DF   BIT $DF00
FFB0  50 05      BVC $FFB7 ;branch if C not pressed
FFB2  A9 03      LDA #$03
FFB4  4C 36 A6   JMP $A636
FFB7  60         RTS
FFB8  2C 03 02   BIT $0203  ;load flag set?
FFBB  10 19      BPL $FFD6
FFBD  A9 02      LDA #$02
FFBF  8D 00 DF   STA $DF00  ;sel row 1
FFC2  A9 10      LDA #$10
FFC4  2C 00 DF   BIT $DF00
FFC7  D0 0A      BNE $FFD3  ;branch if SPACE pressed
FFC9  AD 00 FC   LDA $FC00
FFCC  4A         LSR A
FFCD  90 EE      BCC $FFBD  ;branch while char not ready in ACIA
FFCF  AD 01 FC   LDA $FC01
FFD2  60         RTS
FFD3  EE 03 02   INC $0203	;turn off load flag
FFD6  4C ED FE   JMP $FEED
FFD9  00         BRK
FFDA  00         BRK
FFDB  00         BRK
FFDC  00         BRK
FFDD  00         BRK
FFDE  00         BRK
FFDF  00         BRK
FFE0  40         .BYT $40       ;initial cursor pos after CR, LF ($64 for OSI440/C1P,$40 for OSI540)
FFE1  3F         .BYT $3F		;default terminal width/characters per line -1
FFE2  01         .BYT $01       ;screen memory size 00 = 1K otherwise 2K
FFE3  00 03      .BYT $00,$03	;default BASIC workspace lower bounds
FFE5  FF 3F      .BYT $FF,$3F	;default BASIC workspace upper bounds
FFE7  00 03      .BYT $00,$03   ;variable workspace lower bounds
FFE9  FF 3F      .BYT $FF,$3F   ;variable workspace upper bounds
FFEB  4C B8 FF   JMP $FFB8      ;Input routine jump
FFEE  4C 67 FF   JMP $FF67      ;Output routine jump
FFF1  4C 99 FF   JMP $FF99      ;CTRL-C check routine jump
FFF4  4C 89 FF   JMP $FF89      ;Load routine jump
FFF7  4C 94 FF   JMP $FF94      ;Save routine jump
FFFA  30 01      .BYTE $30, $01  ;NMI vector
FFFC  00 FF      .BYTE $00, $FF  ;Reset vector
FFFE  C0 01      .BYTE $C0, $01  ;IRQ vector

; Page 5
; $FD00 rom  -- HD controller boot loader for CD-36/74
;
; The OSI hard disk controller consists of 8 memory mapped I/O addresses
; starting at $C200 which are visble for ~10us after accessing $C280
; (otherwise NULL read -- $C2)	C202 seems visible on OSI596 always
; The disk controller can transfer data to or from 4K of shared memory which
; is mapped to $E000 to $EFFF.
;
; Under 65U the hard disk is formatted with sectors that match the size of
; the 8" floppy disk $E00/3584 bytes + overhead.
;
; The boot track is located at track 0, cyln 0, head 0

;
; Mem at $EFFE, $EFFF used to store desired cylinder# (0)
; Access $C280 in order to make disk controller registers active(visible) for a few ms
; Write at $C200-$C207
; Read C202 (status)
; Read at $e010-EE19 (disk contents)
;
; The only addresses that are available to READ are C202 & C207. All addresses
; are inactive unless preceded by read of $c280 except $c202
;
; Control Registers
; C200 = /HDeADDrLod     head addr (bit0-3)        (cylinder hi) (bit 7) & track (bit0-6)
; C201 = /Seek Strobe  (cylinder lo)
;         bit 0 - bit 7 = cyn addr (lo)
;
; C202 = controller status / disk control load
; 74/36  OSI 592 C202 READ DISK STATUS
;		 bit 7 (PW RST)
;		 bit 6 (PWR OK)
;		 bit 5 MHD MulSel
;		 bit 4 MHD Cursense
;		 bit 3 Ready
;		 bit 2 Illegal Addr
;		 bit 1 Seek Late
;      	 bit 0 Seek Complete
;
;        OSI 592 C202 WRITE /DISK CONTROL LOAD
;        bit 7 m mode
;        bit 6 strobe late
;        bit 5 stobe early
;        bit 4 restore
;        bit 3 offset rev
;        bit 2 offset fwd
;        bit 1 drive sel hi
;        bit 0 drive sel lo

;
; Disk Geometry	for Winchester 74MB hard drive
; Cylinder (0 to 338) (track)  -> 72,898,560 bytes total
; Track    (0 to 11)  (head)
; Sector   (0 to 4)	  (sector)
; sector is 3584 bytes long  (14 * 256)	+ overhead
;
; Sector translation table 74M (absolute disk address of sector)
; -------------------------------------
; $c200 bit 7=1=cyln >=256
; $c201 cyln lo
; $c200 then write track(head)
;          ($C204 $C203)    ($C206 $C205)   $C207
;         (start xfer adr) (end xfer adr)
; sector 0 ($0010)			($0725)
; sector 1 ($0750)			($0E65)
; sector 2 ($0E90)			($15A5)
; sector 3 ($15D0)			($1CE5)
; sector 4 ($1D10)			($2425)      $00 on read, then $80, then $00
;             +=3 on read                $40 on write, then $c0, then $40

;
; Boot track format
; code executes at $E018
; Sector is 3584/$E00 bytes long
; last two bytes contain checksum of track
;
FD00  20 0C FD   JSR $FD0C ;read sector 0 to E010+
FD03  4C 18 E0   JMP $E018 ;run the code
FD06  20 16 FD   JSR $FD16
FD09  4C 18 E0   JMP $E018
FD0C  A9 00      LDA #$00
FD0E  8D FF EF   STA $EFFF
FD11  A9 00      LDA #$00
FD13  8D FE EF   STA $EFFE
FD16  D8         CLD		  ;retry sector read entry point
FD17  A2 07      LDX #$07
FD19  A9 00      LDA #$00
FD1B  2C 80 C2   BIT $C280    ;make controller visible
FD1E  9D 00 C2   STA $C200,X  ;initialize controller
FD21  CA         DEX
FD22  10 F7      BPL $FD1B
FD24  AD FF EF   LDA $EFFF  
FD27  8D 00 C2   STA $C200	;cylinder hi  (0) & track (0)
FD2A  AD FE EF   LDA $EFFE
FD2D  8D 01 C2   STA $C201  ;cylinder lo  (0)
FD30  A9 10      LDA #$10
FD32  2C 80 C2   BIT $C280  ;make controller visible
FD35  8D 02 C2   STA $C202	;1->0 = exec
FD38  A9 00      LDA #$00
FD3A  8D 02 C2   STA $C202
FD3D  20 98 FD   JSR $FD98    ;keep looping until #$d9 read from  $C202
FD40  A2 03      LDX #$03	  ;set controller to sector offset 0
FD42  BD AB FD   LDA $FDAB,X  ;$13, $00, $25, $07 = (19, 0, 37, 7)
FD45  2C 80 C2   BIT $C280    ;make controller visible
FD48  9D 03 C2   STA $C203,X  ;C206 = 07, c205 = 25, c204=00, c203=13 set sector xfer addrs
FD4B  CA         DEX		  
FD4C  10 F4      BPL $FD42
FD4E  2C 80 C2   BIT $C280   ;make controller visible
FD51  A9 80      LDA #$80
FD53  8D 07 C2   STA $C207	 ;begin transfer
FD56  AD 07 C2   LDA $C207   ;c207 R/W 
FD59  30 FB      BMI $FD56	 ;loop while busy
FD5B  AD 12 E0   LDA $E012
FD5E  4D FF EF   EOR $EFFF   ;loaded target cylnder hi?
FD61  30 B3      BMI $FD16
FD63  AD 13 E0   LDA $E013   ;loaded target cylinder lo?
FD66  4D FE EF   EOR $EFFE
FD69  D0 AB      BNE $FD16
FD6B  A9 18      LDA #$18    ;Checksum sector data E018-EE17
FD6D  85 FC      STA $FC
FD6F  A9 E0      LDA #$E0
FD71  85 FD      STA $FD
FD73  A9 0E      LDA #$0E	 ;$FE = # pages
FD75  85 FE      STA $FE
FD77  A9 00      LDA #$00
FD79  AA         TAX
FD7A  A8         TAY
FD7B  18         CLC
FD7C  71 FC      ADC ($FC),Y     ;E018,Y
FD7E  90 04      BCC $FD84
FD80  E8         INX
FD81  F0 01      BEQ $FD84
FD83  18         CLC
FD84  C8         INY
FD85  D0 F5      BNE $FD7C		 ;(perform 16bit checksum of loaded data)
FD87  E6 FD      INC $FD
FD89  C6 FE      DEC $FE
FD8B  D0 EF      BNE $FD7C
FD8D  CD 18 EE   CMP $EE18		 ;EE18 = chksum lo
FD90  D0 84      BNE $FD16   ;failed? RETRY
FD92  EC 19 EE   CPX $EE19		 ;EE19 = chksum hi
FD95  D0 F9      BNE $FD90 
FD97  60         RTS         ;DATA OK!
FD98  AD 02 C2   LDA $C202   ;Read from $C202, wait for #$D9 or %1101 1001
FD9B  C9 D9      CMP #$D9	 ;                          #$C4    %1100 0100
FD9D  F0 0B      BEQ $FDAA   ;#$D9 signals done
FD9F  29 C4      AND #$C4
FDA1  C9 C4      CMP #$C4
FDA3  D0 F3      BNE $FD98
FDA5  68         PLA        ;pop return address from JSR & start over
FDA6  68         PLA
FDA7  4C 16 FD   JMP $FD16  ;keep looping until $D9 read
FDAA  60         RTS
FDAB  13 00 25   .BYTE $13, $00, $25, $07  ;sector 0 read: start & end values
FDAF  20 16 FD   JSR $FD16
FDB2  6C FC FE   JMP ($FEFC)
FDB5  24 24      BIT $24
FDB7  24 24      BIT $24
FDB9  24 24      BIT $24
FDBB  24 24      BIT $24
FDBD  24 24      BIT $24
FDBF  24 24      BIT $24
FDC1  24 24      BIT $24
FDC3  24 24      BIT $24
FDC5  24 24      BIT $24
FDC7  24 24      BIT $24
FDC9  24 24      BIT $24
FDCB  24 24      BIT $24
FDCD  24 24      BIT $24
FDCF  24 24      BIT $24
FDD1  24 24      BIT $24
FDD3  24 24      BIT $24
FDD5  24 24      BIT $24
FDD7  24 24      BIT $24
FDD9  24 24      BIT $24
FDDB  24 24      BIT $24
FDDD  24 24      BIT $24
FDDF  24 24      BIT $24
FDE1  24 24      BIT $24
FDE3  24 24      BIT $24
FDE5  24 24      BIT $24
FDE7  24 24      BIT $24
FDE9  24 24      BIT $24
FDEB  24 24      BIT $24
FDED  24 24      BIT $24
FDEF  24 24      BIT $24
FDF1  24 24      BIT $24
FDF3  24 24      BIT $24
FDF5  24 24      BIT $24
FDF7  24 24      BIT $24
FDF9  24 24      BIT $24
FDFB  24 24      BIT $24
FDFD  24 24      BIT $24
FDFF  24         BIT $

; Page 6
; $FE00 block for serial system OSI 65A Serial Monitor with H/D/M FFxx rom
; ACIA control @ $FC00, ACIA data @ $FC01
;
FE00  AD 00 FC   LDA $FC00  ;*get 1 ascii char from ACIA w/ echo
FE03  4A         LSR A
FE04  90 FA      BCC $FE00
FE06  AD 01 FC   LDA $FC01
FE09  29 7F      AND #$7F   ;strip off msb
FE0B  48         PHA        ;send char out via ACIA
FE0C  AD 00 FC   LDA $FC00
FE0F  4A         LSR A
FE10  4A         LSR A
FE11  90 F9      BCC $FE0C
FE13  68         PLA
FE14  8D 01 FC   STA $FC01
FE17  60         RTS
FE18  20 00 FE   JSR $FE00  ;*get hex nibble from ascii
FE1B  C9 52      CMP #'R
FE1D  F0 16      BEQ $FE35	; R cmd?
FE1F  C9 30      CMP #'0
FE21  30 F5      BMI $FE18  ; < '0 ? get another
FE23  C9 3A      CMP #':
FE25  30 0B      BMI $FE32  ; < ': ? goto got lower hex
FE27  C9 41      CMP #'A
FE29  30 ED      BMI $FE18  ; < 'A ? get another
FE2B  C9 47      CMP #'G
FE2D  10 E9      BPL $FE18  ; >= 'G ? get another
FE2F  18         CLC
FE30  E9 06      SBC #$06   ;convert to hex val
FE32  29 0F      AND #$0F
FE34  60         RTS        ;return 1 byte hex value
FE35  A9 03      LDA #$03   ;'R command
FE37  8D 00 FC   STA $FC00
FE3A  A9 B1      LDA #$B1   ;reset ACIA
FE3C  8D 00 FC   STA $FC00
FE3F  D8         CLD
FE40  78         SEI
FE41  A2 26      LDX #$26   ;set stack
FE43  9A         TXS
FE44  A9 0D      LDA #$0D
FE46  20 0B FE   JSR $FE0B  ;send <CR>
FE49  A9 0A      LDA #$0A
FE4B  20 0B FE   JSR $FE0B  ;send <LF>
FE4E  20 00 FE   JSR $FE00	;get input with echo
FE51  C9 4C      CMP #'L
FE53  F0 22      BEQ $FE77	; L cmd?
FE55  C9 50      CMP #'P
FE57  F0 34      BEQ $FE8D	; P cmd?
FE59  C9 47      CMP #'G
FE5B  D0 D8      BNE $FE35
FE5D  AE 2D 01   LDX $012D   ; 'G command
FE60  9A         TXS
FE61  AE 2A 01   LDX $012A   ; read values from storage
FE64  AC 29 01   LDY $0129
FE67  AD 2E 01   LDA $012E   ;ret adder hi
FE6A  48         PHA
FE6B  AD 2F 01   LDA $012F	 ;ret addr lo
FE6E  48         PHA
FE6F  AD 2C 01   LDA $012C	 ;proc status
FE72  48         PHA
FE73  AD 2B 01   LDA $012B
FE76  40         RTI
FE77  20 C7 FE   JSR $FEC7   ; process 'L command (Get 2byte address in $FD,FC)
FE7A  A2 03      LDX #$03
FE7C  A0 00      LDY #$00
FE7E  20 B5 FE   JSR $FEB5   ;get hex input, store at $FF
FE81  A5 FF      LDA $FF
FE83  91 FC      STA ($FC),Y  ;
FE85  C8         INY
FE86  D0 F6      BNE $FE7E
FE88  E6 FD      INC $FD
FE8A  B8         CLV
FE8B  50 F1      BVC $FE7E
FE8D  20 C7 FE   JSR $FEC7   ; 'P command  -- get address in $FD,FC
FE90  A0 00      LDY #$00	 ;*write data starting at ($FC) to ACIA as hex + space
FE92  A2 09      LDX #$09	 ;with lines of 8 bytes, abort with any keystroke
FE94  A9 0D      LDA #$0D
FE96  20 0B FE   JSR $FE0B    ;write <CR><LF>
FE99  A9 0A      LDA #$0A
FE9B  20 0B FE   JSR $FE0B
FE9E  CA         DEX
FE9F  F0 0B      BEQ $FEAC
FEA1  20 E0 FE   JSR $FEE0    ;write ($FC),Y as hex byte and space
FEA4  C8         INY
FEA5  D0 F7      BNE $FE9E
FEA7  E6 FD      INC $FD
FEA9  4C 9E FE   JMP $FE9E
FEAC  AD 00 FC   LDA $FC00    ;is keypress waiting?
FEAF  4A         LSR A
FEB0  B0 8E      BCS $FE40	  ;yup
FEB2  EA         NOP
FEB3  90 DD      BCC $FE92	  ;nope
FEB5  20 18 FE   JSR $FE18    ;*read a 2 byte hex digit from acia store $FC,X
FEB8  0A         ASL A		  ;read hi byte
FEB9  0A         ASL A
FEBA  0A         ASL A
FEBB  0A         ASL A
FEBC  95 FC      STA $FC,X    ;store in $FC,X  ($FF)
FEBE  20 18 FE   JSR $FE18	  ; read a hex digit from acia
FEC1  18         CLC
FEC2  75 FC      ADC $FC,X
FEC4  95 FC      STA $FC,X
FEC6  60         RTS
FEC7  A2 01      LDX #$01	  ;*read 2byte address into $FD,$FC
FEC9  20 B5 FE   JSR $FEB5	  ;read hex into $FD
FECC  CA         DEX
FECD  20 B5 FE   JSR $FEB5	  ;read hex into $FC
FED0  60         RTS
FED1  18         CLC
FED2  69 30      ADC #$30
FED4  C9 3A      CMP #$3A
FED6  B0 04      BCS $FEDC
FED8  20 0B FE   JSR $FE0B
FEDB  60         RTS
FEDC  69 06      ADC #$06
FEDE  90 F8      BCC $FED8
FEE0  B1 FC      LDA ($FC),Y   ;write byte in ($FC),y to ACIA as HEX + space
FEE2  29 F0      AND #$F0
FEE4  4A         LSR A
FEE5  4A         LSR A
FEE6  4A         LSR A
FEE7  4A         LSR A
FEE8  20 D1 FE   JSR $FED1
FEEB  B1 FC      LDA ($FC),Y
FEED  29 0F      AND #$0F
FEEF  20 D1 FE   JSR $FED1
FEF2  A9 20      LDA #$20
FEF4  20 0B FE   JSR $FE0B
FEF7  60         RTS
FEF8  40         RTI
FEF9  9D 
FEFA  30 01      .BYTE $30, $01 ; NMI vector copy (unused)
FEFC  35 FE      .BYTE $35, $FE ; This is called for non-'H/D' keys (monitor Vector)
FEFE  C0 01      .BYTE $C0, $01 ; IRQ vector copy (unused)

;page 7
;standard OSI 505 $FF00 H/D/M floppy disk block
FF00  A0 00      LDY #$00  ;init disk controller
FF02  8C 01 C0   STY $C001 ;select DDRA.
FF05  8C 00 C0   STY $C000 ;0's in DDRA indicate input.
FF08  A2 04      LDX #$04
FF0A  8E 01 C0   STX $C001 ;select PORTA
FF0D  8C 03 C0   STY $C003 ;select DDRB
FF10  88         DEY
FF11  8C 02 C0   STY $C002	;1's in DDRB indicate output.
FF14  8E 03 C0   STX $C003	;select PORT B
FF17  8C 02 C0   STY $C002	;make all outputs high
FF1A  A9 FB      LDA #$FB	;set step towards 0
FF1C  D0 09      BNE $FF27
FF1E  A9 02      LDA #$02
FF20  2C 00 C0   BIT $C000
FF23  F0 1C      BEQ $FF41	;track 0 enabled?
FF25  A9 FF      LDA #$FF
FF27  8D 02 C0   STA $C002	;step off
FF2A  20 99 FF   JSR $FF99	; short delay
FF2D  29 F7      AND #$F7
FF2F  8D 02 C0   STA $C002  ;step on
FF32  20 99 FF   JSR $FF99
FF35  09 08      ORA #$08
FF37  8D 02 C0   STA $C002	;step off
FF3A  A2 18      LDX #$18
FF3C  20 85 FF   JSR $FF85
FF3F  F0 DD      BEQ $FF1E
FF41  A2 7F      LDX #$7F	 ;load head
FF43  8E 02 C0   STX $C002
FF46  20 85 FF   JSR $FF85	 ;delay 320 ms
FF49  AD 00 C0   LDA $C000
FF4C  30 FB      BMI $FF49	 ;wait for index start
FF4E  AD 00 C0   LDA $C000
FF51  10 FB      BPL $FF4E	 ;wait for index end
FF53  A9 03      LDA #$03
FF55  8D 10 C0   STA $C010	 ;reset ACIA
FF58  A9 58      LDA #$58
FF5A  8D 10 C0   STA $C010	 ;/1 RTS hi, no irq
FF5D  20 90 FF   JSR $FF90
FF60  85 FE      STA $FE	 ;read start addr hi
FF62  AA         TAX
FF63  20 90 FF   JSR $FF90	  
FF66  85 FD      STA $FD	 ;read start addr lo
FF68  20 90 FF   JSR $FF90
FF6B  85 FF      STA $FF	 ;read num pages
FF6D  A0 00      LDY #$00
FF6F  20 90 FF   JSR $FF90	 ;read specified num pages
FF72  91 FD      STA ($FD),Y
FF74  C8         INY
FF75  D0 F8      BNE $FF6F
FF77  E6 FE      INC $FE
FF79  C6 FF      DEC $FF
FF7B  D0 F2      BNE $FF6F
FF7D  86 FE      STX $FE	 ;restore start addr hi
FF7F  A9 FF      LDA #$FF    ;disable drive                 
FF81  8D 02 C0   STA $C002
FF84  60         RTS
FF85  A0 F8      LDY #$F8	;long delay
FF87  88         DEY
FF88  D0 FD      BNE $FF87
FF8A  55 FF      EOR $FF,X
FF8C  CA         DEX
FF8D  D0 F6      BNE $FF85
FF8F  60         RTS
FF90  AD 10 C0   LDA $C010	;wait for ACIA char
FF93  4A         LSR A
FF94  90 FA      BCC $FF90
FF96  AD 11 C0   LDA $C011
FF99  60         RTS
FF9A  48 2F 44   .BYTE 'H/D'        
FF9D  2F 4D 3F   .BYTE '/M?'
FFA0  D8         CLD         ;RESET entry point
FFA1  A2 D8      LDX #$D8    ;clr screen
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
FFB8  A9 03      LDA #$03    ;reset ACIA
FFBA  8D 00 FC   STA $FC00
FFBD  A9 B1      LDA #$B1
FFBF  8D 00 FC   STA $FC00
FFC2  B9 9A FF   LDA $FF9A,Y  ;display 'H/D/M?'
FFC5  30 0E      BMI $FFD5
FFC7  99 C6 D0   STA $D0C6,Y
FFCA  AE 01 FE   LDX $FE01    
FFCD  D0 03      BNE $FFD2
FFCF  20 0B FE   JSR $FE0B    ;send to serial if present
FFD2  C8         INY
FFD3  D0 ED      BNE $FFC2
FFD5  AD 01 FE   LDA $FE01    ;done with prompt. Is this serial system?
FFD8  D0 05      BNE $FFDF
FFDA  20 00 FE   JSR $FE00    ;get char from serial system
FFDD  B0 03      BCS $FFE2    ;carry always set
FFDF  20 ED FE   JSR $FEED    ;get char via (polled KB)
FFE2  C9 48      CMP #$48     ;'H
FFE4  F0 0A      BEQ $FFF0
FFE6  C9 44      CMP #$44     ;'D
FFE8  D0 0C      BNE $FFF6
FFEA  20 00 FF   JSR $FF00    ;D entry point
FFED  4C 00 22   JMP $2200	  ;execute loaded program (hopefully at 2200)
FFF0  4C 00 FD   JMP $FD00    ;H entry point
FFF3  20 00 FF   JSR $FF00
FFF6  6C FC FE   JMP ($FEFC)  ;any other key? jmp to 65V or 65A monitor
FFF9  EA         NOP
FFFA  30 01      .BYTE $30,$01  ; NMI vector
FFFC  A0 FF      .BYTE $A0,$FF  ; RST vector
FFFE  C0 01      .BYTE $C0,$01  ; IRQ vector
