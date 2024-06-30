; Page 0
; 6800 Disassembly from $FF00 to $FFFF
; 6800 Serial Monitor program for OSI 510 board
;
L1F34	=	$1F34
L1F35	=	$1F35
L1FB0	=	$1FB0
L1FDF	=	$1FDF
;
	org	$FF00
;
;
FF00	7E FF D3        LFF00:	jmp	INSER
;
F803 : 47 		"G"		asra
F804 : 24 FA 		"$ "		bcc	LFF00
;
FF06	B6 FC 01        LFF06	ldaA	$FC01
FF09	84 7F           	andA	#%01111111
FF0B	81 7F           	cmpA	#$7F
FF0D	27 F1           	beq	LFF00
FF0F	7E FF 88        	jmp	OUTSER
;
FF12	8D EC           LFF12:	JSR	LFF00
FF14	81 52           	cmpA	#$52   ;'R
FF16	27 13           	beq	LFF2B
FF18	81 30           	cmpA	#$30  ;'0
FF1A	2B F6           	bmi	LFF12
FF1C	81 39           	cmpA	#$39  ;'9
FF1E	2F 0A           	ble	LFF2A    
FF20	81 41           	cmpA	#$41  ;'A
FF22	2B EE           	bmi	LFF12
FF24	81 46           	cmpA	#$46  ;'F
FF26	2E EA           	bgt	LFF12
FF28	80 07           	subA	#$07
FF2A	39              LFF2A	RTS	
;
FF2B	7E FF A8        LFF2B	jmp	LFFA8
;
FF2E	8D 07           LFF2E	JSR	LFF37
FF30	8D 13           LFF30	JSR	LFF45
FF32	A7 00           	staA	0, X
FF34	08              	incX	
FF35	20 F9           	jr	LFF30
;
FF37	8D 0C           LFF37:	JSR	LFF45
FF39	B7 1F 34        	staA	L1F34
FF3C	8D 07           	JSR	LFF45
FF3E	B7 1F 35        	staA	L1F35
FF41	FE 1F 34        	ldX	L1F34
FF44	39              	RTS	
;
FF45	8D CB           LFF45:	JSR	LFF12
FF47	48              	lslA	
FF48	48              	lslA	
FF49	48              	lslA	
FF4A	48              	lslA	
FF4B	16              	tAB	
FF4C	8D C4           	JSR	LFF12
FF4E	84 0F           	andA	#%00001111
FF50	1B              	aBA	
FF51	39              	RTS	
;
;
FF52	                	db	$00, $00
;
FF54	8D E1           LFF54	JSR	LFF37
FF56	86 0D           LFF56	ldaA	#$0D
FF58	8D 2E           	JSR	OUTSER
FF5A	86 0A           	ldaA	#$0A
FF5C	8D 2A           	JSR	OUTSER
FF5E	8D 17           	JSR	LFF77
FF60	8D 15           	JSR	LFF77
FF62	8D 13           	JSR	LFF77
FF64	8D 11           	JSR	LFF77
FF66	8D 0F           	JSR	LFF77
FF68	8D 0D           	JSR	LFF77
FF6A	8D 0B           	JSR	LFF77
FF6C	8D 09           	JSR	LFF77
FF6E	B6 FC 00        	ldaA	$FC00
FF71	47              	asrA	
FF72	24 E2           	bcc	LFF56
FF74	7E FF B2        	jmp	LFFB2
;
FF77	8D 26           LFF77:	JSR	LFF9F
FF79	39              	RTS	
;
FF7A	44              LFF7A:	lsrA	
FF7B	44              	lsrA	
FF7C	44              	lsrA	
FF7D	44              	lsrA	
FF7E	84 0F           LFF7E:	andA	#%00001111
FF80	8B 30           	addA	#$30
FF82	81 39           	cmpA	#$39
FF84	23 02           	bls	OUTSER
FF86	8B 07           	addA	#$07
FF88	37              OUTSER:	pushB	
FF89	F6 FC 00        LFF89	ldaB	$FC00
FF8C	57              	asrB	
FF8D	57              	asrB	
FF8E	24 F9           	bcc	LFF89
FF90	B7 FC 01        	staA	$FC01
FF93	33              	popB	
FF94	39              	RTS	
;
FF95	A6 00           LFF95:	ldaA	0, X
FF97	8D E1           	JSR	LFF7A
FF99	A6 00           	ldaA	0, X
FF9B	8D E1           	JSR	LFF7E
FF9D	08              	incX	
FF9E	39              	RTS	
;
FF9F	8D F4           LFF9F:	JSR	LFF95
FFA1	86 20           LFFA1:	ldaA	#$20
FFA3	20 E3           	jr	OUTSER
;
;
FFA5	                	db	$00, $00, $00
;
FFA8	86 03           LFFA8	ldaA	#$03   ;IRQ, SWI vector entry 
FFAA	B7 FC 00        	staA	$FC00	   ;reset ACIA
FFAD	86 B1           	ldaA	#$B1
FFAF	B7 FC 00        	staA	$FC00	   ;/16 8N2 +XIRQ +RIRQ
FFB2	8E 1F 28        LFFB2	ldS	#$1F28
FFB5	86 0D           	ldaA	#$0D
FFB7	8D CF           	JSR	OUTSER
FFB9	86 0A           	ldaA	#$0A
FFBB	8D CB           	JSR	OUTSER
FFBD	BD FF 00        	call	LFF00
FFC0	16              	tAB	
FFC1	8D DE           	JSR	LFFA1
FFC3	C1 4C           	cmpB	#$4C    ;L
FFC5	26 03           	bne	LFFCA
FFC7	7E FF 2E        	jmp	LFF2E
;
FFCA	C1 50           LFFCA	cmpB	#$50  ;'P
FFCC	27 86           	beq	LFF54
FFCE	C1 47           	cmpB	#$47     ;'G
FFD0	26 E0           	bne	LFFB2
FFD2	3B              	RTSi	
;
FFD3	B6 1F DF        INSER	ldaA	L1FDF   ;$1FDF input redir flag?
FFD6	27 03           	beq	LFFDB
FFD8	7E 1F B0        	jmp	L1FB0
;
FFDB	B6 FC 00        LFFDB	ldaA	$FC00  ;Get char from serial
FFDE	47              	asrA	
FFDF	24 FA           	bcc	LFFDB
FFE1	7E FF 06        	jmp	LFF06
;
;
FFE4	                	db	$00, $00, $00
;
FFE7	7F 1F DF        LFFE7	clr	L1FDF	;reset vector entry
FFEA	C6 00           	ldaB	#$00
FFEC	F7 F7 01        	staB	$F701
FFEF	F7 F7 00        	staB	$F700  ;Set PIA DDRA to output
FFF2	C6 04           	ldaB	#$04
FFF4	F7 F7 01        	staB	$F701
FFF7	7E FF A8        	jmp	LFFA8
;
;				;IRQ vector ($FFA8)
FFFA	                	db  $FF, $A8, ;SWI instru int vector ($FFA8)
FFFC                        	db  $1F, $E0  ;NMI vector   ($1FE0)
FFFE 				db  $FF, $E7  ;reset vector	($FFE7)
;-----------------------------------------------------------------------------


