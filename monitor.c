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
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <ctype.h>
#include "fake6502/fake6502.h"

#include <SDL.h>

// ----------------------------------------------------------------------------

static void help(void) {
    printf("commands: (all values are in hexadecimal)\n"
           "help            - print this help\n"
           "quit            - exit emulator\n"
           "cont            - continue emulation\n"
           "d mem           - dump memory contents\n"
           "c mem val ...   - change memory to value(s)\n"
          );
}

// ----------------------------------------------------------------------------

static void dump(void) {
    static uint16_t loc;
    char *p = strtok(NULL, " \t\n\r");

    if (p) {
        loc = strtol(p, NULL, 16);
    }

    for (int y=0; y<16; y++) {
        printf("%04x: ", loc + y*16);
        for (int x=0; x<16; x++) {
            printf("%02x ", read6502(loc+y*16+x));
        }
        for (int x=0; x<16; x++) {
            uint8_t c = read6502(loc+y*16+x);
            printf("%c", isprint(c) ? c : '.');
        }
        putchar('\n');
    }

    loc += 256;
}

// ----------------------------------------------------------------------------

static void change(void) {
    char *p = strtok(NULL, " \t\n\r");
    if (!p) goto err_out;

    uint16_t loc = strtol(p, NULL, 16);

    p = strtok(NULL, " \t\n\r");
    if (!p) goto err_out;

    uint8_t val = strtol(p, NULL, 16);
    write6502(loc, val);

    while ((p = strtok(NULL, " \t\n\r"))) {
        val = strtol(p, NULL, 16);
        loc++;
        write6502(loc, val);
    }

    return;

err_out:
    printf("usage: c mem val ...\n");
}

// ----------------------------------------------------------------------------

static void cpu(void) {
    uint8_t status = getP();
    printf("PC=%04x A=%02x X=%02x Y=%02x SP=%04x P=", PC, A, X, Y, SP+0x0100);
    putchar(status & 0x80 ? 'N' : '-');
    putchar(status & 0x40 ? 'V' : '-');
    putchar(status & 0x20 ? '1' : '-');
    putchar(status & 0x10 ? 'B' : '-');
    putchar(status & 0x08 ? 'D' : '-');
    putchar(status & 0x04 ? 'I' : '-');
    putchar(status & 0x02 ? 'Z' : '-');
    putchar(status & 0x01 ? 'C' : '-');
    putchar('\n');
}

// ----------------------------------------------------------------------------

bool monitor(void) {
    char *lineptr = NULL;
    size_t size = 0;

    signal(SIGINT, SIG_IGN);

    printf("MONITOR\n");
    cpu();

    while (1) {
        printf(">");

        if (getline(&lineptr, &size, stdin) < 0) {
            printf("EOF\n");
            return false;
        }
    
        char *p = strtok(lineptr, " \t\n\r");

        if (!p) continue;

        if (!strcmp(p, "quit")) {
            return false;
        } else if (!strcmp(p, "cont")) {
            return true;
        } else if (!strcmp(p, "help")) {
            help();
        } else if (!strcmp(p, "d")) {
            dump();
        } else if (!strcmp(p, "c")) {
            change();
        } else if (!strcmp(p, "cpu")) {
            cpu();
        }
    }

    signal(SIGINT, SIG_DFL);
    return true;
}

// ----------------------------------------------------------------------------

