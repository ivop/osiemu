; $FE00 block for serial system OSI 65A Serial Monitor
;         Cmds 'R' reset,
;              'P' <address> - dump data at supplied address until keypress
;              'L' <address><data> - read hex data from acia until 'R' encountered
;              'G' Go - set CPU value to the following:
;
;                  Execute address hi,lo @ $012E, $012F
;                  S Stack pointer    @ $012D
;                  K Processor status @ $012C
;                  A @ $012B
;                  X @ $012A
;                  Y @ $0129

*=$FE00
SFE00   LDA $FC00  ;[Get 1 ASCII char from ACIA w/ echo]
        LSR A
        BCC SFE00
        LDA $FC01
        AND #$7F   ;strip off msb
SFE0B   PHA        ;send char out via ACIA
LFE0C   LDA $FC00
        LSR A
        LSR A
        BCC LFE0C
        PLA
        STA $FC01
        RTS
SFE18   JSR SFE00  ;[Get hex nibble from ASCII]
        CMP #$52
        BEQ LFE35  ; R cmd (reset)
        CMP #$30
        BMI SFE18  ; < '0 ? get another
        CMP #$3A
        BMI LFE32  ; < ': ? goto got lower hex
        CMP #$41
        BMI SFE18  ; < 'A ? get another
        CMP #$47
        BPL SFE18  ; >= 'G ? get another
        CLC
        SBC #$06   ;convert to hex val
LFE32   AND #$0F
        RTS        ;return 1 byte hex value
LFE35   LDA #$03   ;'R command
        STA $FC00
        LDA #$B1   ;reset ACIA 8N2/16
        STA $FC00
        CLD
LFE40   SEI
        LDX #$26   ;set stack
        TXS
        LDA #$0D
        JSR SFE0B  ;send <CR>
        LDA #$0A
        JSR SFE0B  ;send <LF>
        JSR SFE00  ;get input with echo
        CMP #$4C
        BEQ LFE77  ; L cmd?
        CMP #$50
        BEQ LFE8D  ; P cmd?
        CMP #$47
        BNE LFE35
        LDX $012D   ; 'G command
        TXS
        LDX $012A   ; read values from storage
        LDY $0129
        LDA $012E   ;ret addr hi
        PHA
        LDA $012F   ;ret addr lo
        PHA
        LDA $012C   ;proc status
        PHA
        LDA $012B
        RTI
LFE77   JSR SFEC7   ; process 'L command (Get 2byte address in $FD,FC)
        LDX #$03
        LDY #$00
LFE7E   JSR SFEB5   ;get hex input, store at $FF
        LDA $FF
        STA ($FC),Y  ;
        INY
        BNE LFE7E
        INC $FD
        CLV
        BVC LFE7E
LFE8D   JSR SFEC7   ; 'P command  -- get address in $FD,FC
        LDY #$00    ;[Write data starting at ($FC) to ACIA as hex + space
LFE92   LDX #$09    ; with lines of 8 bytes, abort with any keystroke]
        LDA #$0D
        JSR SFE0B    ;write <CR><LF>
        LDA #$0A
        JSR SFE0B
LFE9E   DEX
        BEQ LFEAC
        JSR SFEE0    ;write ($FC),Y as hex byte and space
        INY
        BNE LFE9E
        INC $FD
        JMP LFE9E
LFEAC   LDA $FC00    ;is keypress waiting?
        LSR A
        BCS LFE40    ;yup
        NOP
        BCC LFE92    ;nope
SFEB5   JSR SFE18    ;[Read a 2 byte hex digit from acia store $FC,X]
        ASL A        ;read hi byte
        ASL A
        ASL A
        ASL A
        STA $FC,X    ;store in $FC,X  ($FF)
        JSR SFE18    ; read a hex digit from acia
        CLC
        ADC $FC,X
        STA $FC,X
        RTS
SFEC7   LDX #$01     ;[Read 2byte address into $FD,$FC]
        JSR SFEB5    ;read hex into $FD
        DEX
        JSR SFEB5    ;read hex into $FC
        RTS
SFED1   CLC
        ADC #$30
        CMP #$3A
        BCS LFEDC
LFED8   JSR SFE0B
        RTS
LFEDC   ADC #$06
        BCC LFED8
SFEE0   LDA ($FC),Y   ;write byte in ($FC),y to ACIA as HEX + space
        AND #$F0
        LSR A
        LSR A
        LSR A
        LSR A
        JSR SFED1
        LDA ($FC),Y
        AND #$0F
        JSR SFED1
        LDA #$20
        JSR SFE0B
        RTS

        .BYTE $40,$9D
        .WORD $0130 ;<NMI>
        .WORD $FE35 ;<RESET>
        .WORD $01C0 ;<IRQ>
