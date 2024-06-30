; Monitor ROM used in OSI C3D system
; pages 0-3 = pages 4-7

;Page 0 not used, filled with $FF
         
;
; Page 1
; Hard disk loader located at $FD00 for OSI 590/596/525 controller or OSI 598 CD-7/10MB Shugart
;
; Mem at $EFFE used to store desired cylinder# (0)
; Access $C280 in order to make disk controller registers active(visible) for a few ms
; Write at $C200-$C207
; Read C202 (status)
; Read at $e010-EE19 (disk contents)
; ----------------------------------
; Disk Geometry	 CD-7 SA1004 8MB HD
;
; Formatted Hard drive Size =  7,311,360 
; (256 or 255 cylinders ) CylnSize =  28,672  
; (4 heads 0to3): TrkSize =  7168 (2 OSI sectors) 
; sector is 3584 bytes long +  overhead (+8 for trk header, +2 for sector checksum)
;

;
;
; C200 = cylinder hi (bit 7) & track (bit0-6) 
; C201 = cylinder lo
; C202 = controller status
;               write                 read
;        bit 7
;        bit 6
;        bit 5 (head step 1->0)						
;        bit 4 1 = init? 			
;        bit 3						  READY ctrl OK when 1 ($x9 = OK)
;        bit 2                        ERROR
;      	 bit 1 StepDir 0= to trk0     1= @Trk 0 (?)
;        bit 0 drive enable			  COMPLETE ctrl OK when 1 ($x9 = OK)
;        These bits have different meanings on CD-36/74
; C203 start lo (sector offset registers)
; C204 start hi
; C205 end lo
; C206 end hi
;
; C207 = write                      read
;        bit 7 1=start operation  1=ctrlr busy
;        bit 6 1=write 0=read
;
;
; $E010 - start of "DMA" memory
;
;  E000-E00E (zero out)
;  E00F = 1
;
; Sector translation table
; -------------------------------------
; sector offset OSI596/598
;          ($C204 $C203)    ($C206 $C205)   $C207
;         (start xfer adr) (end xfer adr)
; sector 0 ($0010)			($0725)
; sector 1 ($0750)			($0E65)
; sector 2 ($0E90)			($15A5)
; sector 3 ($15D0)			($1CE5)
; sector 4 ($1D10)			($2425)      $00 on read, then $80, then $00
;             +=3 on read                $40 on write, then $c0, then $40
; F.Y.I sector data is skewed by $1C2 bytes on write... sector data written
; starts at E1D2 to EFCB, read goes to E010-EE19  only on CD-7 not CD-36/74
;
; Boot track format
; code executes at $E018
; Sector is 3584/$E00 bytes long
; last two bytes contain checksum of track
; E010 = $A1, EO11 = 0, E012 = cynl hi (always 0 for CD7)
; E013-E015 = sector address on disk (cylinder0-FF, head 0-3, sector0-1, flag, hdr chksum )
;
; Page 1
; Hard disk loader located at $FD00 for OSI 590/596/525 controller or OSI 598 CD-7/10MB Shugart
FD00  20 12 FD   JSR $FD12	   ;read sector 0 to $E010+
FD03  4C 18 E0   JMP $E018     ;execute code
FD06  20 1C FD   JSR $FD1C     
FD09  4C 18 E0   JMP $E018
FD0C  20 1C FD   JSR $FD1C
FD0F  6C FC FE   JMP ($FEFC)
FD12  A9 00      LDA #$00      ;*init controller & track
FD14  A2 07      LDX #$07
FD16  20 CD FD   JSR $FDCD	   ;write $00 to C207
FD19  8D FE EF   STA $EFFE     ; storage for desired cylinder (0)
FD1C  D8         CLD           ; RETRY READ ENTRY POINT
FD1D  A2 07      LDX #$07      ; Zero C207 down to C200
FD1F  A9 00      LDA #$00	   ; C202 = 01
FD21  E0 02      CPX #$02
FD23  D0 01      BNE $FD26
FD25  2A         ROL A		   ;shift carry to bit 0
FD26  20 CD FD   JSR $FDCD
FD29  CA         DEX
FD2A  10 F3      BPL $FD1F
FD2C  AD 02 C2   LDA $C202	   ;get status
FD2F  29 09      AND #$09
FD31  D0 E9      BNE $FD1C	   ;ok? if not restart
FD33  A9 04      LDA #$04	   ;* Wait for ctrl or HD? to get ready
FD35  85 FF      STA $FF
FD37  A0 00      LDY #$00
FD39  AD 02 C2   LDA $C202	   ;get status
FD3C  29 02      AND #$02	   ;is bit 1 set?  (trk 0 sense)
FD3E  F0 15      BEQ $FD55	   ;if so continue
FD40  18         CLC
FD41  20 BE FD   JSR $FDBE	   ;*write $21, $01 to C202 (Head Step to 0 'cause carry clear)
FD44  A2 90      LDX #$90
FD46  CA         DEX
FD47  D0 FD      BNE $FD46	   ;delay some
FD49  CA         DEX
FD4A  D0 FD      BNE $FD49	   ;delay some more
FD4C  88         DEY
FD4D  D0 EA      BNE $FD39	   ;loop waiting for c202 bit 1
FD4F  C6 FF      DEC $FF
FD51  10 E6      BPL $FD39	   ;try 4*256 times
FD53  30 C7      BMI $FD1C	   ;failed, jump back to reinit ctrlr
FD55  A8         TAY		   ;entry when ctrlr bit 1 = 1
FD56  CC FE EF   CPY $EFFE     ;is target cylinder#?
FD59  F0 06      BEQ $FD61	   ;if so branch
FD5B  20 BE FD   JSR $FDBE	   ;write $23, $03 to $C202 (Head Step up/go to next cyln)
FD5E  C8         INY
FD5F  D0 F5      BNE $FD56
FD61  AD 02 C2   LDA $C202	   ;wait for C202 bit 0
FD64  29 01      AND #$01
FD66  D0 F9      BNE $FD61
FD68  A2 03      LDX #$03	   ;*write $72, 0, $62, 8 to C203-C206
FD6A  BD D4 FD   LDA $FDD4,X   ;address start & address end for sector 0
FD6D  20 CD FD   JSR $FDCD	   
FD70  E8         INX
FD71  E0 07      CPX #$07
FD73  D0 F5      BNE $FD6A
FD75  A9 80      LDA #$80
FD77  20 CD FD   JSR $FDCD	   ;write $80 to C207 (execute)
FD7A  AD 07 C2   LDA $C207
FD7D  30 FB      BMI $FD7A	   ;wait until operation completes
FD7F  AD 13 E0   LDA $E013     ;cylinder lo on disk
FD82  4D FE EF   EOR $EFFE     ;desired cylinder lo
FD85  0D 14 E0   ORA $E014     ;head on disk
FD88  0D 15 E0   ORA $E015	   ;sector on disk
FD8B  D0 8F      BNE $FD1C	   ;sum should be 0 (0 head, 0 sector, 0 cylinder) if not start over
FD8D  A9 18      LDA #$18	   ;*chksum sector data E018 thru EE17 
FD8F  85 FC      STA $FC       ;compare to (EE18 lo, EE19 hi)
FD91  A9 E0      LDA #$E0
FD93  85 FD      STA $FD
FD95  A9 0E      LDA #$0E
FD97  85 FE      STA $FE
FD99  A9 00      LDA #$00
FD9B  AA         TAX
FD9C  A8         TAY
FD9D  18         CLC
FD9E  71 FC      ADC ($FC),Y
FDA0  90 04      BCC $FDA6
FDA2  E8         INX
FDA3  F0 01      BEQ $FDA6
FDA5  18         CLC
FDA6  C8         INY
FDA7  D0 F5      BNE $FD9E
FDA9  E6 FD      INC $FD
FDAB  C6 FE      DEC $FE
FDAD  D0 EF      BNE $FD9E
FDAF  85 FC      STA $FC
FDB1  86 FD      STX $FD
FDB3  CD 18 EE   CMP $EE18   ;sector checksum lo read from disk
FDB6  D0 D3      BNE $FD8B
FDB8  EC 19 EE   CPX $EE19   ;sector checksum hi read from disk
FDBB  D0 CE      BNE $FD8B   ;retry read if not 0
FDBD  60         RTS
FDBE  08         PHP		 ;*write to $C202 $21 then $01   ;step down
FDBF  A9 00      LDA #$00	 ;if carry set write $23 then 03 ;step up
FDC1  6A         ROR A		 ;a head step signal
FDC2  6A         ROR A
FDC3  28         PLP
FDC4  09 21      ORA #$21
FDC6  20 CB FD   JSR $FDCB
FDC9  49 20      EOR #$20
FDCB  A2 02      LDX #$02	   ;*Write byte in A to $C202
FDCD  08         PHP           ;*Write byte in A to controller at X offset
FDCE  78         SEI
FDCF  2C 80 C2   BIT $C280     ;make disk controller active for a while
FDD2  9D 00 C2   STA $C200,X   ;set controller register
FDD5  28         PLP
FDD6  60         RTS
FDD7  72 00      .BYTE $72, $00, $62, $08 ;disk read offset? start lo,hi, end lo,hi
FDDB  FF         ERR
FDDC  FF         ERR
FDDD  FF         ERR
FDDE  FF         ERR
FDDF  FF         ERR
FDE0  FF         ERR
FDE1  FF         ERR
FDE2  FF         ERR
FDE3  FF         ERR
FDE4  FF         ERR
FDE5  FF         ERR
FDE6  FF         ERR
FDE7  FF         ERR
FDE8  FF         ERR
FDE9  FF         ERR
FDEA  FF         ERR
FDEB  FF         ERR
FDEC  FF         ERR
FDED  FF         ERR
FDEE  FF         ERR
FDEF  FF         ERR
FDF0  FF         ERR
FDF1  FF         ERR
FDF2  FF         ERR
FDF3  FF         ERR
FDF4  FF         ERR
FDF5  FF         ERR
FDF6  FF         ERR
FDF7  FF         ERR
FDF8  FF         ERR
FDF9  FF         ERR
FDFA  FF         ERR
FDFB  FF         ERR
FDFC  FF         ERR
FDFD  FF         ERR
FDFE  FF         ERR
FDFF  FF         ERR
;
; Page 2
; $FE00 block for serial system OSI 65A Serial Monitor with H/D/M FFxx rom
;
FE00  AD 00 FC   LDA $FC00   ;get input from serial & echo
FE03  4A         LSR A
FE04  90 FA      BCC $FE00
FE06  AD 01 FC   LDA $FC01
FE09  29 7F      AND #$7F
FE0B  48         PHA         ;write char in A to serial
FE0C  AD 00 FC   LDA $FC00
FE0F  4A         LSR A
FE10  4A         LSR A
FE11  90 F9      BCC $FE0C
FE13  68         PLA
FE14  8D 01 FC   STA $FC01
FE17  60         RTS
FE18  20 00 FE   JSR $FE00  ;READ HEX NIBBLE entry ;get key with echo
FE1B  C9 52      CMP #$52  ;'R  ;check for Reset Cmd
FE1D  F0 16      BEQ $FE35 
FE1F  C9 30      CMP #$30  ;'0   ;read hex digit ignore others
FE21  30 F5      BMI $FE18
FE23  C9 3A      CMP #$3A  ;':
FE25  30 0B      BMI $FE32
FE27  C9 41      CMP #$41  ;'A
FE29  30 ED      BMI $FE18
FE2B  C9 47      CMP #$47  ;'G
FE2D  10 E9      BPL $FE18
FE2F  18         CLC
FE30  E9 06      SBC #$06
FE32  29 0F      AND #$0F     ;return HEX nibble 0-F
FE34  60         RTS
FE35  A9 03      LDA #$03   ;entry point Reset ACIA & start
FE37  8D 00 FC   STA $FC00
FE3A  A9 B1      LDA #$B1   ;8N2
FE3C  8D 00 FC   STA $FC00
FE3F  D8         CLD
FE40  78         SEI
FE41  A2 26      LDX #$26
FE43  9A         TXS
FE44  A9 0D      LDA #$0D
FE46  20 0B FE   JSR $FE0B
FE49  A9 0A      LDA #$0A
FE4B  20 0B FE   JSR $FE0B   ;write <CR><LF>
FE4E  20 00 FE   JSR $FE00   ;get key with echo
FE51  C9 4C      CMP #$4C    ;'L
FE53  F0 22      BEQ $FE77
FE55  C9 50      CMP #$50    ;'P
FE57  F0 34      BEQ $FE8D
FE59  C9 47      CMP #$47    ;'G
FE5B  D0 D8      BNE $FE35
FE5D  AE 2D 01   LDX $012D   ;Go cmd A,X,Y, K & execute
FE60  9A         TXS
FE61  AE 2A 01   LDX $012A
FE64  AC 29 01   LDY $0129
FE67  AD 2E 01   LDA $012E
FE6A  48         PHA
FE6B  AD 2F 01   LDA $012F
FE6E  48         PHA
FE6F  AD 2C 01   LDA $012C
FE72  48         PHA
FE73  AD 2B 01   LDA $012B
FE76  40         RTI         ;Execute Go cmd
FE77  20 C7 FE   JSR $FEC7   ;L command entry, get hex word
FE7A  A2 03      LDX #$03
FE7C  A0 00      LDY #$00
FE7E  20 B5 FE   JSR $FEB5   ;get hex at $FC+3 ($FF)
FE81  A5 FF      LDA $FF
FE83  91 FC      STA ($FC),Y  ;store it
FE85  C8         INY          
FE86  D0 F6      BNE $FE7E    ;continue to fill
FE88  E6 FD      INC $FD      ;get next page full
FE8A  B8         CLV
FE8B  50 F1      BVC $FE7E
FE8D  20 C7 FE   JSR $FEC7   ;P cmd Entry, get hex word
FE90  A0 00      LDY #$00
FE92  A2 09      LDX #$09
FE94  A9 0D      LDA #$0D
FE96  20 0B FE   JSR $FE0B   ;emit <CR>
FE99  A9 0A      LDA #$0A
FE9B  20 0B FE   JSR $FE0B   ;emit <LF>
FE9E  CA         DEX
FE9F  F0 0B      BEQ $FEAC
FEA1  20 E0 FE   JSR $FEE0
FEA4  C8         INY
FEA5  D0 F7      BNE $FE9E
FEA7  E6 FD      INC $FD
FEA9  4C 9E FE   JMP $FE9E
FEAC  AD 00 FC   LDA $FC00
FEAF  4A         LSR A
FEB0  B0 8E      BCS $FE40   ;abort on keypress
FEB2  EA         NOP
FEB3  90 DD      BCC $FE92
FEB5  20 18 FE   JSR $FE18  ;get hex nibble (msb)
FEB8  0A         ASL A
FEB9  0A         ASL A
FEBA  0A         ASL A
FEBB  0A         ASL A
FEBC  95 FC      STA $FC,X
FEBE  20 18 FE   JSR $FE18    ;get hex nibble
FEC1  18         CLC
FEC2  75 FC      ADC $FC,X
FEC4  95 FC      STA $FC,X
FEC6  60         RTS
FEC7  A2 01      LDX #$01   ;Get HEX WORD $FC, $FD
FEC9  20 B5 FE   JSR $FEB5  ;get $FD
FECC  CA         DEX
FECD  20 B5 FE   JSR $FEB5  ;get $FC
FED0  60         RTS
FED1  18         CLC          ;convert hex nibble to ASCII
FED2  69 30      ADC #$30
FED4  C9 3A      CMP #$3A
FED6  B0 04      BCS $FEDC
FED8  20 0B FE   JSR $FE0B
FEDB  60         RTS
FEDC  69 06      ADC #$06
FEDE  90 F8      BCC $FED8
FEE0  B1 FC      LDA ($FC),Y   ;print HEX byte ($FC),Y + <Space>
FEE2  29 F0      AND #$F0
FEE4  4A         LSR A
FEE5  4A         LSR A
FEE6  4A         LSR A
FEE7  4A         LSR A
FEE8  20 D1 FE   JSR $FED1    ;print msb
FEEB  B1 FC      LDA ($FC),Y
FEED  29 0F      AND #$0F
FEEF  20 D1 FE   JSR $FED1    ;print lsb
FEF2  A9 20      LDA #$20
FEF4  20 0B FE   JSR $FE0B   ;emit <Space>
FEF7  60         RTS
FEF8  40         RTI
FEF9  9D 
FEFA  30 01   	 .BYTE $30, $01  ; $0130 NMI
FEFC  35 FE      .BYTE $35, $FE  ; $FE35 Reset
FEFE  C0 01      .BYTE $C0, $01  ; $01C0 IRQ

;Page 3
;
;standard OSI 505 $FF00 H/D/M block
;
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
FFED  4C 00 22   JMP $2200	  ;execute loaded pgm
FFF0  4C 00 FD   JMP $FD00    ;H entry point
FFF3  20 00 FF   JSR $FF00
FFF6  6C FC FE   JMP ($FEFC)  ;any other key? jmp to 65V or 65A monitor
FFF9  EA         NOP
FFFA  30 01      .BYTE $30, $01  ; NMI vector
FFFC  A0 FF      .BYTE $A0, $FF  ; RST vector
FFFE  C0 01      .BYTE $C0, $01  ; IRQ vector


;Page 4 not used
EC00- ECFF FF     NOT USED

;
; Page 5
; Hard disk loader $FD00 (for Shugart 10M 1004 drive 590/596)
; the same as page 1
FD00  20 12 FD   JSR $FD12
FD03  4C 18 E0   JMP $E018
FD06  20 1C FD   JSR $FD1C
FD09  4C 18 E0   JMP $E018
FD0C  20 1C FD   JSR $FD1C
FD0F  6C FC FE   JMP ($FEFC)
FD12  A9 00      LDA #$00		;*init controller
FD14  A2 07      LDX #$07
FD16  20 CD FD   JSR $FDCD		;write $00 to C207
FD19  8D FE EF   STA $EFFE
FD1C  D8         CLD
FD1D  A2 07      LDX #$07
FD1F  A9 00      LDA #$00
FD21  E0 02      CPX #$02
FD23  D0 01      BNE $FD26
FD25  2A         ROL A
FD26  20 CD FD   JSR $FDCD
FD29  CA         DEX
FD2A  10 F3      BPL $FD1F
FD2C  AD 02 C2   LDA $C202
FD2F  29 09      AND #$09
FD31  D0 E9      BNE $FD1C		;ok? if not restart
FD33  A9 04      LDA #$04       ;wait for ctrl or HD? to get ready
FD35  85 FF      STA $FF
FD37  A0 00      LDY #$00
FD39  AD 02 C2   LDA $C202		;get status
FD3C  29 02      AND #$02		;is bit 1 set? trk o sense
FD3E  F0 15      BEQ $FD55		;if so continue
FD40  18         CLC
FD41  20 BE FD   JSR $FDBE      ;step head towards 0
FD44  A2 90      LDX #$90
FD46  CA         DEX
FD47  D0 FD      BNE $FD46
FD49  CA         DEX
FD4A  D0 FD      BNE $FD49
FD4C  88         DEY
FD4D  D0 EA      BNE $FD39
FD4F  C6 FF      DEC $FF
FD51  10 E6      BPL $FD39
FD53  30 C7      BMI $FD1C
FD55  A8         TAY
FD56  CC FE EF   CPY $EFFE
FD59  F0 06      BEQ $FD61
FD5B  20 BE FD   JSR $FDBE
FD5E  C8         INY
FD5F  D0 F5      BNE $FD56
FD61  AD 02 C2   LDA $C202
FD64  29 01      AND #$01
FD66  D0 F9      BNE $FD61
FD68  A2 03      LDX #$03
FD6A  BD D4 FD   LDA $FDD4,X
FD6D  20 CD FD   JSR $FDCD
FD70  E8         INX
FD71  E0 07      CPX #$07
FD73  D0 F5      BNE $FD6A
FD75  A9 80      LDA #$80
FD77  20 CD FD   JSR $FDCD
FD7A  AD 07 C2   LDA $C207
FD7D  30 FB      BMI $FD7A
FD7F  AD 13 E0   LDA $E013
FD82  4D FE EF   EOR $EFFE
FD85  0D 14 E0   ORA $E014
FD88  0D 15 E0   ORA $E015
FD8B  D0 8F      BNE $FD1C
FD8D  A9 18      LDA #$18
FD8F  85 FC      STA $FC
FD91  A9 E0      LDA #$E0
FD93  85 FD      STA $FD
FD95  A9 0E      LDA #$0E
FD97  85 FE      STA $FE
FD99  A9 00      LDA #$00
FD9B  AA         TAX
FD9C  A8         TAY
FD9D  18         CLC
FD9E  71 FC      ADC ($FC),Y
FDA0  90 04      BCC $FDA6
FDA2  E8         INX
FDA3  F0 01      BEQ $FDA6
FDA5  18         CLC
FDA6  C8         INY
FDA7  D0 F5      BNE $FD9E
FDA9  E6 FD      INC $FD
FDAB  C6 FE      DEC $FE
FDAD  D0 EF      BNE $FD9E
FDAF  85 FC      STA $FC
FDB1  86 FD      STX $FD
FDB3  CD 18 EE   CMP $EE18
FDB6  D0 D3      BNE $FD8B
FDB8  EC 19 EE   CPX $EE19
FDBB  D0 CE      BNE $FD8B
FDBD  60         RTS
FDBE  08         PHP
FDBF  A9 00      LDA #$00
FDC1  6A         ROR A
FDC2  6A         ROR A
FDC3  28         PLP
FDC4  09 21      ORA #$21
FDC6  20 CB FD   JSR $FDCB
FDC9  49 20      EOR #$20
FDCB  A2 02      LDX #$02
FDCD  08         PHP
FDCE  78         SEI
FDCF  2C 80 C2   BIT $C280
FDD2  9D 00 C2   STA $C200,X
FDD5  28         PLP
FDD6  60         RTS
FDD7  72 00      .BYTE $72, $00, $62, $08
FDDB  FF         ERR
FDDC  FF         ERR
FDDD  FF         ERR
FDDE  FF         ERR
FDDF  FF         ERR
FDE0  FF         ERR
FDE1  FF         ERR
FDE2  FF         ERR
FDE3  FF         ERR
FDE4  FF         ERR
FDE5  FF         ERR
FDE6  FF         ERR
FDE7  FF         ERR
FDE8  FF         ERR
FDE9  FF         ERR
FDEA  FF         ERR
FDEB  FF         ERR
FDEC  FF         ERR
FDED  FF         ERR
FDEE  FF         ERR
FDEF  FF         ERR
FDF0  FF         ERR
FDF1  FF         ERR
FDF2  FF         ERR
FDF3  FF         ERR
FDF4  FF         ERR
FDF5  FF         ERR
FDF6  FF         ERR
FDF7  FF         ERR
FDF8  FF         ERR
FDF9  FF         ERR
FDFA  FF         ERR
FDFB  FF         ERR
FDFC  FF         ERR
FDFD  FF         ERR
FDFE  FF         ERR
FDFF  FF         ERR

; Page 6
; $FE00 block for serial system OSI 65A Serial Monitor with H/D/M FFxx rom
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
FE1D  F0 16      BEQ $FE35
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
FE53  F0 22      BEQ $FE77
FE55  C9 50      CMP #'P
FE57  F0 34      BEQ $FE8D
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
FEFA  30 01      .BYTE $30, $01 ; NMI vector?
FEFC  35 FE      .BYTE $35, $FE ; This is called for non-'H/D' keys (monitor Vector)
FEFE  C0 01      .BYTE $C0, $01 ; IRQ vector?


; Page 7
; Standard 505 H/D/M boot at $FF00
;
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
FF9A  48         .BYTE 'H/D/M?'
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
FFFA  30 01      .BYTE $30, $01
FFFC  A0 FF      .BYTE $A0, $FF 
FFFE  C0 01      .BYTE $C0, $01