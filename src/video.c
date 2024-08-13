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
#include <math.h>

#include <SDL.h>
#include <SDL_image.h>
#include <SDL_render.h>

#include "video.h"
#include "tape.h"
#include "floppy.h"
#include "hslrgb.h"
#include "portability.h"
#include "control.h"

// ----------------------------------------------------------------------------

#define OSD_COLOR 0xff, 0x00, 0x00

char *font_filename = "fonts/type1.png";
char *graph_font_filename = "fonts/graph.png";

uint8_t SCREEN[0x0800];      // 2kB Video RAM
uint8_t COLOR[0x0800];       // 2kB Color RAM
uint8_t HIRES[0x2000];       // 2kB for 440B, 8kB for 541

bool video_enabled = true;
bool color_ram_enabled = false;
bool video_smooth = false;
bool fullscreen = false;

unsigned int zoom = 1, stretchx = 1, stretchy = 1;

double aspectx = 1.0;
double aspecty = 1.0;

uint16_t screen_ram_bottom = 0xd000;
uint16_t screen_ram_top    = 0xd7ff;
uint16_t color_ram_bottom  = 0xe000;
uint16_t color_ram_top     = 0xe7ff;

int screen_width = 512;
int screen_height = 256;

int osi_width = 64;
int osi_height = 32;
int osi_stride = 64;

static SDL_Window *window;
static SDL_Renderer *renderer;

static SDL_Texture *screen;

static SDL_Texture *font;
static SDL_Texture *graph_font;
static SDL_Texture *tape_icon;
static SDL_Texture *drive1_icon;
static SDL_Texture *drive2_icon;
static SDL_Texture *drive3_icon;
static SDL_Texture *drive4_icon;
static SDL_Texture *digits;
static SDL_Texture *background;         // single character "font"
static SDL_Texture *scanlines;
static SDL_Texture *pixels;

static SDL_Rect src_rect_64x64 = {  0,  0, 64, 64 };
static SDL_Rect dst_rect_64x64 = { 16, 16, 64, 64 };

static SDL_Rect src_rect_digits = {  0,  0, 32, 64 };
static SDL_Rect dst_rect_digits = { 96, 16, 32, 64 };

static int monochrome[][3] = {
    [COLOR_GREEN]  = { 0x00, 0xff, 0x00 },
    [COLOR_AMBER]  = { 0xff, 0xbf, 0x00 },
    [COLOR_WHITE]  = { 0xff, 0xff, 0xff },
    [COLOR_BLUISH] = { 0x8a, 0xc2, 0xff }
};

enum mono_colors mono_color = COLOR_WHITE;
enum color_modes color_mode = COLORS_MONOCHROME;

static int colors_440b[4][3] = {
    { 0xff, 0xff, 0xff },           // white
    { 0xff, 0x00, 0x00 },           // red
    { 0x00, 0xff, 0x00 },           // green
    { 0xff, 0xff, 0x00 }            // yellow
};

// 540B
static double clock_delay_angles[7];
static double first_angle = 60.0;           // yellow
static double propagation_delay = 30.0;

static int mapping_74ls151[7] = { 0, 2, 3, 5, 6, 4, 1 };

static double lightness[2] = { 0.10, 0.60 };
double saturation = 0.75;

static int colors_540b[2][8][3];    // [dim|bright][8 colors][3 rgb values]

static uint8_t Hz_tick_540b;

static double angles_630[8] = {
      0.0,  // dummy
      0.0,  // red      (360)
    120.0,  // green
     60.0,  // yellow   (0+120)/2
    240.0,  // blue
    300.0,  // magenta  (240+360)/2
    180.0,  // cyan     (240+120)/2
      0.0   // dummy
};

static int colors_630[16][3];  // 8 dim/bright pairs, maps directly to bits 3-0

static double *angles_440b = angles_630; // white + three identical colors

enum hires_modes hires_mode = HIRES_NONE;

static SDL_Texture *hires_bytes;
static SDL_Texture *hires_screen;

static bool hires_visible;

bool scanlines_enable;
bool pixels_enable;

static double interval;
static double counter;

