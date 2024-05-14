/*
 * osiemu - Ohio Scientific Instruments, Inc. Emulator
 *
 * Copyright © 2024 by Ivo van Poorten
 *
 * This file is licensed under the terms of the 2-clause BSD license. Please
 * see the LICENSE file in the root project directory for the full text.
 */

/* Notes:
 *      PIA emulation is incomplete. No IRQs and CA1/2 and CB1/2.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "floppy.h"

bool floppy_enable;

struct port {
    uint8_t input_mask;
    uint8_t input_value;
    uint8_t output_mask;
    uint8_t output_value;
};

struct pia {
    uint8_t cra;
    struct port porta;
    uint8_t crb;
    struct port portb;
};

static struct pia pia;

#define DATA_DIRECTION_ACCESS   0x04        // bit 2, 0 active(!)

bool floppy_init(void) {
    memset(&pia, 0, sizeof(struct pia));
    pia.porta.input_mask = pia.portb.input_mask = 0xff;
}

static uint8_t merge_pins(struct port *p) {
    return (p->input_value  & p->input_mask) |
           (p->output_value & p->output_mask);
}

uint8_t floppy_pia_read(uint16_t address) {
    printf("floppy: pia read $%04x\n", address);
    switch (address & 3) {
    case 0:     // ORA or DDRA
        if (!(pia.cra & DATA_DIRECTION_ACCESS)) {
            return pia.porta.output_mask;
        } else {
            return merge_pins(&pia.porta);
        }
        break;
    case 1:     // CRA
        return pia.cra;
        break;
    case 2:     // ORB or DDRB
        if (!(pia.crb & DATA_DIRECTION_ACCESS)) {
            return pia.portb.output_mask;
        } else {
            return merge_pins(&pia.portb);
        }
        break;
    case 3:     // CRB
        return pia.crb;
        break;
    }
}

void floppy_pia_write(uint16_t address, uint8_t value) {
    printf("floppy: pia write $%04x, $%02x\n", address, value);
    switch (address & 3) {
    case 0:     // ORA or DDRA
        if (!(pia.cra & DATA_DIRECTION_ACCESS)) {
            printf("floppy: set porta I/O mask to $%02x\n", value);
            pia.porta.output_mask = value;
            pia.porta.input_mask = ~value;
        } else {
            printf("floppy: porta: output value $%02x\n", value);
            pia.porta.output_value = value;
        }
        break;
    case 1:     // CRA
        pia.cra = value;
        break;
    case 2:     // ORB or DDRB
        if (!(pia.crb & DATA_DIRECTION_ACCESS)) {
            printf("floppy: set portb I/O mask to $%02x\n", value);
            pia.portb.output_mask = value;
            pia.portb.input_mask = ~value;
        } else {
            printf("floppy: portb: output value $%02x\n", value);
            pia.portb.output_value = value;
        }
        break;
    case 3:     // CRB
        pia.crb = value;
        break;
    }
}

uint8_t floppy_acia_read(uint8_t address) {
}

void floppy_acia_write(uint16_t address, uint8_t value) {
}
