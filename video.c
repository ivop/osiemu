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

#include <SDL.h>
#include <SDL_image.h>

#include "video.h"

// ----------------------------------------------------------------------------

char *font_filename = "chargen/type1.pbm";

uint8_t SCREEN[0x0800];      // 2kB Video RAM
uint8_t COLOR[0x0800];       // 2kB Color RAM

bool video_enabled = true;
bool color_enabled = false;

int zoom = 1, stretchx = 1, stretchy = 1;

int screen_width = 512;
int screen_height = 256;

int osi_width = 64;
int osi_height = 32;

SDL_Window *window;
SDL_Surface *winsurface;
SDL_Surface *screen;
SDL_Surface *font;

enum mono_colors {
    COLOR_GREEN = 0,
    COLOR_AMBER,
    COLOR_WHITE
};

static int colors [][3] = {
    // 540B colors, 600D colors??? Not sure yet how the colors work
    [0] = { 0xff, 0xff, 0xff },     // yellow
    [1] = { 0xff, 0x00, 0x00 },     // red
    [2] = { 0x00, 0xff, 0x00 },     // green
    [3] = { 0x70, 0x82, 0x38 },     // olive
    [4] = { 0x00, 0x00, 0xff },     // blue
    [5] = { 0x80, 0x00, 0x80 },     // purple
    [6] = { 0x87, 0xce, 0xeb },     // sky blue
    [7] = { 0x00, 0x00, 0x00 },     // black
};

static int monochrome[][3] = {
    // mono colors
    [COLOR_GREEN] = { 0x00, 0xff, 0x00 },
    [COLOR_AMBER] = { 0xff, 191, 0 },
    [COLOR_WHITE] = { 0xff, 0xff, 0xff }
};

static int mono_color = COLOR_WHITE;

// ----------------------------------------------------------------------------

static void blit_char(SDL_Surface *s, SDL_Surface *font,
                      int x, int y, unsigned char c, int color) {
    SDL_Rect srcrect = { 0, c*8, 8, 8 };
    SDL_Rect dstrect = { x*8, y*8, 8, 8, };

    SDL_SetSurfaceColorMod(s, monochrome[color][0],
                              monochrome[color][1],
                              monochrome[color][2]);
    SDL_BlitSurface(font, &srcrect, s, &dstrect);
}

// ----------------------------------------------------------------------------

static void blit_screenmem(SDL_Surface *s, SDL_Surface *font) {
    if (!video_enabled) return;

    for (int y = 0; y < osi_height; y++) {
        for (int x = 0; x < osi_width; x++) {
            blit_char(s, font, x, y, SCREEN[x+y*osi_width], mono_color);
        }
    }
}

// ----------------------------------------------------------------------------

static SDL_Surface *load_optimized(SDL_Window *w, char *filename) {
    SDL_Surface *s, *t = NULL;
    if ((s = IMG_Load(filename))) {
        t = SDL_ConvertSurfaceFormat(s, SDL_GetWindowPixelFormat(w), 0);
        SDL_FreeSurface(s);
    } else {
        fprintf(stderr, "error: unable to load %s\n", filename);
    }
    return t;
}

static SDL_Surface *empty_surface(SDL_Window *win, int w, int h) {
    SDL_Surface *s, *t = NULL;
    s = SDL_CreateRGBSurface(0, w, h, 32, 0, 0, 0, 0);
    t = SDL_ConvertSurfaceFormat(s, SDL_GetWindowPixelFormat(win), 0);
    SDL_FreeSurface(s);
    return t;
}

// ----------------------------------------------------------------------------

void screen_update(void) {
    blit_screenmem(screen, font);
    SDL_Rect fillrect = { 0, 0, stretchx * zoom * screen_width,
                                stretchy * zoom * screen_height };
    SDL_BlitScaled(screen, 0, winsurface, &fillrect);
    SDL_UpdateWindowSurface(window);
}

// ----------------------------------------------------------------------------

bool screen_init(void) {
    screen_width = osi_width * 8;
    screen_height = osi_height * 8;

    window = SDL_CreateWindow("OSIEMU",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              stretchx * zoom * screen_width,
                              stretchy * zoom * screen_height,
                              SDL_WINDOW_SHOWN );
    if( window == NULL ) {
        fprintf(stderr,  "error: cannot create window: %s\n", SDL_GetError() );
        return 1;
    }

    if (!(font = load_optimized(window, font_filename))) {
        return false;
    }

    winsurface = SDL_GetWindowSurface(window);
    screen = empty_surface(window, screen_width, screen_height);
    return true;
}

// ----------------------------------------------------------------------------

