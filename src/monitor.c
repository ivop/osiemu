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
#include <unistd.h>
#include <fcntl.h>
#include <SDL.h>

#include "fake6502/fake6502.h"
#include "monitor.h"
#include "video.h"
#include "disasm.h"
#include "tape.h"
#include "floppy.h"

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
        int operand = 0, operand2 = 0;
        
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
    if (bp_enable && PC == bp) {
        puts("BREAKPOINT ENCOUNTERED");
        return true;
    }
    return false;
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

    p = strtok(NULL, "\t\n\r");

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

    p = strtok(NULL, "\t\n\r");

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

static void hide(void) {
    screen_hide();
}

// ----------------------------------------------------------------------------

static void tapes(void) {
    printf("tape input: %s\n", tape_input_filename ? tape_input_filename :
                                                                    "<empty>");
    printf("tape output: %s\n", tape_output_filename ? tape_output_filename :
                                                                    "<empty>");
}

static void eject(void) {
    char *p = strtok(NULL, " \t\n\r");

    if (!p) {
err_usage:
        puts("usage: eject input|output");
        return;
    }

    if (!strcmp(p, "input")) {
        tape_eject_input();
    } else if (!strcmp(p, "output")) {
        tape_eject_output();
    } else {
        goto err_usage;
    }
}

static void insert(void) {
    bool output = false;
    char *p = strtok(NULL, " \t\n\r");

    if (!p) {
err_usage:
        puts("usage: eject input|output");
        return;
    }

    if (!strcmp(p, "input")) {
        output = false;
    } else if (!strcmp(p, "output")) {
        output = true;
    } else {
        goto err_usage;
    }

    p = strtok(NULL, "\t\n\r");

    if (!p) goto err_usage;

    if (output) {
        tape_insert_output(strdup(p));
    } else {
        tape_insert_input(strdup(p));
    }
}

static void xrewind(void) {
    char *p = strtok(NULL, " \t\n\r");

    if (!p) {
err_usage:
        puts("usage: rewind input|output");
        return;
    }

    if (!strcmp(p, "input")) {
        tape_rewind_input();
    } else if (!strcmp(p, "output")) {
        tape_rewind_output();
    } else {
        goto err_usage;
    }
}

// ----------------------------------------------------------------------------

static bool check_controller(void) {
    if (disk_type < 0) {
        puts("no drive controller available");
        return false;
    }
    return true;
}

static void xdrives(void) {
    if (!check_controller()) return;
    printf("controller: %s\"\n", disk_type == TYPE_525_SS ? "5.25" : "8");
    for (int i=0; i<4; i++) {
        printf("%d: %s\n", i, drives[i].fname ? drives[i].fname : "<empty>");
    }
}

static int check_drive_number(char *p) {
    int num = atoi(p);
    if (num < 0 || num > 3) {
        puts("invalid drive number");
        return -1;
    }
    return num;
}

static void swap(void) {
    if (!check_controller()) return;

    char *p = strtok(NULL, " \t\n\r");
    if (!p) {
err_usage:
        puts("usage: swap numx numy");
        return;
    }

    int numx = check_drive_number(p);
    if (numx < 0) return;

    p = strtok(NULL, " \t\n\r");

    if (!p) goto err_usage;

    int numy = check_drive_number(p);
    if (numy < 0) return;

    struct drive temp;

    memcpy(&temp, &drives[numx], sizeof(struct drive));
    memcpy(&drives[numx], &drives[numy], sizeof(struct drive));
    memcpy(&drives[numy], &temp, sizeof(struct drive));

    printf("swapped drives %d and %d\n", numx, numy);
}

static void unmount(void) {
    if (!check_controller()) return;

    char *p = strtok(NULL, " \t\n\r");
    if (!p) {
        puts("usage: unmount num");
        return;
    }

    int num = check_drive_number(p);
    if (num < 0) return;

    floppy_unmount(&drives[num]);
}

static void xmount(void) {
    if (!check_controller()) return;

    char *p = strtok(NULL, " \t\n\r");
    if (!p) {
err_usage:
        puts("usage: mount num file");
        return;
    }

    int num = check_drive_number(p);
    if (num < 0) return;

    p = strtok(NULL, "\t\n\r");
    if (!p) goto err_usage;

    floppy_mount(&drives[num], strdup(p));
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
    { "tapes",  tapes,  "",            "list current tape files" },
    { "eject",  eject,  "input|output","eject input or output tape" },
    { "insert", insert, "input|output file", "insert input or output tape" },
    { "rewind", xrewind,"input|output","rewind input or output tape" },
    { "drives", xdrives,"",            "list mounted floppies" },
    { "swap",   swap,   "numx numy",   "swap drives numx and numy" },
    { "unmount",unmount,"num",         "unmount drive" },
    { "mount",  xmount, "num file",    "mount file to drive num" },
    { "", NULL, "", "" }
};

// ----------------------------------------------------------------------------

static void help(void) {
    char temp[26];

    puts("commands: (all values are in hexadecimal)\n"
           "q,quit                   - exit emulator\n"
           "cont                     - continue emulation");

    for (int i=0; commands[i].func; i++) {
        snprintf(temp, 26, "%s %s", commands[i].name, commands[i].args);
        printf("%-25s- %s\n", temp, commands[i].desc);
    }
}

// ----------------------------------------------------------------------------

static void purge_stdin(void) {
    char buf[256];
    int retval, save_fcntl = fcntl(0, F_GETFL);

    fcntl(0, F_SETFL, save_fcntl | O_NONBLOCK);

    do {
        retval = read(0, buf, 256);
    } while (retval > 0);

    fcntl(0, F_SETFL, save_fcntl);
}

// ----------------------------------------------------------------------------

bool monitor(void) {
    int i;
    char *lineptr = NULL;
    size_t size = 0;
    char prev = ' ';

    signal(SIGINT, SIG_IGN);

    puts("MONITOR");
    regs();

    purge_stdin();

    while (1) {
        printf(">");
        fflush(stdout);

        if (getline(&lineptr, &size, stdin) < 0) {
            printf("EOF\n");
            return false;
        }
    
        char *p = strtok(lineptr, " \t\n\r");

        if (!p) {
            if (prev == 'd') {
                dump();
            } else if (prev == 'u') {
                unasm();
            }
            continue;
        }

        if (!strcmp(p, "quit") || !strcmp(p, "q")) {
            return false;
        } else if (!strcmp(p, "cont")) {
            return true;
        }
        for (i=0; commands[i].func; i++) {
            if (!strcmp(p, commands[i].name)) break;
        }
        if (commands[i].func) {
            if (strlen(p) == 1) {
                if (p[0] == 'd' || p[0] == 'u') {
                    prev = p[0];
                };
            } else {
                prev = ' ';
            }
            commands[i].func();
        } else {
            puts("huh?");
        }
    }


    signal(SIGINT, SIG_DFL);
    return true;
}

// ----------------------------------------------------------------------------

