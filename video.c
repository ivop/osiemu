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

#include <SDL.h>
#include <SDL_image.h>
#include <SDL2_rotozoom.h>

#include "video.h"
#include "tape.h"
#include "floppy.h"

// ----------------------------------------------------------------------------

char *font_filename = "chargen/type1.pbm";

uint8_t SCREEN[0x0800];      // 2kB Video RAM
uint8_t COLOR[0x0800];       // 2kB Color RAM

bool video_enabled = true;
bool color_enabled = false;
bool video_smooth = false;
bool fullscreen = false;

int zoom = 1, stretchx = 1, stretchy = 1;

double aspectx = 1.0;
double aspecty = 1.0;

int screen_width = 512;
int screen_height = 256;

int osi_width = 64;
int osi_height = 32;

static SDL_Window *window;
static SDL_Renderer *renderer;

static SDL_Texture *screen;

static SDL_Texture *font;
static SDL_Texture *tape_icon;
static SDL_Texture *drive1_icon;
static SDL_Texture *drive2_icon;
static SDL_Texture *digits;

static SDL_Rect src_rect_64x64 = {  0,  0, 64, 64 };
static SDL_Rect dst_rect_64x64 = { 16, 16, 64, 64 };

static SDL_Rect src_rect_digits = {  0,  0, 32, 64 };
static SDL_Rect dst_rect_digits = { 96, 16, 32, 64 };

#if 0
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
#endif

static int monochrome[][3] = {
    // mono colors
    [COLOR_GREEN] = { 0x00, 0xff, 0x00 },
    [COLOR_AMBER] = { 0xff, 191, 0 },
    [COLOR_WHITE] = { 0xff, 0xff, 0xff }
};

enum mono_colors mono_color = COLOR_WHITE;

// ----------------------------------------------------------------------------

static void blit_char(SDL_Texture *font, int x, int y, unsigned char c) {
    SDL_Rect srcrect = { 0, c*8, 8, 8 };
    SDL_Rect dstrect = { x*8, y*8, 8, 8, };

    SDL_SetRenderTarget(renderer, screen);
	SDL_RenderCopy(renderer, font, &srcrect, &dstrect);
}

static void blit_screenmem(SDL_Texture *font) {
    if (!video_enabled) return;

    SDL_SetTextureColorMod(font, monochrome[mono_color][0],
                                 monochrome[mono_color][1],
                                 monochrome[mono_color][2]);

    for (int y = 0; y < osi_height; y++) {
        for (int x = 0; x < osi_width; x++) {
            blit_char(font, x, y, SCREEN[x+y*osi_width]);
        }
    }
}

// ----------------------------------------------------------------------------

static SDL_Texture *load_texture(char *filename) {
    SDL_Texture *t = NULL;
    if (!(t = IMG_LoadTexture(renderer, filename))) {
        fprintf(stderr, "error: cannot load texture %s\n", filename);
    }
    return t;
}

// ----------------------------------------------------------------------------

void screen_update(void) {
    blit_screenmem(font);

    SDL_SetRenderTarget(renderer, NULL);
    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, screen, NULL, NULL );

    // On-Screen-Display

    if (tape_running) {
        SDL_RenderCopy(renderer, tape_icon, &src_rect_64x64, &dst_rect_64x64);
    } else if (drive_enable && head_on_disk) {
        int drive, track;
        SDL_Texture *p;
        floppy_get_current_track_and_drive(&track, &drive);
        if (drive == 1) {
            p = drive2_icon;
        } else {
            p = drive1_icon;
        }
        SDL_RenderCopy(renderer, p, &src_rect_64x64, &dst_rect_64x64);
        int n = track / 10, m = track % 10;
        if (n > 9) n = 9;

        src_rect_digits.x = n * 32;
        dst_rect_digits.x = 96;
        SDL_RenderCopy(renderer, digits, &src_rect_digits, &dst_rect_digits);

        src_rect_digits.x = m * 32;
        dst_rect_digits.x = 96 + 32;
        SDL_RenderCopy(renderer, digits, &src_rect_digits, &dst_rect_digits);
    }

    SDL_RenderPresent(renderer);
}

// ----------------------------------------------------------------------------

bool screen_init(void) {
    screen_width = osi_width * 8;
    screen_height = osi_height * 8;

    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, video_smooth ? "linear" : "");

    window = SDL_CreateWindow("OSIEMU",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              aspectx * stretchx * zoom * screen_width,
                              aspecty * stretchy * zoom * screen_height,
                              SDL_WINDOW_SHOWN );
    if( window == NULL ) {
        fprintf(stderr,  "error: cannot create window: %s\n", SDL_GetError() );
        return false;
    }

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    if (!renderer) {
        fprintf(stderr, "error: cannot create renderer\n");
        return false;
    }

    SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff);

    if (!(font = load_texture(font_filename))) {
        return false;
    }

    if (!(tape_icon = load_texture("icons/tape.png"))) {
        return false;
    }

    if (!(drive1_icon = load_texture("icons/floppy1.png"))) {
        return false;
    }

    if (!(drive2_icon = load_texture("icons/floppy2.png"))) {
        return false;
    }

    if (!(digits = load_texture("icons/digits.png"))) {
        return false;
    }

    SDL_SetTextureColorMod(tape_icon, 0xff, 0x00, 0x00);
    SDL_SetTextureColorMod(drive1_icon, 0xff, 0x00, 0x00);
    SDL_SetTextureColorMod(drive2_icon, 0xff, 0x00, 0x00);
    SDL_SetTextureColorMod(digits, 0xff, 0x00, 0x00);

    screen = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
                                         SDL_TEXTUREACCESS_TARGET,
                                         screen_width, screen_height);

    if (!screen) {
        fprintf(stderr, "error: unable to create blank texture\n");
        return false;
    }

    return true;
}

// ----------------------------------------------------------------------------

uint8_t screen_read(uint16_t address) {
    return SCREEN[address & 0x07ff];
}

// ----------------------------------------------------------------------------

void screen_write(uint16_t address, uint8_t value) {
    SCREEN[address & 0x07ff] = value;
}

// ----------------------------------------------------------------------------

void screen_hide(void) {
    SDL_HideWindow(window);
}

// ----------------------------------------------------------------------------

void screen_unhide(void) {
    SDL_ShowWindow(window);
}

// ----------------------------------------------------------------------------

void screen_toggle_fullscreen(void) {
    fullscreen = !fullscreen;

    if (fullscreen) {
        SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN_DESKTOP);
    } else {
        SDL_SetWindowFullscreen(window, 0);
    }
}
