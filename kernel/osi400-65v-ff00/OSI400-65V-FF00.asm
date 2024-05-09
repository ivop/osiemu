;Single ROM for 440 board 65V monitor (ASCII KB)

*=$FF00
RESET_HANDLER       
       LDX #$28
       TXS			;set stack ptr, clear decimal
       CLD          
       LDA #$03 
	   STA $FC00
	   LDA #$B1 	;set ACIA to 8N2
	   STA $FC00
       LDA #$00
       STA $FE
	   STA $FF
       STA $FB		;turn off serial input (use KB)
       TAY
	   LDA #$20
DLOOP
	   STA $D000,Y
	   STA $D100,Y
	   STA $D200,Y
	   STA $D300,Y
	   INY
	   BNE DLOOP
       BEQ LFF43    ;always branch
LFF2A  JSR SFFE9    ;get char from ascii kb/serial
       CMP #$2F
       BEQ LFF4F	;cmd '/'
       CMP #$47
       BEQ LFF4C	;cmd 'G'
       CMP #$4C		
       BEQ LFF7C	;cmd 'L'
       JSR SFF93
       BMI LFF2A
       LDX #$02
       JSR SFFDA
LFF43  LDA ($FE),Y	;(initially points to $0000)
       STA $FC
       JSR SFFAC	;display monitor address & data
       BNE LFF2A	;always branch
LFF4C  JMP ($00FE)
       
LFF4F  JSR SFFE9	;process '/' cmd -- get char from ascii kb/serial
       CMP #$2E		
       BEQ LFF2A	;'.' exits
       CMP #$0D
       BNE LFF69	;<CR> increments monitor address
       INC $FE
       BNE LFF60
       INC $FF
LFF60  LDY #$00
       LDA ($FE),Y
       STA $FC
       JMP LFF77
       
LFF69  JSR SFF93	;hex char is stored, others ignored
       BMI LFF4F
       LDX #$00
       JSR SFFDA
       LDA $FC
       STA ($FE),Y
LFF77  JSR SFFAC
       BNE LFF4F
LFF7C  STA $FB
LFF7E  BEQ LFF4F	;*read 7bit byte from ACIA
LFF80  LDA $FC00
       LSR A
       BCC LFF80	;wait for byte ready
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
SFF93  CMP #$30     ;< 0?  *ascii char to hex value
       BMI LFFA9
       CMP #$3A     ;<':' ?
       BMI LFFA6
       CMP #$41     ;< 'A' ?
       BMI LFFA9
       CMP #$47     ;>= 'G' >
       BPL LFFA9
       SEC
       SBC #$07
LFFA6  AND #$0F
       RTS
       
LFFA9  LDA #$80
       RTS
       
SFFAC  LDX #$03      ;hex output 4 bytes @ $FF to $FC
       LDY #$00      ;display bytes in $FF, $FE, $FD, $FC
LFFB0  LDA $FC,X
       LSR A
       LSR A
       LSR A
       LSR A
       JSR SFFCA
       LDA $FC,X
       JSR SFFCA
       DEX
       BPL LFFB0
       LDA #$20      ;blank  extra chars on display (from $FD)
       STA $D0CA
       STA $D0CB
       RTS
       
SFFCA  AND #$0F      ;display hex nibble @D0C6+
       ORA #$30
       CMP #$3A
       BMI LFFD5
       CLC
       ADC #$07
LFFD5  STA $D0C6,Y
       INY
       RTS
       
SFFDA  LDY #$04      ;shift nibble into memory
       ASL A
       ASL A
       ASL A
       ASL A
LFFE0  ROL A
       ROL $FC,X
       ROL $FD,X
       DEY
       BNE LFFE0
       RTS
       
SFFE9  LDA $FB      ;controls ASCII KB or serial
       BNE LFF7E    
LFFED  LDA $DF01    ;entry for chr-in
       BMI LFFED    ;wait for msb bit to go low
       PHA          ;save KB value
LFFF3  LDA $DF01    ;wait for msb to go hi
       BPL LFFF3    
       PLA          ;return KB value
       RTS
		.BYTE $30, $01 ;NMI vector (unused at current address)
		.BYTE $00, $FF ;Reset vector
		.BYTE $C0, $01 ;IRQ vector    
		