const char * const mono_colors_name[] = {
    [COLOR_GREEN]  = "green",
    [COLOR_AMBER]  = "amber",
    [COLOR_WHITE]  = "white",
    [COLOR_BLUISH] = "bluish"
};

const char * const color_modes_name[] = {
    [COLORS_MONOCHROME] = "monochrome",
    [COLORS_440B]       = "440b",
    [COLORS_540B]       = "540b",
    [COLORS_630]        = "630"
};

const char * const hires_modes_name[] = {
    [HIRES_NONE] = "none",
    [HIRES_440B] = "440b",
    [HIRES_541]  = "541"
};

// ----------------------------------------------------------------------------

static void blit_char(SDL_Texture *font, int x, int y, unsigned char c) {
    SDL_Rect srcrect = { 0, c*8, 8, 8 };
    SDL_Rect dstrect = { x*8, y*8, 8, 8, };

	SDL_RenderCopy(renderer, font, &srcrect, &dstrect);
}

static void blit_screenmem(SDL_Texture *font) {
    if (!video_enabled) return;

    SDL_SetRenderTarget(renderer, screen);
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);

    switch (color_mode) {
    case COLORS_MONOCHROME:
do_monochrome:
        SDL_RenderClear(renderer);
        SDL_SetTextureColorMod(font, monochrome[mono_color][0],
                                     monochrome[mono_color][1],
                                     monochrome[mono_color][2]);
        for (int y = 0; y < osi_height; y++) {
            for (int x = 0; x < osi_width; x++) {
                blit_char(font, x, y, SCREEN[x+y*osi_stride]);
            }
        }
        break;
    case COLORS_440B:
        SDL_RenderClear(renderer);
        for (int y = 0; y < osi_height; y++) {
            for (int x = 0; x < osi_width; x++) {

                // Assume SixBit ASCII
                uint8_t k = SCREEN[x+y*osi_stride] & 0x3f;   // 6-bits
                k = ((k - 0x20) & 0x3f) + 0x20;              // adjust in font
                uint8_t color = SCREEN[x+y*osi_stride] >> 6; // upper 2 bits
                SDL_SetTextureColorMod(font, colors_440b[color][0],
                                             colors_440b[color][1],
                                             colors_440b[color][2]);
                blit_char(font, x, y, k);
            }
        }
        break;
    case COLORS_540B:
        if (!(control_5xx & CONTROL_540B_COLOR_ON))
            goto do_monochrome;
        for (int y = 0; y < osi_height; y++) {
            for (int x = 0; x < osi_width; x++) {
                int v = COLOR[x+y*osi_stride];
                int c = (v >> 1) & 7;
                bool i = v & 1;

                SDL_SetTextureColorMod(background, colors_540b[i][c][0],
                                                   colors_540b[i][c][1],
                                                   colors_540b[i][c][2]);
                blit_char(background, x, y, 0);

                i ^= 1;
                SDL_SetTextureColorMod(font, colors_540b[i][c][0],
                                             colors_540b[i][c][1],
                                             colors_540b[i][c][2]);
                blit_char(font, x, y, SCREEN[x+y*osi_stride]);
            }
        }
        break;
    case COLORS_630:
        if (!(control_6xx & CONTROL_630_COLOR_ON))
            goto do_monochrome;
        SDL_RenderClear(renderer);
        for (int y = 0; y < osi_height; y++) {
            for (int x = 0; x < osi_width; x++) {
                int c = COLOR[x+y*osi_stride] & 0x0f;

                SDL_SetTextureColorMod(font, colors_630[c][0],
                                             colors_630[c][1],
                                             colors_630[c][2]);

                blit_char(font, x, y, SCREEN[x+y*osi_stride]);
            }
        }
        break;
    }

    if (!hires_visible) return;

    switch (hires_mode) {
    case HIRES_NONE:
        break;
    case HIRES_440B:
        SDL_SetRenderTarget(renderer, hires_screen);
        SDL_SetTextureBlendMode(hires_screen, SDL_BLENDMODE_BLEND);
        SDL_SetRenderDrawColor(renderer, 255, 255, 255, 0);
        SDL_RenderClear(renderer);
        for (int y=0; y<128; y++) {
            for (int x=0; x<16; x++) {
                uint8_t bits = HIRES[y*16+x];

                SDL_Rect src_bits = { 0, bits, 4, 1 };
                SDL_Rect dst_bits = { x*8, y , 4, 1 };

                if (color_mode == COLORS_440B) {
                    uint8_t color = SCREEN[(y/4)*osi_stride + x*2] >> 6;
                    SDL_SetTextureColorMod(hires_bytes, colors_440b[color][0],
                                                        colors_440b[color][1],
                                                        colors_440b[color][2]);
                }

                SDL_RenderCopy(renderer, hires_bytes, &src_bits, &dst_bits);

                src_bits.x = 4;
                dst_bits.x += 4;

                if (color_mode == COLORS_440B) {
                    uint8_t color = SCREEN[(y/4)*osi_stride + x*2 + 1] >> 6;
                    SDL_SetTextureColorMod(hires_bytes, colors_440b[color][0],
                                                        colors_440b[color][1],
                                                        colors_440b[color][2]);
                }

                SDL_RenderCopy(renderer, hires_bytes, &src_bits, &dst_bits);
            }
        }
        break;
    case HIRES_541:
        SDL_SetRenderTarget(renderer, hires_screen);
        SDL_SetTextureBlendMode(hires_screen, SDL_BLENDMODE_BLEND);
        SDL_SetRenderDrawColor(renderer, 255, 255, 255, 0);
        SDL_RenderClear(renderer);
        for (int y=0; y<256; y++) {
            for (int x=0; x<32; x++) {
                uint8_t bits = HIRES[y*32+x];

                SDL_Rect src_bits = { 0, bits, 8, 1 };
                SDL_Rect dst_bits = { x*8, y , 8, 1 };

                SDL_RenderCopy(renderer, hires_bytes, &src_bits, &dst_bits);
            }
        }
        break;
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
    SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xff);
    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, screen, NULL, NULL );

    if (hires_mode && hires_visible) {
        SDL_RenderCopy(renderer, hires_screen, NULL, NULL);
    }

    if (scanlines_enable) {
        SDL_RenderCopy(renderer, scanlines, NULL, NULL);
    }
    if (pixels_enable) {
        SDL_RenderCopy(renderer, pixels, NULL, NULL);
    }

    // On-Screen-Display

    if (floppy_activity) {
        int drive, track;
        SDL_Texture *p;

        floppy_get_current_track_and_drive(&track, &drive);
        switch (drive) {
        case 0: p = drive1_icon; break;
        case 1: p = drive2_icon; break;
        case 2: p = drive3_icon; break;
        case 3: p = drive4_icon; break;
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

        floppy_activity--;
    } else if (tape_running) {
        SDL_RenderCopy(renderer, tape_icon, &src_rect_64x64, &dst_rect_64x64);
    }

    SDL_RenderPresent(renderer);
}

