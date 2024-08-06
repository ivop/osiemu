; Key Poller, Model 600 keyboard, by Ivo van Poorten, August 2024
; Based on Synmon and Cegmon, but less code and heavily optimized.
; Test with syn600, replace $fd00 and put extra page in front to create
; a $500 bytes ROM.

cur_char = $0213
wait_cntr = $0214
tmpval = $0215
last_char = $0216

modifiers = $0100   ; BASIC area that is used to build numerals before printing
                    ; After some testing, this seems safe.

KEYBD = $df00

    opt h-      ; no XEX headers
    opt f+      ; single block, fills with $ff

; ----------------------------------------------------------------------------

; extra bank in front of fc00-ffff

    org $fb00

begin_extra:

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

end_extra:

    .print "EXTRA size: ", end_extra-begin_extra

; ----------------------------------------------------------------------------

    org $fc00

    ins 'page4-fc00-c1-diskboot.dat'

; ----------------------------------------------------------------------------

    org $fd00

GETKEY:
    txa         ; Push X and Y to the stack
    pha
    tya
    pha

scan_again:
    lda #$01
    ldy #0
    sty modifiers
    dey

@:
    eor #$ff
    sta KEYBD
    eor #$ff

    pha
    lda KEYBD
    eor #$FF
    tax
    pla

    cpx #0
    bne key_pressed

next:
    iny
    asl
    bne @-
    beq no_key_pressed

key_pressed:
    lsr                             ; check row 0 ($01)
    bcc normal_character_pressed

    rol                             ; correct back to $01
    stx modifiers                   ; save modifiers

    cpx #$21                        ; ESC+CAPS
    bne next

; all ESC combos: cpx #$20 ! bcc next ! cpx #$28 ! bcs next ; 4 bytes bigger

    lda #$1b
    bne lookup_done

normal_character_pressed:
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
    ldx #$64            ; long delay on first character
    cmp last_char
    bne set_wait_cntr

    ldx #$0f            ; shorter repeat rate

set_wait_cntr:
    stx wait_cntr
    sta last_char
    sta tmpval

foo:

; apply key modifiers

    lda modifiers
    tay                 ; save modifiers in Y

    and #7
    tax
    beq no_shift_or_caps

    lda tmpval
    cmp #$5f            ; RUB
    beq getkey_done

    cmp #$61
    bcc @+

    eor #$20
    bne adjust_done

@:
    cpx #1              ; just CAPS?
    beq adjust_done

    cmp #$31
    bcc @+

    eor #$10
    bne adjust_done

@:
    cmp #$30
    bne @+

    clc
    adc #$10
    bne adjust_done

@:
    cmp #$2c
    bcc adjust_done

    eor #$10

adjust_done:
    sta tmpval

no_shift_or_caps:
    tya                 ; restore saved modifiers
    and #$40            ; control key?
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

    .print "space left: ", $fe00-*

; ----------------------------------------------------------------------------

    org $fe00

    ins 'page6-fe00-c1-monitor.dat'

    org $ff00

    ins 'page7-ff00-c1-dcwm.dat'

