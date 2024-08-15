; ----------------------------------------------------------------------------
;
; Single ROM for 440 board 65V Monitor (ASCII keyboard)
; Assemble with Mad-Assembler
; Cleanup by Ivo van Poorten, August 2024
;
; ----------------------------------------------------------------------------

    opt h-              ; No Atari XEX header

; ----------------------------------------------------------------------------

CR = 13

load_flag = $fb
hexbytes  = $fc
ptr       = $fe

    org $ff00

SCREEN  = $d000
ASCIIKB = $df01

ACIA_CONTROL = $fc00
ACIA_STATUS  = $fc00
ACIA_TDR     = $fc01
ACIA_RDR     = $fc01

; ----------------------------------------------------------------------------

reset:
    ldx #$28
    txs                      ;set stack ptr, clear decimal
    cld

    lda #$03
    sta ACIA_CONTROL
    lda #$b1     ;set acia to 8n2
    sta ACIA_CONTROL

    lda #$00
    sta ptr
    sta ptr+1

    sta $fb                 ; turn off serial input (use keyboard)

    tay
    lda #' '
@:
    .rept 4
        sta SCREEN+#*256,y
    .endr
    iny
    bne @-

    beq start               ; branch always

; ----------------------------------------------------------------------------

main_loop:
    jsr get_key
    cmp #'/'
    beq handle_slash

    cmp #'G'
    beq handle_goto

    cmp #'L'
    beq handle_load

    jsr handle_hex_input

    bmi main_loop

    ldx #$02                ; hexbytes index
    jsr store_nibble

start:
    lda (ptr),y
    sta hexbytes

    jsr display_hexbytes    ; display monitor address and data
    bne main_loop           ; branch always

handle_goto:
    jmp (ptr)
    
; ----------------------------------------------------------------------------

handle_slash:
    jsr get_key
    cmp #'.'
    beq main_loop

    cmp #CR
    bne do_hex_input

    inw ptr                 ; CR increments monitor address

    ldy #$00
    lda (ptr),y             ; read data from new location
    sta $fc
    jmp display_and_continue
    
do_hex_input:
    jsr handle_hex_input
    bmi handle_slash

    ldx #$00                ; hexbytes index
    jsr store_nibble

    lda hexbytes
    sta (ptr),y

display_and_continue:
    jsr display_hexbytes
    bne handle_slash        ; branch always

; ----------------------------------------------------------------------------

handle_load:
    sta $fb

acia_input:
    beq handle_slash

@:
    lda ACIA_STATUS
    lsr
    bcc @-                  ; wait for received byte

    lda ACIA_RDR
:3  nop
    and #$7f
    rts

; ----------------------------------------------------------------------------

:4  brk

; ----------------------------------------------------------------------------

; bmi == less than
; bpl == greater or equal

handle_hex_input:
    cmp #'0'
    bmi invalid_input

    cmp #'9'+1
    bmi valid_input

    cmp #'A'
    bmi invalid_input

    cmp #'G'
    bpl invalid_input

    sec
    sbc #$07                ; adjust A-F

valid_input:
    and #$0f
    rts
    
invalid_input:
    lda #$80
    rts
    
; ----------------------------------------------------------------------------

display_hexbytes:
    ldx #$03      ;hex output 4 bytes @ $ff to $fc
    ldy #$00        ; screen index

lffb0
    lda hexbytes,x
:4  lsr
    jsr display_nibble

    lda hexbytes,x
    jsr display_nibble

    dex
    bpl lffb0

    lda #' '
    sta SCREEN+6*32+10
    sta SCREEN+6*32+11
    rts

; ----------------------------------------------------------------------------

display_nibble:
    and #$0f
    ora #'0'
    cmp #'9'+1
    bmi @+

    clc
    adc #$07        ; Adjust A-F

@:
    sta SCREEN+6*32+6,y
    iny
    rts
    
; ----------------------------------------------------------------------------

store_nibble:
    ldy #$04
:4  asl

@:
    rol
    rol hexbytes,x
    rol hexbytes+1,x
    dey
    bne @-
    rts
    
; ----------------------------------------------------------------------------

get_key:
    lda $fb         ; Controls ASCII keyboard or serial
    bne acia_input    

    .error * != $ffed   ; Entry point mismatch

LFFED:              ; Character Input entry point

@:
    lda ASCIIKB
    bmi @-          ; Wait for bit 7 to go low, indicating valid character

    pha             ; Save key on stack

@:
    lda ASCIIKB     ; Wait for bit 7 to go high again
    bpl @-

    pla             ; Restore key
    rts

    .word $0130     ; NMI
    .word reset     ; RESET
    .word $01c0     ; IRQ
