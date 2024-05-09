; $FExx 65V ROM Monitor for system with ASCII KB @ $DF01 & UART @ $FB05(430) 440 video

INPUT=$FEE9
FLAG=$FB
DAT=$FC
PNTL=$FE
PNTH=$FF

*=$FE00
		LDX #$28
		TXS
		CLD
		LDA $FB06	;clear S1883
		LDA #$FF
		STA $FB05	;Set S1883 8N2
		LDX #$D4    ;clear 1K screen
		LDA #$D0
		STA PNTH
		LDA #$00
		STA PNTL
		STA FLAG
		TAY
		LDA #$20	;fill 1K screen $D000-$D7FF with $20 ' '
VM1		STA (PNTL),Y
		INY
		BNE VM1
		INC PNTH
		CPX PNTH
		BNE VM1
		STY PNTH
		BEQ IN
ADDR	JSR INPUT
		CMP #'/
		BEQ DATA
		CMP #'G
		BEQ GO
		CMP #'L
		BEQ LOAD
		JSR LEGAL
		BMI ADDR
		LDX #$02
		JSR ROLL
IN		LDA (PNTL),Y
		STA DAT
		JSR $FEAC
		BNE ADDR
GO		JMP (PNTL)
DATA	JSR INPUT
		CMP #'.
		BEQ ADDR
		CMP #$0D
		BNE DATA
		INC PNTL
		BNE DAT3
		INC PNTH
DAT3	LDY #$00
		LDA (PNTL),Y
		STA DAT
		JMP INNER
		JSR LEGAL
		BMI DATA
		LDX #$00
		JSR ROLL
		LDA DAT
		STA (PNTL),Y
INNER	JSR OUTPUT
		BNE DATA
LOAD	STA FLAG
L1		BEQ DATA
OTHER	LDA $FB05    ;was LDA $FC00
		LSR A
		BCC OTHER
		LDA $FB03    ; was LDA $FC01
		STA $FB07    ; was NOP NOP NOP
		AND #$7F
		RTS
		.BYTE 0,0,0,0 ;space
LEGAL	CMP #'0
		BMI FAIL
		CMP #':
		BMI OK
		CMP #'A
		BMI FAIL
		CMP #'G
		BPL FAIL
		SEC
		SBC #$07
OK		AND #$0F
		RTS
FAIL	LDA #$80
		RTS
OUTPUT	LDX #$03	;output LLLL DD onto screen
		LDY #$00
OUI		LDA DAT,X
		LSR A
		LSR A
		LSR A
		LSR A
		JSR DIGIT
		LDA DAT,X
		JSR DIGIT
		DEX
		BPL OUI
		LDA #$20
		STA $D0CA
		STA $D0CB
		RTS
DIGIT	AND #$0F  ;output 1 digit to screen
		ORA #$30
		CMP #$3A
		BMI HA1
		CLC
		ADC #$07
HA1		STA $D0C6,Y
		INY
		RTS
ROLL	LDY #$04	;move LSD in AC to LSD in 2 Byte Num
		ASL A
		ASL A
		ASL A
		ASL A
R01		ROL A
		ROL DAT,X
		ROL DAT+1,X
		DEY
		BNE R01
		RTS
		LDA FLAG
		BNE L1		;yes go do ACIA input
KBTEST	LDA $DF01 	;$FEED
		BMI KBTEST
		PHA
KB1		LDA $DF01
		BPL KB1
		PLA
		RTS
		.BYTE $30, $01	;NMI vector
		.BYTE $00, $FE  ;RESET vector
		.BYTE $CO, $01  ;IRQ vector