;
;Page 1
; $FF00
; $FF00 Basic Boot (C/W/M?) for serial system 
FF00  D8         CLD
FF01  A2 28      LDX #$28
FF03  9A         TXS
FF04  20 22 BF   JSR $BF22
FF07  20 FE BE   JSR $BEFE
FF0A  A0 00      LDY #$00
FF0C  98         TYA
FF0D  A2 0E      LDX #$0E
FF0F  9D 03 02   STA $0203,X
FF12  CA         DEX
FF13  10 FA      BPL $FF0F
FF15  B9 B7 FF   LDA $FFB7,Y
FF18  30 06      BMI $FF20
FF1A  20 15 BF   JSR $BF15
FF1D  C8         INY
FF1E  D0 F5      BNE $FF15
FF20  20 07 BF   JSR $BF07
FF23  C9 4D      CMP #'M
FF25  D0 03      BNE $FF2A
FF27  4C 40 FE   JMP $FE40
FF2A  C9 57      CMP #'W
FF2C  D0 03      BNE $FF31
FF2E  4C 00 00   JMP $0000
FF31  C9 43      CMP #'C
FF33  D0 CB      BNE $FF00
FF35  A9 00      LDA #$00
FF37  AA         TAX
FF38  A8         TAY
FF39  4C 11 BD   JMP $BD11
FF3C  0A 4F 4B   .BYTE $A, 'OK'
FF3F  0D         .BYTE $D
FF40  F0 BE      BEQ $FF00
FF42  48         PHA
FF43  8E 04 02   STX $0204
FF46  AD 10 02   LDA $0210
FF49  D0 22      BNE $FF6D
FF4B  68         PLA
FF4C  20 15 BF   JSR $BF15
FF4F  48         PHA
FF50  AD 05 02   LDA $0205
FF53  F0 13      BEQ $FF68
FF55  68         PLA
FF56  20 F3 BE   JSR $BEF3
FF59  C9 0D      CMP #$0D
FF5B  D0 0C      BNE $FF69
FF5D  48         PHA
FF5E  A2 0A      LDX #$0A
FF60  A9 00      LDA #$00
FF62  20 F3 BE   JSR $BEF3
FF65  CA         DEX
FF66  D0 FA      BNE $FF62
FF68  68         PLA
FF69  AE 04 02   LDX $0204
FF6C  60         RTS
FF6D  68         PLA
FF6E  48         PHA
FF6F  AE 11 02   LDX $0211
FF72  DD 3C FF   CMP $FF3C,X
FF75  D0 08      BNE $FF7F
FF77  E8         INX
FF78  E0 04      CPX #$04
FF7A  D0 05      BNE $FF81
FF7C  20 AE FF   JSR $FFAE
FF7F  A2 00      LDX #$00
FF81  8E 11 02   STX $0211
FF84  4C 50 FF   JMP $FF50
FF87  AD 00 FC   LDA $FC00
FF8A  4A         LSR A
FF8B  90 13      BCC $FFA0
FF8D  A9 00      LDA #$00
FF8F  8D 03 02   STA $0203
FF92  AD 01 FC   LDA $FC01
FF95  F0 F0      BEQ $FF87
FF97  29 7F      AND #$7F
FF99  C9 05      CMP #$05
FF9B  D0 CF      BNE $FF6C
FF9D  20 AE FF   JSR $FFAE
FFA0  AD 03 02   LDA $0203
FFA3  F0 E2      BEQ $FF87
FFA5  AD 05 FB   LDA $FB05
FFA8  4A         LSR A
FFA9  90 DC      BCC $FF87
FFAB  4C EA BE   JMP $BEEA
FFAE  AD 10 02   LDA $0210
FFB1  49 FF      EOR #$FF
FFB3  8D 10 02   STA $0210
FFB6  60         RTS
FFB7  43         .BYTE 'C/W/M?'
FFBD  AD 00 FC   LDA $FC00
FFC0  4A         LSR A
FFBF  90 03      BCC $FFBD
FFC3  4C 33 A6   JMP $A633
FFC6  4C 28 A6   JMP $A628
FFC9  48         PHA
FFCA  A9 01      LDA #$01
FFCC  D0 08      BNE $FFD6
FFCE  48         PHA
FFCF  A9 01      LDA #$01
FFD1  8D 03 02   STA $0203
FFD4  A9 00      LDA #$00
FFD6  8D 05 02   STA $0205
FFD9  68         PLA
FFDA  20 FE BE   JSR $BEFE
FFDD  4C 19 A3   JMP $A319
FFE0  64 18      ERR #$18
FFE2  00         BRK
FFE3  00         BRK
FFE4  03         ERR
FFE5  FF         ERR
FFE6  3F         ERR
FFE7  00         BRK
FFE8  03         ERR
FFE9  FF         ERR
FFEA  3F         ERR
FFEB  4C 87 FF   JMP $FF87
FFEE  4C 42 FF   JMP $FF42
FFF1  4C BD FF   JMP $FFBD	;read from serial
FFF4  4C CE FF   JMP $FFCE
FFF7  4C C9 FF   JMP $FFC9
FFFA  30 01      .BYTE $30, $01 ;NMI vector
FFFC  00 FF      .BYTE $00, $FF ;Reset vector
FFFE  C0 01      .BYTE $C0, $01 ;IRQ vector

