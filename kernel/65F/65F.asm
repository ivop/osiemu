;Reconstructed 65F ROM for early OSI 400 & 440/500 systems.
;Supports Disk and either 65V or 65A monitor ROM at $FE00.
;Thanks to bxdanny for the partial assembly dump, I was able to
;fill in the missing pieces with code from other ROMs. -Mark
;

DISK=$C000

*=$FF00
SFF00   LDY #$00     ;[init disk controller, boot track 0 @ $2200]
        STY DISK+1   ;select DDRA.
        STY DISK     ;0's in DDRA indicate input.
        LDX #$04
        STX DISK+1   ;select PORTA
        STY DISK+3   ;select DDRB
        DEY
        STY DISK+2   ;1's in DDRB indicate output.
        STX DISK+3   ;select PORT B
        STY DISK+2   ;make all outputs high
        LDA #$FB
        JSR SFF89    ;step to track +1
        LDX #$18
        JSR SFF74    ;delay
LFF24   LDA #$02
        BIT DISK
        BEQ LFF33    ;track 0 enabled?
        LDA #$FF     ;step down to 0
        JSR SFF89
        JMP LFF24
LFF33   LDX #$7F
        STX DISK+2   ;load head
        JSR SFF74    ;delay
LFF3B   LDA DISK
        BMI LFF3B    ;wait for index start
LFF40   LDA DISK
        BPL LFF40    ;wait for index end
        LDA #$03
        STA DISK+$10 ;reset disk ACIA
        LDA #$58
        STA DISK+$10 ;/1 RTS hi, no irq
        JSR SFF7F
        STA $01      ;read start addr hi
        JSR SFF7F
        STA $00      ;read start addr lo
        JSR SFF7F
        STA $02      ;read num pages
        LDY #$00
LFF60   JSR SFF7F
        STA ($00),Y  ;read the specified num pages
        INY
        BNE LFF60
        INC $01
        DEC $02
        BNE LFF60
        LDA #$FF
        STA DISK+2   ;disable drive
        RTS
SFF74   LDY #$F8     ;loop for delay
LFF76   DEY
        BNE LFF76
        EOR $FF,X
        DEX
        BNE SFF74
        RTS
SFF7F   LDA DISK+$10 ;read byte from disk
        LSR A
        BCC SFF7F
        LDA DISK+$11
SFF88   RTS
SFF89   STA DISK+2   ;($FB=step direction up )
        JSR SFF88
        AND #$F7     ;step on
        STA DISK+2
        JSR SFF88
        ORA #$08     ;step off
        STA DISK+2
        LDX #$18
        JSR SFF74    ;delay
        BEQ SFF88    ;??? (not sure if this is correct original could be JMP SFF88)
        BRK
        .BYTE 'D/M?'

RESET  ;FFA8
		CLD
        LDX #$D4     ;max vid page address (hi) (1K/OSI440 video; use D8 for OSI540)
        LDA #$D0     ;start vid address (hi)
        STA $01
        LDY #$00
        STY $00
        LDA #$20
LFFB5   STA ($00),Y  ;erase video memory (1K)
        INY
        BNE LFFB5
        INC $01
        CPX $01
        BNE LFFB5
        LDA #$03
        STA $FC00    ;reset ACIA
        LDA #$B1
        STA $FC00    ;8N2 /16 RTSIRQ
LFFCA   LDA $FFA4,Y  ;"D/M?" prompt
        BMI LFFDD    ;end of prompt?
        STA $D0C6,Y  ;write to video memory
        LDX $FE01    ;test 65A (0) vs 65V ($28) monitor
        BNE LFFDA
        JSR $FE0B    ;65A send char out via ACIA
LFFDA   INY
        BNE LFFCA
LFFDD   LDA $FE01    ;test 65A (0) vs 65V ($28) monitor
        BNE LFFE7
        JSR $FE00    ;65A GetChar with echo
        BCS LFFEA
LFFE7   JSR $FEED    ;65V GetChar from ASCII KB/etc.
LFFEA   CMP #$44     ;'D
        BNE LFFF7
        JSR SFF00    ;call disk load routine subroutine
        JMP $2200    ;execute loaded disk track (hopefully $2200)
LFFF4   JSR SFF00
LFFF7   JMP ($FEFC)  ;(storage for entry point to monitor)
        .WORD $0130  ;NMI vector
		.WORD RESET  ;reset vector
		.WORD $01C0  ;IRQ vector