// ----------------------------------------------------------------------------

static void init_hires_bytes(void) {
    SDL_SetRenderTarget(renderer, hires_bytes);
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 0);
    SDL_SetTextureBlendMode(hires_bytes, SDL_BLENDMODE_BLEND);
    SDL_RenderClear(renderer);
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    for (int y=0; y<256; y++) {
        uint8_t mask = 0x01;
        for (int x=0; x<8; x++) {
            if (y & mask) {
                SDL_RenderDrawPoint(renderer, x, y);
            }
            mask <<= 1;
        }
    }
}

// ----------------------------------------------------------------------------

// See doc/osi540-colors.txt for details

static void init_colors_540b(void) {
    double n = propagation_delay;

    clock_delay_angles[0] = first_angle;

    for (int i=1; i<=6; i++) {
        clock_delay_angles[i] = clock_delay_angles[i-1] + 180.0 - n;
        if (clock_delay_angles[i] < 0.0) clock_delay_angles[i] += 360.0;
        clock_delay_angles[i] = fmod(clock_delay_angles[i], 360.0);
    }

    int R, G, B;
    for (int i=0; i<=1; i++) {          // dim, bright
        for (int j=0; j<=6; j++) {      // angles
            double angle = clock_delay_angles[mapping_74ls151[j]];
            hsl_to_rgb(angle, saturation, lightness[i], &R, &G, &B);
            colors_540b[i][j][0] = R;
            colors_540b[i][j][1] = G;
            colors_540b[i][j][2] = B;
        }
    }

    for (int i=0; i<=1; i++) {
        hsl_to_rgb(0.0, 0.0, lightness[0] + i*0.85, &R, &G, &B);
        colors_540b[i][7][0] = R;       // dark grey / light grey
        colors_540b[i][7][1] = G;
        colors_540b[i][7][2] = B;
    }
}

