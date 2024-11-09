/*
 * osi2hfe
 *
 * Convert OSI DIsk Bitstream to HxC HFE
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

static void fixBE16(void *p) {
#ifdef ENABLE_BIG_ENDIAN
    uint8_t *q = p, t;
    t = q[0];
    q[0] = q[1];
    q[1] = t;
#else
#endif
}

static uint8_t fullbyte;
static bool highnib;

static void put_bit(bool bit, FILE *outp) {
    if (!highnib) {
        if (bit) fullbyte = 0x0a;
        else     fullbyte = 0x02;
    } else {
        if (bit) fullbyte |= 0xa0;
        else     fullbyte |= 0x20;
        fputc(fullbyte, outp);
    }
    highnib ^= 1;
}

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
        puts("input: 5.25\", 40 tracks, 125kbps, 300rpm, single sided");
        ph.ntracks = ntracks = 40;
        ph.bitrate = 250;       // clocked output is twice the input
        ph.rpm = 300;
        trksize = 0x0d00;
    } else if (oh.type == TYPE_8_SS) {
        puts("input: 8\", 77 tracks, 250kbps, 360rpm, single sided");
        ph.ntracks = ntracks = 77;
        ph.bitrate = 500;       // clocked output is twice the input
        ph.rpm = 360;
        trksize = 0x1500;
    } else if (oh.type == TYPE_80_SD_SS_300) {
        puts("input: 5.25\" or 3.5\", 80 tracks, 125kbps, 300rpm, single sided");
        ph.ntracks = ntracks = 80;
        ph.bitrate = 250;
        ph.rpm = 300;
        trksize = 0x0d00;
    } else {
        fprintf(stderr, "error: osi: unknown type %d\n", oh.type);
        return 1;
    }

    ph.nsides = 2;

    printf("output: %d tracks, %d kbps, %d rpm, %d sides\n", ph.ntracks,
                                                             ph.bitrate,
                                                             ph.rpm,
                                                             ph.nsides);

    outtrksize = 2 * ((trksize * 4 + 511) / 512);   // 4 bits per bit, 2 sides
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

    for (int i=0; i<ph.ntracks; i++) {
        phlut[i].offset = 0x03 + i * outtrksize;
        phlut[i].length = outtrksize * 512;
    }

    // fix possible Big Endian types

    for (int i=0; i<256; i++) {
        fixBE16(&phlut[i].offset);
        fixBE16(&phlut[i].length);
    }
    fixBE16(&ph.bitrate);
    fixBE16(&ph.rpm);
    fixBE16(&ph.offset);

    // write header and LUT

    fwrite(&ph, sizeof(ph), 1, outp);
    for (int i=0; i<(512-sizeof(ph)); i++)
        fputc(0xff, outp);

    fwrite(phlut, 1024, 1, outp);

    // convert tracks

    fseek(inp, oh.offset * 256, SEEK_SET);

    for (int i=0; i<ph.ntracks; i++) {
        for (int k=0; k<trksize; k+=64) {
            for (int j=0; j<64; j++) {
                int b = fgetc(inp);
                for (uint8_t m = 0x80; m; m>>=1) {
                    bool bit = b & m;
                    put_bit(!bit, outp);
                }
            }
            for (int j=0; j<256; j++) {
                fputc(0x11, outp);
            }
        }
    }

    fclose(inp);
    fclose(outp);
    free(track);
    puts("conversion done.");
}
