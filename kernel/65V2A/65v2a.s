; OSI 65V2A video PROM monitor for OSI540 with ASCII keyboard & BASIC-In-ROM
;
; Cleaned up by Ivo van Poorten, May 2024
; Assemble with: mads -o:output.rom 65v2a.s
;
; $203 - load flag $01 = load from ACIA
; $205 - save flag $0 = NOT save mode
; $212 - disable CTRL-C check
;
; Memory map:
;
; $fe00     Monitor (not in this source)
; $ff00     This boot code
;

    opt h-      ; disable Atari header

CR  = $0d

NMI = $0130
IRQ = $01c0

DISABLE = 0
ENABLE  = 1

FLAG_LOAD         = $0203
FLAG_SAVE         = $0205
FLAG_IGNORE_CTRLC = $0212


BASIC_CHECK_CTRLC = $a633
BASIC_COLDSTART   = $bd11
BASIC_WRITE_ACIA  = $bf15
BASIC_RESET_ACIA  = $bf22        ; Reset ACIA to 8N2, div16
BASIC_CHROUT      = $bf2d

SCREEN = $d000

ACIA_CONTROL = $fc00
ACIA_DATA    = $fc01

PROM_MONITOR = $fe00

    org $ff00

RESET:
    cld
    ldx #$28
    txs

    jsr BASIC_RESET_ACIA

    ldy #DISABLE
    sty FLAG_IGNORE_CTRLC
    sty FLAG_LOAD
    sty FLAG_SAVE

    sty $0206
    lda settings    ; #$40
    sta $0200
    lda #$20        ; clear 2k screen
    sta $0201
    sta $020f

clear_screen:
    sta SCREEN+7*256,y
    sta SCREEN+6*256,y
    sta SCREEN+5*256,y
    sta SCREEN+4*256,y
    sta SCREEN+3*256,y
    sta SCREEN+2*256,y
    sta SCREEN+1*256,y
    sta SCREEN,y
    iny
    bne clear_screen

print_cwm_message:
    lda cwm_message,y
    beq end_of_message

    jsr BASIC_CHROUT

    iny
    bne print_cwm_message

end_of_message:

    jsr character_input

    cmp #'M'
    bne no_monitor

    jmp PROM_MONITOR

no_monitor:
    cmp #'W'
    bne no_warmboot

    jmp $0000   ;warmstart location

no_warmboot:
    cmp #'C'
    bne RESET

    lda #0
    tax
    tay
    jmp BASIC_COLDSTART

cwm_message
    .byte 'C/W/M?',0

; ----------------------------------------------------------------------------

character_output:
    jsr BASIC_CHROUT

    pha

    lda FLAG_SAVE
    beq exit_pla_rts

    pla

    jsr BASIC_WRITE_ACIA

    cmp #CR
    bne exit_rts   ;[during save, upon detection of <cr> output 10 nuls]

    pha
    txa
    pha

    ldx #10
    lda #0

write_zeroes:
    jsr BASIC_WRITE_ACIA

    dex
    bne write_zeroes

    pla
    tax
    pla
    rts

; ----------------------------------------------------------------------------

load_enable:
    pha        ;[load routine enable entry]
    lda #ENABLE
    sta FLAG_LOAD
    lda #DISABLE

store_save_flag:
    sta FLAG_SAVE

exit_pla_rts:
    pla

exit_rts:
    rts

; ----------------------------------------------------------------------------

save_enable:
    pha        ;[save routine enable entry]
    lda #ENABLE
    bne store_save_flag

; ----------------------------------------------------------------------------

check_ctrlc:
    lda FLAG_IGNORE_CTRLC
    bne ignore_ctrlc

    jmp read_ascii_keyboard_for_ctrlc

ignore_ctrlc:
no_ctrlc:
    jmp $a628  ;goes to rts

; ----------------------------------------------------------------------------

character_input:
    jmp start_input

read_ascii_keyboard_for_ctrlc:
    lda $df01  ;check for character from ascii kb
    bmi no_ctrlc

    jmp BASIC_CHECK_CTRLC       ; tail call

read_acia:
    lda ACIA_DATA
    and #$7f        ; 7-bit ASCII
    rts

; Unreached code

    pla
    tay
    pla
    tax

start_input:
    lda $df01  ;[input char from acia, or kb; stop load if keyboard char detected]
    bmi no_keyboard_key

    pha

    lda #DISABLE
    sta FLAG_LOAD

wait_for_ascii_keyboard_strobe:
    lda $df01
    bpl wait_for_ascii_keyboard_strobe

    pla
    rts

no_keyboard_key:
    lda FLAG_LOAD
    beq character_input  ;no, branch

    lda ACIA_CONTROL
    lsr
    bcc character_input  ;branch, no char from serial yet

    jmp read_acia
    
settings:
    .byte $40      ;initial cursor pos after cr lf
                   ; ($64 for osi440/c1p,$40 for osi540)

    .byte $3f      ;default terminal width/characters per line -1
    .byte $01      ;screen memory size 00 = 1k otherwise 2k

    .byte $00,$03  ;default basic workspace lower bounds
    .byte $ff,$3f  ;default basic workspace upper bounds

    .byte $00,$03  ;variable workspace lower bounds
    .byte $ff,$3f  ;variable workspace upper bounds
    
; JUMP VECTORS

vector_jmp_input:
    jmp character_input

vector_jmp_ouput:
    jmp character_output

vector_jmp_check_ctrlc:
    jmp check_ctrlc

vector_jmp_load:
    jmp load_enable

vector_jmp_save:
    jmp save_enable

    .word NMI
    .word RESET
    .word IRQ

; vim: filetype=asm sw=4 ts=4 et
