; ----------------------------------------------------------------------------
;
; Format an empty disk (5.25" only)
;
; Erase track 0-39, write track markers on track 1-39
; Byte encoding 8E1
;
; Build with:
; mads -o:format.xex format.s && ../../tools/xex2lod < format.xex >format.lod
;
; ----------------------------------------------------------------------------

    org $0300

; ----------------------------------------------------------------------------

; DEBUG

SCREEN = $d000

; ----------------------------------------------------------------------------

; Variables

tmp     = $f0
curtrk  = $f1       ; under head, BCD(!)

; ----------------------------------------------------------------------------

DATA_DIRECTION_ACCESS = $04     ; bit 2, 0 active (!)

ORA   = $c000       ; output register A
DDRA  = $c000       ; data directrion A
CRA   = $c001       ; control register A

ORB  = $c002        ; output register B
DDRB = $c002        ; data direction B
CRB  = $c003        ; control register B

PORTA = $c000       ; alias for ORA
PORTB = $c002       ; alias for ORB

; ----------------------------------------------------------------------------

; PORTA

DRIVE0_NOT_READY_MASK = 0x01        ; 0 = drive0 reads, 1 = not ready
HEAD_NOT_TRACK0_MASK  = 0x02        ; 0 = above, 1 = not above
DRIVE1_NOT_READY_MASK = 0x10        ; 0 = drive1 reads, 1 = not ready
DISK_R_W_MASK         = 0x20        ; 0 = protected, 1 = r/w
DRIVE0_SELECT_MASK    = 0x40        ; 0 = drive1, 1 = drive0
NOT_INDEX_HOLE_MASK   = 0x80        ; 0 = above hole, 1 = not above

; PORTB

READ_FROM_DISK_MASK   = 0x01        ; nWRITE: 0 = write, 1 = read
ERASE_ENABLE_MASK     = 0x02        ; nERASE: 0 = enabled, 1 = disabled
DIRECTION_MASK        = 0x04        ; nSTEPDIR: 0 = to trk 39, 1 = to trk 0
MOVE_HEAD_MASK        = 0x08        ; nSTEP: 1->0 move, 1 = steady
FAULT_RESET_MASK      = 0x10        ; nRESET: 0 = reset, 1 = normal
DRIVE_01_23_MASK      = 0x20        ; 0 = drive 2/3, 1 = drive 0/1
LOW_CURRENT_MASK      = 0x40        ; mostly 1, 0 on 8" trk >= 44
HEAD_NOT_ON_DISK_MASK = 0x80        ; nHEADLOAD 0 = on disk, 1 = lifted

; ----------------------------------------------------------------------------

ACIA_CONTROL = $c010    ; control register
ACIA_STATUS  = $c010    ; status register
ACIA_TDR     = $c011    ; transmit data register
ACIA_RDR     = $c011    ; receive data register

CONTROL_DIV_MASK = 0x03             ; divider 1,16,64,master reset
CONTROL_RESET    = 0x03
CONTROL_WS_MASK  = 0x1c             ; word select, see below
CONTROL_TX_CTRL  = 0x60             ; transmit control bits, see below
CONTROL_RX_IRQE  = 0x80             ; receive interrupt enable

STATUS_RDRF_MASK = 0x01             ; Rx data register full
STATUS_TDRE_MASK = 0x02             ; Tx data register empty
STATUS_nDCD_MASK = 0x04             ; /DCD Data Carrier Detect
STATUS_nCTS_MASK = 0x08             ; /CTS Clear To Send
STATUS_FE_MASK   = 0x10             ; Rx Frame Error
STATUS_OVRN_MASK = 0x20             ; Rx Overrun
STATUS_PE_MASK   = 0x40             ; Rx Parity Error
STATUS_IRQ_MASK  = 0x80             ; /IRQ, if pin output is low, bit is 1
                                    ; clear by read of RDR

WS_SHIFT = 2

WS_7E2 = 0x00
WS_7O2 = 0x01
WS_7E1 = 0x02
WS_7O1 = 0x03
WS_8N2 = 0x04
WS_8N1 = 0x05
WS_8E1 = 0x06
WS_8O1 = 0x07

TCB_SHIFT = 5

TCB_nRTS_LOW_IRQ_DIS           = 0x00
TCB_nRTS_LOW_IRQ_ENA           = 0x01
TCB_nRTS_HIGH_IRQ_DIS          = 0x02
TCB_nRTS_LOW_BREAK_LVL_IRQ_DIS = 0x03

; ----------------------------------------------------------------------------

.proc init_pia
    ldy #0
    ldx #DATA_DIRECTION_ACCESS

    sty CRA         ; select DDRA
    sty DDRA        ; set all pins to input
    stx CRA         ; select ORA

    sty CRB         ; select DDRB
    dey             ; Y=$ff
    sty DDRB        ; set all pins to output
    stx CRB         ; select ORB
    sty PORTB       ; set all outputs high

    rts
.endp

; ----------------------------------------------------------------------------

.proc init_acia
    lda #CONTROL_RESET
    sta ACIA_CONTROL
    lda #(TCB_nRTS_HIGH_IRQ_DIS << TCB_SHIFT) | (WS_8E1 << WS_SHIFT)
    sta ACIA_CONTROL

    rts
.endp

; ----------------------------------------------------------------------------

; NOT_INDEX_HOLE_MASK = 0x80, 0 = above hole, 1 = not above

.proc wait_past_index_hole

not_above_hole:
    lda PORTA
    bmi not_above_hole

above_hole:
    lda PORTA
    bpl above_hole

    rts                 ; right after hole
.endp

; ----------------------------------------------------------------------------

; Head Movement, step in and step out

.proc step_in
    lda PORTB
    ora #DIRECTION_MASK
    bne step
.endp

.proc step_out
    lda PORTB
    and #~DIRECTION_MASK
    ; [[fallthrough]]
.endp

.proc step
    sta PORTB

    jsr short_delay             ; jsr + rts = 6 + 6 = 12 cycles

    and #~MOVE_HEAD_MASK
    sta PORTB                   ; 1->0 transition, move

    jsr short_delay             ; jsr + rts = 6 + 6 = 12 cycles

    ora #MOVE_HEAD_MASK
    sta PORTB                   ; back to 1, ready for next transition

    ldx #$18                    ; 65D: $18, OS65D: $08
    bne long_delay_X            ; branch always
.endp

; SEEK TO TRACK 0 ENTRY POINT

.proc seek_to_track0
    jsr step_out

    jsr long_delay              ; always returns with X=Y=0, and Z=1

    sty curtrk                  ; set curtrk to zero

keep_moving:
    lda #HEAD_NOT_TRACK0_MASK
    bit PORTA
    beq long_delay              ; bit 1 is 0, means track 0 sensor is triggered

    jsr step_in                 ; ends with long_delay_X, hence Z=1
    beq keep_moving             ; branch always

    ; [[fallthrough]]
.endp

; Long delays always return with X=Y=0 and Z=1

.proc long_delay
    ldx #$18                    ; 65D: $18, OS65D: $0c

    ; [[fallthrough]]
.endp

.proc long_delay_X
    ldy #$f8                    ; 65D: $f8, OS65D: $c7      2 cycles
@:
    dey                         ; 2 cycles
    bne @-                      ; 3 cycles if taken, $f8*5-1 = 1239 cycles

    dex                         ; 2 cycles
    bne long_delay_X            ; 3 cycles if taken, $18*1244-1 = 29855 cycles

                                ; long delay = ca. 30.3 ms @ 983040 Hz CPU
                                ; X times ca. 1.265 ms

    ; [[fallthrough]]
.endp

.proc short_delay
    rts
.endp

; ----------------------------------------------------------------------------

.ifdef DO_NOT_ASSEMBLE

; convert binary to BCD (0-99 max.)
; code size: 21 bytes

.proc convert_to_bcd
    ldx #0
@:
    cmp #10
    bcc final_step

    inx

; carry is always set
    sbc #10
    bcs @-

final_step:
    sta tmp

    txa
    asl
    asl
    asl
    asl

; carry is always clear
    adc tmp
    rts
.endp

.endif

; ----------------------------------------------------------------------------

.proc put_head_on_disk
    lda PORTB
    and #~HEAD_NOT_ON_DISK_MASK

    ; [[fallthrough]]
.endp

.proc move_head
    sta PORTB
    ldx #$28
    jmp long_delay_X
.endp

.proc lift_head_from_disk
    lda PORTB
    ora #HEAD_NOT_ON_DISK_MASK
    bne move_head
.endp

; ----------------------------------------------------------------------------

.proc enable_write_and_erase
    lda PORTB
    and #~(READ_FROM_DISK_MASK | ERASE_ENABLE_MASK)
    ; [[fallthrough]]
.endp

.proc common_write_and_erase
    sta PORTB
    rts
.endp

.proc disable_write_and_erase
    lda PORTB
    ora #(READ_FROM_DISK_MASK | ERASE_ENABLE_MASK)
    bne common_write_and_erase
.endp

; ----------------------------------------------------------------------------

; Write all 1's on track 0
; Return C=1 on error, C=0 when OK

.proc erase_track0
    jsr seek_to_track0

    jsr put_head_on_disk

    jsr wait_past_index_hole

    jsr enable_write_and_erase

    jsr wait_past_index_hole

    jsr disable_write_and_erase

    jsr lift_head_from_disk

    clc
    rts
.endp

; ----------------------------------------------------------------------------

; Write byte in X to ACIA

.proc output_byte

wait_until_tdr_empty:
    lda ACIA_STATUS
    lsr
    lsr
    bcc wait_until_tdr_empty

    stx ACIA_TDR
    rts
.endp

; ----------------------------------------------------------------------------

; Write all 1's, then write 43h 57h BCD_trknum 58h, then all 1's again

.proc write_track_marker
    jsr wait_past_index_hole

    jsr enable_write_and_erase

    ldx #$08
    jsr long_delay_X

    ldx #$43
    jsr output_byte
    ldx #$57
    jsr output_byte
    ldx curtrk
    jsr output_byte
    ldx #$58
    jsr output_byte

    jsr wait_past_index_hole

    jsr disable_write_and_erase

    rts
.endp

; ----------------------------------------------------------------------------

.proc initialize_tracks_1_39
    jsr seek_to_track0

    jsr put_head_on_disk

next_track:
    jsr step_out

    sed                     ; to avoid using BCD conversion, we count in BCD
    lda curtrk              ; inc does not work in BCD mode
    clc
    adc #1
    sta curtrk
    cld

    jsr write_track_marker

    lda curtrk
    cmp #$39
    bne next_track

    jsr lift_head_from_disk

    rts
.endp

; ----------------------------------------------------------------------------

.proc format_disk
    jsr init_pia
    jsr init_acia

    lda #DISK_R_W_MASK
    bit PORTA
    bne not_write_protected

error_out:
    sec
    rts

not_write_protected:
    jsr erase_track0
    jsr initialize_tracks_1_39
    jsr seek_to_track0

    clc
    rts
.endp

; ----------------------------------------------------------------------------

.proc main
    jsr format_disk

    jmp *
.endp

; ----------------------------------------------------------------------------

    run main

; vim: filetype=asm sw=4 ts=4 et
