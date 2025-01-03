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
#include "stdlib.h"

// ----------------------------------------------------------------------------

bool floppy_enable;
unsigned int floppy_debug;

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

int disk_type = -1;
struct drive drives[4];

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

static bool write_enable;
static bool erase_enable;
static bool step_to_3976;
static bool drive_01_23;
static bool low_current UNUSED;
static bool head_on_disk;

int floppy_activity;

static char *floppy_type_names[3] = {
    "5.25\" SS",
    "8\" SS",
    "5.25\" or 3.5\" SS"
};

// ACIA

static uint8_t control;
static uint8_t status;
static uint8_t RDR;
static uint8_t TDR;

enum parity_e {
    NO_PARITY,
    EVEN_PARITY,
    ODD_PARITY
};

struct framing {
    uint8_t ndatabits;
    enum parity_e parity;
    bool two_stopbits;
    char *name;
};

static struct framing word_select[8] = {
    { 7, EVEN_PARITY, true,  "7E2" },
    { 7,  ODD_PARITY, true,  "7O2" },
    { 7, EVEN_PARITY, false, "7E1" },
    { 7,  ODD_PARITY, false, "7O1" },
    { 8,   NO_PARITY, true,  "8N2" },
    { 8,   NO_PARITY, false, "8N1" },
    { 8, EVEN_PARITY, false, "8E1" },
    { 8,  ODD_PARITY, false, "8O1" }
};

static uint8_t ndatabits;
static uint8_t rx_curdatabit, tx_curdatabit;
static uint8_t rx_databyte, tx_databyte;

static enum parity_e parity_type;
static bool parity_calc;
static bool two_stopbits;

static bool nRTS;
static bool txirq_enabled;
static bool rxirq_enabled;

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

#define READ_FROM_DISK_MASK     0x01    // nWRITE: 0 = write, 1 = read
#define ERASE_ENABLE_MASK       0x02    // nERASE: 0 = enabled, 1 = disabled
#define DIRECTION_MASK          0x04    // nSTEPDIR: 0 = to trk 39, 1 = to trk 0
#define MOVE_HEAD_MASK          0x08    // nSTEP: 1->0 move, 1 = steady
#define FAULT_RESET_MASK        0x10    // nRESET: 0 = reset, 1 = normal
#define DRIVE_01_23_MASK        0x20    // 0 = drive 2/3, 1 = drive 0/1
#define LOW_CURRENT_MASK        0x40    // mostly 1, 0 on 8" trk >= 44
#define HEAD_NOT_ON_DISK_MASK   0x80    // nHEADLOAD 0 = on disk, 1 = lifted

// ----------------------------------------------------------------------------

// Framing state-machine

enum acia_rx_state_e {
    STATE_WAIT_FOR_STARTBIT,
    STATE_COLLECT_DATABITS,
    STATE_READ_PARITY,
    STATE_READ_STOPBIT1,
    STATE_READ_STOPBIT2
};

enum acia_rx_state_e acia_receive_state = STATE_WAIT_FOR_STARTBIT;

enum acia_tx_state_e {
    STATE_IDLE_OR_WRITE_STARTBIT,
    STATE_WRITE_DATABITS,
    STATE_WRITE_PARITY,
    STATE_WRITE_STOPBIT1,
    STATE_WRITE_STOPBIT2
};

enum acia_tx_state_e acia_transmit_state = STATE_IDLE_OR_WRITE_STARTBIT;

// ----------------------------------------------------------------------------

