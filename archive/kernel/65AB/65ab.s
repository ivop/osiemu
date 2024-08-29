; OSI Serial Boot rom for BASIC in ROM machines @ $ff00
; Expects 6850 ACIA @ $fc00 and S1883/AY-5-1013 UART @ fb03+
; ROM still works if uart is missing, but with broken basic load and save
; functionality
;
; Adds ctrl+e processing to toggle output to acia suppression
; Expects 65A serial monitor rom at $fe00 as well as BASIC roms at $a000-$bfff
;
;$203 - load flag 1 = from UART/cassette (alternate serial)
;$204 - (temp)
;$205 - save flag 0 = not save mode
;$210 - suppress output flag 0 = no pause
;$211 - position of match of <lf>OK<cr> message to console
;
; This ROM does NOT work without BASIC. It uses BASIC routines for ACIA
; and UART I/O
;
; Cleanup and conversion to Mad-Assembler by Ivo van Poorten, August 2024

; ----------------------------------------------------------------------------

    opt h-

BASIC_COLDSTART  = $bd11    ; Cold start entry point

BASIC_ACIA_INIT  = $bf22    ; Master reset 6850 and set to 8N2 div.16
BASIC_ACIA_WRITE = $bf15    ; Send value in A
BASIC_ACIA_READ  = $bf07    ; Receive value & 0x7f into A

BASIC_UART_INIT  = $befe    ; Reset S1883 to 8N2
BASIC_UART_WRITE = $bef3    ; Send value in A
BASIC_UART_READ  = $beea    ; Receive value & 0x7f into A

; ----------------------------------------------------------------------------

BASIC_LOAD_FLAG      = $0203
BASIC_TEMP           = $0204
BASIC_SAVE_FLAG      = $0205
BASIC_REPEAT_RATE    = $0206
BASIC_SCROLL_ROUTINE = $0207    ; $0207-$020e Copied here by BASIC
BASIC_UNUSED         = $020f    ; $020f-$0211 Unused by BASIC
BASIC_CTRL_C_FLAG    = $0212

SUPPRESS_FLAG  = $0210
LAST_MATCH_POS = $0211

; ----------------------------------------------------------------------------

WARMSTART_VECTOR = $0000
MONITOR_65A      = $fe40        ; Hardcoded address, must match 65a.rom

; ----------------------------------------------------------------------------

ACIA_CONTROL = $fc00
ACIA_STATUS  = $fc00
ACIA_TDR     = $fc01
ACIA_RDR     = $fc01

CTRL_E = 5
CR     = 13

; ----------------------------------------------------------------------------

    org $ff00

reset_handler:
    cld
    ldx #$28
    txs

    jsr BASIC_ACIA_INIT
    jsr BASIC_UART_INIT

    ldy #$00
    tya
    ldx #$0e

clear_basic_vars:
    sta BASIC_LOAD_FLAG,x
    dex
    bpl clear_basic_vars

print_cwm:
    lda cwm_message,y
    bmi cwm_message_done

    jsr BASIC_ACIA_WRITE

    iny
    bne print_cwm

cwm_message_done:
    jsr BASIC_ACIA_READ
    cmp #'M'
    bne @+

    jmp MONITOR_65A

@:
    cmp #'W'
    bne @+

    jmp WARMSTART_VECTOR

@:
    cmp #'C'
    bne reset_handler

    lda #0
    tax
    tay
    jmp BASIC_COLDSTART

; ----------------------------------------------------------------------------

message_lf_OK_cr:
    .byte $0a,'O','K',$0d   ;message from basic we watch for

; ----------------------------------------------------------------------------

; Not sure why this is here, but $ff40 look suspiciously similar to a
; fixed entry point.

    .error * != $ff40

    beq reset_handler

; ----------------------------------------------------------------------------

entry_output:
    pha
    stx BASIC_TEMP

    lda SUPPRESS_FLAG
    bne watch_suppressed_output

    pla                     ; no suppress, send to output

    jsr BASIC_ACIA_WRITE

    pha

continue_entry_output:
    lda BASIC_SAVE_FLAG
    beq save_flag_not_set

    pla

    jsr BASIC_UART_WRITE

    cmp #CR
    bne no_CR_encountered

    pha

    ldx #$0a
    lda #$00

@:
    jsr BASIC_UART_WRITE
    dex
    bne @-

save_flag_not_set:
    pla

no_CR_encountered:
    ldx BASIC_TEMP          ; restore previous X

return_io_done:
    rts

; ----------------------------------------------------------------------------

watch_suppressed_output:
    pla
    pha

    ldx LAST_MATCH_POS
    cmp message_lf_OK_cr,x
    bne no_match_restart_matching

    inx
    cpx #$04
    bne done_matching

    jsr toggle_suppress_flag        ; turn back on after OK from BASIC

no_match_restart_matching:
    ldx #0

done_matching:
    stx LAST_MATCH_POS

    jmp continue_entry_output

; ----------------------------------------------------------------------------

entry_input:

no_valid_input:
    lda ACIA_STATUS         ; test bit 1, RDR full
    lsr
    bcc no_character_waiting

    lda #0                  ; disable
    sta BASIC_LOAD_FLAG

    lda ACIA_RDR
    beq no_valid_input

    and #$7f
    cmp #CTRL_E
    bne return_io_done

    jsr toggle_suppress_flag

no_character_waiting:
    lda BASIC_LOAD_FLAG
    beq entry_input   ;no? so loop back to wait for acia

    lda $fb05   ;does uart have char?
    lsr
    bcc entry_input   ;no keep waiting

    jmp BASIC_UART_READ

toggle_suppress_flag:
    lda SUPPRESS_FLAG
    eor #$ff
    sta SUPPRESS_FLAG

    rts

; ----------------------------------------------------------------------------

cwm_message:
    .byte 'C/W/M?'

; ----------------------------------------------------------------------------

entry_check_ctrl_c:
    lda ACIA_STATUS
    lsr
    bcc lffc6   ;is char waiting from acia?
    jmp $a633   ;yes, test for ctrl-c

lffc6:
    jmp $a628   ;goes to rts

; ----------------------------------------------------------------------------

entry_save:
    pha

    lda #1                  ; enable
    bne store_save_flag

entry_load:
    pha

    lda #1                  ; enable
    sta BASIC_LOAD_FLAG

    lda #0                  ; disable

    ; [[fallthrough]]

store_save_flag:
    sta BASIC_SAVE_FLAG

    pla

    jsr BASIC_UART_INIT

    jmp $a319

; ----------------------------------------------------------------------------

; Settings MUST start at $ffe0

    .error * != $ffe0

; 0xffe0
    .byte $64 ; line start offset (for video system)
    .byte $18 ; line length - 1
    .byte $00 ; screen ram 0=1k, 1=2k
    .byte $00,$03  ;default basic workspace lower bounds
    .byte $ff,$3f  ;default basic workspace upper bounds
    .byte $00,$03  ;variable workspace lower bounds
    .byte $ff,$3f  ;variable workspace upper bounds

; ----------------------------------------------------------------------------

; Vectors MUST start at $ffeb

    .error * != $ffeb

    jmp entry_input
    jmp entry_output
    jmp entry_check_ctrl_c
    jmp entry_load
    jmp entry_save

; CPU Vectors MUST start at $fffa

    .error * != $fffa

    .word $0130             ; NMI
    .word reset_handler
    .word $01c0             ; IRQ

