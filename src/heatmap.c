/*
 * osiemu - Ohio Scientific Instruments, Inc. Emulator
 *
 * Copyright © 2024 by Ivo van Poorten
 *
 * This file is licensed under the terms of the 2-clause BSD license. Please
 * see the LICENSE file in the root project directory for the full text.
 */

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include "heatmap.h"

static bool enabled;
static int heatmap_r[65536], heatmap_w[65536];
static uint8_t gradient[1280][3];

static void generate_gradient(void) {
    for (int i = 0; i <= 255; i++) {
        gradient[i][1] = gradient[512+i][0] = gradient[1024+i][2] = i;
        gradient[i][2] = gradient[256+i][1] = gradient[512+i][1] = 
        gradient[768+i][0] = gradient[1024+i][0] = 255;
        gradient[256+i][2] = gradient[768+i][1] = 255 - i;
    }
}

void heatmap_init(void) {
    memset(heatmap_r, 0, sizeof(heatmap_r));
    memset(heatmap_w, 0, sizeof(heatmap_w));
    puts("heatmap: cleared");
}

void heatmap_read(uint16_t address) {
    if (enabled) heatmap_r[address]++;
}

void heatmap_write(uint16_t address) {
    if (enabled) heatmap_w[address]++;
}

void heatmap_enable(void) {
    enabled = true;
    puts("heatmap: enabled");
}

void heatmap_disable(void) {
    enabled = false;
    puts("heatmap: disabled");
}

void heatmap_status(void) {
    if (enabled) heatmap_enable();      // prints status
    else         heatmap_disable();
}

void heatmap_save(char *filename) {
    char *name = "osiemu-heatmap.txt";
    if (filename) name = filename;
    FILE *f = fopen(name, "wb");
    if (!f) {
        printf("heatmap: unable to save to %s\n", name);
        return;
    }
    fprintf(f, "; reads\n");
    for (int i=0; i<65536; i++)
        if (heatmap_r[i])
            fprintf(f, "%d, 0x%04x, %d\n", i, i, heatmap_r[i]);
    fprintf(f, "; writes\n");
    for (int i=0; i<65536; i++)
        if (heatmap_w[i])
            fprintf(f, "%d, 0x%04x, %d\n", i, i, heatmap_w[i]);
    fclose(f);
    printf("heatmap: saved to %s\n", name);
}

void heatmap_image(char *filename) {
    generate_gradient();
    char *name = "osiemu-heatmap.ppm";
    if (filename) name = filename;
    FILE *f = fopen(name, "wb");
    if (!f) {
        printf("heatmap: unable to save image to %s\n", name);
        return;
    }
    fprintf(f, "P6\n256 528\n255\n");
    for (int y=0; y<256; y++) {
        for (int x=0; x<256; x++) {
            int v = heatmap_r[y*256 + x];
            v = v <= 1279 ? v : 1279;
            fprintf(f, "%c%c%c", gradient[v][0], gradient[v][1], gradient[v][2]);
        }
    }
    for (int y=0; y<16; y++)
        for (int x=0; x<256; x++)
            fprintf(f, "%c%c%c", 255, 255, 255);
    for (int y=0; y<256; y++) {
        for (int x=0; x<256; x++) {
            int v = heatmap_w[y*256 + x];
            v = v <= 1279 ? v : 1279;
            fprintf(f, "%c%c%c", gradient[v][0], gradient[v][1], gradient[v][2]);
        }
    }
    fclose(f);
    printf("heatmap: image saved to %s\n", name);
}
