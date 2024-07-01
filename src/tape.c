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
#include <stdlib.h>
#include "portability.h"
#include "tape.h"
#include "acia.h"

double tape_baseclock = 4800.0;

char *tape_input_filename;
char *tape_output_filename;

static FILE *inputf;
static FILE *outputf;
static double timer;
static double ticks_per_clock;
static int bits_per_byte;               // inluding start, parity, stop
static int bits_remaining;
static int baud_timer;
static int baud_div;
static int activity;

bool tape_running = false;
static bool reading = false;
static bool writing = false;

static uint8_t control;
static uint8_t status;
static uint8_t RDR;                     // Receive Data Register
static uint8_t TDR;                     // Transmit Data Register

static int word_select_times[8] = {
    11,     // start bit + 7 bits + even parity + 2 stop bits
    11,     // start bit + 7 bits +  odd parity + 2 stop bits
    10,     // start bit + 7 bits + even parity + 1 stop bit
    10,     // start bit + 7 bits +  odd parity + 1 stop bit
    11,     // start bit + 8 bits +   no parity + 2 stop bits
    10,     // start bit + 8 bits +   no parity + 1 stop bit
    11,     // start bit + 8 bits + even parity + 1 stop bit
    11      // start bit + 8 bits +  odd parity + 1 stop bit
};

void tape_eject_input(void) {
    fclose(inputf);
    free(tape_input_filename);
    tape_input_filename = NULL;
    inputf = NULL;
    puts("tape: input ejected");
}

void tape_eject_output(void) {
    fclose(outputf);
    free(tape_output_filename);
    tape_output_filename = NULL;
    outputf = NULL;
    puts("tape: output ejected");
}

bool tape_insert_input(char *filename) {
    if (inputf) tape_eject_input();
    if (!(inputf = fopen(filename, "rb"))) {
        fprintf(stderr, "tape: input: cannot open %s\n", filename);
        return false;
    }
    printf("tape: input: %s\n", filename);
    tape_input_filename = filename;
    return true;
}

bool tape_insert_output(char *filename) {
    if (outputf) tape_eject_output();
    if (!(outputf = fopen(filename, "wb"))) {
        fprintf(stderr, "tape: output: cannot open %s\n", filename);
        return false;
    }
    printf("tape: input: %s\n", filename);
    tape_output_filename = filename;
    return true;
}

bool tape_init(char *input_file, char *output_file, double cpu_clock) {
    if (input_file) {
        if (!tape_insert_input(input_file)) return false;
    }
    if (output_file) {
        if (!tape_insert_output(output_file)) return false;
    }

    ticks_per_clock = cpu_clock / tape_baseclock;
    bits_per_byte = 11;
    return true;
}

static void tape_rewind_input(void) {
    if (inputf) {
        printf("tape: rewinding input tape\n");
        fseek(inputf, 0, SEEK_SET);
    }
}

void tape_rewind(void) {
    tape_rewind_input();
    tape_running = false;
    reading = false;
    writing = false;
}

void tape_tick(double ticks) {
    timer += ticks;
    if (timer < ticks_per_clock) return;

    timer -= ticks_per_clock;

    if (!tape_running) return;

    baud_timer--;

    if (baud_timer) return;

    baud_timer = baud_div;

    bits_remaining--;

    if (bits_remaining <= 0) {
        bits_remaining = 0;
        if (reading && inputf) {
            // receiving...
            int v = fgetc(inputf);
            if (v < 0) {                           // end-of-file
                setbit(status, STATUS_FE_MASK);
            } else {
                clrbit(status, STATUS_FE_MASK);
                RDR = v;
                if (getbit(status, STATUS_RDRF_MASK)) {
                    setbit(status, STATUS_OVRN_MASK);
                } else {
                    clrbit(status, STATUS_OVRN_MASK);
                }
                setbit(status, STATUS_RDRF_MASK);
            }
            bits_remaining = bits_per_byte;
        }
        if (writing && outputf) {
            // transmitting...
            if (!(status & STATUS_TDRE_MASK)) {
                fputc(TDR, outputf);
                setbit(status, STATUS_TDRE_MASK);
                bits_remaining = bits_per_byte;
            } else {
                bits_remaining = bits_per_byte;
            }
        }
        activity--;
        if (activity < 0) {
            printf("tape: no activity, stopping\n");
            tape_running = false;
        }
    }

}

uint8_t tape_read(uint16_t address) {
    activity = 300;
    switch (address & 1) {
    case 0:                     // status register
        if (!tape_running) {
            printf("tape: reading status, activate tape\n");
            tape_running = true;
            printf("tape: assume reading\n");
            reading = true;     // assume reading, unless TDR is written
        }
        return status;
        break;
    case 1:                     // receive register
        clrbit(status, STATUS_RDRF_MASK);
        clrbit(status, STATUS_OVRN_MASK);
        return RDR;
        break;
    }
    unreachable();
}

void tape_write(uint16_t address, uint8_t value) {
    activity = 300;
    switch (address & 1) {
    case 0:                     // control register
        control = value;
        switch (control & CONTROL_DIV_MASK) {
        case 0:
            printf("tape: set baud rate to %.1f\n", tape_baseclock / 1);
            baud_div = baud_timer = 1;
            break;
        case 1:
            printf("tape: set baud rate to %.1f\n", tape_baseclock / 16);
            baud_div = baud_timer = 16;
            break;
        case 2:
            printf("tape: set baud rate to %.1f\n", tape_baseclock / 64);
            baud_div = baud_timer = 64;
            break;
        case 3:
            printf("tape: master reset\n");
            tape_running = 0;
            status = 0;
            setbit(status, STATUS_TDRE_MASK);   // empty
            break;
        }
        bits_per_byte = word_select_times[(control & CONTROL_WS_MASK) >> 2];
        break;
    case 1:                     // transmit register
        if (tape_running) {
            if (!writing) {
                tape_rewind_input();
                printf("tape: switch to writing\n");
                reading = false;
                writing = true;     // switch to writing
            }
            TDR = value;
            clrbit(status, STATUS_TDRE_MASK);   // not empty
        }
        break;
    }
}
