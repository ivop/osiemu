
; OSI SERIAL BOOT ROM FOR BASIC IN ROM MACHINES @ $FF00
; Expects 6850 ACIA @$FC00 and S1883/AY-5-1013 UART @FB03+
; note: ROM still works if UART is missing, but with broken BASIC LOAD and SAVE functionality
;
; Adds CTRL+E processing to toggle output to ACIA suppression
; expects 65A serial monitor ROM at $FE00 as well as BASIC ROMS at $A000-$BFFF

;$203 - load flag $01 = from UART/cassette (alternate serial)
;$204 - (temp)
;$205 - save flag $0 = NOT save mode
;$210 - suppress output flag 0 = no pause
;$211 - position of match of <LF>OK<CR> message to console

*=$FF00
RESET_HANDLER
        CLD
        LDX #$28
        TXS
        JSR $BF22   ;init ACIA 8N2/16
        JSR $BEFE   ;Reset UART set to 8N2
        LDY #$00
        TYA
        LDX #$0E
LFF0F   STA $0203,X ;init BASIC flags to 0
        DEX
        BPL LFF0F
LFF15   LDA LFFB7,Y ;send C/W/M? message to console
        BMI LFF20
        JSR $BF15   ;write to ACIA
        INY
        BNE LFF15
LFF20   JSR $BF07   ;wait for input from ACIA mask to 7bits
        CMP #$4D    ;'M
        BNE LFF2A
        JMP $FE40   ;jump to 65A monitor start

LFF2A   CMP #$57    ;'W
        BNE LFF31
        JMP $0000   ;warmstart vector

LFF31   CMP #$43    ;'C
        BNE RESET_HANDLER
        LDA #$00
        TAX
        TAY
        JMP $BD11   ;goto BASIC cold start routine

LFF3C   .BYTE $0A,'O','K',$0D   ;message from BASIC we watch for

LFF40   BEQ RESET_HANDLER
LFF42   PHA         ;[output routine entry point]
        STX $0204   ;store X for later
        LDA $0210   ;test "suppress" flag
        BNE LFF6D
        PLA         ;no suppress, send to output
        JSR $BF15   ;output to ACIA (console)
        PHA
LFF50   LDA $0205   ;test for SAVE mode
        BEQ LFF68   ;nope, branch to return
        PLA
        JSR $BEF3   ;output to UART (SAVE)
        CMP #$0D
        BNE LFF69   ;upon <CR> pad with 10 NULS
        PHA
        LDX #$0A
        LDA #$00
LFF62   JSR $BEF3   ;output to UART
        DEX
        BNE LFF62
LFF68   PLA         ;restore 'A'
LFF69   LDX $0204   ;restore 'X'
LFF6C   RTS

LFF6D   PLA         ;watch for <LF>OK<CR> message to be sent to console
        PHA
        LDX $0211   ;last match position
        CMP LFF3C,X ;the message
        BNE LFF7F
        INX
        CPX #$04
        BNE LFF81
        JSR SFFAE   ;ah-ha we've printed an 'OK' message,toggle "suppress" flag
LFF7F   LDX #$00    ;didn't match, reset to start comparison over
LFF81   STX $0211   ;store match pos for later
        JMP LFF50

LFF87   LDA $FC00   ;[INPUT routine entry point]
        LSR A       ;test ACIA status
        BCC LFFA0   ;branch if no character waiting
        LDA #$00
        STA $0203   ;disable load from UART flag
        LDA $FC01   ;get char from ACIA
        BEQ LFF87   ;loop till not NUL
        AND #$7F    ;mask to 7bits
        CMP #$05    ;was it CTRL-E
        BNE LFF6C   ;no, so return
        JSR SFFAE   ;(toggle output supression flag)
LFFA0   LDA $0203   ;is load from UART flag set?
        BEQ LFF87   ;no? so loop back to wait for ACIA
        LDA $FB05   ;does UART have char?
        LSR A
        BCC LFF87   ;no keep waiting
        JMP $BEEA   ;read UART char, mask to 7bits, RTS

SFFAE   LDA $0210   ;toggle "suppress" flag
        EOR #$FF
        STA $0210
        RTS


LFFB7   .BYTE 'C/W/M?'

LFFBD   LDA $FC00   ;CTRL-C check entry point
        LSR A
        BCC LFFC6   ;is char waiting from ACIA?
        JMP $A633   ;yes, test for CTRL-C

LFFC6   JMP $A628   ;goes to RTS

LFFC9   PHA         ;enable SAVE mode
        LDA #$01
        BNE LFFD6
LFFCE   PHA         ;enable LOAD mode
        LDA #$01
        STA $0203   ;set load flag
        LDA #$00    ;unset save flag
LFFD6   STA $0205   ;(set or unset save flag dep. on entry)
        PLA
        JSR $BEFE
        JMP $A319

LFFE0   .BYTE $64 ; LINE START OFFSET (for video system)
        .BYTE $18 ; LINE LENGTH - 1
        .BYTE $00 ; SCREEN RAM 0=1K, 1=2K
        .BYTE $00,$03  ;default BASIC workspace lower bounds
        .BYTE $FF,$3F  ;default BASIC workspace upper bounds
        .BYTE $00,$03  ;variable workspace lower bounds
        .BYTE $FF,$3F  ;variable workspace upper bounds

LFFEB   JMP LFF87   ; INPUT
LFFEE   JMP LFF42   ; OUTPUT
LFFF1   JMP LFFBD   ; CTRL-C check
LFFF4   JMP LFFCE   ; LOAD
LFFF7   JMP LFFC9   ; SAVE
        .WORD $0130 ;<NMI>
        .WORD $FF00 ;<RESET>
        .WORD $01C0 ;<IRQ>
