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
#include <getopt.h>
#include "fake6502/fake6502.h"

// ----------------------------------------------------------------------------

static uint8_t RAM[0xa000];         // 40kB RAM
static uint8_t BASIC[0x2000];       // 8kB BASIC ROM
static uint8_t SCREEN[0x0800];      // 2kB Video RAM
static uint8_t COLOR[0x0800];       // 2kB Color RAM
static uint8_t KERNEL[0x1000];      // 4kB Kernel ROM

static uint16_t kernel_bottom = 0xf000;

static char *basic_filename = "basic/basic-osi.rom";
static char *kernel_filename = "kernel/synmon-alt.rom";

// ----------------------------------------------------------------------------

// Memory Map:
//
// 0000-9fff    RAM
//
// a000-bfff    BASIC ROM
//
//              Model 470 disk controller board
// c000-c00f    PIA for disk I/O
// c010-c01f    ACIA for disk I/O
//
// cf00-cf1f    Up to 16 ACIA's (Model 550 serial port board)
//              used by multishare system and C3s
//
// d000-d7ff    Screen RAM  (32x32 or 64x32, stride is always 64)
// de00         video mode:
//              write:
//                  bit 0, 1=32, 0=64
//                  bit 1, 1=tone on (642 keyboard)
//                  bit 2, 1=color on
//                  bit 3, 1=enable 38-40kHz AC Home control output
//              read:
//                  bit 7 toggles at 1/120th of a second (duty cycle is 60Hz)
//
// df00         Polled Keyboard (Model 542/542B or Model 600/600D (inverted))
// df01         R2R DAC output, or tone generator at 49152/value Hz
//
// e000-e7ff    Color RAM
//
// f000-ffff    Kernel ROM
//
// f000-ffff    some pages might contain another peripheral
//              if fcxx is ACIA, page fc is mapped to f4
//
// fcxx         ACIA, Model 502's cassette interface

// ----------------------------------------------------------------------------

// dfxx --> polled keyboard, Model 542/542B or Model 600/600D (inverted)

uint8_t read6502(uint16_t address) {
    if (address < 0xa000)
        return RAM[address];
    if (address < 0xc000)
        return BASIC[address - 0xa000];
    if (address >= 0xd000 && address <= 0xd7ff)
        return SCREEN[address - 0xd000];
    if (address >= 0xe000 && address <= 0xe7ff)
        return COLOR[address - 0xe000];
    if (address >= kernel_bottom)
        return KERNEL[address - 0xf000];

    return 0xff;
}

void write6502(uint16_t address, uint8_t value) {
    if (address < 0xa000)
        RAM[address] = value;
    if (address >= 0xd000 && address <= 0xd7ff)
        SCREEN[address - 0xd000] = value;
    if (address >= 0xe000 && address <= 0xe7ff)
        SCREEN[address - 0xe000] = value;
}

// ----------------------------------------------------------------------------

// Load binary data into *buf
// If filesize > size, truncate.
// If filesize < size, prepend with zeroes, i.e. loaded data is at the end
// of the buffer.
// Return false if file I/O failed.
//
static bool load_file(uint8_t *buf, int size, char *filename, bool iskernel) {
    printf("loading %s\n", filename);
    FILE *f = fopen(filename, "rb");
    if (!f) {
        fprintf(stderr, "error: %s: unable to open\n", filename);
        return false;
    }

    fseek(f, 0, SEEK_END);
    int filesize = ftell(f);

    if (filesize > size) {
        fprintf(stderr, "warning: %s is larger than buffer size %d, "
                        "truncating...\n", filename, size);
        filesize = size;
    }

    int offset = size - filesize;

    memset(buf, 0, offset);

    fseek(f, 0, SEEK_SET);
    if (fread(buf + offset, 1, filesize, f) != filesize) {
        fprintf(stderr, "error: %s: read error\n", filename);
        return false;
    }

    fclose(f);

    if (iskernel) kernel_bottom = 0xf000 + offset;
    return true;
}

// ----------------------------------------------------------------------------

static void usage(void) {
    fprintf(stderr, "usage: ./osiemu [options]\n\n"
"options:\n"
"\n"
"    -b/--basic filename.rom    specify BASIC ROM\n"
"    -k/--kernel filename.rom   specify kernel ROM\n"
"\n"
"    -h/--help                  show usage information\n"
);
}

// ----------------------------------------------------------------------------

static struct option long_options[] = {
    { "help",       no_argument,        0, 'h' },
    { "basic",      required_argument,  0, 'b' },
    { "kernel",     required_argument,  0, 'k' },
};

int main(int argc, char **argv) {
    int option, index, cycles;

    while ((option = getopt_long(argc, argv, "hb:k:",
                                 long_options, &index)) != -1) {
        switch (option) {
        case 0:
            printf("long option %s with argument %s\n",
                    long_options[index].name, optarg);
            break;
        case 'b':
            basic_filename = strdup(optarg);
            break;
        case 'k':
            kernel_filename = strdup(optarg);
            break;
        case 'h':
            usage();
            return 1;
        case ':':
        case '?':
            return 1;
        }
    }

    if (!load_file(BASIC, 8192, basic_filename, false)) return 1;
    if (!load_file(KERNEL, 4096, kernel_filename, true)) return 1;

    if (optind != argc) {
        fprintf(stderr, "error: wrong command line arguments\n");
        return 1;
    }

    reset6502();
    while (cycles < 1000000) {
        cycles += step6502();
    }
}