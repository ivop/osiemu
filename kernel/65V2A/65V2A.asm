; OSI 65V2A video PROM monitor for OSI540 with ASCII keyboard & BASIC-In-ROM

;$203 - load flag $01 = load from ACIA
;$205 - save flag $0 = NOT save mode
;$212 - disable CTRL-C check
*=$FF00

LFF00	CLD
		LDX #$28
		TXS
		JSR $BF22  ;reset ACIA 8N2/16
		LDY #$00
		STY $0212
		STY $0203
		STY $0205
		STY $0206
		LDA LFFE0  ;#$40
		STA $0200
		LDA #$20   ;clear 2K screen
		STA $0201
		STA $020F
LFF23	STA $D700,Y
		STA $D600,Y
		STA $D500,Y
		STA $D400,Y
		STA $D300,Y
		STA $D200,Y
		STA $D100,Y
		STA $D000,Y
		INY
		BNE LFF23
LFF3E	LDA LFF65,Y  ;'C/W/M?'
		BEQ LFF49
		JSR $BF2D    ;basic screen chrout
		INY
		BNE LFF3E
LFF49	JSR LFFAB
		CMP #$4D  ;'M
		BNE LFF53
		JMP $FE00	;65V monitor rom entry
LFF53	CMP #$57  ;'W
		BNE LFF5A
		JMP $0000	;warmstart location
LFF5A	CMP #$43  ;'C
		BNE LFF00
		LDA #$00
		TAX
		TAY
		JMP $BD11  ;BASIC Cold Start
LFF65	.BYTE 'C/W/M?',0
        ;[output routine entry]
LFF6C	JSR $BF2D  ;Output to screen
		PHA
		LDA $0205	;SAVE flag on?
		BEQ LFF99
		PLA
		JSR $BF15   ;write to ACIA
		CMP #$0D
		BNE LFF9A	;[during SAVE, upon detection of <CR> output 10 NULs]
		PHA
		TXA
		PHA
		LDX #$0A
		LDA #$00
LFF84	JSR $BF15   ;write to ACIA
		DEX
		BNE LFF84
		PLA
		TAX
		PLA
		RTS
LFF8E	PHA        ;[Load routine enable entry]
		LDA #$01
		STA $0203  ;load flag
		LDA #$00
LFF96	STA $0205  ;save flag
LFF99	PLA
LFF9A	RTS
LFF9B	PHA        ;[Save routine enable entry]
		LDA #$01
		BNE LFF96
LFFA0	LDA $0212  ;[CTRL-C check routine entry]
		BNE LFFA8  ; not 0 = ignore ctrl-c
		JMP LFFAE
LFFA8	JMP $A628  ;goes to RTS
LFFAB	JMP LFFC0  ;[Input routine entry]
LFFAE	LDA $DF01  ;check for character from ASCII KB
		BMI LFFA8
		JMP $A633  ;(test for CTRL-C)
LFFB6	LDA $FC01  ;read 7bit char from ACIA
		AND #$7F
		RTS
		PLA
		TAY
		PLA
		TAX
LFFC0	LDA $DF01  ;[input char from ACIA, or KB; stop load if keyboard char detected]
		BMI LFFD2  ;(no char waiting, branch)
		PHA
		LDA #$00   ;disable load flag
		STA $0203
LFFCB	LDA $DF01  ;wait for KB strobe to raise to indicate character ready
		BPL LFFCB
		PLA
		RTS
LFFD2	LDA $0203  ;is serial load flag set?
		BEQ LFFAB  ;no, branch
		LDA $FC00
		LSR A
		BCC LFFAB  ;branch, no char from serial yet
		JMP LFFB6
		
LFFE0	.BYTE $40      ;initial cursor pos after CR, LF ($64 for OSI440/C1P,$40 for OSI540)
		.BYTE $3F      ;default terminal width/characters per line -1
		.BYTE $01      ;screen memory size 00 = 1K otherwise 2K
		.BYTE $00,$03  ;default BASIC workspace lower bounds
		.BYTE $FF,$3F  ;default BASIC workspace upper bounds
		.BYTE $00,$03  ;variable workspace lower bounds
		.BYTE $FF,$3F  ;variable workspace upper bounds
		
		JMP LFFAB      ;Input routine jump
		JMP LFF6C      ;Output routine jump
		JMP LFFA0      ;CTRL-C check routine jump
		JMP LFF8E      ;Load routine jump
		JMP LFF9B      ;Save routine jump
		.WORD $0130    ;NMI vector
		.WORD LFF00    ;Reset vector
		.WORD $01C0    ;IRQ vector