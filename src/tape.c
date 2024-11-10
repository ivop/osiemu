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
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include "portability.h"
#include "tape.h"
#include "acia.h"

double tape_baseclock = 4800.0;

char *tape_input_filename;
char *tape_output_filename;

static int inputfd = -1;
static int outputfd = -1;
static double timer;
static double ticks_per_clock;
static int bits_per_byte;               // inluding start, parity, stop
static int rx_bits_remaining;
static int tx_bits_remaining;
static int baud_timer;
static int baud_div;
static bool started;
int tape_activity;

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
    if (inputfd < 0) {
        puts("tape: input already empty");
        return;
    }
    close(inputfd);
    free(tape_input_filename);
    tape_input_filename = NULL;
    inputfd = -1;
    puts("tape: input ejected");
}

void tape_eject_output(void) {
    if (outputfd < 0) {
        puts("tape: output already empty");
        return;
    }
    printf("tape: closing %s\n", tape_output_filename);
    close(outputfd);
    free(tape_output_filename);
    tape_output_filename = NULL;
    outputfd = -1;
    puts("tape: output ejected");
}

bool tape_insert_input(char *filename) {
    if (inputfd >= 0) tape_eject_input();
    if ((inputfd = open(filename, O_NONBLOCK | O_RDONLY)) < 0) {
        fprintf(stderr, "tape: input: cannot open %s\n", filename);
        return false;
    }
    printf("tape: input: %s\n", filename);
    tape_input_filename = filename;
    return true;
}

bool tape_insert_output(char *filename) {
    if (outputfd >= 0) tape_eject_output();
    if ((outputfd = open(filename, O_NONBLOCK | O_WRONLY | O_CREAT, 0666)) < 0) {
        fprintf(stderr, "tape: output: cannot open %s\n", filename);
        return false;
    }
    printf("tape: output: %s\n", filename);
    tape_output_filename = filename;
    return true;
}

static bool tape_insert_both(char *filename) {
    if (inputfd >= 0) tape_eject_input();
    if (outputfd >= 0) tape_eject_output();
    puts("tape: input and output are identical");
    if ((inputfd = open(filename, O_NONBLOCK | O_RDWR, 0666)) < 0) {
        fprintf(stderr, "tape: i/o: cannot open %s\n", filename);
        return false;
    }
    outputfd = inputfd;
    tape_input_filename = tape_output_filename = filename;
    return true;
}

bool tape_init(char *input_file, char *output_file, double cpu_clock) {
    if (input_file && output_file && !strcmp(input_file, output_file)) {
        if (!tape_insert_both(input_file)) return false;
    } else {
        if (input_file) {
            if (!tape_insert_input(input_file)) return false;
        }
        if (output_file) {
            if (!tape_insert_output(output_file)) return false;
        }
    }

    ticks_per_clock = cpu_clock / tape_baseclock;
    bits_per_byte = 11;
    baud_timer = 1;
    return true;
}

void tape_rewind_input(void) {
    if (inputfd >= 0) {
        puts("tape: rewinding input tape");
        lseek(inputfd, 0, SEEK_SET);
    } else {
        puts("tape: there is no input tape to rewind");
    }
}

void tape_rewind_output(void) {
    if (outputfd >= 0) {
        puts("tape: rewinding output tape");
        close(outputfd);
        outputfd = open(tape_output_filename, O_NONBLOCK | O_WRONLY | O_CREAT, 0666);
    } else {
        puts("tape: there is no output tape to rewind");
    }
}

void tape_tick(double ticks) {
    timer += ticks;
    if (timer < ticks_per_clock) return;

    timer -= ticks_per_clock;

    baud_timer--;

    if (baud_timer) return;

    baud_timer = baud_div;

    if (!started) return;

    if (rx_bits_remaining) {
        rx_bits_remaining--;
    } else {
        if (inputfd >= 0) {
            // we cheat a little, we only fill RDR if the previous byte
            // has been read
            if (!getbit(status, STATUS_RDRF_MASK)) {
                uint8_t c;
                if (read(inputfd, &c, 1) == 1) {
                    clrbit(status, STATUS_FE_MASK);
                    RDR = c;
                    if (getbit(status, STATUS_RDRF_MASK)) {
                        setbit(status, STATUS_OVRN_MASK);
                    } else {
                        clrbit(status, STATUS_OVRN_MASK);
                    }
                    setbit(status, STATUS_RDRF_MASK);
                    rx_bits_remaining = bits_per_byte - 1;
                }
            }
        }
    }

    if (tx_bits_remaining) {
        tx_bits_remaining--;
    } else {
        if (outputfd) {
            // transmitting...
            if (!(status & STATUS_TDRE_MASK)) {
                if (write(outputfd, &TDR, 1) == 1) {
                    setbit(status, STATUS_TDRE_MASK);
                    tx_bits_remaining = bits_per_byte - 1;
                }
            }
        }
    }
}

uint8_t tape_read(uint16_t address) {
    tape_activity = 25;
    started = true;
    switch (address & 1) {
    case 0:                     // status register
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
    tape_activity = 25;
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
            status = 0;
            setbit(status, STATUS_TDRE_MASK);   // empty
            break;
        }
        bits_per_byte = word_select_times[(control & CONTROL_WS_MASK) >> 2];
        break;
    case 1:                     // transmit register
        TDR = value;
        clrbit(status, STATUS_TDRE_MASK);   // not empty
        break;
    }
}
