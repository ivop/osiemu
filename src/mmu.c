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
#include <string.h>
#include "fake6502/fake6502.h"

#include "mmu.h"
#include "keyboard.h"
#include "video.h"
#include "tape.h"
#include "floppy.h"
#include "control.h"
#include "sound.h"
#include "heatmap.h"

// ----------------------------------------------------------------------------

static uint8_t RAM[0xc000];         // Maximum of 48kB RAM
static uint8_t RAM_d000[0x1000];    // eXtra RAM (Model 555, $d000-$dfff)
static uint8_t RAM_e000[0x1000];    // eXtra RAM (Model 555, $e000-$efff)
static uint8_t RAM_f000[0x1000];    // eXtra RAM (unofficial, $f000-$ffff)

bool mmu_basic_enabled = true;
uint16_t mmu_ram_top = 0x9fff;
bool mmu_xram_d000_enabled;
bool mmu_xram_e000_enabled;
bool mmu_xram_f000_enabled;

uint8_t BASIC[0x2000];              // 8kB BASIC ROM
uint8_t KERNEL[0x1000];             // 4kB Kernel ROM

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
// d000-d7ff    Screen RAM 1kB or 2kB / 1kB screen + 1kB colors (Model 630)
// d800         Superboard II/Model 600 control register
// de00         Model 54x control register
//              write:
//                  bit 0, 1=64x32, 0=32x32s64
//                  bit 1, 1=tone on (542 keyboard)
//                  bit 2, 1=color on (540 graphics)
//                  bit 3, 1=enable 38-40kHz AC Home control output
//              read:
//                  bit 7 toggles at 1/120th of a second (duty cycle is 60Hz)
//
// df00         Polled Keyboard (Model 542/542B or Model 600/600D (inverted))
// df01         ASCII keyboard
// df01         8R DAC output, or tone generator at 49152/(value+1) Hz
//
// e000-e7ff    Color RAM 540B or 2kB 128x128 hires 440B
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
    heatmap_read(address);
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
        if (address >= screen_ram_bottom && address <= screen_ram_top) {
            return screen_read(address);
        }
        if (color_ram_enabled) {
            if (address >= color_ram_bottom && address <= color_ram_top) {
                return screen_color_ram_read(address);
            }
            if (color_mode == COLORS_540B && address == 0xde00) {
                return screen_control_540b_read(address);
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
    if (mmu_xram_d000_enabled) {
        if (address >= 0xd000 && address <= 0xdfff) {
            return RAM_e000[address & 0x0fff];
        }
    }
    if (mmu_xram_e000_enabled) {
        if (address >= 0xe000 && address <= 0xefff) {
            return RAM_e000[address & 0x0fff];
        }
    }
    if ((address & 0xff00) == 0xdf00) {
        return keyboard_read();
    }
    if (address >= kernel_bottom) {
        return KERNEL[address - 0xf000];
    }
    if (address >= tape_location && address <= tape_location+0xff) {
        return tape_read(address);
    }
    if (mmu_xram_f000_enabled) {
        if (address >= 0xf000 /* && address <= 0xffff */) {
            return RAM_f000[address & 0x0fff];
        }
    }
//    printf("mmu: unmapped read from $%04x (PC=$%04x)\n", address, PC);
    return address >> 8;
}

void write6502(uint16_t address, uint8_t value) {
    heatmap_write(address);
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
        if (address >= screen_ram_bottom && address <= screen_ram_top) {
            screen_write(address, value);
            return;
        }
        if (color_ram_enabled) {
            if (address >= color_ram_bottom && address <= color_ram_top) {
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
    if (mmu_xram_d000_enabled) {
        if (address >= 0xd000 && address <= 0xdfff) {
            RAM_d000[address & 0x0fff] = value;
            return;
        }
    }
    if (mmu_xram_e000_enabled) {
        if (address >= 0xe000 && address <= 0xefff) {
            RAM_e000[address & 0x0fff] = value;
            return;
        }
    }
    if (control_6xx_enable && address == 0xd800) {
        control_6xx_write(address, value);
        return;
    }
    if (control_5xx_enable && address == 0xde00) {
        control_5xx_write(address, value);
        return;
    }
    if (address == 0xdf01 && sound_mode == SOUND_MODE_542B) {
        sound_5xx_write_dac_or_tone(value);
    }
    if ((address & 0xff00) == 0xdf00) {
        keyboard_write(value);
        if (sound_mode == SOUND_MODE_600) {
            sound_6xx_write_dac(value);
        }
        return;
    }
    if (address >= tape_location && address <= tape_location+0xff) {
        tape_write(address, value);
        return;
    }
    if (mmu_xram_f000_enabled) {
        if (address >= 0xf000 /* && address <= 0xffff */) {
            RAM_f000[address & 0x0fff] = value;
            return;
        }
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
bool mmu_load_file(char *heading, uint8_t *buf, unsigned int size, char *filename, bool iskernel) {
    printf("%s: loading %s\n", heading, filename);
    FILE *f = fopen(filename, "rb");
    if (!f) {
        fprintf(stderr, "error: %s: unable to open '%s'\n", heading, filename);
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
