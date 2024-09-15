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
