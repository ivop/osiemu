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

#include "monitor.h"
#include "video.h"
#include "disasm.h"

static struct distabitem *distab = distabNMOS6502;

// ----------------------------------------------------------------------------

static void help(void) {
    puts("commands: (all values are in hexadecimal)\n"
           "h,help          - print this help\n"
           "q,quit          - exit emulator\n"
           "cont            - continue emulation\n"
           "show            - show emulation window\n"
           "hide            - hide emulation window\n"
           "regs            - show CPU registers\n"
           "setcpu type     - set CPU type to nmos|undef|cmos\n"
           "setbp mem       - set breakpoint\n"
           "clrbp           - clear breakpoint\n"
           "d [mem]         - dump memory contents\n"
           "c mem val ...   - change memory to value(s)\n"
           "u [mem]         - unassemble memory"
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
    puts("usage: c mem val ...");
}

// ----------------------------------------------------------------------------

static void regs(void) {
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

static void do_setcpu(char *cputype) {
    printf("CPU type set to ");
    if (!strcmp(cputype, "undef")) {
        distab = distabNMOS6502UNDEF;
        puts("NMOS w/ undefined opcodes");
    } else if (!strcmp(cputype, "cmos")) {
        distab = distabCMOS65C02;
        puts("CMOS");
    } else {
        distab = distabNMOS6502;
        puts("NMOS");
    }
}

static void setcpu(void) {
    char *p = strtok(NULL, " \t\n\r");
    if (!p) {
        puts("usage: setcpu (nmos|undef|cmos)");
    } else {
        do_setcpu(p);
    }
}

// ----------------------------------------------------------------------------

static void unassemble(void) {
    static uint16_t loc;
    char *p = strtok(NULL, " \t\n\r");

    if (p) {
        loc = strtol(p, NULL, 16);
    }

    int lines = 0;
    while (lines < 23) {
        printf("%04x: ", loc);

        int opcode = read6502(loc++);
        printf("%02x ", opcode);

        int mode = distab[opcode].mode;

        int n = isizes[mode];
        int operand, operand2 = 0;
        
        if (n > 1) {
            operand = read6502(loc++);
            printf("%02x ", operand);

            if (n > 2) {
                int t = read6502(loc++);
                operand |= t << 8;
                printf("%02x ", t);
            } else {
                printf("   ");
            }
        } else {
            printf("      ");
        }

        if (mode == MODE_REL) {
            operand += loc - (operand & 0x80 ? 0x100 : 0);
        } else if (mode == MODE_ZP_REL) {
            operand2 = operand >> 8;
            operand &= 0xff;
            operand2 += loc - (operand2 & 0x80 ? 0x100 : 0);
        }

        printf("    %s ", distab[opcode].inst);
        printf(fmts[mode], operand, operand2);
        putchar('\n');
        lines++;
    }
}

// ----------------------------------------------------------------------------

static uint16_t bp;
static bool bp_enable;

// ----------------------------------------------------------------------------

static void setbp(void) {
    char *p = strtok(NULL, " \t\n\r");

    if (!p) {
        puts("usage: setbp mem");
        return;
    }

    bp = strtol(p, NULL, 16);
    printf("breakpoint set at PC=%04x\n", bp);
    bp_enable = true;
}

// ----------------------------------------------------------------------------

static void clrbp(void) {
    bp_enable = false;
}

// ----------------------------------------------------------------------------

bool monitor_checkbp(void) {
    bool ret = true;
    if (PC == bp) {
        screen_hide();
        puts("BREAKPOINT ENCOUNTERED");
        ret = monitor();
        screen_unhide();
    }
    return ret;
}

// ----------------------------------------------------------------------------

bool monitor(void) {
    char *lineptr = NULL;
    size_t size = 0;

    signal(SIGINT, SIG_IGN);

    puts("MONITOR");
    regs();

    while (1) {
        printf(">");

        if (getline(&lineptr, &size, stdin) < 0) {
            printf("EOF\n");
            return false;
        }
    
        char *p = strtok(lineptr, " \t\n\r");

        if (!p) continue;

        if (!strcmp(p, "quit") || !strcmp(p, "q")) {
            return false;
        } else if (!strcmp(p, "cont")) {
            return true;
        } else if (!strcmp(p, "help") || !strcmp(p, "h")) {
            help();
        } else if (!strcmp(p, "hide")) {
            screen_hide();
        } else if (!strcmp(p, "show")) {
            screen_unhide();
            screen_update();
        } else if (!strcmp(p, "d")) {
            dump();
        } else if (!strcmp(p, "c")) {
            change();
        } else if (!strcmp(p, "regs")) {
            regs();
        } else if (!strcmp(p, "setcpu")) {
            setcpu();
        } else if (!strcmp(p, "u")) {
            unassemble();
        } else if (!strcmp(p, "setbp")) {
            setbp();
        } else if (!strcmp(p, "clrbp")) {
            clrbp();
        } else {
            puts("huh?");
        }
    }

    signal(SIGINT, SIG_DFL);
    return true;
}

// ----------------------------------------------------------------------------

