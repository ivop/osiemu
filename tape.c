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
#include "acia.h"
#include "tape.h"

static struct acia tape_acia;
static FILE *inputf;
static FILE *outputf;

int tape_input(void) {
    return inputf ? fgetc(inputf) : -1;
}

int tape_output(uint8_t byte) {
    if (outputf) {
        fputc(byte, outputf);
        return 0;
    } else {
        return -1;
    }
}

bool tape_init(char *input_file, char *output_file, double cpu_clock) {
    tape_acia.input = tape_input;
    tape_acia.output = tape_output;

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

    acia_init(&tape_acia, cpu_clock);
    return true;
}

void tape_tick(void) {
    acia_tick(&tape_acia);
}

uint8_t tape_read(uint16_t address) {
    return acia_read(&tape_acia, address);
}

void tape_write(uint16_t address, uint8_t value) {
    acia_write(&tape_acia, address, value);
}