static bool login_drive(struct drive *d) {
    d->f = fopen(d->fname, "r+b");
    if (!d->f) {
        fprintf(stderr, "floppy: unable to open '%s' for R/W\n", d->fname);
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
        fprintf(stderr, "floppy: wrong disk type\n");
        fprintf(stderr, "floppy: all drives must be of the same type\n");
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
    d->mapsize = filesize;

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
                 char *drive2_filename, char *drive3_filename,
                                                        double cpu_clock) {
    memset(&pia, 0, sizeof(struct pia));
    pia.porta.input_mask = pia.portb.input_mask = 0xff;

    drives[0].fname = drive0_filename;
    drives[1].fname = drive1_filename;
    drives[2].fname = drive2_filename;
    drives[3].fname = drive3_filename;

    for (int i=0; i<=3; i++) {
        if (drives[i].fname) {
            if (!login_drive(&drives[i])) {
                return false;
            }
            if (!init_memory_mapped_io(&drives[i])) {
                return false;
            }
        }
    }

    if (!(drives[0].f || drives[1].f || drives[2].f || drives[3].f)) {
        puts("floppy: disabled");
        return true;
    }

    switch (disk_type) {
    case TYPE_525_SS:
        ntracks = 40;
        trksize = 0x0d00;
        rpm = 300;
        bitrate = 125000.0;
        hole_length = 5.5;          // see doc/disk-format.txt
        seek_time = 3.0;
        break;
    case TYPE_8_SS:
        ntracks = 77;
        trksize = 0x1500;
        rpm = 360;
        bitrate = 250000.0;
        hole_length = 3.0;          // see doc/disk-format.txt
        seek_time = 3.0;
        break;
    case TYPE_80_SD_SS_300:
        ntracks = 80;
        trksize = 0x0d00;
        rpm = 300;
        bitrate = 125000.0;
        hole_length = 1.0;
        seek_time = 3.0;
        break;
    default:
        fprintf(stderr, "floppy: unknown disk format\n");
        return false;
    }

    interval = cpu_clock / bitrate;
    bits_per_hole = bitrate / 1000 * hole_length;
    bits_per_seek = bitrate / 1000 * seek_time;
    bits_per_revolution = bitrate / (rpm / 60.0);

    printf("floppy: type %s\n", floppy_type_names[disk_type]);
    printf("floppy: number of tracks: %d\n", ntracks);
    printf("floppy: bitrate: %.0f\n", bitrate);
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

    setbit(status, STATUS_TDRE_MASK);   // empty
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
    floppy_activity = 25;
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

static void determine_current_drive(void) {
    if (pia.porta.output_mask & DRIVE0_SELECT_MASK) {
        curdrive = !getbit(pia.porta.output_value, DRIVE0_SELECT_MASK);
    } else {
        curdrive = 0;
    }
    if (!drive_01_23) {
        curdrive += 2;
    }
}

// ----------------------------------------------------------------------------

static void act_on_portb_output_value(uint8_t prev_value) {
    uint8_t value = pia.portb.output_value;

    write_enable = !(value & READ_FROM_DISK_MASK);
    erase_enable = !(value & ERASE_ENABLE_MASK);
    step_to_3976 = !(value & DIRECTION_MASK);
    drive_01_23  =   value & DRIVE_01_23_MASK;
    head_on_disk = !(value & HEAD_NOT_ON_DISK_MASK);

    if (floppy_debug > 1) {
        printf("floppy: write = %sabled, erase = %sabled, head = %s\n",
                                    write_enable ? "en" : "dis",
                                    erase_enable ? "en" : "dis",
                                    head_on_disk ? "lowered" : "lifted");
    }

    determine_current_drive();

    bool move_prev = prev_value & MOVE_HEAD_MASK;
    bool move_now  =      value & MOVE_HEAD_MASK;

    if (move_prev && !move_now) {
        if (step_to_3976) {
            if (drives[curdrive].curtrk < ntracks-1) {
                drives[curdrive].curtrk++;
            }
            if (floppy_debug) {
                printf("floppy: seek in, track %d\n", drives[curdrive].curtrk);
            }
        } else {
            if (drives[curdrive].curtrk > 0) {
                drives[curdrive].curtrk--;
            }
            if (floppy_debug) {
                printf("floppy: seek out, track %d\n", drives[curdrive].curtrk);
            }
        }
        seek_counter = seek_time;
    }
}

// ----------------------------------------------------------------------------

void floppy_pia_write(uint16_t address, uint8_t value) {
    floppy_activity = 25;
    switch (address & 3) {
    case 0:     // ORA or DDRA
        if (!(pia.cra & DATA_DIRECTION_ACCESS)) {
            pia.porta.output_mask = value;
            pia.porta.input_mask = ~value;
        } else {
            pia.porta.output_value = value;
            determine_current_drive();
        }
        break;
    case 1:     // CRA
        pia.cra = value;
        break;
    case 2:     // ORB or DDRB
        if (!(pia.crb & DATA_DIRECTION_ACCESS)) {
            pia.portb.output_mask = value;
            pia.portb.input_mask = ~value;
        } else {
            uint8_t prev_value = pia.portb.output_value;
            pia.portb.output_value = value;
            act_on_portb_output_value(prev_value);
        }
        break;
    case 3:     // CRB
        pia.crb = value;
        break;
    }
}

// ----------------------------------------------------------------------------

uint8_t floppy_acia_read(uint8_t address) {
    floppy_activity = 25;
    switch (address & 1) {
    case 0:                 // status register
        return status;
        break;
    case 1:                 // receive register
        clrbit(status, STATUS_RDRF_MASK);
        clrbit(status, STATUS_OVRN_MASK);
        clrbit(status, STATUS_IRQ_MASK);    // cleared on read of RDR
        return RDR;
        break;
    }
    unreachable();
}

// ----------------------------------------------------------------------------

void floppy_acia_write(uint16_t address, uint8_t value) {
    floppy_activity = 25;
    int ws;
    switch (address & 1) {
    case 0:                 // control register
        control = value;
        switch (control & CONTROL_DIV_MASK) {
        case 0:
            break;
        case 1:
            break;
        case 2:
            break;
        case 3:
            if (floppy_debug) puts("floppy: master reset");
            status = 0;
            setbit(status, STATUS_TDRE_MASK);   // empty
            acia_receive_state = STATE_WAIT_FOR_STARTBIT;
            acia_transmit_state = STATE_IDLE_OR_WRITE_STARTBIT;
            rxirq_enabled = false;
            txirq_enabled = false;
            nRTS = false;
            return;
            break;
        }
        ws = (control & CONTROL_WS_MASK) >> WS_SHIFT;
        ndatabits    = word_select[ws].ndatabits;
        parity_type  = word_select[ws].parity;
        two_stopbits = word_select[ws].two_stopbits;

        if (!!(control & CONTROL_RX_IRQE)) rxirq_enabled = true;

        switch ((control & CONTROL_TX_CTRL) >> TXCTRL_SHIFT) {
        case 3:
            // transmit break level omitted
        case 0:
            nRTS = false;
            txirq_enabled = false;
            break;
        case 1:
            nRTS = false;
            txirq_enabled = true;
            break;
        case 2:
            nRTS = true;
            txirq_enabled = false;
            break;
        }
        if (floppy_debug) {
            printf("floppy: select %s\n", word_select[ws].name);
            printf("floppy: txctrl: /RTS = %s, txirq = %sabled\n",
                                            nRTS ? "high" : "low",
                                            txirq_enabled ? "en" : "dis");
            printf("floppy: rxirq = %sabled\n", rxirq_enabled ? "en" : "dis");
        }
        break;
    case 1:                 // transmit register
        TDR = value;
        clrbit(status, STATUS_TDRE_MASK);       // not empty
        clrbit(status, STATUS_IRQ_MASK);        // cleared on write to TDR
        break;
    }
}

// ----------------------------------------------------------------------------

static bool get_bit(struct drive *d) {
    if (!d->bit) {
        d->bit = 0x80;
        d->pos++;
    }

    bool x = d->map[d->offset + d->curtrk*trksize + d->pos] & d->bit;
    d->bit >>= 1;
    return x;
}

static void put_bit(struct drive *d, bool bit) {
    if (!d->bit) {
        d->bit = 0x80;
        d->pos++;
    }
    d->map[d->offset + d->curtrk*trksize + d->pos] &= ~d->bit;
    if (bit) {
        d->map[d->offset + d->curtrk*trksize + d->pos] |=  d->bit;
    }
    d->bit >>= 1;
}

// ----------------------------------------------------------------------------

static void floppy_one_emulation_cycle(void) {
    bits_counter++;
    if (bits_counter >= bits_per_revolution) {
        bits_counter = 0;
        drives[curdrive].pos = drives[curdrive].bit = 0;   // reset to start
    }

    if (!drives[curdrive].f) {      // no floppy loaded
        hole = false;
        return;
    }

    if (bits_counter < bits_per_hole) {
        hole = true;
    } else {
        hole = false;
    }

    if (seek_counter) {     // do nothing during track-to-track seek
        seek_counter--;
        get_bit(&drives[curdrive]);     // drop bit
        return;
    }

    bool rx_bit = 1;

    if (head_on_disk && !write_enable) {
        rx_bit = get_bit(&drives[curdrive]);
    }

    switch (acia_receive_state) {
    case STATE_WAIT_FOR_STARTBIT:
        if (rx_bit) break;
        acia_receive_state = STATE_COLLECT_DATABITS;
        rx_curdatabit = rx_databyte = parity_calc = 0;
        break;
    case STATE_COLLECT_DATABITS:
        rx_databyte |= rx_bit << rx_curdatabit;
        parity_calc ^= rx_bit; // note: ^= because += does not overflow to 0
        rx_curdatabit++;
        if (rx_curdatabit >= ndatabits) {
            if (parity_type > NO_PARITY) {
                acia_receive_state = STATE_READ_PARITY;
            } else {
                acia_receive_state = STATE_READ_STOPBIT1;
            }
        }
        break;
    case STATE_READ_PARITY:
        if (parity_type == EVEN_PARITY && rx_bit != parity_calc) {
            setbit(status, STATUS_PE_MASK);     // parity error
        } else if (parity_type == ODD_PARITY && rx_bit != !parity_calc) {
            setbit(status, STATUS_PE_MASK);     // parity error
        } else {
            clrbit(status, STATUS_PE_MASK);
        }
        acia_receive_state = STATE_READ_STOPBIT1;
        break;
    case STATE_READ_STOPBIT1:
        if (!rx_bit) {
            setbit(status, STATUS_FE_MASK);     // framing error
        } else {
            clrbit(status, STATUS_FE_MASK);
        }
        if (two_stopbits) {
            acia_receive_state = STATE_READ_STOPBIT2;
            break;
        }
        acia_receive_state = STATE_WAIT_FOR_STARTBIT;
        goto copy_byte_to_rdr;
        break;
    case STATE_READ_STOPBIT2:
        if (!rx_bit) {
            setbit(status, STATUS_FE_MASK);     // framing error
        } else {
            clrbit(status, STATUS_FE_MASK);
        }
        acia_receive_state = STATE_WAIT_FOR_STARTBIT;

copy_byte_to_rdr:   // copy byte to RDR and set RDRF
        RDR = rx_databyte;
        if (status & STATUS_RDRF_MASK) {
            setbit(status, STATUS_OVRN_MASK);
        } else {
            clrbit(status, STATUS_OVRN_MASK);
        }
        setbit(status, STATUS_RDRF_MASK);       // new byte available
        if (rxirq_enabled)
            setbit(status, STATUS_IRQ_MASK);
        break;
    }   // end of switch rx state

    bool tx_bit;

    switch (acia_transmit_state) {
    case STATE_IDLE_OR_WRITE_STARTBIT:
        if (status & STATUS_TDRE_MASK) {    // empty
            tx_bit = 1;
        } else {
            tx_curdatabit = parity_calc = 0;
            tx_databyte = TDR;                              // consume byte
            setbit(status, STATUS_TDRE_MASK);               // empty again
            if (txirq_enabled)
                setbit(status, STATUS_IRQ_MASK);
            acia_transmit_state = STATE_WRITE_DATABITS;
            tx_bit = 0;                                     // startbit
        }
        break;
    case STATE_WRITE_DATABITS:
        tx_bit = tx_databyte & (1 << tx_curdatabit);
        parity_calc ^= tx_bit;
        tx_curdatabit++;
        if (tx_curdatabit >= ndatabits) {
            if (parity_type > NO_PARITY) {
                acia_transmit_state = STATE_WRITE_PARITY;
            } else {
                acia_transmit_state = STATE_WRITE_STOPBIT1;
            }
        }
        break;
    case STATE_WRITE_PARITY:
        if (parity_type == EVEN_PARITY) {
            tx_bit = parity_calc;
        } else if (parity_type == ODD_PARITY) {
            tx_bit = !parity_calc;
        }
        acia_transmit_state = STATE_WRITE_STOPBIT1;
        break;
    case STATE_WRITE_STOPBIT1:
        tx_bit = 1;
        if (two_stopbits) {
            acia_transmit_state = STATE_WRITE_STOPBIT2;
        } else {
            acia_transmit_state = STATE_IDLE_OR_WRITE_STARTBIT;
        }
        break;
    case STATE_WRITE_STOPBIT2:
        tx_bit = 1;
        acia_transmit_state = STATE_IDLE_OR_WRITE_STARTBIT;
        break;
    } // end of switch tx state

    if (head_on_disk && write_enable) {
        put_bit(&drives[curdrive], tx_bit);
    }

    if (!head_on_disk) {
        get_bit(&drives[curdrive]);     // drop bit, advance pointers
    }
}

void floppy_tick(double ticks) {
    if (!floppy_enable) {
        return;
    }

    floppy_ticks += ticks;
    while (floppy_ticks >= interval) {      // beware of long 6502 instructions
        floppy_ticks -= interval;
        floppy_one_emulation_cycle();
    }
}

// ----------------------------------------------------------------------------

void floppy_get_current_track_and_drive(int *track, int *drive) {
    *drive = curdrive;
    *track = drives[curdrive].curtrk;
}

// ----------------------------------------------------------------------------

void floppy_unmount(struct drive *d) {
    if (!floppy_enable) return;
    if (d->f) {
        printf("floppy: unmounting %s\n", d->fname);
        munmap(d->map, d->mapsize);
        fclose(d->f);
        d->f = NULL;
        free(d->fname);
        d->fname = NULL;
    }
}

void floppy_mount(struct drive *d, char *filename) {
    if (!floppy_enable) return;
    floppy_unmount(d);
    d->fname = filename;
    if (login_drive(d)) {
        if (init_memory_mapped_io(d)) {
            printf("floppy: mounted '%s'\n", filename);
        }
    }
}

void floppy_quit(void) {
    if (!floppy_enable) return;
    for (int i=0; i<4; i++) floppy_unmount(&drives[i]);
}

// ----------------------------------------------------------------------------
