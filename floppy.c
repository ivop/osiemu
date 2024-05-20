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
#include <sys/mman.h>
#include "portability.h"
#include "floppy.h"
#include "acia.h"

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

enum osi_disk_type {
    TYPE_525_SS,
    TYPE_8_SS
};

static int disk_type = -1;

struct drive {
    FILE *f;
    char *fname;
    off_t offset;
    char *map;

    unsigned int pos;
    uint8_t bit;
    uint8_t curbyte;

    unsigned int curtrk;
    bool ready;
    bool r_w;
};

struct drive drives[2];
static int curdrive;

static double floppy_ticks;
static double interval;

static unsigned int ntracks;
static unsigned int trksize;
static double rpm;
static double bitrate;
static double hole_length;      // time of index hole in ms (5.0 or 5.5)
static double seek_time;        // track-to-track seek time in ms (3.0)

static int bits_counter;
static int seek_counter;
static int bits_per_hole;
static int bits_per_seek;
static int bits_per_revolution;
static bool hole;

// ----------------------------------------------------------------------------

#define DATA_DIRECTION_ACCESS   0x04        // bit 2, 0 active(!)

// PORTA input bits  (PA6 can be output)

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
#define DRIVE_ENABLE_MASK       0x20        // 0 = drive off, 1 = drive on
#define LOW_CURRENT_MASK        0x40        // 0 = high?, 1 = low
#define HEAD_NOT_ON_DISK_MASK   0x80        // 0 = head on disk, 1 = lift head

// ----------------------------------------------------------------------------

// Framing state-machine

enum acia_state_e {
    STATE_WAIT_FOR_STARTBIT,
    STATE_COLLECT_DATABITS,
    STATE_READ_PARITY,
    STATE_READ_STOPBIT1,
    STATE_READ_STOPBIT2
};

enum acia_state_e acia_state = STATE_WAIT_FOR_STARTBIT;

// ----------------------------------------------------------------------------

static bool login_drive(struct drive *d) {
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

    d->offset = fgetc(d->f) * 256;
    d->curtrk = 7;                  // just somewhere not track 0
    d->pos = d->bit = 0;
    d->ready = true;
    d->r_w = true;

    printf("floppy: inserted disk %s\n", d->fname);

    return true;
}

// ----------------------------------------------------------------------------

static bool init_memory_mapped_io(struct drive *d) {
    fseek(d->f, 0, SEEK_END);
    long filesize = ftell(d->f);
    fseek(d->f, 0, SEEK_SET);

    int fd = fileno(d->f);

    d->map = mmap(NULL, filesize, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if (d->map == (void*)-1) {
        perror("floppy: mmap failed!");
        return false;
    }
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
            if (!login_drive(&drives[i])) {
                return false;
            }
        }
    }

    if (!(drives[0].f || drives[1].f)) {
        puts("floppy: disabled");
        return true;
    }

    switch (disk_type) {
    case TYPE_525_SS:
        ntracks = 40;
        trksize = 0x0d00;
        rpm = 300;
        bitrate = 125000.0;
        hole_length = 5.5;
        seek_time = 3.0;
        break;
    case TYPE_8_SS:
        ntracks = 77;
        trksize = 0x1500;
        rpm = 360;
        bitrate = 250000.0;
        hole_length = 5.0;
        seek_time = 3.0;
        break;
    }

    for (int i=0; i<=1; i++) {
        if (drives[i].f) {
            if (!init_memory_mapped_io(&drives[i])) {
                return false;
            }
        }
    }

    interval = cpu_clock / bitrate;
    bits_per_hole = bitrate / 1000 * hole_length;
    bits_per_seek = bitrate / 1000 * seek_time;
    bits_per_revolution = bitrate / (rpm / 60.0);

    printf("floppy: type %s\n", disk_type ? "8\" SS" : "5\" SS");
    printf("floppy: number of tracks: %d\n", ntracks);
    printf("floppy: bit interval %.2lf ticks\n", interval);
    printf("floppy: bits per index hole: %d (%.2lf ms)\n", bits_per_hole,
                                                           hole_length);
    printf("floppy: bits per track-to-track seek: %d (%.2lf ms)\n",
                                              bits_per_seek, seek_time);
    printf("floppy: bits per revolution: %d\n", bits_per_revolution);

    bits_counter = 0;

    pia.porta.output_value = 0xff;      // for drivesel bit out (PA6)
    curdrive = 0;

    floppy_enable = true;
    puts("floppy: enabled");

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
    unreachable();
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
    switch (address & 1) {
    case 0:
        return 0;
        break;
    case 1:
        return 0;
        break;
    }
    unreachable();
}

// ----------------------------------------------------------------------------

void floppy_acia_write(uint16_t address, uint8_t value) {
}

// ----------------------------------------------------------------------------

static bool get_bit(struct drive *d) {
    if (!d->bit) {
        d->curbyte = d->map[d->offset + d->curtrk*trksize + d->pos];
        d->bit = 0x80;
        d->pos++;
    }

    bool x = d->curbyte & d->bit;
    d->bit >>= 1;
    return x;
}

// ----------------------------------------------------------------------------

void floppy_tick(double ticks) {
    if (!floppy_enable) {
        return;
    }

    if (!(pia.portb.output_value & DRIVE_ENABLE_MASK)) {
        return;
    }

    floppy_ticks += ticks;
    if (floppy_ticks < interval) {
        return;
    }

    floppy_ticks -= interval;

    if (bits_counter < bits_per_hole) {
        hole = true;
    } else {
        hole = false;
    }

    bits_counter++;
    if (bits_counter >= bits_per_revolution) {
        bits_counter = 0;
        drives[curdrive].pos = drives[curdrive].bit = 0;   // reset to start
    }

    if (bits_counter < bits_per_hole) {
        hole = true;
    } else {
        hole = false;
    }

    if (seek_counter) {     // do nothing during track-to-track seek
        seek_counter--;
        return;
    }

    if (pia.portb.output_value & HEAD_NOT_ON_DISK_MASK) {
        return;
    }

    // collect serial framed bits and pass on to ACIA

    bool bit = get_bit(&drives[curdrive]);

    //printf("floppy: bit: %x\n", bit);

    switch (acia_state) {
    case STATE_WAIT_FOR_STARTBIT:
        if (bit) break;
        acia_state = STATE_COLLECT_DATABITS;
        // set some value to 8 or whatever was selected and count down later
        break;
    case STATE_COLLECT_DATABITS:
        // if all bits are collected, acia_state = STATE_READ_PARITY
        // if parity, acia_state = STATE_READ_PARITy
        // else acia_state = STATE_READ_STOPBIT1
        break;
    case STATE_READ_PARITY:
        // if (bit != calculated_parity) set PE
        acia_state = STATE_READ_STOPBIT1;
        break;
    case STATE_READ_STOPBIT1:
        if (!bit) break;        // set framing error
        acia_state = STATE_WAIT_FOR_STARTBIT;   // or STOPBIT2
        // if last framing bit, copy byte to RDR and set RDRF
        break;
    case STATE_READ_STOPBIT2:
        if (!bit) break;        // set framing error
        acia_state = STATE_WAIT_FOR_STARTBIT;
        // copy byte to RDR and set RDRF
        break;
    }
}

// ----------------------------------------------------------------------------