// ----------------------------------------------------------------------------

// See doc/osi630-colors.txt for details

static void init_colors_630(void) {
    int R, G, B;

    for (int i=0; i<16; i++) {
        int j = i >> 1;
        int k = i & 1;

        if (j == 0) {           // black/grey
            hsl_to_rgb(0.0, 0.0, k ? 0.5 : 0.0, &R, &G, &B);
        } else if (j == 7) {    // grey/white
            hsl_to_rgb(0.0, 0.0, k ? 1.0 : 0.5, &R, &G, &B);
        } else {                // colors
            hsl_to_rgb(angles_630[j], saturation, k ? 0.50 : 0.25, &R, &G, &B);
        }

        colors_630[i][0] = R;
        colors_630[i][1] = G;
        colors_630[i][2] = B;
    }
}

// ----------------------------------------------------------------------------

static void init_colors_440b(void) {
    int R, G, B;

    for (int i=0; i<4; i++) {
        if (i == 0) {           // white
            hsl_to_rgb(0.0, 0.0, 0.9, &R, &G, &B);
        } else {                // colors
            hsl_to_rgb(angles_440b[i], saturation, 0.50, &R, &G, &B);
        }

        colors_440b[i][0] = R;
        colors_440b[i][1] = G;
        colors_440b[i][2] = B;
    }
}

// ----------------------------------------------------------------------------

bool screen_init(double cpu_clock, double fps) {
    screen_width = osi_width * 8;
    screen_height = osi_height * 8;

    int window_width = aspectx * stretchx * zoom * screen_width;
    int window_height = aspecty * stretchy * zoom * screen_height;

    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, video_smooth ? "linear" : "");

    window = SDL_CreateWindow("OSIEMU",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              window_width, window_height,
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
    if (!(graph_font = load_texture(graph_font_filename))) {
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
    if (!(drive3_icon = load_texture("icons/floppy3.png"))) {
        return false;
    }
    if (!(drive4_icon = load_texture("icons/floppy4.png"))) {
        return false;
    }
    if (!(digits = load_texture("icons/digits.png"))) {
        return false;
    }

    SDL_SetTextureColorMod(tape_icon,   OSD_COLOR);
    SDL_SetTextureColorMod(drive1_icon, OSD_COLOR);
    SDL_SetTextureColorMod(drive2_icon, OSD_COLOR);
    SDL_SetTextureColorMod(drive3_icon, OSD_COLOR);
    SDL_SetTextureColorMod(drive4_icon, OSD_COLOR);
    SDL_SetTextureColorMod(digits,      OSD_COLOR);

    screen = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
                                         SDL_TEXTUREACCESS_TARGET,
                                         screen_width, screen_height);

    if (!screen) {
        fprintf(stderr, "error: unable to create screen texture\n");
        return false;
    }

    if (hires_mode > HIRES_NONE) {
        hires_bytes = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
                                                  SDL_TEXTUREACCESS_TARGET,
                                                  8, 256);

        if (!hires_bytes) {
            fprintf(stderr, "error: unable to create hires texture\n");
            return false;
        }

        unsigned int hires_screen_width;
        unsigned int hires_screen_height;

        if (hires_mode == HIRES_440B) {
            hires_screen_width = hires_screen_height = 128;
        } else {
            hires_screen_width = hires_screen_height = 256;
        }

        hires_screen = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
                                                   SDL_TEXTUREACCESS_TARGET,
                                                   hires_screen_width,
                                                   hires_screen_height);

        if (!hires_screen) {
            fprintf(stderr, "error: unable to create hires screen texture\n");
            return false;
        }

        init_hires_bytes();
    }

    if (color_mode == COLORS_540B) {
        init_colors_540b();
        background = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
                                                 SDL_TEXTUREACCESS_TARGET,
                                                 8, 8);
        if (!background) {
            fprintf(stderr, "error: unable to create background texture\n");
            return false;
        }

        SDL_SetRenderTarget(renderer, background);
        SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
        SDL_RenderClear(renderer);
    } else if (color_mode == COLORS_630) {
        init_colors_630();
    } else if (color_mode == COLORS_440B) {
        init_colors_440b();
    }

    interval = cpu_clock / fps / 2.0;

    if (zoom > 1 && scanlines_enable) {
        int scanlines_height = screen_height * 2;
        scanlines = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
                                               SDL_TEXTUREACCESS_TARGET,
                                               1, scanlines_height);
        if (!scanlines) {
            fprintf(stderr, "error: unable to create scanlines texture\n");
            return false;
        }

        SDL_SetRenderTarget(renderer, scanlines);
        SDL_SetTextureBlendMode(scanlines, SDL_BLENDMODE_BLEND);
        for (int y=0; y<scanlines_height; y+=2) {
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
            SDL_RenderDrawLine(renderer, 0, y, 0, y);
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 128);
            SDL_RenderDrawLine(renderer, 0, y+1, 0, y+1);
        }
    }

    if (zoom > 1 && pixels_enable) {
        int pixels_width = screen_width * 2;
        pixels = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
                                             SDL_TEXTUREACCESS_TARGET,
                                             pixels_width, 1);
        if (!pixels) {
            fprintf(stderr, "error: unable to create pixels texture\n");
            return false;
        }

        SDL_SetRenderTarget(renderer, pixels);
        SDL_SetTextureBlendMode(pixels, SDL_BLENDMODE_BLEND);
        for (int x=0; x<pixels_width; x+=2) {
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
            SDL_RenderDrawLine(renderer, x, 0, x, 0);
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 128);
            SDL_RenderDrawLine(renderer, x+1, 0, x+1, 0);
        }
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