;Page 2
; $FD00 Polled Keyboard routine (C2/C4)	KB @ $DF00, $DF01

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
FDD1  2F         ERR
FDD2  20 5A 41   JSR $415A
FDD5  51 2C      EOR ($2C),Y
FDD7  4D 4E 42   EOR $424E
FDDA  56 43      LSR $43,X
FDDC  58         CLI
FDDD  4B         ERR
FDDE  4A         LSR A
FDDF  48         PHA
FDE0  47         ERR
FDE1  46 44      LSR $44
FDE3  53         ERR
FDE4  49 55      EOR #$55
FDE6  59 54 52   EOR $5254,Y
FDE9  45 57      EOR $57
FDEB  00         BRK
FDEC  00         BRK
FDED  0D 0A 4F   ORA $4F0A
FDF0  4C 2E 00   JMP $002E
FDF3  FF         ERR
FDF4  2D BA 30   AND $30BA
FDF7  B9 B8 B7   LDA $B7B8,Y
FDFA  B6 B5      LDX $B5,Y
FDFC  B4 B3      LDY $B3,X
FDFE  B2 B1      ERR #$B1

;Page3
; $FE00 65V C2/C4 65V Rom Monitor
; what hardware is at $FB05,6? 430Board UART probably
; requires polled KB
;
FE00  A2 28      LDX #$28
FE02  9A         TXS
FE03  D8         CLD
FE04  AD 06 FB   LDA $FB06
FE07  A9 FF      LDA #$FE
FE09  8D 05 FB   STA $FB05
FE0C  A2 D8      LDX #$D8
FE0E  A9 D0      LDA #$D0
FE10  85 FF      STA $FE
FE12  A9 00      LDA #$00
FE14  85 FE      STA $FE
FE16  85 FB      STA $FB
FE18  A8         TAY
FE19  A9 20      LDA #$20
FE1B  91 FE      STA ($FE),Y
FE1D  C8         INY
FE1E  D0 FB      BNE $FE1B
FE20  E6 FF      INC $FE
FE22  E4 FF      CPX $FE
FE24  D0 F5      BNE $FE1B
FE26  84 FF      STY $FE
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
FE5E  E6 FF      INC $FE
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
FEF0  A9 FF      LDA #$FE
FEF2  8D 00 DF   STA $DF00
FEF5  AD 00 DF   LDA $DF00
FEF8  60         RTS
FEF9  EA         NOP
FEFA  30 01      .BYTE $30, $01
FEFC  00 FE      .BYTE $00, $FE
FEFE  C0 01      .BYTE $C0, $01

