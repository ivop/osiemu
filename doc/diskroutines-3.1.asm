    opt h-
; ----------------------------------------------------------------------------

; Generated by Frida version 0.9 beta

; Thu Jun 6 21:06:20 2024

; ----------------------------------------------------------------------------

; GENERATED LABELS

PIA_DRA=$c000
PIA_DRB=$c002
ACIA_CONTROL_STATUS=$c010
ACIA_DATA=$c011

; ----------------------------------------------------------------------------

; SEGMENT: 1

; Name    : Segment 0
; Start   : $2663
; End     : $29ea

; LOCAL LABELS

L00e5=$e5
L00f6=$f6
L00f7=$f7
L00f8=$f8
L00f9=$f9
L00fa=$fa
L00fb=$fb
L00fd=$fd
ptr=$fe
drive_number=$265c
track_under_head_bcd=$265d
sector_number=$265e
sector_page_count=$265f
bufptr=$2660
track_number_to_move_to=$2662
L2a4b=$2a4b
L2c83=$2c83

; 
; Disassembled from: diskroutines-3.1-2663-29ea.bin
; 
    org  $2663

go_to_track0
    jsr move_one_track_up

    jsr wait_loop_0c_c7

    sty track_under_head_bcd
keep_moving
    lda #$02
    bit PIA_DRA
; track 0 sensor triggered
    beq wait_loop_0c_c7

    jsr move_one_track_down

    beq keep_moving

wait_loop_0c_c7
    ldx #$0c
wait_loop_X_c7
    ldy #$c7
inner_wait_loopx
    dey 
    bne inner_wait_loopx

    dex 
    bne wait_loop_X_c7

short_wait
    rts 

; ----------------------------------------------------------------------
move_one_track_down
    lda PIA_DRB
    ora #$04
    bne move_into_direction

move_one_track_up
    lda #$fb
    and PIA_DRB
move_into_direction
    sta PIA_DRB
    jsr short_wait

    and #$f7
; bit 3 1-->0 transition, do move
    sta PIA_DRB
    jsr short_wait

L269E=*+1
    ora #$08
; set bit 3 back to 1 for next move
    sta PIA_DRB
    ldx #$08
; branch always
    bne wait_loop_X_c7

; ----------------------------------------------------------------------
move_head_to_track_number
    lda track_number_to_move_to
    sec 
    ldx #$ff
convert_to_BCD
    inx 
    sbc #$0a
    bcs convert_to_BCD

    adc #$0a
    sta L00fa
    txa 
    asl 
    asl 
    asl 
    asl 
    ora L00fa
    sta L00fa
    pha 
    bit L269e
    beq conversion_done

    and #$06
    bne L26cd

conversion_done
    pla 
    cmp #$40
    bcc track_less_or_equal_to_40

L26cd
    lda #$08
    bne error_out

track_less_or_equal_to_40
    lda drive_number
    and #$01
    tay 
    jsr check_drive_ready

    bcc seek_loop

    lda #$06
error_out
    jmp L2a4b

seek_loop
    sed 
    ldx L00fa
    cpx track_under_head_bcd
    beq seek_to_track_done

    bcs seek_up

    lda #$99
    adc track_under_head_bcd
    sta track_under_head_bcd
    jsr move_one_track_down

    beq seek_loop

seek_up
    lda #$00
    adc track_under_head_bcd
    sta track_under_head_bcd
    jsr move_one_track_up

    beq seek_loop

seek_to_track_done
    cld 
    jmp wait_loop_0c_c7

; ----------------------------------------------------------------------
set_current_based_on_track
    lda PIA_DRB
    ldx #$42
    cpx track_under_head_bcd
    bcc lower_than_42

; set current bit
    ora #$40
    bne store_current_bit

; clear current bit
lower_than_42
    and #$bf
store_current_bit
    sta PIA_DRB
    rts 

; ----------------------------------------------------------------------
wait_until_and_past_index_hole
    lda PIA_DRA
    bmi wait_until_and_past_index_hole

