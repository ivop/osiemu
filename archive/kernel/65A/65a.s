; ----------------------------------------------------------------------------
;
; $fe00 block for serial system OSI 65A serial monitor
;
;   cmds 'r' reset,
;        'p' <address> - dump data at supplied address until keypress
;        'l' <address><data> - read hex data from acia until 'r' encountered
;        'g' go - set cpu value to the following:
;
;               execute address hi,lo @ $012e, $012f
;                  s stack pointer    @ $012d
;                  k processor status @ $012c
;                                   a @ $012b
;                                   x @ $012a
;                                   y @ $0129
;
; Cleanup/readability by Ivo van Poorten, August 2024
; Assemble with Mad-Assembler
; Works without BASIC as it accesses ACIA @ $fc00 directly
;
; ----------------------------------------------------------------------------

    opt h-          ; disable Atari XEX header

; ----------------------------------------------------------------------------

    org $fe00

LF = 10
CR = 13

ptr = $fc

ACIA_CONTROL = $fc00
ACIA_STATUS  = $fc00
ACIA_TDR     = $fc01
ACIA_RDR     = $fc01

; ----------------------------------------------------------------------------

acia_recv_byte_with_echo:
@:
    lda ACIA_STATUS             ; wait for RDR full
    lsr
    bcc @-

    lda ACIA_RDR
    and #$7f

acia_send_byte:
    pha

@:
    lda ACIA_STATUS     ; wait for TDR empty
    lsr
    lsr
    bcc @-

    pla
    sta ACIA_TDR
    rts

; ----------------------------------------------------------------------------

acia_read_hex_digit:

invalid_digit:
    jsr acia_recv_byte_with_echo

    cmp #'R'            ; RESET
    beq RESET

    cmp #'0'
    bmi invalid_digit           ;  < '0' ? get another

    cmp #'9'+1
    bmi valid_digit             ; <= '9' ? goto got lower hex

    cmp #'A'
    bmi invalid_digit           ;  < 'A' ? get another

    cmp #'F'+1
    bpl invalid_digit           ;  > 'F' ? get another

    clc
    sbc #$06                    ; -7, adjust for decimal

valid_digit:
    and #$0f
    rts

; ----------------------------------------------------------------------------

; Entry point when only ROM @ $ff00

RESET:
    lda #$03            ; Master Reset
    sta ACIA_CONTROL
    lda #$b1            ; %1 01 100 01
                        ;  |  |  |   +-- div 16
                        ;  |  |  +------ 8 data bits, 2 stop bits, no parity
                        ;  |  +--------- /RTS low, transmit interrupt enabled
                        ;  +------------ receive interrupt enabled
                        ;
                        ; Why are interrupts enabled?

    sta ACIA_CONTROL
    cld

; Entry point from 65AB

    .error * != $fe40

restart:
    sei                 ; disable IRQ

    ldx #$26
    txs

    lda #CR
    jsr acia_send_byte
    lda #LF
    jsr acia_send_byte

    jsr acia_recv_byte_with_echo

    cmp #'L'
    beq handle_L_command

    cmp #'P'
    beq handle_P_command

    cmp #'G'
    bne RESET

handle_G_command:
    ldx $012d
    txs

; read values from "storage"

    ldx $012a       ; X
    ldy $0129       ; Y

    lda $012e       ; address MSB
    pha
    lda $012f       ; address LSB
    pha
    lda $012c       ; status flags
    pha

    lda $012b       ; A
    rti             ; fake jump with A,X,Y, and P set.

; ----------------------------------------------------------------------------

handle_L_command:
    jsr read_address_into_ptr

    ldx #$03        ; ptr,x = $ff
    ldy #$00

@:
    jsr read_hex_byte_store_ptr_x   ; get hex input, store at $ff

    lda $ff
    sta (ptr),y
    iny
    bne @-

    inc ptr+1
    clv
    bvc @-          ; branch always

; ----------------------------------------------------------------------------

handle_P_command
    jsr read_address_into_ptr

    ldy #$00    ;[write data starting at (ptr) to acia as hex + space

lfe92
    ldx #$09    ; with lines of 8 bytes, abort with any keystroke]

    lda #$0d
    jsr acia_send_byte    ;write <cr><lf>
    lda #$0a
    jsr acia_send_byte

@:
    dex
    beq lfeac

    jsr acia_send_hex_byte_plus_space   ; send (ptr),y as hex byte and space

    iny
    bne @-

    inc $fd
    jmp @-

; ----------------------------------------------------------------------------

lfeac
    lda ACIA_STATUS     ; check if TDR is full, i.e. byte received
    lsr
    bcs restart

    nop
    bcc lfe92           ; branch always

; ----------------------------------------------------------------------------

read_hex_byte_store_ptr_x:
    jsr acia_read_hex_digit

:4  asl                         ; high nibble
    sta ptr,x                   ; save

    jsr acia_read_hex_digit    ; read a hex digit from acia

    clc                         ; add high nibble
    adc ptr,x
    sta ptr,x                   ; store

    rts

; ----------------------------------------------------------------------------

read_address_into_ptr:
    ldx #1
    jsr read_hex_byte_store_ptr_x       ; read into ptr+1

    dex
    jsr read_hex_byte_store_ptr_x       ; read into ptr

    rts

; ----------------------------------------------------------------------------

acia_send_hex_value:
    clc
    adc #'0'
    cmp #'9'+1
    bcs convert_A_F

@:
    jsr acia_send_byte

    rts

convert_A_F:
    adc #$06                ; +7 (!) convert $3a --> $41 ('A'), etc...
    bcc @-                  ; branch always

; ----------------------------------------------------------------------------

acia_send_hex_byte_plus_space:
    lda (ptr),y             ; write byte in (ptr),y to acia as hex + space
    and #$f0                ; unneeded masking of high nibble
:4  lsr
    jsr acia_send_hex_value

    lda (ptr),y
    and #$0f
    jsr acia_send_hex_value

    lda #' '
    jsr acia_send_byte

    rts

; ----------------------------------------------------------------------------

    .byte $40,$9d
    .word $0130         ; NMI
    .word RESET
    .word $01c0         ; IRQ

