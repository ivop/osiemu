; FFxx ROM for OSI440 video + BASIC ROMS ASCII Keyboard

;$200 - current screen cursor pos
;$201 - temp storage for char to be printed
;$203 - load flag $01 = from ACIA

;$205 - save flag $0 = NOT save mode
;$206 - time delay for CRT driver
;$20F - 
;$212 - CTRL-C flag, not 0 = ignore Ctrl-C

*=$FF00
RESET_HANDLER
         CLD
         LDX #$28
         TXS
         JSR $BF22   ;init ACIA 8N2/16
         LDY #$00
         STY $0212
         STY $0203
         STY $0205
         STY $0206
         LDA LFFE0
         STA $0200
         LDA #$20
         STA $0201
         STA $020F
LFF23    STA $D700,Y	;erase 2K screen
         STA $D600,Y
         STA $D500,Y
         STA $D400,Y
         STA $D300,Y
         STA $D200,Y
         STA $D100,Y
         STA $D000,Y
         INY
         BNE LFF23
LFF3E    LDA LFF65,Y
         BEQ LFF49
         JSR $BF2D	;BASIC screen printer
         INY
         BNE LFF3E
LFF49    JSR SFFAB
         CMP #$4D
         BNE LFF53
         JMP $FE00	;Monitor ROM start
         
LFF53    CMP #$57
         BNE LFF5A
         JMP $0000	;Warm Start
         
LFF5A    CMP #$43
         BNE RESET_HANDLER
         LDA #$00
         TAX
         TAY
         JMP $BD11	;goto BASIC cold start routine
		 
LFF65    .BYTE 'C/W/M?',0

LFF6C    JSR $BF2D	;BASIC screen printer
         PHA
         LDA $0205
         BEQ LFF99
         PLA
         JSR $BF15	;write to ACIA
         CMP #$0D
         BNE LFF9A
         PHA
         TXA
         PHA
         LDX #$0A
         LDA #$00
LFF84    JSR $BF15	;write to ACIA
         DEX
         BNE LFF84
         PLA
         TAX
         PLA
         RTS
         
LFF8E    PHA
         LDA #$01
         STA $0203
         LDA #$00
LFF96    STA $0205
LFF99    PLA
LFF9A    RTS
         
LFF9B    PHA
         LDA #$01
         BNE LFF96
LFFA0    LDA $0212
         BNE LFFA8
         JMP LFFAE
         
LFFA8    JMP $A628
         
SFFAB    JMP LFFC0
         
LFFAE    LDA $DF01
         BMI LFFA8
         JMP $A633
         
LFFB6    LDA $FC01
         AND #$7F
         RTS
         
LFFBC    PLA
         TAY
         PLA
         TAX
LFFC0    LDA $DF01
         BMI LFFD2
         PHA
         LDA #$00
         STA $0203
LFFCB    LDA $DF01	;wait for ASCII Keyboard keypress
         BPL LFFCB
         PLA
         RTS
         
LFFD2    LDA $0203
         BEQ SFFAB
         LDA $FC00
         LSR A
         BCC SFFAB
         JMP LFFB6
         
LFFE0    .BYTE $64     ; LINE START OFFSET (for video system)
		 .BYTE $18     ; LINE LENGTH - 1
		 .BYTE $00     ; SCREEN RAM 0=1K, 1=2K
		 .BYTE $00,$03 ;default BASIC workspace lower bounds
		 .BYTE $FF,$3F ;default BASIC workspace upper bounds
		 .BYTE $00,$03 ;variable workspace lower bounds
		 .BYTE $FF,$3F ;variable workspace upper bounds
LFFEB    JMP SFFAB     ; INPUT    
LFFEE    JMP LFF6C     ; OUTPUT    
LFFF1    JMP LFFA0     ; CTRL-C check    
LFFF4    JMP LFF8E     ; LOAD   
LFFF7    JMP LFF9B     ; SAVE    
         .WORD $0130   ;<NMI>
		 .WORD $FF00   ;<RESET>
		 .WORD $01C0   ;<IRQ>
		 