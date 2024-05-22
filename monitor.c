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

static void unasm(void) {
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
    if (bp_enable && PC == bp) {
        screen_hide();
        puts("BREAKPOINT ENCOUNTERED");
        ret = monitor();
        screen_unhide();
    }
    return ret;
}

// ----------------------------------------------------------------------------

static void load(void) {
    uint16_t loc;
    char *p = strtok(NULL, " \t\n\r");

    if (!p) {
err_usage:
        puts("usage: l mem file");
        return;
    }

    loc = strtol(p, NULL, 16);

    p = strtok(NULL, " \t\n\r");

    if (!p) goto err_usage;

    FILE *f = fopen(p, "rb");
    if (!f) {
        printf("error: cannot open '%s'\n", p);
        return;
    }

    int c;

    while ((c = fgetc(f)) >= 0) {
        write6502(loc++, c);
    }

    fclose(f);
}

// ----------------------------------------------------------------------------

static void save(void) {
    uint16_t start, end;
    char *p = strtok(NULL, " \t\n\r");

    if (!p) {
err_usage:
        puts("usage: s start end file");
        return;
    }

    start = strtol(p, NULL, 16);

    p = strtok(NULL, " \t\n\r");

    if (!p) goto err_usage;

    end = strtol(p, NULL, 16);

    p = strtok(NULL, " \t\n\r");

    if (!p) goto err_usage;

    if (start > end) {
        printf("error: start > end\n");
        goto err_usage;
    }

    FILE *f = fopen(p, "wb");

    if (!f) {
        printf("error: cannot open '%s'\n", p);
        return;
    }

    while (start <= end) {
        fputc(read6502(start++), f);
    }

    fclose(f);
}

// ----------------------------------------------------------------------------

static void setpc(void) {
    char *p = strtok(NULL, " \t\n\r");

    if (!p) {
        puts("usage: setpc mem");
        return;
    }

    PC = strtol(p, NULL, 16);
    regs();
}

static void setbyte(uint8_t *byte, char *name) {
    char *p = strtok(NULL, " \t\n\r");

    if (!p) {
        printf("usage: set%s val\n", name);
        return;
    }

    *byte = strtol(p, NULL, 16);
    if (name[0] != 'p') regs();
}

static void seta(void) {
    setbyte(&A, "a");
}

static void setx(void) {
    setbyte(&X, "x");
}

static void sety(void) {
    setbyte(&Y, "y");
}

static void setsp(void) {
    setbyte(&SP, "sp");
}

static void setp(void) {
    uint8_t P, Q = P = getP();
    setbyte(&P, "p");
    if (P != Q) {
        setP(P);
        regs();
    }
}

// ----------------------------------------------------------------------------

static void show(void) {
    screen_unhide();
    screen_update();
}

// ----------------------------------------------------------------------------

static void hide(void) {
    screen_hide();
}

// ----------------------------------------------------------------------------

static void help(void);

static struct command {
    char *name;
    void(*func)(void);
    char *args;
    char *desc;
} commands[] = {
    { "help",   help,   "",            "print this help" },
    { "show",   show,   "",            "show emulation window" },
    { "hide",   hide,   "",            "hide emulation window" },
    { "d",      dump,   "[mem]",       "dump memory contents" },
    { "c",      change, "mem val ...", "change memory to value(s)" },
    { "regs",   regs,   "",            "display CPU registers" },
    { "setcpu", setcpu, "type",        "set CPU type to nmos|undef|cmos" },
    { "u",      unasm,  "[mem]",       "unassemble memory" },
    { "setbp",  setbp,  "mem",         "set breakpoint" },
    { "clrbp",  clrbp,  "",            "clear breakpoint" },
    { "l",      load,   "mem file",    "load raw data from file to mem" },
    { "s",      save,   "beg end file","save raw data to file" },
    { "setpc",  setpc,  "val",         "set PC to value" },
    { "seta",   seta,   "val",         "set A to value" },
    { "setx",   setx,   "val",         "set X to value" },
    { "sety",   sety,   "val",         "set Y to value" },
    { "setsp",  setsp,  "val",         "set SP to value" },
    { "setp",   setp,   "val",         "set P to value" },
    { "", NULL, "", "" }
};

// ----------------------------------------------------------------------------

static void help(void) {
    char temp[21];

    puts("commands: (all values are in hexadecimal)\n"
           "q,quit              - exit emulator\n"
           "cont                - continue emulation");

    for (int i=0; commands[i].func; i++) {
        snprintf(temp, 21, "%s %s", commands[i].name, commands[i].args);
        printf("%-20s- %s\n", temp, commands[i].desc);
    }
}


// ----------------------------------------------------------------------------

bool monitor(void) {
    int i;
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
        }
        for (i=0; commands[i].func; i++) {
            if (!strcmp(p, commands[i].name)) break;
        }
        if (commands[i].func) {
            commands[i].func();
        } else {
            puts("huh?");
        }
    }


    signal(SIGINT, SIG_DFL);
    return true;
}

// ----------------------------------------------------------------------------

