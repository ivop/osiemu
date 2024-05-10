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

#define TX_RX_CLOCK     19200.0

static FILE *inputf;
static FILE *outputf;
static double timer;
static double ticks_per_clock;
static int bits_per_byte;               // inluding start, parity, stop
static int bits_remaining;
static int baud_timer;
static int baud_div;

static bool running = false;
static bool reading = false;
static bool writing = false;

static uint8_t control;
static uint8_t status;
static uint8_t RDR;                     // Receive Data Register
static uint8_t TDR;                     // Transmit Data Register

#define CONTROL_DIV_MASK    0x03        // divider 1,16,64,master reset
#define CONTROL_WS_MASK     0x1c        // see below
#define CONTROL_TX_CTRL     0x60        // transmit control
#define CONTROL_RX_IRQE     0x80        // receive interrupt enable

#define STATUS_RDRF_MASK    0x01        // Rx data register full
#define STATUS_TDRE_MASK    0x02        // Tx data register empty
#define STATUS_nDCD_MASK    0x04        // /DCD Data Carrier Detect
#define STATUS_nCTS_MASK    0x08        // /CTS Clear To Send
#define STATUS_FE_MASK      0x10        // Rx Frame Error
#define STATUS_OVRN_MASK    0x20        // Rx Overrun
#define STATUS_PE_MASK      0x40        // Rx Parity Error
#define STATUS_IRQ_MASK     0x80        // /IRQ, if pin output is low, bit is 1
                                        // clear by read of RDR

#define setbit(v,msk)   (v) |= (msk)
#define clrbit(v,msk)   (v) &= ~(msk)
#define getbit(v,msk)   (v & (msk))

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

    ticks_per_clock = cpu_clock / TX_RX_CLOCK;
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
    running = false;
    reading = false;
    writing = false;
}

void tape_tick(double ticks) {
    timer += ticks;
    if (timer < ticks_per_clock) return;

    timer -= ticks_per_clock;

    if (!running) return;

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
                RDR = v;
                if (getbit(status, STATUS_RDRF_MASK)) {
                    setbit(status, STATUS_OVRN_MASK);
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
                bits_remaining = 1;
            }
        }
    }
}

uint8_t tape_read(uint16_t address) {
    switch (address & 1) {
    case 0:                     // status register
        if (!running) {
            printf("tape: reading status, activate tape\n");
            running = true;
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
}

void tape_write(uint16_t address, uint8_t value) {
//    fprintf(stderr, "tape: write: %04x <-- %02x\n", address, value);
    switch (address & 1) {
    case 0:                     // control register
        control = value;
        switch (control & CONTROL_DIV_MASK) {
        case 0:
            printf("tape: set baud rate to %.1f\n", TX_RX_CLOCK / 1);
            baud_div = baud_timer = 1;
            break;
        case 1:
            printf("tape: set baud rate to %.1f\n", TX_RX_CLOCK / 16);
            baud_div = baud_timer = 16;
            break;
        case 2:
            printf("tape: set baud rate to %.1f\n", TX_RX_CLOCK / 64);
            baud_div = baud_timer = 64;
            break;
        case 3:
            printf("tape: master reset\n");
            running = 0;
            status = 0;
            setbit(status, STATUS_TDRE_MASK);   // empty
            break;
        }
        bits_per_byte = word_select_times[(control & CONTROL_WS_MASK) >> 2];
        break;
    case 1:                     // transmit register
        if (running) {
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