;Page 4
; $FF00 Std Basic Boot (C/W/M?) C2/C4 
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
FF5F  43         ERR
FF60  2F         ERR
FF61  57         ERR
FF62  2F         ERR
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
FFE0  40         RTI
FFE1  3F         ERR
FFE2  01 00      ORA ($00,X)
FFE4  03         ERR
FFE5  FF         ERR
FFE6  3F         ERR
FFE7  00         BRK
FFE8  03         ERR
FFE9  FF         ERR
FFEA  3F         ERR
FFEB  4C B8 FF   JMP $FFB8
FFEE  4C 67 FF   JMP $FF67
FFF1  4C 99 FF   JMP $FF99
FFF4  4C 89 FF   JMP $FF89
FFF7  4C 94 FF   JMP $FF94
FFFA  30 01      .BYTE $30, $01
FFFD  FF         .BYTE $00, $FF
FFFE  C0 01      .BYTE $C0, $01

;Page 5
; $FD00 rom  -- HD controller boot loader 74M HD
;
FD00  20 0C FD   JSR $FD0C
FD03  4C 18 E0   JMP $E018
FD06  20 16 FD   JSR $FD16
FD09  4C 18 E0   JMP $E018
FD0C  A9 00      LDA #$00
FD0E  8D FF EF   STA $EFFF
FD11  A9 00      LDA #$00
FD13  8D FE EF   STA $EFFE
FD16  D8         CLD
FD17  A2 07      LDX #$07
FD19  A9 00      LDA #$00
FD1B  2C 80 C2   BIT $C280
FD1E  9D 00 C2   STA $C200,X
FD21  CA         DEX
FD22  10 F7      BPL $FD1B
FD24  AD FF EF   LDA $EFFF
FD27  8D 00 C2   STA $C200
FD2A  AD FE EF   LDA $EFFE
FD2D  8D 01 C2   STA $C201
FD30  A9 10      LDA #$10       
FD32  2C 80 C2   BIT $C280      ;prepare clock in
FD35  8D 02 C2   STA $C202      ;set controller reset
FD38  A9 00      LDA #$00
FD3A  8D 02 C2   STA $C202
FD3D  20 98 FD   JSR $FD98
FD40  A2 03      LDX #$03
FD42  BD AB FD   LDA $FDAB,X
FD45  2C 80 C2   BIT $C280
FD48  9D 03 C2   STA $C203,X
FD4B  CA         DEX
FD4C  10 F4      BPL $FD42
FD4E  2C 80 C2   BIT $C280
FD51  A9 80      LDA #$80
FD53  8D 07 C2   STA $C207
FD56  AD 07 C2   LDA $C207
FD59  30 FB      BMI $FD56
FD5B  AD 12 E0   LDA $E012
FD5E  4D FF EF   EOR $EFFF
FD61  30 B3      BMI $FD16
FD63  AD 13 E0   LDA $E013
FD66  4D FE EF   EOR $EFFE
FD69  D0 AB      BNE $FD16
FD6B  A9 18      LDA #$18
FD6D  85 FC      STA $FC
FD6F  A9 E0      LDA #$E0
FD71  85 FD      STA $FD
FD73  A9 0E      LDA #$0E
FD75  85 FE      STA $FE
FD77  A9 00      LDA #$00
FD79  AA         TAX
FD7A  A8         TAY
FD7B  18         CLC
FD7C  71 FC      ADC ($FC),Y
FD7E  90 04      BCC $FD84
FD80  E8         INX
FD81  F0 01      BEQ $FD84
FD83  18         CLC
FD84  C8         INY
FD85  D0 F5      BNE $FD7C
FD87  E6 FD      INC $FD
FD89  C6 FE      DEC $FE
FD8B  D0 EF      BNE $FD7C
FD8D  CD 18 EE   CMP $EE18
FD90  D0 84      BNE $FD16
FD92  EC 19 EE   CPX $EE19
FD95  D0 F9      BNE $FD90
FD97  60         RTS
FD98  AD 02 C2   LDA $C202
FD9B  C9 D9      CMP #$D9
FD9D  F0 0B      BEQ $FDAA
FD9F  29 C4      AND #$C4
FDA1  C9 C4      CMP #$C4
FDA3  D0 F3      BNE $FD98
FDA5  68         PLA
FDA6  68         PLA
FDA7  4C 16 FD   JMP $FD16
FDAA  60         RTS
FDAB  13         ERR
FDAC  00         BRK
FDAD  25 07      AND $07
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
FDFF  24 
;
; Page 6
; $FE00 block for serial system OSI 65A Serial Monitor with H/D/M FFxx rom

