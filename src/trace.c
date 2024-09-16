/*
 * osiemu - Ohio Scientific Instruments, Inc. Emulator
 *
 * Copyright © 2024 by Ivo van Poorten
 *
 * This file is licensed under the terms of the 2-clause BSD license. Please
 * see the LICENSE file in the root project directory for the full text.
 */

#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "fake6502/fake6502.h"
#include "disasm.h"
#include "trace.h"

struct trace_item {
    double tick;
    uint16_t pc;
    uint8_t a, x, y, sp, p;
    char *dis;
};

static bool trace;
static const long increase = 10000;
static double myticks;
static long idx;
static long nentries;
static struct trace_item *trace_log;

enum stack_item_type {
    TYPE_UNKNOWN = 0,
    TYPE_LSB,
    TYPE_MSB,
    TYPE_PHA,
    TYPE_PHP,
    TYPE_PHX,
    TYPE_PHY
};

static bool trace_stack;
static enum stack_item_type stack_items[256];
static uint16_t stack_pcs[256];

void trace_tick(double ticks) {
    if (!trace) return;

    if (idx == nentries) {
        nentries += increase;
        trace_log = realloc(trace_log, nentries * sizeof(struct trace_item));
    }

    trace_log[idx].tick = myticks; 
    trace_log[idx].pc   = PC; 
    trace_log[idx].a    = A; 
    trace_log[idx].x    = X; 
    trace_log[idx].y    = Y; 
    trace_log[idx].sp   = SP; 
    trace_log[idx].p    = getP(); 

    uint16_t loc = PC;
    trace_log[idx].dis = strdup(disasm_get_string(&loc));

    myticks += ticks;
    idx++;
}

void trace_init(void) {
    if (trace_log) {
        for (long i = 0; i<idx; i++) {
            if (trace_log[i].dis) free(trace_log[i].dis);
        }
        free(trace_log);
        trace_log = NULL;
    }
    myticks = idx = nentries = 0;
}

void trace_on(void) {
    puts("trace: enabled");
    trace = true;
}

void trace_off(void) {
    puts("trace: disabled");
    trace = false;
}

bool trace_status(void) {
    if (trace) trace_on();      // print stuff
    else trace_off();
    return trace;
}

void trace_save(char *filename) {
    char *name = "osiemu-trace.txt";
    if (filename) name = filename;
    FILE *f = fopen(name, "wb");
    if (!f) {
        printf("trace: unable to open %s for writing\n", name);
        return;
    }
    for (long i = 0; i < idx; i++) {
        char buf[64];
        snprintf(buf, 64, "%12.0f: A=%02x X=%02x Y=%02x SP=%02x P=%s PC=",
                trace_log[i].tick,
                trace_log[i].a,
                trace_log[i].x,
                trace_log[i].y,
                trace_log[i].sp,
                Ptostring(trace_log[i].p));
        fputs(buf, f);
        fputs(trace_log[i].dis, f);
        fputs("\r\n", f);
    }
    fclose(f);
    printf("trace: log written to %s\n", name);
}

void trace_stack_on(void) {
    trace_stack = true;
    puts("trace stack: on");
}

void trace_stack_off(void) {
    trace_stack = false;
    puts("trace stack: off");
}

bool trace_stack_status(void) {
    if (trace_stack) trace_stack_on();
    else             trace_stack_off();
    return trace_stack;
}

void trace_stack_tick(void) {
    if (!trace_stack) return;

    uint8_t opcode = read6502(PC);
    uint8_t sp = SP;

    switch (opcode) {
    case 0x20:          // JSR
        stack_items[sp]   = TYPE_MSB;
        stack_items[sp-1] = TYPE_LSB;
        stack_pcs[sp]   = PC;
        stack_pcs[sp-1] = PC;
        break;
    case 0x48:          // PHA
        stack_items[sp] = TYPE_PHA;
        stack_pcs[sp]   = PC;
        break;
    case 0x08:          // PHP
        stack_items[sp] = TYPE_PHP;
        stack_pcs[sp]   = PC;
        break;
    case 0xda:          // PHX
        stack_items[sp] = TYPE_PHX;
        stack_pcs[sp]   = PC;
        break;
    case 0x5a:          // PHY
        stack_items[sp] = TYPE_PHY;
        stack_pcs[sp]   = PC;
        break;
    }
}

void trace_stack_show(void) {
    for (int i=SP+1; i <= 0xff; i++) {
        switch (stack_items[i]) {
        case TYPE_UNKNOWN:
            printf("%02x: %02x (unknown)\n", i, read6502(0x0100+i));
            break;
        case TYPE_LSB:
            if (i != 0xff) {
                uint16_t ra = (read6502(0x0101+i) << 8) | read6502(0x0100+i);
                printf("%02x: %04x (return address: %04x) (by PC=%04x)\n", i, ra, ra+1, stack_pcs[i]);
                i++;        // extra increment
            } else {
                printf("%02x: %02x (LSB) (by PC=%04x)\n", i, read6502(0x0100+i), stack_pcs[i]);
            }
            break;
        case TYPE_MSB:
            printf("%02x: %02x (MSB) (by PC=%04x)\n", i, read6502(0x0100+i), stack_pcs[i]);
            break;
        case TYPE_PHA:
            printf("%02x: %02x (ACCU) (by PC=%04x)\n", i, read6502(0x0100+i), stack_pcs[i]);
            break;
        case TYPE_PHP:
            printf("%02x: %02x (FLAGS) (by PC=%04x)\n", i, read6502(0x0100+i), stack_pcs[i]);
            break;
        case TYPE_PHX:
            printf("%02x: %02x (X register) (by PC=%04x)\n", i, read6502(0x0100+i), stack_pcs[i]);
            break;
        case TYPE_PHY:
            printf("%02x: %02x (Y register) (by PC=%04x)\n", i, read6502(0x0100+i), stack_pcs[i]);
            break;
        }
    }
}
