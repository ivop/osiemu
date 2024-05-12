/*
 * hfe2osi
 *
 * Convert HFE to OSI Bitstream
 * Includes all the 8E1 and 8N1 framing and zeroes for timing.
 * This stream will be sent directly to the ACIA at the selected bitrate
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>

static struct picfileformatheader {
    uint8_t  id[8];
    uint8_t  version;
    uint8_t  ntracks;
    uint8_t  nsides;
    uint8_t  encoding;
    uint16_t bitrate;
    uint16_t rpm;
    uint8_t  interface;
    uint8_t  dnu;
    uint16_t offset;
    uint8_t  r_w;
    // v1.1 additions
    uint8_t single_step;
    uint8_t track0s0_altencoding;
    uint8_t track0s0_encoding;
    uint8_t track0s1_altencoding;
    uint8_t track0s1_encoding;
} ph;

static struct pictracklut {
    uint16_t offset;
    uint16_t length;
} phlut[256];

static struct osibitstream {
    uint8_t id[16];
    uint8_t version;
    uint8_t type;
    uint8_t offset;
} oh;

enum osi_disk_type {
    TYPE_525_SS,
    TYPE_8_SS
};

static FILE *inp, *outp;
static uint8_t *trkbuf;
static unsigned int ntracks;
static unsigned int trksize;
static int opos;
static uint8_t obit;

static void put_bit(bool bit) {
    if (!obit) {
        obit = 0x80;
        opos++;
    }
    if (bit) {
        trkbuf[opos] |= obit;
    } else {
        trkbuf[opos] &= ~obit;
    }
    obit >>= 1;
}

static uint8_t *phtrkbuf;
static uint8_t phbyte, phhalf;
static int phpos;

static bool get_bit(void) {
    bool x;
    if (!phhalf) {
        phbyte = phtrkbuf[phpos] & 0x0f;
        phhalf = 1;
    } else {
        phbyte = phtrkbuf[phpos] >> 4;
        phpos++;
        phhalf = 0;
    }
    if (phbyte == 0x0a) return 1;
    else if (phbyte == 0x02) return 0;
    else if (phbyte == 0x00) return 0;
    else {
        fprintf(stderr, "weird bit %x\n", phbyte);
        exit(1);
    }
}

static void fixLE16(void *p) {
#ifdef ENABLE_BIG_ENDIAN
    uint8_t *q = p, t;
    t = q[0];
    q[0] = q[1];
    q[1] = t;
#else
#endif
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "error: usage: hfe2osi input.hfe output.osi\n");
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

    if (fread(&ph, sizeof(ph), 1, inp) != 1) {
        fprintf(stderr, "error reading %s\n", argv[1]);
        return 1;
    }

    fixLE16(&ph.bitrate);
    fixLE16(&ph.rpm);
    fixLE16(&ph.offset);

    if (strncmp(ph.id, "HXCPICFE", 8)) {
        fprintf(stderr, "error: %s is not a HXCPICFE file\n", argv[1]);
        return 1;
    }

    printf("number of tracks: %d\n", ph.ntracks);
    printf("number of sides: %d\n", ph.nsides);
    printf("bitrate: %d\n", ph.bitrate);
    printf("rpm: %d\n", ph.rpm);

    if (ph.encoding != 0xff) {
        fprintf(stderr, "error: expected encoding 0xff\n");
        return 1;
    }

    oh.version = 1;
    oh.offset  = 1;
    // OSIHFE outputs double sided for single sided disks
    if (ph.ntracks == 40 && ph.nsides == 2 && ph.bitrate == 250 && ph.rpm == 300) {
        printf("detected 5.25\", 40 tracks, 125kbps\n");
        oh.type = TYPE_525_SS;
        ntracks = 40;
        trksize = 0x0d00;
    } else if (ph.ntracks == 70 && ph.nsides == 2 && ph.bitrate == 500 && ph.rpm == 360) {
        printf("detected 8\", 77 tracks, 250kbps\n");
        oh.type = TYPE_8_SS;
        trksize = 0x1500;
    } else {
        printf("unknown format detected\n");
        return 1;
    }

    fseek(inp, ph.offset * 0x0200, SEEK_SET);
    if (fread(phlut, 1024, 1, inp) != 1) {
        fprintf(stderr, "error: reading LUT\n");
        return 1;
    }
    for (int i=0 ; i<256; i++) {
        fixLE16(&phlut[i].offset);
        fixLE16(&phlut[i].length);
    }

    memcpy(oh.id, "OSIDISKBITSTREAM", 16);
    fwrite(&oh, sizeof(oh), 1, outp);
    for (int i=0; i<256-sizeof(oh); i++)        // pad header with 0xff
        fputc(0xff, outp);

    trkbuf = malloc(trksize);
    if (!trkbuf) {
        fprintf(stderr, "error: out of memory\n");
        return 1;
    }

    for (int i=0; i<ntracks; i++) {
        memset(trkbuf, 0xff, trksize);

        int length = ((phlut[i].length+511)/512)*512;
        uint8_t *p = phtrkbuf = realloc(phtrkbuf, length);

        fseek(inp, phlut[i].offset*0x0200, SEEK_SET);

        while (length) {
            if (fread(p, 256, 1, inp) != 1) {
                fprintf(stderr, "error: reading from %s\n", argv[1]);
                return 1;
            }
            for (int x=0; x<256; x++)
                fgetc(inp);
            p+=256;
            length -= 512;
        }

        phpos = phhalf = opos = 0;
        obit = 0x80;

        while (phpos < phlut[i].length/2 && opos < trksize) {
            put_bit(!get_bit());                 // bitstream is inverted
        }

        if (fwrite(trkbuf, trksize, 1, outp) != 1) {
            fprintf(stderr, "error: writing to %s\n", argv[2]);
            return 1;
        }
    }

    fclose(inp);
    fclose(outp);
}