// ----------------------------------------------------------------------------

uint8_t screen_color_ram_read(uint16_t address) {
    return COLOR[(address - color_ram_bottom) & 0x07ff];
}

// ----------------------------------------------------------------------------

void screen_color_ram_write(uint16_t address, uint8_t value) {
    COLOR[(address - color_ram_bottom) & 0x07ff] = value;
}

// ----------------------------------------------------------------------------

uint8_t screen_hires_ram_read(uint16_t address) {
    if (hires_mode == HIRES_440B) {
        return HIRES[address & 0x07ff];
    } else {
        return HIRES[address & 0x1fff];
    }
}

// ----------------------------------------------------------------------------

void screen_hires_ram_write(uint16_t address, uint8_t value) {
    if (hires_mode == HIRES_440B) {
        HIRES[address & 0x07ff] = value;
    } else {
        HIRES[address & 0x1fff] = value;
    }
}

// ----------------------------------------------------------------------------

uint8_t screen_control_540b_read(uint16_t address UNUSED) {
    return Hz_tick_540b;
}

// ----------------------------------------------------------------------------

void screen_swap_fonts(void) {
    void *t = font;
    font = graph_font;
    graph_font = t;
}

// ----------------------------------------------------------------------------

void screen_tick(double ticks) {
    if (color_mode != COLORS_540B) return;

    counter += ticks;
    if (counter >= interval) {
        counter -= interval;
        Hz_tick_540b ^= 0x80;
    }
}

// ----------------------------------------------------------------------------

void screen_toggle_hires(void) {
    hires_visible ^= 1;
}

// ----------------------------------------------------------------------------

static void create_screen_texture(void) {
    screen_width = osi_width * 8;
    screen_height = osi_height * 8;

    if (screen) SDL_DestroyTexture(screen);
    screen = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
                                         SDL_TEXTUREACCESS_TARGET,
                                         screen_width, screen_height);
}

void screen_reinit_540(void) {
    if (control_5xx & 1) {
        osi_width = 64;
    } else {
        osi_width = 32;
    }
    create_screen_texture();
}

void screen_reinit_600(void) {
    if (control_6xx & 1) {
        osi_width = osi_stride = 64;
        osi_height = 16;
    } else {
        osi_width = osi_stride = 32;
        osi_height = 32;
    }
    create_screen_texture();
}
