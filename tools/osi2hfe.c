/*
 * osi2hfe
 *
 * Convert OSI DIsk Bitstream to HFE
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include "hfe.h"
#include "osi.h"

static struct picfileformatheader ph;
static struct pictracklut phlut[256];
static struct osibitstream oh;

static FILE *inp, *outp;
static uint8_t *trkbuf;
static unsigned int ntracks;
static unsigned int trksize;        // in bytes

static unsigned int outtrksize;     // in 512 byte blocks
static unsigned char *track;

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "error: usage: osi2hfe input.os[58]\n");
        return 1;
    }

    inp = fopen(argv[1], "rb");
    if (!inp) {
        fprintf(stderr, "error: unable to open %s\n", argv[1]);
        return 1;
    }
    outp = fopen(argv[2], "wb");
    if (!outp) {
        fprintf(stderr, "error: unable to open %s\n", argv[2]);
        return 1;
    }

    if (fread(&oh, sizeof(oh), 1, inp) != 1) {
        fprintf(stderr, "error reading %s\n", argv[1]);
        return 1;
    }

    if (strncmp(oh.id, "OSIDISKBITSTREAM", 16)) {
        fprintf(stderr, "error: %s is not an OSI Disk Bitstream\n", argv[1]);
        return 1;
    }

    if (oh.version > 1) {
        fprintf(stderr, "error: osi: unsupported version %d\n", oh.version);
        return 1;
    }

    memset(&ph, 0xff, sizeof(ph));

    if (oh.type == TYPE_525_SS) {
        puts("input: 5.25\", 40 tracks, single sided");
        ph.ntracks = ntracks = 40;
        ph.bitrate = 250;
        ph.rpm = 300;
        trksize = 0x0d00;
    } else if (oh.type == TYPE_8_SS) {
        puts("input: 8\", 77 tracks, single sided");
        ph.ntracks = ntracks = 77;
        ph.bitrate = 500;
        ph.rpm = 360;
        trksize = 0x1500;
    } else {
        fprintf(stderr, "error: osi: unknown type %d\n", oh.type);
        return 1;
    }

    ph.nsides = 2;

    printf("output: %d tracks, %d kbps, %d rpm, %d sides\n", ph.ntracks,
                                                             ph.bitrate,
                                                             ph.rpm,
                                                             ph.nsides);
    outtrksize = 2 * ((trksize * 4 + 511) / 512);
    track = malloc(outtrksize);

    if (!track) {
        fprintf(stderr, "error: out of memory\n");
        return 1;
    }

    memcpy(ph.id, "HXCPICFE", 8);
    ph.version = 0;
    ph.encoding = 0xff;
    ph.interface = 0x07;    // generic shugart
    ph.offset = 0x01;       // 1*512 bytes offset to LUT
    ph.dnu = ph.r_w = 0;

    // layout:
    // 512 bytes header
    // 1024 bytes LUT (256*sizeof(struct pictracklut) = 256*4)
    // tracks

    memset(phlut, 0xff, sizeof(phlut));

    // calculate LUT

    // create flux bitstream

    // fix possible Big Endian types

    // write out file
}