wait_past_index_hole
    lda PIA_DRA
    bpl wait_past_index_hole

    rts 

; ----------------------------------------------------------------------
lower_head_and_wait_for_data_area
    jsr put_head_on_disk

wait_for_data_area
    jsr wait_until_and_past_index_hole

; ACIA master reset
    lda #$03
    sta ACIA_CONTROL_STATUS
; ACIA word select 8E1
    lda #$58
    sta ACIA_CONTROL_STATUS
    rts 

; ----------------------------------------------------------------------
read_track_to_ind_ptr_buffer
    jsr lower_head_and_wait_for_data_area

wait_for_byte_ready
    lda PIA_DRA
    bpl lift_head_and_exit

    lda ACIA_CONTROL_STATUS
    lsr 
    bcc wait_for_byte_ready

; receive and store byte
    lda ACIA_DATA
    sta (ptr),y
    iny 
    bne wait_for_byte_ready

    inc ptr+1
    jmp wait_for_byte_ready

; ----------------------------------------------------------------------
put_head_on_disk
    lda #$7f
    and PIA_DRB
do_head_up_or_down
    sta PIA_DRB
    ldx #$28
    jmp wait_loop_X_c7

lift_head_and_exit
    lda #$80
lift_head_with_A
    ora PIA_DRB
    bne do_head_up_or_down

; ----------------------------------------------------------------------
initialize_tracks_1_39
    lda #$39
    sta L00e5
    jsr go_to_track0

; move to next track (2c83 is outside segment, check later)
next_track
    jsr L2c83

    jsr write_track_header_information

    lda track_under_head_bcd
    cmp #$39
    bne next_track

    rts 

write_track_header_information
    lda #$02
    bit PIA_DRA
    bne not_track0

; we are on track 0 (should not happen), error 3
    lda #$03
    bne error_out2

not_track0
    lda #$20
    bit PIA_DRA
    bne not_write_protected

; disk is write protected, error 4
    lda #$04
error_out2
    jmp L2a4b

not_write_protected
    jsr lower_head_and_wait_for_data_area

; enable write circuits
    lda #$fc
    and PIA_DRB
    sta PIA_DRB
    ldx #$0a
    jsr wait_loop_X_c7

    ldx #$43
    jsr write_byte_to_disk

    ldx #$57
    jsr write_byte_to_disk

    ldx track_under_head_bcd
    jsr write_byte_to_disk

    ldx #$58
    jsr write_byte_to_disk

wait_until_end_of_revolution
    lda PIA_DRA
    bmi wait_until_end_of_revolution

; lift head, disable write, set erase(?)
    lda #$83
; branch always
    bne lift_head_with_A

; ----------------------------------------------------------------------
write_byte_to_disk
    lda ACIA_CONTROL_STATUS
    lsr 
    lsr 
; wait until transmit register is empty
    bcc write_byte_to_disk

; transmit
    stx ACIA_DATA
    rts 

; ----------------------------------------------------------------------
read_byte_from_disk
    lda ACIA_CONTROL_STATUS
    lsr 
    bcc read_byte_from_disk

    lda ACIA_DATA
just_rts
    rts 

; ----------------------------------------------------------------------
write_sector_to_disk_with_error_check
    lda bufptr
    sta ptr
    lda bufptr+1
    sta ptr+1
    lda sector_page_count
    beq wrong_page_count

    bpl check_max_page_count

wrong_page_count
    lda #$0b
error_out2_trampoline
    bne error_out2

check_max_page_count
    cmp #$09
    bpl wrong_page_count

    lda #$02
    bit PIA_DRA
; can't write to sector to track 0
    beq just_rts

    lsr 
    sta L00fa
    lda #$20
    bit PIA_DRA
    bne write_protect_is_clear

    lda #$04
    bne error_out2_trampoline

