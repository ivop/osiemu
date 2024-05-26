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
#include "fake6502/fake6502.h"

#include "mmu.h"
#include "keyboard.h"
#include "video.h"
#include "tape.h"
#include "floppy.h"

// ----------------------------------------------------------------------------

uint8_t RAM[0xc000];         // Maximum of 48kB RAM
uint8_t BASIC[0x2000];       // 8kB BASIC ROM
uint8_t KERNEL[0x1000];      // 4kB Kernel ROM

bool mmu_basic_enabled = true;
uint16_t mmu_ram_top = 0x9fff;
uint16_t tape_location = 0xf000;

static uint16_t kernel_bottom;

// ----------------------------------------------------------------------------

// Memory Map:
//
// 0000-7fff    RAM
//
// 8000-9fff    RAM or 256x256 hires 541 (set ram_top to 7ffe)
//
// a000-bfff    BASIC ROM or RAM
//
//              Model 470 disk controller board
// c000-c00f    PIA for disk I/O
// c010-c01f    ACIA for disk I/O
//
// cf00-cf1f    Up to 16 ACIA's (Model 550 serial port board)
//              used by multishare system and C3s
//
// d000-d7ff    Screen RAM 1kB or 2kB
// de00         video mode: model 540B
//              write:
//                  bit 0, 1=32, 0=64
//                  bit 1, 1=tone on (642 keyboard)
//                  bit 2, 1=color on
//                  bit 3, 1=enable 38-40kHz AC Home control output
//              read:
//                  bit 7 toggles at 1/120th of a second (duty cycle is 60Hz)
//
// df00         Polled Keyboard (Model 542/542B or Model 600/600D (inverted))
// df01         ASCII keyboard
// df01         R2R DAC output, or tone generator at 49152/value Hz
//
// e000-e7ff    Color RAM / 2kB 128x128 hires 440B
//
// f000-f0ff    ACIA for tape input
//
// f000-ffff    Kernel ROM, kernel_bottom adjusted by size of kernel ROM
//
// f000-ffff    some pages might contain another peripheral
//              if fcxx is ACIA, page fc is mapped to f4
//
// fcxx         ACIA, Model 502's cassette interface

// ----------------------------------------------------------------------------

uint8_t read6502(uint16_t address) {
    if (address <= mmu_ram_top) {
        return RAM[address];
    }
    if (mmu_basic_enabled) {
        if (address >= 0xa000 && address <= 0xbfff) {
            return BASIC[address - 0xa000];
        }
    }
    if (floppy_enable) {
        if (address >= 0xc000 && address <= 0xc003) {
            return floppy_pia_read(address);
        }
        if (address >= 0xc010 && address <= 0xc011) {
            return floppy_acia_read(address);
        }
    }
    if (video_enabled) {
        if (address >= 0xd000 && address <= 0xd7ff) {
            return screen_read(address);
        }
        if (color_ram_enabled) {
            if (address >= 0xe000 && address <= 0xe7ff) {
                return screen_color_ram_read(address);
            }
        }
        if (hires_mode == HIRES_440B) {
            if (address >= 0xe000 && address <= 0xe7ff) {
                return screen_hires_ram_read(address);
            }
        }
        if (hires_mode == HIRES_541) {
            if (address >= 0x8000 && address <= 0x9fff) {
                return screen_hires_ram_read(address);
            }
        }
    }
    if (keyboard_ascii_enable && address == 0xdf01) {
        return keyboard_ascii_read();
    }
    if ((address & 0xff00) == 0xdf00) {
        return keyboard_read();
    }
    if (address >= kernel_bottom) {
        return KERNEL[address - 0xf000];
    }
    if (address >= tape_location && address <= tape_location+3) {
        return tape_read(address);
    }
//    printf("mmu: unmapped read from $%04x (PC=$%04x)\n", address, PC);
    return 0xff;
}

void write6502(uint16_t address, uint8_t value) {
    if (address <= mmu_ram_top) {
        RAM[address] = value;
        return;
    }
    if (floppy_enable) {
        if (address >= 0xc000 && address <= 0xc003) {
            floppy_pia_write(address, value);
            return;
        }
        if (address >= 0xc010 && address <= 0xc011) {
            floppy_acia_write(address, value);
            return;
        }
    }
    if (video_enabled) {
        if (address >= 0xd000 && address <= 0xd7ff) {
            screen_write(address, value);
            return;
        }
        if (color_ram_enabled) {
            if (address >= 0xe000 && address <= 0xe7ff) {
                screen_color_ram_write(address, value);
                return;
            }
        }
        if (hires_mode == HIRES_440B) {
            if (address >= 0xe000 && address <= 0xe7ff) {
                screen_hires_ram_write(address, value);
                return;
            }
        }
        if (hires_mode == HIRES_541) {
            if (address >= 0x8000 && address <= 0x9fff) {
                screen_hires_ram_write(address, value);
                return;
            }
        }
    }
    if ((address & 0xff00) == 0xdf00) {
        keyboard_write(value);
        return;
    }
    if (address >= tape_location && address <= tape_location+3) {
        tape_write(address, value);
        return;
    }
//    printf("mmu: unmapped write to $%04x ($%02x) (PC=$%04x)\n",
//                                                    address, value, PC);
}

// ----------------------------------------------------------------------------

// Load binary data into *buf
// If filesize > size, truncate.
// If filesize < size, prepend with zeroes, i.e. loaded data is at the end
// of the buffer.
// Return false if file I/O failed.
//
bool mmu_load_file(uint8_t *buf, unsigned int size, char *filename, bool iskernel) {
    printf("loading %s\n", filename);
    FILE *f = fopen(filename, "rb");
    if (!f) {
        fprintf(stderr, "error: %s: unable to open\n", filename);
        return false;
    }

    fseek(f, 0, SEEK_END);
    unsigned long filesize = ftell(f);

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