FE00  AD 00 FC	 LDA $FC00
FE03  4A		 LSR A
FE04  90 FA      BCC $FE00
FE06  AD 01 FC   LDA $FC01
FE09  29 7F      AND #$7F
FE0B  48         PHA
FE0C  AD 00 FC   LDA $FC00
FE0F  4A         LSR A
FE10  4A         LSR A
FE11  90 F9      BCC $FE0C
FE13  68         PLA
FE14  8D 01 FC   STA $FC01
FE17  60         RTS
FE18  20 00 FE   JSR $FE00
FE1B  C9 52      CMP #$52  ; R
FE1D  F0 16      BEQ $FE35
FE1F  C9 30      CMP #$30  ; 0
FE21  30 F5      BMI $FE18
FE23  C9 3A      CMP #$3A  ; :
FE25  30 0B      BMI $FE32
FE27  C9 41      CMP #$41  ; A
FE29  30 ED      BMI $FE18
FE2B  C9 47      CMP #$47  ; G
FE2D  10 E9      BPL $FE18
FE2F  18         CLC
FE30  E9 06      SBC #$06
FE32  29 0F      AND #$0F
FE34  60         RTS
FE35  A9 03      LDA #$03
FE37  8D 00 FC   STA $FC00
FE3A  A9 B1      LDA #$B1
FE3C  8D 00 FC   STA $FC00
FE3F  D8         CLD
FE40  78         SEI
FE41  A2 26      LDX #$26
FE43  9A         TXS
FE44  A9 0D      LDA #$0D	; <cr>
FE46  20 0B FE   JSR $FE0B
FE49  A9 0A      LDA #$0A	; <lf>
FE4B  20 0B FE   JSR $FE0B
FE4E  20 00 FE   JSR $FE00
FE51  C9 4C      CMP #$4C	; L
FE53  F0 22      BEQ $FE77
FE55  C9 50      CMP #$50	; P
FE57  F0 34      BEQ $FE8D
FE59  C9 47      CMP #$47	; G
FE5B  D0 D8      BNE $FE35
FE5D  AE 2D 01   LDX $012D
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
FE76  40         RTI
FE77  20 C7 FE   JSR $FEC7
FE7A  A2 03      LDX #$03
FE7C  A0 00      LDY #$00
FE7E  20 B5 FE   JSR $FEB5
FE81  A5 FF      LDA $FF
FE83  91 FC      STA ($FC),Y
FE85  C8         INY
FE86  D0 F6      BNE $FE7E
FE88  E6 FD      INC $FD
FE8A  B8         CLV
FE8B  50 F1      BVC $FE7E
FE8D  20 C7 FE   JSR $FEC7
FE90  A0 00      LDY #$00
FE92  A2 09      LDX #$09
FE94  A9 0D      LDA #$0D
FE96  20 0B FE   JSR $FE0B
FE99  A9 0A      LDA #$0A
FE9B  20 0B FE   JSR $FE0B
FE9E  CA         DEX
FE9F  F0 0B      BEQ $FEAC
FEA1  20 E0 FE   JSR $FEE0
FEA4  C8         INY
FEA5  D0 F7      BNE $FE9E
FEA7  E6 FD      INC $FD
FEA9  4C 9E FE   JMP $FE9E
FEAC  AD 00 FC   LDA $FC00
FEAF  4A         LSR A
FEB0  B0 8E      BCS $FE40
FEB2  EA         NOP
FEB3  90 DD      BCC $FE92
FEB5  20 18 FE   JSR $FE18
FEB8  0A         ASL A
FEB9  0A         ASL A
FEBA  0A         ASL A
FEBB  0A         ASL A
FEBC  95 FC      STA $FC,X
FEBE  20 18 FE   JSR $FE18
FEC1  18         CLC
FEC2  75 FC      ADC $FC,X
FEC4  95 FC      STA $FC,X
FEC6  60         RTS
FEC7  A2 01      LDX #$01
FEC9  20 B5 FE   JSR $FEB5
FECC  CA         DEX
FECD  20 B5 FE   JSR $FEB5
FED0  60         RTS
FED1  18         CLC
FED2  69 30      ADC #$30
FED4  C9 3A      CMP #$3A
FED6  B0 04      BCS $FEDC
FED8  20 0B FE   JSR $FE0B
FEDB  60         RTS
FEDC  69 06      ADC #$06
FEDE  90 F8      BCC $FED8
FEE0  B1 FC      LDA ($FC),Y
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
FEFA  30 01      .BYTE $30, $01
FEFD  FF 35      .BYTE $35, $FE
FEFE  C0 01      .BYTE $C0, $01
;
; Page 7
;;standard OSI 505 $FF00 H/D/M block
FF00  A0 00      LDY #$00	;reset disk PIA
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
FF53  A9 03      LDA #$03	;reset ACIA
FF55  8D 10 C0   STA $C010
FF58  A9 58      LDA #$58
FF5A  8D 10 C0   STA $C010
FF5D  20 90 FF   JSR $FF90	;read target hi from disk
FF60  85 FE      STA $FE
FF62  AA         TAX
FF63  20 90 FF   JSR $FF90	;read target lo from disk
FF66  85 FD      STA $FD
FF68  20 90 FF   JSR $FF90	;read # pages from disk
FF6B  85 FF      STA $FF
FF6D  A0 00      LDY #$00
FF6F  20 90 FF   JSR $FF90
FF72  91 FD      STA ($FD),Y  ;read n pages from disk, store at addr 
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
FF90  AD 10 C0   LDA $C010	;read A from disk ACIA
FF93  4A         LSR A
FF94  90 FA      BCC $FF90
FF96  AD 11 C0   LDA $C011
FF99  60         RTS
FF9A  48         PHA
FF9B  2F         ERR
FF9C  44 2F      ERR #$2F
FF9E  4D 3F D8   EOR $D83F
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