write_protect_is_clear
    lda #$01
    sta L00f6
    lda #$03
    sta L00f8
    jsr position_head_above_sector

    jsr wait_400us_time_last_sector_length

; enable write circuits
    lda #$fe
    and PIA_DRB
    sta PIA_DRB
    ldx #$25
short_wait_loop
    dex 
    bne short_wait_loop

; ; does nothing?
    lda #$ff
    and PIA_DRB
    sta PIA_DRB
    jsr wait_400us_time_last_sector_length

; sector start code
    ldx #$76
    jsr write_byte_to_disk

    ldx sector_number
    jsr write_byte_to_disk

    ldx sector_page_count
    stx L00fd
    jsr write_byte_to_disk

    ldy #$00
write_next_byte_from_page
    lda (ptr),y
    tax 
    jsr write_byte_to_disk

    iny 
    bne write_next_byte_from_page

    inc ptr+1
    dec L00fd
    bne write_next_byte_from_page

; end with $47 and $53
    ldx #$47
    jsr write_byte_to_disk

    ldx #$53
    jsr write_byte_to_disk

    lda sector_page_count
; multiply by 2
    asl 
    sta L00fd
; multiply by 2 (A = A*4)
    asl 
    clc 
; add A*2
    adc L00fd
; end result is A*6
    jsr wait_300us_times_page_count

; enable read circuits
    lda PIA_DRB
    ora #$01
    sta PIA_DRB
    ldx #$69
yet_another_short_wait_loop
    dex 
    bne yet_another_short_wait_loop

; erase bit high
    ora #$02
    sta PIA_DRB
reset_ptr_to_begin_of_buffer
    clc 
    txa 
    adc ptr+1
    sec 
    sbc sector_page_count
    sta ptr+1
    jsr verify_sector_against_ind_ptr

    bcs exit_data_ok

; retry
    dec L00f8
    bne reset_ptr_to_begin_of_buffer

    dec L00f6
    bmi read_back_failed

    txa 
    adc ptr+1
    sec 
    sbc sector_page_count
    sta ptr+1
; NOTE: this jumps in the middle of a routine that expects a byte pushed
; to the stack, which has not happened here. BUG
    bne one_more_try

exit_data_ok
    rts 

read_back_failed
    lda #$02
    bne error_out3

wait_400us_time_last_sector_length
    lda L00fa
    asl 
    asl 
    asl 
wait_300us_times_page_count
    tay 
outer_wait_loop
    ldx #$12
inner_wait_loop
    dex 
    bne inner_wait_loop

    nop 
    nop 
    dey 
    bne outer_wait_loop

    rts 

; ----------------------------------------------------------------------
; used during search for track headers
read_byte_from_disk_with_error_checking
    lda PIA_DRA
    bpl error_index_hole_found

    lda ACIA_CONTROL_STATUS
    lsr 
; wait for receive buffer full
    bcc read_byte_from_disk_with_error_checking

    lda ACIA_DATA
    rts 

error_index_hole_found
    lda #$09
error_out3
    jmp L2a4b

; ----------------------------------------------------------------------
position_head_above_sector
    jsr wait_for_data_area

read_next_byte
    jsr read_byte_from_disk_with_error_checking

search_for_43
    cmp #$43
    bne read_next_byte

    jsr read_byte_from_disk_with_error_checking

    cmp #$57
    bne search_for_43

; start of sector marker $43 $57 found
    jsr read_byte_from_disk

    cmp track_under_head_bcd
    beq on_the_right_track

    lda #$05
    bne error_out3

on_the_right_track
    jsr read_byte_from_disk

    dec sector_number
    beq sector_number_found

    lda #$00
    sta L00f9
not_found_loop
    jsr read_past_sector

    bcc error_10

    lda sector_number
    cmp L00f9
    bne not_found_loop

    cmp L00fb
    bne error_10

; restore sector_number (dec first, inc now)
sector_number_found
    inc sector_number
    rts 

error_10
    lda #$0a
    bne error_out3

