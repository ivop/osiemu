/*
 * osiemu - Ohio Scientific Instruments, Inc. Emulator
 *
 * Copyright © 2024 by Ivo van Poorten
 *
 * This file is licensed under the terms of the 2-clause BSD license. Please
 * see the LICENSE file in the root project directory for the full text.
 */

/* Notes:
 *      PIA emulation is incomplete. No IRQs and CA1/2 and CB1/2.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "floppy.h"

// ----------------------------------------------------------------------------

bool floppy_enable;

struct port {
    uint8_t input_mask;
    uint8_t input_value;
    uint8_t output_mask;
    uint8_t output_value;
};

struct pia {
    uint8_t cra;
    struct port porta;
    uint8_t crb;
    struct port portb;
};

static struct pia pia;

static FILE *drive1 = NULL;
static FILE *drive2 = NULL;

enum osi_disk_type {
    TYPE_525_SS,
    TYPE_8_SS
};

static int disk_type = -1;

struct drive {
    FILE *f;
    char *fname;
    unsigned int ntracks;
    unsigned int trksize;
    unsigned int offset;

    unsigned int curtrk;
    bool ready;
    bool r_w;
};

struct drive drives[2];
static int curdrive;

static double floppy_ticks;
static double interval;

static int bits_done;
static int bits_per_hole;
static int bits_per_revolution;
static bool hole;

// ----------------------------------------------------------------------------

#define DATA_DIRECTION_ACCESS   0x04        // bit 2, 0 active(!)

// PORTA input bits

#define DRIVE0_NOT_READY_MASK   0x01        // 0 = drive0 reads, 1 = not ready
#define HEAD_NOT_TRACK0_MASK    0x02        // 0 = above, 1 = not above
#define DRIVE1_NOT_READY_MASK   0x10        // 0 = drive1 reads, 1 = not ready
#define DISK_R_W_MASK           0x20        // 0 = protected, 1 = r/w
#define DRIVE0_SELECT_MASK      0x40        // 0 = drive1, 1 = drive0
#define NOT_INDEX_HOLE_MASK     0x80        // 0 = above hole, 1 = not above

// PORTB output bits

#define READ_FROM_DISK_MASK     0x01        // 0 = write, 1 = read
#define ERASE_ENABLE_MASK       0x02        // 0 = disabled, 1 = enabled
#define DIRECTION_MASK          0x04        // 0 = to track 39, 1 = to track 0
#define MOVE_HEAD_MASK          0x08        // 1->0 move, 1 = steady
#define FAULT_RESET_MASK        0x10        // 0 = reset, 1 = normal
#define DRIVE_ENABLE_MASK       0x20        // 0 = drive1, 1 = drive0
#define LOW_CURRENT_MASK        0x40        // 0 = high?, 1 = low
#define HEAD_ON_DISK_MASK       0x80        // 0 = head on disk, 1 = lift head

#define setbit(v,msk)   (v) |= (msk)
#define clrbit(v,msk)   (v) &= ~(msk)
#define getbit(v,msk)   (v & (msk))
#define cpybit(v,msk,b) { if (b) setbit(v,msk); else clrbit(v,msk); }

// ----------------------------------------------------------------------------

static bool login_drive(struct drive *d, double cpu_clock) {
    d->f = fopen(d->fname, "r+b");
    if (!d->f) {
        fprintf(stderr, "floppy: unable to open %s for R/W\n", d->fname);
        return false;
    }

    char ID[16];
    if (fread(ID, 16, 1, d->f) != 1) {
        fprintf(stderr, "floppy: error reading disk\n");
        return false;
    }
    if (memcmp(ID, "OSIDISKBITSTREAM", 16)) {
        fprintf(stderr, "floppy: not an OSI Disk Bitstream\n");
        return false;
    }

    int version = fgetc(d->f);
    if (version != 1) {
        fprintf(stderr, "floppy: unsupported version %d\n", version);
        return false;
    }

    int type = fgetc(d->f);
    if (disk_type >= 0 && type != disk_type) {
        fprintf(stderr, "floppy: both drives must be of the same type\n");
        return false;
    }
    disk_type = type;

    switch (disk_type) {
    case TYPE_525_SS:
        d->ntracks = 40;
        d->trksize = 0x0d00;
        interval = cpu_clock / 125000.0;
        break;
    case TYPE_8_SS:
        d->ntracks = 77;
        d->trksize = 0x1500;
        interval = cpu_clock / 250000.0;
        break;
    default:
        fprintf(stderr, "floppy: unknown type %d\n", disk_type);
        return false;
    }

    d->offset = fgetc(d->f);
    d->curtrk = 7;                  // just somewhere not track 0
    d->ready = true;
    d->r_w = true;

    printf("floppy: inserted disk %s\n", d->fname);
    printf("floppy: type %s\n", disk_type ? "8\" SS" : "5\" SS");
    printf("floppy: number of tracks: %d\n", d->ntracks);

    return true;
}

// ----------------------------------------------------------------------------

bool floppy_init(char *drive0_filename, char *drive1_filename,
                                                        double cpu_clock) {
    memset(&pia, 0, sizeof(struct pia));
    pia.porta.input_mask = pia.portb.input_mask = 0xff;

    drives[0].fname = drive0_filename;
    drives[1].fname = drive1_filename;

    for (int i=0; i<=1; i++) {
        if (drives[i].fname) {
            if (!login_drive(&drives[i], cpu_clock)) {
                return false;
            }
        }
    }

    if (drives[0].f || drives[1].f) {
        floppy_enable = true;
        printf("floppy: enabled\n");
    }

    pia.porta.output_value = 0xff;      // for drivesel bit out (PA6)
    curdrive = 0;

    setbit(pia.porta.input_value, DRIVE0_NOT_READY_MASK);
    setbit(pia.porta.input_value, DRIVE1_NOT_READY_MASK);
    setbit(pia.porta.input_value, HEAD_NOT_TRACK0_MASK);
    setbit(pia.porta.input_value, DISK_R_W_MASK);
    setbit(pia.porta.input_value, DRIVE0_SELECT_MASK);
    setbit(pia.porta.input_value, NOT_INDEX_HOLE_MASK);

    return true;
}

// ----------------------------------------------------------------------------

static void determine_porta_input_value(void) {
    uint8_t v = 0;      // start with bits cleared

    if (!drives[0].ready) {
        setbit(v, DRIVE0_NOT_READY_MASK);
    }
    if (drives[curdrive].curtrk != 0) {
        setbit(v, HEAD_NOT_TRACK0_MASK);
    }
    if (!drives[1].ready) {
        setbit(v, DRIVE1_NOT_READY_MASK);
    }
    if (drives[curdrive].r_w) {
        setbit(v, DISK_R_W_MASK);
    }
    if (!curdrive) {
        setbit(v, DRIVE0_SELECT_MASK);
    }
    if (!hole) {
        setbit(v, NOT_INDEX_HOLE_MASK);
    }

    pia.porta.input_value = v;
}

// ----------------------------------------------------------------------------

static uint8_t merge_pins(struct port *p) {
    return (p->input_value  & p->input_mask) |
           (p->output_value & p->output_mask);
}

// ----------------------------------------------------------------------------

uint8_t floppy_pia_read(uint16_t address) {
//    printf("floppy: pia read $%04x\n", address);
    switch (address & 3) {
    case 0:     // ORA or DDRA
        if (!(pia.cra & DATA_DIRECTION_ACCESS)) {
            return pia.porta.output_mask;
        } else {
            determine_porta_input_value();
            return merge_pins(&pia.porta);
        }
        break;
    case 1:     // CRA
        return pia.cra;
        break;
    case 2:     // ORB or DDRB
        if (!(pia.crb & DATA_DIRECTION_ACCESS)) {
            return pia.portb.output_mask;
        } else {
            return merge_pins(&pia.portb);
        }
        break;
    case 3:     // CRB
        return pia.crb;
        break;
    }
}

// ----------------------------------------------------------------------------

static void act_on_portb_output_value(void) {
}

// ----------------------------------------------------------------------------

void floppy_pia_write(uint16_t address, uint8_t value) {
//    printf("floppy: pia write $%04x, $%02x\n", address, value);
    switch (address & 3) {
    case 0:     // ORA or DDRA
        if (!(pia.cra & DATA_DIRECTION_ACCESS)) {
            printf("floppy: set porta I/O mask to $%02x\n", value);
            pia.porta.output_mask = value;
            pia.porta.input_mask = ~value;
        } else {
            printf("floppy: porta: output value $%02x\n", value);
            pia.porta.output_value = value;
            if (pia.porta.output_mask & DRIVE0_SELECT_MASK) {
                curdrive = !getbit(value, DRIVE0_SELECT_MASK);
            }
        }
        break;
    case 1:     // CRA
        pia.cra = value;
        break;
    case 2:     // ORB or DDRB
        if (!(pia.crb & DATA_DIRECTION_ACCESS)) {
            printf("floppy: set portb I/O mask to $%02x\n", value);
            pia.portb.output_mask = value;
            pia.portb.input_mask = ~value;
        } else {
            printf("floppy: portb: output value $%02x\n", value);
            pia.portb.output_value = value;
            act_on_portb_output_value();
        }
        break;
    case 3:     // CRB
        pia.crb = value;
        break;
    }
}

// ----------------------------------------------------------------------------

uint8_t floppy_acia_read(uint8_t address) {
}

// ----------------------------------------------------------------------------

void floppy_acia_write(uint16_t address, uint8_t value) {
}

// ----------------------------------------------------------------------------

void floppy_tick(double ticks) {
    if (!floppy_enable) {
        return;
    }

    floppy_ticks += ticks;
    if (floppy_ticks < interval) {
        return;
    }

    floppy_ticks -= interval;
}

// ----------------------------------------------------------------------------
