; ----------------------------------------------------------------------------
;
; Alternative Key Poller
;
; Copyright © 2024 by Ivo van Poorten
;
; Inspired by Synmon and Cegmon poller, but most code is new and heavily
; optimized. Cegmon functionality in Synmon space.
;
; ----------------------------------------------------------------------------

; Page 2 Variables

cur_char  = $0213
wait_cntr = $0214
tmpval    = $0215
last_char = $0216
modifiers = $02ff   ; should be free to use

; Hardware Registers

KEYBD = $df00

; ----------------------------------------------------------------------------

    opt h-      ; no XEX headers
    opt f+      ; single block, fills with $ff

; ----------------------------------------------------------------------------

    org $fc00

    ins 'page4-fc00-c1-diskboot.dat'

; ----------------------------------------------------------------------------

    org $fd00

GETKEY:
    txa
    pha
    tya
    pha

scan_again:
    lda #$01                ; Row mask
    ldy #0                  ; Row counter
    sty modifiers
    dey

@:
    eor #$ff
    sta KEYBD
    eor #$ff

    pha
    lda KEYBD
    eor #$FF
    tax                     ; Key pressed in X
    pla

    cpx #0
    bne key_pressed

next:
    iny                     ; Increase row counter
    asl
    bne @-
    beq no_key_pressed

; ----------------------------------------------------------------------------

key_pressed:
    lsr                     ; check if row 0 ($01)
    bcc normal_key_pressed

    rol                     ; correct back to $01
    stx modifiers           ; save modifiers

    cpx #$21                ; ESC+CAPS
    bne next

; all ESC combos: cpx #$20 ! bcc next ! cpx #$28 ! bcs next ; 4 bytes bigger

    lda #$1b
    bne lookup_done

normal_key_pressed:
    lda matrix_index_tab,y
    sta tmpval              ; store "corrected" row*7 

    txa                     ; A=column
    ldy #7                  ; convert to index 0-7
@:
    dey
    asl
    bcc @-

    bcs lookup_key          ; branch always

; ----------------------------------------------------------------------------

no_key_pressed:
    sta last_char

new_char:
    sta cur_char

    lda #2
    sta wait_cntr
    bne scan_again          ; branch always

; ----------------------------------------------------------------------------

lookup_key:                 ; we _always_ enter lookup_key with C=1 
    tya                     ; A=column
    adc tmpval              ; add saved row*7 + 1 (carry)
    tay

    lda keyboard_matrix-1,y ; retrieve ASCII from table (-1 compensates C)

lookup_done:
    cmp cur_char
    bne new_char

    dec wait_cntr
    beq debounce_done

    ldy #$10

delay_loop:
    ldx #$40
@:
    dex
    bne @-

    dey
    bne delay_loop

    beq scan_again

debounce_done:
    ldx #$64                ; long delay on first character
    cmp last_char
    bne set_wait_cntr

    ldx #$0f                ; shorter repeat rate

set_wait_cntr:
    stx wait_cntr
    sta last_char
    sta tmpval

; Apply key modifiers --------------------------------------------------------

    lda modifiers
    tay                     ; save modifiers in Y

    and #7
    tax
    beq no_shift_or_caps

    lda tmpval
    cmp #$5f                ; RUB, case modifiers have no effect
    beq getkey_done

    cmp #$61                ; >= 0x61 always toupper() SHIFT+CAPS
    bcc @+

    eor #$20
    bne case_adjust_done

@:
    cpx #1                  ; just CAPS?
    beq case_adjust_done    ; for < 0x60, CAPS has no effect

    cmp #$30                ; special case, add #$10
    bne @+

    clc
    adc #$10
    bne case_adjust_done

@:
    cmp #$21                ; don't adjust space (0x20) and below
    bcc case_adjust_done

    eor #$10                ; all other keys with lshift or rshift

case_adjust_done:
    sta tmpval

no_shift_or_caps:
    tya                     ; restore saved modifiers
    and #$40                ; control key?
    beq getkey_done

    lda tmpval
    and #$1f
    sta tmpval

getkey_done:
    pla
    tay
    pla
    tax
    lda tmpval
    rts

; ----------------------------------------------------------------------------

keyboard_matrix:
    dta 'p;/ zaq'
    dta ',mnbvcx'
    dta 'kjhgfds'
    dta 'iuytrew'
;    dta $00,$00,$0D,$0A,'ol.'      ; removed unused columns
    dta $0D,$0A,'ol.'
;    dta $00,$5F,'-:098'
    dta $5F,'-:098'
    dta '7654321'

matrix_index_tab:
;    dta 0, 7, 14, 21, 28, 35, 42
    dta 0, 7, 14, 21, 26, 32, 39    ; corrected indeces for removed unused keys

    .print "space left: ", $fe00-*

; ----------------------------------------------------------------------------

    org $fe00

    ins 'page6-fe00-c1-monitor.dat'

    org $ff00

    ins 'page7-ff00-c1-dcwm.dat'

