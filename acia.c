/*
 * osiemu - Ohio Scientific Instruments, Inc. Emulator
 *
 * Copyright © 2024 by Ivo van Poorten
 *
 * This file is licensed under the terms of the 2-clause BSD license. Please
 * see the LICENSE file in the root project directory for the full text.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "acia.h"

// Control register
//
enum acia_stop_bits {
    ACIA_STOP_BITS_1,
    ACIA_STOP_BITS_2
};

enum acia_word_length {
    ACIA_WORD_LENGTH_8,
    ACIA_WORD_LENGTH_7,
    ACIA_WORD_LENGTH_6,
    ACIA_WORD_LENGTH_5
};

enum acia_receiver_clock_source {
    ACIA_CLOCK_SOURCE_EXTERNAL,
    ACIA_CLOCK_SOURCE_INTERNAL
};

enum acia_baud_rate {
    ACIA_BAUD_RATE_16XEXT,
    ACIA_BAUD_RATE_50,
    ACIA_BAUD_RATE_75,
    ACIA_BAUD_RATE_110,
    ACIA_BAUD_RATE_135,
    ACIA_BAUD_RATE_150,
    ACIA_BAUD_RATE_300,
    ACIA_BAUD_RATE_600,
    ACIA_BAUD_RATE_1200,
    ACIA_BAUD_RATE_1800,
    ACIA_BAUD_RATE_2400,
    ACIA_BAUD_RATE_3600,
    ACIA_BAUD_RATE_4800,
    ACIA_BAUD_RATE_7200,
    ACIA_BAUD_RATE_9600,
    ACIA_BAUD_RATE_19200
};

// Command register
//
enum acia_parity_enabled {
    ACIA_PARITY_DISABLED,
    ACIA_PARITY_ENABLED
};

enum acia_parity_type {
    ACIA_PARITY_ODD,
    ACIA_PARITY_EVEN,
    ACIA_PARITY_MARK,
    ACIA_PARITY_SPACE
};

enum acia_receive_mode {
    ACIA_RECEIVE_NORMAL,
    ACIA_RECEIVE_ECHO
};

enum acia_tx_controls {
    ACIA_TX_NO_INT_RTS_HIGH,
    ACIA_TX_INT_RTS_LOW,
    ACIA_TX_NO_INT_RTS_LOW,
    ACIA_TX_NO_INT_RTS_LOW_BRK
};

enum acia_rx_irq {
    ACIA_RX_IRQ_ENABLED,
    ACIA_RX_IRQ_DISABLED
};

enum acia_tx_rx_ready {
    ACIA_DTR_DISABLED,
    ACIA_DTR_ENABLED
};

// Status register
//
enum acia_parity_error {
    ACIA_PARITY_NO_ERROR,
    ACIA_PARITY_ERROR
};

enum acia_framing_error {
    ACIA_FRAMING_NO_ERROR,
    ACIA_FRAMING_ERROR
};

enum acia_overrun {
    ACIA_NO_OVERRUN,
    ACIA_OVERRUN
};

enum acia_rx_full {
    ACIA_RX_EMPTY,
    ACIA_RX_FULL
};

enum acia_tx_empty {
    ACIA_TX_FULL,
    ACIA_TX_EMPTY
};

enum acia_data_carrier_detect {
    ACIA_DCD_DETECTED,
    ACIA_DCD_NOT_DETECTED
};

enum acia_data_set_ready {
    ACIA_DSR_READY,
    ACIA_DSR_NOT_READY
};

enum acia_interrupt {
    ACIA_NO_INTERRUPT,
    ACIA_INTERRUPT
};

static uint8_t word_length_masks[4] = { 0xff, 0x7f, 0x3f, 0x1f };

static double baudrates[16] = {
    0, 50, 75, 109.92, 134.58, 150, 300, 600,
    1200, 1800, 2400, 3600, 4800, 7200, 9600, 19200
};

// CONTROL register functions
//
static inline enum acia_stop_bits get_stop_bits(struct acia *a) {
    return !!(a->control & 0x80);
}

static inline enum acia_word_length get_word_length(struct acia *a) {
    return (a->control & 0x60) >> 5;
};

static inline enum acia_receiver_clock_source get_clock_source(struct acia *a){
    return !!(a->control & 0x10);
}

static inline enum acia_baud_rate get_baudrate(struct acia *a) {
    return a->control & 0x0f;
}

static inline double get_baudrate_d(struct acia *a) {
    return baudrates[get_baudrate(a)];
}

static inline void set_stopbits(struct acia *a,
                                enum acia_stop_bits bit) {
    a->control &= ~0x80;
    if (bit) a->control |= 0x80;
}

static inline void set_word_length(struct acia *a, 
                                   enum acia_word_length length) {
    a->control &= ~0x60;
    length &= 3;
    a->control |= length << 5;
}

static inline void set_clock_source(struct acia *a, int source) {
    a->control &= ~0x10;
    if (source) a->control |= 0x10;
}

static inline void set_baudrate(struct acia *a,
                                enum acia_baud_rate rate) {
    a->control &= ~0x0f;
    rate &= 0x0f;
    a->control |= rate;
}

// COMMAND register functions
//
static inline enum acia_parity_type get_parity_type(struct acia *a) {
    return a->command >> 6;
}

static inline enum acia_parity_enabled get_parity_enabled(struct acia *a) {
    return !!(a->command & 0x20);
}

static inline enum acia_receive_mode get_receive_mode(struct acia *a) {
    return !!(a->command & 0x10);
}

static inline enum acia_tx_controls get_transmitter_controls(struct acia *a) {
    return (a->command & 0xc0) >> 2;
}

static inline enum acia_rx_irq get_receiver_interrupt_enable(struct acia *a) {
    return (a->command & 0x02) >> 1;
}

static inline enum acia_tx_rx_ready get_data_terminal_ready(struct acia *a) {
    return a->command & 0x01;
}

static inline void set_parity_type(struct acia *a,
                                   enum acia_parity_type type) {
    a->command &= ~0x3f;
    type &= 3;
    a->command |= type << 6;
}

static inline void set_parity_enabled(struct acia *a,
                                      enum acia_parity_enabled v) {
    a->command &= ~0x20;
    if (v) a->command |= 0x20;
}

static inline void set_receive_mode(struct acia *a,
                                     enum acia_receive_mode mode) {
    a->command &= ~0x10;
    if (mode) a->command |= 0x10;
}

static inline void set_transmitter_controls(struct acia *a,
                                            enum acia_tx_controls ctrl) {
    a->command &= ~0xa0;
    ctrl &= 3;
    a->command |= ctrl << 2;
}

static inline void set_receiver_interrupt_enable(struct acia *a,
                                                 enum acia_rx_irq v) {
    a->command &= ~0x02;
    if (v) a->command |= 0x02;
}

static inline void set_data_terminal_ready(struct acia *a,
                                           enum acia_tx_rx_ready v) {
    a->command &= ~0x01;
    if (v) a->command |= 0x01;
}

// STATUS register functions
//
static inline enum acia_parity_error get_parity_error(struct acia *a) {
    return a->status & 0x01;
}

static inline enum acia_framing_error get_framing_error(struct acia *a) {
    return !!(a->status & 0x02);
}

static inline enum acia_overrun get_overrun(struct acia *a) {
    return !!(a->status & 0x04);
}

static inline enum acia_rx_full get_rx_full(struct acia *a) {
    return !!(a->status & 0x08);
}

static inline enum acia_tx_empty get_tx_empty(struct acia *a) {
    return !!(a->status & 0x10);
}

static inline enum acia_data_carrier_detect get_data_carrier_detect(
                                                            struct acia *a) {
    return !!(a->status & 0x20);
}

static inline enum acia_data_set_ready get_data_set_ready(struct acia *a) {
    return !!(a->status & 0x40);
}

static inline enum acia_interrupt get_interrupt(struct acia *a) {
    return !!(a->status & 0x80);
}

static inline void set_parity_error(struct acia *a,
                                    enum acia_parity_error e) {
    a->status &= ~0x01;
    if (e) a->status |= 0x01;
}

static inline void set_framing_error(struct acia *a,
                                     enum acia_framing_error e) {
    a->status &= ~0x02;
    if (e) a->status |= 0x02;
}

static inline void set_overrun(struct acia *a, enum acia_overrun o) {
    a->status &= ~0x04;
    if (o) a->status |= 0x04;
}

static inline void set_rx_full(struct acia *a, enum acia_rx_full f) {
    a->status &= ~0x08;
    if (f) a->status |= 0x08;
}

static inline void set_tx_empty(struct acia *a, enum acia_tx_empty e) {
    a->status &= ~0x10;
    if (e) a->status |= 0x10;
}

static inline void set_data_carrier_detect(struct acia *a,
                                           enum acia_data_carrier_detect dtd) {
    a->status &= ~0x20;
    if (dtd) a->status |= 0x20;
}

static inline void set_data_set_ready(struct acia *a,
                                      enum acia_data_set_ready dsr) {
    a->status &= ~0x40;
    if (dsr) a->status |= 0x40;
}

static inline void set_interrupt(struct acia *a,
                                 enum acia_interrupt i) {
    a->status &= 0x80;
    if (i) a->status |= 0x80;
}

// INTERNAL
//
static void acia_program_reset(struct acia *a) {
    set_data_terminal_ready(a, ACIA_DTR_DISABLED);
    set_receiver_interrupt_enable(a, ACIA_RX_IRQ_DISABLED);
    set_transmitter_controls(a, ACIA_TX_NO_INT_RTS_HIGH);
    set_receive_mode(a, ACIA_RECEIVE_NORMAL);
    set_overrun(a, ACIA_NO_OVERRUN);
}

// EXTERNAL
//
void acia_hardware_reset(struct acia *a) {
    a->control = a->command = a->status = 0;
    set_receiver_interrupt_enable(a, ACIA_RX_IRQ_DISABLED);
}

void acia_init(struct acia *a, double cpu_clock) {
    acia_hardware_reset(a);
}

void acia_tick(struct acia *a) {
}

uint8_t acia_read(struct acia *a, uint16_t address) {
}

void acia_write(struct acia *a, uint16_t address, uint8_t value) {
}
