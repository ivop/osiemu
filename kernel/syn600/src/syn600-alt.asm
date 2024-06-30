;This is the ROM contents of the Ohio Scientific "SYN600" ROM used in the 
;OSI 600 Superboard/Challenger C1P and also compatible with Challenger C2P/OSI502 CPU board
;and Challenger C4P & C8P/OSI505 CPU board
;In the OSI 600, the full 2K ROM may be visible, but only the last 4 pages are needed ($FC00-FFFF)
;In other systems, the ROM is configured to provide 3 pages at $FD00-FFFF. Which pages are mapped 
;of the 4 available depend on the configuration needed. BASIC-in-ROM & cassette or floppy disk based.
;
;You can assemble this ROM with the A65 assembler ( http://osi.marks-lab.com/software/tools.html ),
;which will allow you to generate the binary ROM image even though duplicate addresses are specified 
;in the assembler file. (The are multiple $FDxx, $FExx and $FFxx pages) 
;A binary relocation warning is generated but assembling continues.
;
;The following flag determines if the generated ROM is configured as originally shipped, or
;altered for the C1P to perform a screen clear before depending on having working lower 1K RAM.
;This is useful to visually indicate the system is initializing even if problems prevent correct RAM 
;access.
;Use Original=1 to make the original ROM, or ORIGINAL=0 to make a binary compatible version with
;altered order of execution.
;
ORIGINAL=1


	; SYN600 - OSI 2K multiboard System ROM
	; page 0 'H/D/M'   maps to $FF00 for a C2/C4 540Video & disk system
	; page 1 keypoller maps to $FD00 for a C2/C4 540Video system
	; page 2 monitor   maps to $FE00 for a C2/C4 540Video system
	; page 3 'C/W/M'   maps to $FF00 for a C2/C4 540Video & tape system
	; page 4 disk boot maps to $FC00 for a C1 system
	; page 5 keypoller maps to $FD00 for a C1 system
	; page 6 monitor   maps to $FE00 for a C1 system
	; page 7 'D/C/W/M' maps to $FF00 for a C1 system

; RAM locations used by BASIC ROM & system ROM
;$200 - cursor pos
;$201 - save char under cursor
;$202 - temp storage for char to be printed
;$203 - load flag $80 = serial
;$204 - (temp)
;$205 - save flag $0 = NOT save mode
;$206 - repeat rate for CRT routine
;$207-$20E part of scroll routine (video dependent) LDA $D700,Y STA $D700,Y INY RTS
;$20F - $211 not used
;$212 - ctrl-c flag
;$213 = temp storage for KB calculations
;$214 = debounce/repeat counter
;$215 = current key pressed
;$216 = last key pressed

;page 0 'H/D/M'   maps to $FF00 for a C2/C4 540 Video & disk system
*=$FF00
MFF00  LDY #$00      ;init disk controller
       STY $C001     ;select DDRA.
       STY $C000     ;0's in DDRA indicate input.
       LDX #$04      
       STX $C001     ;select PORTA
       STY $C003     ;select DDRB
       DEY          
       STY $C002     ;1's in DDRB indicate output.
       STX $C003     ;select PORT B
       STY $C002     ;make all outputs high
       LDA #$FB      
       BNE MFF27     ;step to track +1
MFF1E  LDA #$02      
       BIT $C000     ;test track 0 enabled?
       BEQ MFF41     
       LDA #$FF      ;step down to 0
MFF27  STA $C002     
       JSR MFF99     ;(short delay)
       AND #$F7      ;step on
       STA $C002     
       JSR MFF99     ;(short delay)
       ORA #$08      
       STA $C002     ;step off
       LDX #$18      
       JSR MFF85     ;delay
       BEQ MFF1E
MFF41  LDX #$7F      ;load head
       STX $C002     
       JSR MFF85     ;delay
MFF49  LDA $C000     
       BMI MFF49     ;wait for index start
MFF4E  LDA $C000     
       BPL MFF4E     ;wait for index end
       LDA #$03      
       STA $C010     ;reset disk ACIA
       LDA #$58      
       STA $C010     ;/1 RTS hi, no irq
       JSR MFF90     
       STA $FE       ;read start addr hi
       TAX           
       JSR MFF90     
       STA $FD       ;read start addr lo
       JSR MFF90     
       STA $FF       ;read num pages
       LDY #$00      
MFF6F  JSR MFF90     
       STA ($FD),Y   ;read the specified num pages
       INY
       BNE MFF6F
       INC $FE
       DEC $FF
       BNE MFF6F
       STX $FE
       LDA #$FF      ;disable drive
       STA $C002
       RTS
       
MFF85  LDY #$F8      ;delay routine
MFF87  DEY
       BNE MFF87
       EOR $FF,X
       DEX
       BNE MFF85
       RTS
       
MFF90  LDA $C010    ;read a byte from disk
       LSR A
       BCC MFF90
       LDA $C011
MFF99  RTS
       
MFF9A .BYTE 'H/D/M?' ;48 2F 44 2F 4D 3F 
;Entry point for RESET ($FFA0)
MFFA0  CLD
       LDX #$D8		;clear 2K screen
       LDA #$D0
       STA $FE
       LDY #$00
       STY $FD
       LDA #$20
MFFAD  STA ($FD),Y
       INY
       BNE MFFAD
       INC $FE
       CPX $FE
       BNE MFFAD
       LDA #$03
       STA $FC00	;reset ACIA
       LDA #$B1
       STA $FC00	;Set ACIA 8N2 +recv IRQ
MFFC2  LDA MFF9A,Y
       BMI MFFD5
       STA $D0C6,Y	;display H/D/M? message
       LDX LFE00+1	;flag serial or video system? 0=serial
       BNE MFFD2
       JSR $FE0B	;write to ACIA on serial system/65A monitor
MFFD2  INY
       BNE MFFC2
MFFD5  LDA LFE00+1
       BNE MFFDF
       JSR $FE00	;input from serial system ACIA
       BCS MFFE2
MFFDF  JSR MFEED	;input from polled keyboard (redir to FD00)
MFFE2  CMP #$48		;'H
       BEQ MFFF0
       CMP #$44		;'D
       BNE MFFF6
       JSR RESET_HANDLER
       JMP $2200	;default address of track loaded from diskette
       
MFFF0  JMP LFD00
       
       JSR MFF00 
MFFF6  JMP ($FEFC)	;65V monitor entry ($FE00)
       
       NOP
	   .BYTE $30, $01
	   .WORD MFFA0
	   .BYTE $C0, $01 
	   
;page 1 keypoller maps to $FD00 for a C2/C4 540 Video system
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
;$0213 = temp storage for KB calculations
;$0214 = debounce counter
;$0215 = current key pressed
;$0216 = last key pressed
*=$FD00
MFD00  TXA
       PHA
       TYA
       PHA
MFD04  LDA #$01
MFD06  STA $DF00	;select row
       LDX $DF00	;read row
       BNE MFD13	;any keys pressed?
MFD0E  ASL A
       BNE MFD06
       BEQ MFD66
MFD13  LSR A		;was this row 0?
       BCC MFD1F	;branch if not
       ROL A		;restore row value
       CPX #$21		;was it ESC
       BNE MFD0E	;not esc, keep scanning
       LDA #$1B		;yes, load key value
       BNE MFD40	;branch always
MFD1F  JSR MFDC8	;convert bit set to index
       TYA
       STA $0213	;store row index
       ASL A		;multiply by 8
       ASL A
       ASL A
       SEC
       SBC $0213	;subtract 1 = (*7)
       STA $0213
       TXA
       LSR A
       JSR MFDC8	;convert key col to index
       BNE MFD66	;more than one pressed? exit as no key pressed
       CLC
       TYA
       ADC $0213	;add col to row*7
       TAY
       LDA MFDCF,Y	;read key value from table
MFD40  CMP $0215	;same as last time?
       BNE MFD6B	;branch if not
       DEC $0214	;count down debounce/repeast counter
       BEQ MFD75	;branch when done
       LDY #$05
MFD4C  LDX #$C8		;delay for a while
MFD4E  DEX
       BNE MFD4E
       DEY
       BNE MFD4C
       BEQ MFD04	;branch back to top when done
MFD56  CMP #$01
       BEQ MFD8F	;branch if right shift only
       LDY #$00
       CMP #$02		;was it left shift only
       BEQ MFDA7
       LDY #$C0
       CMP #$20
       BEQ MFDA7
MFD66  LDA #$00
       STA $0216
MFD6B  STA $0215
       LDA #$02
       STA $0214
       BNE MFD04
MFD75  LDX #$96		;1st auto repeat delay value
       CMP $0216
       BNE MFD7E
       LDX #$14		;key repeating delay value
MFD7E  STX $0214
       STA $0216
       LDA #$01		;read row 0
       STA $DF00
       LDA $DF00
       LSR A
       BCC MFDC2	;capslock set? branch if not
MFD8F  TAX
       AND #$03
       BEQ MFD9F	;any shift keys set? branch if not
       LDY #$10		
       LDA $0215
       BPL MFDA7	;was key a shiftable key? (hi bit set)
       LDY #$F0		;subtract $10 value ($31+$F0=$21 "1"->"!")
       BNE MFDA7	;branch always
MFD9F  LDY #$00
       CPX #$20		;is ctrl key pressed?
       BNE MFDA7
       LDY #$C0		;add ctrl key modifier value
MFDA7  LDA $0215
       AND #$7F
       CMP #$20
       BEQ MFDB7
       STY $0213
       CLC
       ADC $0213
MFDB7  STA $0213
       PLA
       TAY
       PLA
       TAX
       LDA $0213
       RTS
       
MFDC2  BNE MFD56	;branch if left shift, no capslock
       LDY #$20		;add upper to lower case value $41->$61 "A"->"a"
       BNE MFDA7
	   
	   ;convert bit position to index
MFDC8  LDY #$08
MFDCA  DEY
       ASL A
       BCC MFDCA
       RTS
       
       ;keyboard key lookup table 7x7	(row 0 contains mostly modifier keys, no lookup)
MFDCF  .BYTE $D0,$BB,'/ ZAQ'				;row 1
       .BYTE ',MNBVCX'						;row 2
       .BYTE 'KJHGFDS'						;row 3
       .BYTE 'IUYTREW'						;row 4
       .BYTE $00,$00,$0D,$0A,'OL.'			;row 5
       .BYTE $00,$FF,$2D,$BA,$30,$B9,$B8	;row 6
       .BYTE $B7,$B6,$B5,$B4,$B3,$B2,$B1	;row 7

; page 2 65V monitor -maps to $FE00 for a C2/C4 540 Video system
*=$FE00

;$FB = load flag 0=input from keyboard
;$FC = current value
;$FD = not written but temporarily hex value copied to screen between addr & value
;$FE = current address low
;$FF = current address high
MFE00  LDX #$28
       TXS
       CLD
       LDA $FB06	; Reset S1883 UART
       LDA #$FF
       STA $FB05	;Set Parity/WordLen/Stopbits 8N2
       LDX #$D8
       LDA #$D0		;Set up to clear screen (2k)
       STA $FF
       LDA #$00
       STA $FE
       STA $FB
       TAY
       LDA #$20
MFE1B  STA ($FE),Y	;clear screen
       INY
       BNE MFE1B
       INC $FF
       CPX $FF
       BNE MFE1B	;loop till done
       STY $FF
       BEQ MFE43	;always branch
MFE2A  JSR MFEE9
       CMP #$2F		;'/
       BEQ MFE4F
       CMP #$47		;'G
       BEQ MFE4C
       CMP #$4C		;'L
       BEQ MFE7C
       JSR MFE93	;test char for hex value
       BMI MFE2A	;branch if not hexadecimal
       LDX #$02
       JSR MFEDA
MFE43  LDA ($FE),Y
       STA $FC
       JSR MFEAC
       BNE MFE2A
MFE4C  JMP ($00FE)
       
MFE4F  JSR MFEE9
       CMP #$2E		;'.
       BEQ MFE2A
       CMP #$0D		;<CR>
       BNE MFE69
       INC $FE
       BNE MFE60
       INC $FF
MFE60  LDY #$00
       LDA ($FE),Y
       STA $FC
       JMP LFE77
       
MFE69  JSR MFE93
       BMI MFE4F
       LDX #$00
       JSR MFEDA
       LDA $FC
       STA ($FE),Y
       JSR MFEAC
       BNE MFE4F
MFE7C  STA $FB
MFE7E  BEQ MFE4F
MFE80  LDA $FC00	;input from ACIA
       LSR A
       BCC MFE80
       LDA $FC01
       NOP
       NOP
       NOP
       AND #$7F		;mask upper bit
       RTS
       
       .BYTE $00,$00,$00,$00
	   
	   ;convert A to hex nibble, return $80 if not hex
MFE93  CMP #$30		;'0
       BMI MFEA9
       CMP #$3A		;':
       BMI MFEA6
       CMP #$41		;'A
       BMI MFEA9
       CMP #$47		;'G
       BPL MFEA9
       SEC
       SBC #$07
MFEA6  AND #$0F
       RTS
       
MFEA9  LDA #$80
       RTS
       ;display current address, data on screen
MFEAC  LDX #$03
       LDY #$00
MFEB0  LDA $FC,X
       LSR A
       LSR A
       LSR A
       LSR A
       JSR MFECA
       LDA $FC,X
       JSR SFECA
       DEX
       BPL MFEB0
       LDA #$20		;erase space between address & data
       STA $D0CA
       STA $D0CB
       RTS
       
	   ;display nibble on screen as hex
MFECA  AND #$0F
MFECC  ORA #$30
MFECE  CMP #$3A
       BMI MFED5
       CLC
       ADC #$07
MFED5  STA $D0C6,Y
       INY
       RTS
	   
       ;shift in nibble 
MFEDA  LDY #$04
       ASL A
       ASL A
       ASL A
       ASL A
MFEE0  ROL A
       ROL $FC,X
       ROL $FD,X
       DEY
       BNE MFEE0
       RTS
       
MFEE9  LDA $FB		;check load flag
       BNE MFE7E
MFEED  JMP LFD00	;input from keyboard
       
MFEF0  LDA #$FF		
       STA $DF00
       LDA $DF00
       RTS
       NOP
	   ;used when monitor ROM is used as $FF00 ROM
       .BYTE $30, $01	;NMI
	   .BYTE $00, $FE	;RESET
	   .BYTE $C0, $01	;IRQ

; page 3 'C/W/M'   maps to $FF00 for a C2/C4 540 Video & cassette system
*=$FF00	   
NFF00  CLD
       LDX #$28
       TXS
       JSR $BF22	;init ACIA 8N2/16 irq set in BASIC ROM
       LDY #$00
       STY $0212
       STY $0203
       STY $0205
       STY $0206
       LDA $FFE0
       STA $0200
       LDA #$20		;erase 2K screen
NFF1D  STA $D700,Y
       STA $D600,Y
       STA $D500,Y
       STA $D400,Y
       STA $D300,Y
       STA $D200,Y
       STA $D100,Y
       STA $D000,Y
       INY
       BNE NFF1D
NFF38  LDA NFF5F,Y	;display "C/W/M ?" prompt
       BEQ NFF43
       JSR $BF2D	;BASIC Screen print routine
       INY
       BNE NFF38
NFF43  JSR NFFB8
       CMP #$4D
       BNE NFF4D
       JMP LFE00
       
NFF4D  CMP #$57		;'W
       BNE NFF54
       JMP $0000	;Warmstart vector
       
NFF54  CMP #$43		;'C
       BNE NFF00
       LDA #$00
       TAX
       TAY
       JMP $BD11	;BASIC cold start entry
NFF5F       
	   .BYTE 'C/W/M ?',0

NFF67  JSR $BF2D	;BASIC Screen print routine
       PHA
       LDA $0205	;test save flag
       BEQ NFF92
       PLA
       JSR $BF15
       CMP #$0D
       BNE NFF93
       PHA			;during save on output of <CR> write 10 NULs padding
       TXA
       PHA
       LDX #$0A
       LDA #$00
NFF7F  JSR $BF15
       DEX
       BNE NFF7F
       PLA
       TAX
       PLA
       RTS
       
NFF89  PHA
       DEC $0203
       LDA #$00		;disable save flag
NFF8F  STA $0205
NFF92  PLA
NFF93  RTS
       
NFF94  PHA
       LDA #$01
       BNE NFF8F
NFF99  LDA $0212
       BNE NFFB7
       LDA #$01
       STA $DF00	;select row 0 on keyboard
       BIT $DF00
       BVC NFFB7	;test for CTRL keypress
       LDA #$04
       STA $DF00	;select row 3 on keyboard
       BIT $DF00
       BVC NFFB7	;Test for 'C' keypress
       LDA #$03		;CTRL-C detected!
       JMP $A636
       
NFFB7  RTS
       
NFFB8  BIT $0203
       BPL NFFD6
NFFBD  LDA #$02
       STA $DF00	;select row 2 on keyboard
       LDA #$10
       BIT $DF00	;test for space bar pressed
       BNE NFFD3	;branch if pressed
       LDA $FC00	;test for character ready from ACIA
       LSR A
       BCC NFFBD
       LDA $FC01	;load character from ACIA
       RTS
       
NFFD3  INC $0203
NFFD6  JMP MFEED
       
       .BYTE 00,00,00,00,00,00,00
	   
NFFE0  .BYTE $40,$3F,$01  ;cursor start @ $40, line len-1 $3F, 01 = 2K video flag
	   .BYTE $00,$03      ;default BASIC workspace lower bounds
	   .BYTE $FF,$3F      ;default BASIC workspace upper bounds
	   .BYTE $00,$03      ;variable workspace lower bounds
	   .BYTE $FF,$3F      ;variable workspace upper bounds
	   
NFFEB  JMP NFFB8    ;input vector
NFFEE  JMP NFF67    ;output vector
NFFF1  JMP NFF99    ;control-C check vector
NFFF4  JMP NFF89    ;load vector
NFFF7  JMP NFF94    ;save vector
       
       .BYTE $30,$01 ;<NMI>
	   .BYTE $00,$FF ;<RESET>
	   .BYTE $C0,$01 ;<IRQ>


;page 4 $FC00  floppy disk support C1
;DISK PIA @ $C000
;DISK ACIA @ $C010

*=$FC00

LFC00  JSR SFC0C		;load track 0 from disk at specified address (usually $2200)
       JMP ($00FD)		;execute loaded track
LFC06  JSR SFC0C		;load track 0 from disk
       JMP LFE00		;jump to monitor
SFC0C  LDY #$00		    ;init disk controller
       STY $C001       ;select DDRA.
       STY $C000       ;0's in DDRA indicate input.
       LDX #$04        
       STX $C001       ;select PORTA
       STY $C003       ;select DDRB
       DEY
       STY $C002       ;1's in DDRB indicate output.
       STX $C003       ;select PORT B
       STY $C002       ;make all outputs high
       LDA #$FB        
       BNE LFC33       ;step to track +1
LFC2A  LDA #$02        
       BIT $C000       ;track 0 enabled?
       BEQ LFC4D       
       LDA #$FF        ;step down to 0
LFC33  STA $C002       
       JSR SFCA5       ;(short delay)
       AND #$F7        ;step on
       STA $C002       
       JSR SFCA5       ;(short delay)
       ORA #$08        
       STA $C002       ;step off
       LDX #$18        
       JSR SFC91       ;delay
       BEQ LFC2A       
LFC4D  LDX #$7F        ;load head
       STX $C002       
       JSR SFC91       ;delay
LFC55  LDA $C000       
       BMI LFC55       ;wait for index start
LFC5A  LDA $C000       
       BPL LFC5A       ;wait for index end
       LDA #$03        
       STA $C010       ;reset disk ACIA
       LDA #$58        
       STA $C010       ;/1 RTS hi, no irq
       JSR SFC9C       
       STA $FE         ;read start addr hi
       TAX
       JSR SFC9C       
       STA $FD         ;read start addr lo
       JSR SFC9C       
       STA $FF         ;read num pages
       LDY #$00        
LFC7B  JSR SFC9C       
       STA ($FD),Y     ;read the specified num pages
       INY
       BNE LFC7B       
       INC $FE         
       DEC $FF         
       BNE LFC7B       
       STX $FE         
       LDA #$FF        
       STA $C002       ;disable drive
       RTS
SFC91  LDY #$F8        ;loop for delay
LFC93  DEY
       BNE LFC93       
       EOR $FF,X       
       DEX
       BNE SFC91       
       RTS

SFC9C  LDA $C010       ;read byte from disk
       LSR A           
       BCC SFC9C       
       LDA $C011       
SFCA5  RTS
          
SFCA6  LDA #$03		;reset serial port ACIA
       STA $F000
       LDA #$11		;8N2 no irq
       STA $F000
       RTS
       
LFCB1  PHA			;wait & output to ACIA
LFCB2  LDA $F000	;ACIA @ $F000
       LSR A
       LSR A
       BCC LFCB2
       PLA
       STA $F001
       RTS
       
SFCBE  EOR #$FF	;Set KB ROW 
       STA $DF00
       EOR #$FF
       RTS
       
SFCC6  PHA		;read keyboard, return value in X, preserve other registers
       JSR SFCCF
       TAX
       PLA
       DEX
       INX
       RTS
       
SFCCF  LDA $DF00	;load KB Col
       EOR #$FF
       RTS
       ;padding
       .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
       .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
       .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

;page 5 $FD00  key poller for C1

;OSI keyboard decode table reference
;  Columns read from $DF00, Rows selected by writing to $DF00
;  C1 series has inverted values (bit cleared when key pressed)
;
;     7    6    5    4    3    2    1    0
; -----------------------------------------
; 7- 1/!  2/"  3/#  4/$  5/%  6/&  7/'
;
; 6- 8/(  9/)  0/@  :/*  -/=  rub
;
; 5- ./>   L    O    lf   cr
;
; 4-  W    E    R    T    Y    U    I
;
; 3-  S    D    F    G    H    J    K
;
; 2-  X    C    V    B    N    M   ,/<
;
; 1-  Q    A    Z   spc  //?  ;/+   P
;
; 0- rpt  ctl  esc            lsh  rsh  caps
;
;$0213 = temp storage for KB calculations
;$0214 = debounce & autorepeat counter
;$0215 = current key pressed
;$0216 = last key pressed

LFD00  TXA
       PHA
       TYA
       PHA
LFD04  LDA #$01		;recheck for keypress
LFD06  JSR SFCBE	;invert & store value for C1P key row
       JSR SFCC6	;read and invert C1P value, return in X
       BNE LFD13	;branch if key detected
LFD0E  ASL A
       BNE LFD06	;shift row until done
       BEQ LFD66	;branch because no key pressed
LFD13  LSR A
       BCC LFD1F	;was this row 0? branch if not
       ROL A		;restore row in A
       CPX #$21		;was this ESC key?
       BNE LFD0E
       LDA #$1B		;yup set ESC key value
       BNE LFD40	;branch to key set
LFD1F  JSR SFDC8	;convert bit set in A to value 0-7 in Y
       TYA
       STA $0213
       ASL A		;multiply by 8
       ASL A
       ASL A
       SEC
       SBC $0213 	;subtract 1 (= *7)
       STA $0213	;store row*7 in 0213
       TXA
       LSR A
       JSR SFDC8	;get key position index in Y
       BNE LFD66	;if more than 1 key pressed pretend no key pressed
       CLC
       TYA
       ADC $0213	;add col index to row*7 value
       TAY
       LDA LFDCF,Y	;load key value from table
LFD40  CMP $0215	;same as last time?
       BNE LFD6B	;branch if not
       DEC $0214	;still counting down?
       BEQ LFD75	;branch if done
       LDY #$05		;loop for a while
LFD4C  LDX #$C8		;eating CPU cycles
LFD4E  DEX
       BNE LFD4E	;loop
       DEY
       BNE LFD4C	;loop
       BEQ LFD04	;done with delay loop, branch always to retest keypress
LFD56  CMP #$01
       BEQ LFD8F
       LDY #$00
       CMP #$02
       BEQ LFDA7	;branch if left shift
       LDY #$C0
       CMP #$20
       BEQ LFDA7
LFD66  LDA #$00		;clear previous keypress
       STA $0216
LFD6B  STA $0215	;new keypress detected
       LDA #$02		;short debounce retest
       STA $0214
       BNE LFD04
LFD75  LDX #$96		;done waiting, longer autorepeat delay value 
       CMP $0216	;test flag: is auto repeat engaged?
       BNE LFD7E
       LDX #$14		;yes, short autorepeat delay
LFD7E  STX $0214
       STA $0216	;current key store
       LDA #$01
       JSR SFCBE	;select row 0
       JSR SFCCF	;read row
LFD8C  LSR A		;shift value down to test bit 0
       BCC LFDC2	;is capslock set? branch if not
LFD8F  TAX			;save row 0 value in X
       AND #$03
       BEQ LFD9F	;any shift keys pressed? if not, branch
       LDY #$10		;apply shift key
       LDA $0215
       BPL LFDA7	;was the keyboard key a shiftable key (hi bit set?)
       LDY #$F0		;yes subtract $10 ($31+$F0=$21 "1"->"!")
       BNE LFDA7
LFD9F  LDY #$00		;no shifted value
       CPX #$20		;was row0 key CTRL?
       BNE LFDA7
       LDY #$C0		;apply CTRL modifier
LFDA7  LDA $0215
       AND #$7F
       CMP #$20
       BEQ LFDB7	;no modifier for spacebar
       STY $0213
       CLC
       ADC $0213	;apply key modifier
LFDB7  STA $0213
	   PLA			;restore Y & X
	   TAY
       PLA
       TAX
       LDA $0213	;reload key value
       RTS			;exit with current keypress
       
                	;entry if no capslock
LFDC2  BNE LFD56	;branch if left shift
       LDY #$20		;set uppercase to lowercase value "A" + $20 = "a"
       BNE LFDA7	;branch always

SFDC8  LDY #$08		;convert bit set to index (0-7)
LFDCA  DEY
       ASL A
       BCC LFDCA
       RTS

       ;keyboard key lookup table 7x7	(row 0 contains mostly modifier keys, no lookup)
LFDCF  .BYTE $D0,$BB,'/ ZAQ'				;row 1
       .BYTE ',MNBVCX'						;row 2
       .BYTE 'KJHGFDS'						;row 3
       .BYTE 'IUYTREW'						;row 4
       .BYTE $00,$00,$0D,$0A,'OL.'			;row 5
       .BYTE $00,$FF,$2D,$BA,$30,$B9,$B8	;row 6
       .BYTE $B7,$B6,$B5,$B4,$B3,$B2,$B1	;row 7


;page 6	 $FE00	 65V monitor for C1
;$FB = load flag 0=input from keyboard
;$FC = current value
;$FD = not written but temporarily hex value copied to screen between addr & value
;$FE = current address low
;$FF = current address high
MONITOR
LFE00  LDX #$28
       TXS
       CLD
       NOP
       NOP
       NOP
       NOP
       NOP
       NOP
       NOP
       NOP
       LDX #$D4	;end page of screen clear
       LDA #$D0	;start page of screen clear
       STA $FF
       LDA #$00
       STA $FE
       STA $FB
       TAY
       LDA #$20
LFE1B  STA ($FE),Y	;erase screen
       INY
       BNE LFE1B
       INC $FF
       CPX $FF
       BNE LFE1B	;loop until done
       STY $FF		;set initial address to 0000
       BEQ LFE43
LFE2A  JSR SFEE9	;get key from input (KB or ACIA)
       CMP #'/
       BEQ LFE4F
       CMP #'G
       BEQ LFE4C
       CMP #'L
       BEQ LFE7C	;set load flag
       JSR SFE93
       BMI LFE2A
       LDX #$02
       JSR SFEDA
LFE43  LDA ($FE),Y
       STA $FC
       JSR SFEAC
       BNE LFE2A
LFE4C  JMP ($00FE)	;monitor "GO" command
       
LFE4F  JSR SFEE9
       CMP #'.
       BEQ LFE2A
       CMP #$0D
       BNE LFE69
       INC $FE
       BNE LFE60
       INC $FF
LFE60  LDY #$00
       LDA ($FE),Y	;read value from memory
       STA $FC
       JMP LFE77
       
LFE69  JSR SFE93
       BMI LFE4F
       LDX #$00
       JSR SFEDA
       LDA $FC
       STA ($FE),Y
LFE77  JSR SFEAC
       BNE LFE4F
LFE7C  STA $FB		;(load flag for monitor)
       BEQ LFE4F
LFE80  LDA $F000	;wait for character from ACIA
       LSR A
       BCC LFE80
       LDA $F001	;input from ACIA
       NOP
       NOP
       NOP
       AND #$7F	;mask hi bit
       RTS
       
       .BYTE $00, $00, $00, $00 

SFE93  CMP #$30		;convert HEX to binary nibble lo or $80 on err
       BMI LFEA9
       CMP #$3A		;':
       BMI LFEA6
       CMP #$41		;'A
       BMI LFEA9
       CMP #$47		;'G
       BPL LFEA9
       SEC
       SBC #$07
LFEA6  AND #$0F
       RTS
       
LFEA9  LDA #$80
       RTS
       
SFEAC  LDX #$03		;display hex address to screen
       LDY #$00     ;y=starting position offset on screen
LFEB0  LDA $FC,X    ;write hex byte to screen * 4 in reverse order
       LSR A
       LSR A
       LSR A
       LSR A
       JSR SFECA	;lo nibble hex out on screen (hi part 1st)
       LDA $FC,X
       JSR SFECA	;lo nibble hex out on screen
       DEX
       BPL LFEB0
       LDA #$20		; (blank out 2 characters after address)
       STA $D0CA    
       STA $D0CB    
       RTS          
                    
SFECA  AND #$0F		;display low nibble of A as hex in next position on screen
       ORA #$30
       CMP #$3A
       BMI LFED5
       CLC
       ADC #$07
LFED5  STA $D0C6,Y	;address of screen memory for display
       INY
       RTS
       
SFEDA  LDY #$04		;shift in low nibble as address on screen
       ASL A
       ASL A
       ASL A
       ASL A		;shift nibble down
LFEE0  ROL A
       ROL $FC,X	;shift in bits of current address
       ROL $FD,X
       DEY
       BNE LFEE0	;*4 bits
       RTS
       
SFEE9  LDA $FB		;flag load from keyboard or serial
       BNE LFE80
       JMP LFD00
;BASIC I/O init table       
INITTBL
       .WORD SFFBA ;$FFBA
       .WORD LFF69 ;$FF69
       .WORD LFF9B ;$FF9B
       .WORD LFF8B ;$FF8B
       .WORD LFF96 ;$FF96
       .BYTE $30, $01 ; IRQ when mapped to $FFxx
       .BYTE $00, $FE ; RESET when mapped to $FFxx
       .BYTE $C0, $01 ; NMI when mapped to $FFxx

;page 7	 $FF00 ROM for C1 'D/C/W/M ?'
RESET_HANDLER
LFF00  CLD
       LDX #$28
       TXS
       LDY #$0A
LFF06  LDA INITTBL-1,Y ;$FEEF,Y
       STA $0217,Y		;initialize BASIC I/O vectors $0218-$0220
       DEY
       BNE LFF06
.IFN ORIGINAL <
       JSR SFCA6	;reset ACIA
>
       STY $0212	;ctrl-c check flag
       STY $0203	;load flag $FF = input from serial
       STY $0205	;save flag $0 = NOT save mode
       STY $0206	;delay for CRT routine
       LDA LFFE0
       STA $0200	;start column for basic screen print
       LDA #$20
LFF26  STA $D300,Y	;erase 1K screen
       STA $D200,Y
       STA $D100,Y
       STA $D000,Y
       INY
       BNE LFF26
.IFE ORIGINAL <
	   JSR SFCA6	;reset ACIA
>
LFF35  LDA LFF5F,Y	;print D/C/W/M ?
       BEQ LFF40
       JSR $BF2D
       INY
       BNE LFF35
LFF40  JSR SFFBA
       CMP #'M
       BNE LFF4A
       JMP LFE00	;jump to monitor
       
LFF4A  CMP #'W
       BNE LFF51
       JMP $0000	;jump to warm start
       
LFF51  CMP #'C
       BNE LFF58
       JMP $BD11	;jump to BASIC cold start
       
LFF58  CMP #'D
       BNE RESET_HANDLER
       JMP LFC00	;jump to disk boot
       
LFF5F  .BYTE 'D/C/W/M ?',0
LFF69  JSR $BF2D	;BASIC screen print
       PHA
       LDA $0205	;save flag $0 = NOT save mode
       BEQ LFF94
       PLA
       JSR LFCB1	;output to ACIA
       CMP #$0D	;test for <CR>
       BNE LFF95
       PHA
       TXA
       PHA
       LDX #$0A	;write 10 NULs
       LDA #$00
LFF81  JSR LFCB1	;output to ACIA
       DEX
       BNE LFF81
       PLA
       TAX
       PLA
       RTS
       
LFF8B  PHA
       DEC $0203	;load flag $FF = input from serial
       LDA #$00
LFF91  STA $0205	;save flag $0 = NOT save mode
LFF94  PLA
LFF95  RTS
       
LFF96  PHA
       LDA #$01
       BNE LFF91
LFF9B  LDA $0212	;test CTRL-C check disabled?
       BNE LFFB9
       LDA #$FE
       STA $DF00	;sel row 0
       BIT $DF00	;test for CTRL key pressed
       BVS LFFB9	;not pressed, branch
       LDA #$FB
       STA $DF00	;sel row 2
       BIT $DF00	;test for 'C' key?
       BVS LFFB9	;not pressed, branch
       LDA #$03
       JMP $A636
       
LFFB9  RTS
       
SFFBA  BIT $0203	;test input from serial?
       BPL LFFD8	;no, branch
LFFBF  LDA #$FD
       STA $DF00	;sel row 1
       LDA #$10
       BIT $DF00	;test for space-bar
       BEQ LFFD5
       LDA $F000	;wait for ACIA char
       LSR A
       BCC LFFBF
       LDA $F001	;load from ACIA 
       RTS
       
LFFD5  INC $0203	;disable load from serial flag
LFFD8  JMP LFD00	;jump to keyboard scan
       
       .BYTE $FF, $FF, $FF, $FF, $FF

LFFE0  .BYTE $65, $17, $00	;cursor start @ $65, line len-1 $17, 0 = 1K video flag
       
       .BYTE $00, $03  ;default BASIC workspace lower bounds
	   .BYTE $FF, $9F  ;default BASIC workspace upper bounds
	   .BYTE $00, $03  ;variable workspace lower bounds
	   .BYTE $FF, $9F  ;variable workspace upper bounds
   
LFFEB  JMP ($0218)	;input vector
LFFEE  JMP ($021A)	;output vector
LFFF1  JMP ($021C)	;control-C check vector
LFFF4  JMP ($021E)	;load vector
LFFF7  JMP ($0220)	;save vector
       .BYTE $30, $01	;NMI
       .WORD LFF00		;RESET
       .BYTE $C0, $01 	;IRQ

