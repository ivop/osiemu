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
#include "tape.h"

static FILE *inputf;
static FILE *outputf;

bool tape_init(char *input_file, char *output_file, double cpu_clock) {
    if (input_file) {
        if (!(inputf = fopen(input_file, "rb"))) {
            fprintf(stderr, "error: cannot open %s\n", input_file);
            return false;
        }
    }

    if (output_file) {
        if (!(outputf = fopen(output_file, "wb"))) {
            fprintf(stderr, "error: cannot open %s\n", output_file);
            return false;
        }
    }

    return true;
}

void tape_tick(void) {
}

uint8_t tape_read(uint16_t address) {
    fprintf(stderr, "tape: read: %04x\n", address);
}

void tape_write(uint16_t address, uint8_t value) {
    fprintf(stderr, "tape: write: %04x <-- %02x\n", address, value);
}