; ----------------------------------------------------------------------
; OK: C=1
; FAIL: C=0
verify_sector_against_ind_ptr
    pha 
    jsr position_head_above_sector

one_more_try
    jsr read_byte_from_disk_with_error_checking

    cmp #$76
    bne one_more_try

    jsr read_byte_from_disk

    cmp sector_number
    beq verify_sector_found

    pla 
verify_fail
    clc 
    rts 

verify_sector_found
    jsr read_byte_from_disk

    tax 
    sta sector_page_count
    ldy #$00
    pla 
    beq read_current_sector_to_ind_ptr

verify_loop
    lda ACIA_CONTROL_STATUS
    lsr 
    bcc verify_loop

    lda ACIA_DATA
    bit ACIA_CONTROL_STATUS
    bvs verify_fail

    cmp (ptr),y
    bne verify_fail

    iny 
    bne verify_loop

    inc ptr+1
    dex 
    bne verify_loop

    sec 
    rts 

; ----------------------------------------------------------------------
; (ptr) buffer
; page count in X
read_current_sector_to_ind_ptr
    lda ACIA_CONTROL_STATUS
    lsr 
; wait for Rx buffer full
    bcc read_current_sector_to_ind_ptr

    lda ACIA_DATA
    bit ACIA_CONTROL_STATUS
; parity error?
    bvs verify_fail

    sta (ptr),y
    iny 
    bne read_current_sector_to_ind_ptr

    inc ptr+1
    dex 
    bne read_current_sector_to_ind_ptr

; OK!
    sec 
    rts 

; ----------------------------------------------------------------------
; use bufptr
read_sector_with_retries
    lda bufptr
    sta ptr
    lda bufptr+1
    sta ptr+1
    lda #$03
    sta L00f7
retry_reading_sector
    lda #$07
    sta L00f8
retry_read_sector_inner
    lda #$00
; $00 indicating read from disk (?)
    jsr verify_sector_against_ind_ptr

    bcc read_error_occurred

    rts 

restore_ptr_1
    dec ptr+1
    inx 
read_error_occurred
    cpx sector_page_count
    bne restore_ptr_1

    dec L00f8
    bne retry_read_sector_inner

    jsr move_one_track_down

    jsr wait_loop_0c_c7

    jsr move_one_track_up

    jsr wait_loop_0c_c7

    dec L00f7
    bpl retry_reading_sector

    lda #$01
; exit error 1
    jmp L2a4b

; ----------------------------------------------------------------------
; 
; return C=1 OK
; C=0 FAIL
read_past_sector
    lda PIA_DRA
    bpl read_past_sector_fail

; wait for Rx buffer full
    lda ACIA_CONTROL_STATUS
    lsr 
    bcc read_past_sector

    lda ACIA_DATA
    cmp #$76
    bne read_past_sector

; read sector number
    jsr read_byte_from_disk

    sta L00fb
; read sector length (page count)
    jsr read_byte_from_disk

    sta L00fa
    inc L00f9
    tay 
    ldx #$00
read_past_sector_data
    jsr read_byte_from_disk

    dex 
    bne read_past_sector_data

; next page
    dey 
    bne read_past_sector_data

; return OK!
    sec 
    rts 

read_past_sector_fail
    clc 
    rts 

; ----------------------------------------------------------------------
; Enter with A=1 or A=2
select_drive_and_check_ready
    sta drive_number
    asl 
    tax 
    and #$02
    tay 
    lda return_drive_ready_status,x
    sta PIA_DRA
    lda remember_pia_status,x
    sta PIA_DRB
check_drive_ready
    lda PIA_DRA
; drive 1 ready bit to carry
    lsr 
    php 
    cpy #$00
    bne return_drive_ready_status

    plp 
; drive 2, return bit 4 disk ready in carry
    lsr 
    lsr 
    lsr 
    lsr 
    rts 

return_drive_ready_status
    plp 
remember_pia_status
    rts 


; ----------------------------------------------------------------------------