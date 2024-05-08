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
#include "fake6502/fake6502.h"

#include <SDL.h>
#include <SDL_image.h>

// ----------------------------------------------------------------------------

static bool basic_enabled = true;
static bool video_enabled = true;
static bool color_enabled = false;

static uint8_t RAM[0xc000];         // Maximum of 48kB RAM
static uint8_t BASIC[0x2000];       // 8kB BASIC ROM
static uint8_t SCREEN[0x0800];      // 2kB Video RAM
static uint8_t COLOR[0x0800];       // 2kB Color RAM
static uint8_t KERNEL[0x1000];      // 4kB Kernel ROM

static uint16_t ram_top = 0x9fff;           // 0xbfff when BASIC is disabled
static uint16_t kernel_bottom = 0xf000;     // 0xf800 for most 2kB ROMs

static char *basic_filename = "basic/basic-osi.rom";
static char *kernel_filename = "kernel/synmon-alt.rom";
static char *font_filename = "chargen/type1.pbm";

static int screen_width = 512;      // 64 * 8
static int screen_height = 256;     // 32 * 8

static SDL_Window *window;
static SDL_Surface *winsurface;
static SDL_Surface *screen;
static SDL_Surface *font;

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

static int osi_width = 64;
static int osi_height = 32;

// How fast does our 6502 run?

#define CPU_CLOCK_C1P   (3932160/4)     // 1P / Superboard II Service Manual
#define CPU_CLOCK_UK101 (8000000/8)     // WinOSI, source???

static int cpu_clock = CPU_CLOCK_C1P;
static double fps = 60.0;
static double ticks_per_frame;

// ----------------------------------------------------------------------------

// Memory Map:
//
// 0000-9fff    RAM
//
// a000-bfff    BASIC ROM or RAM
//
//              Model 470 disk controller board
// c000-c00f    PIA for disk I/O
// c010-c01f    ACIA for disk I/O
//
// cf00-cf1f    Up to 16 ACIA's (Model 550 serial port board)
//              used by multishare system and C3s
//
// d000-d7ff    Screen RAM  (32x32 or 64x32, stride is always 64)
// de00         video mode:
//              write:
//                  bit 0, 1=32, 0=64
//                  bit 1, 1=tone on (642 keyboard)
//                  bit 2, 1=color on
//                  bit 3, 1=enable 38-40kHz AC Home control output
//              read:
//                  bit 7 toggles at 1/120th of a second (duty cycle is 60Hz)
//
// df00         Polled Keyboard (Model 542/542B or Model 600/600D (inverted))
// df01         R2R DAC output, or tone generator at 49152/value Hz
//
// e000-e7ff    Color RAM
//
// f000-ffff    Kernel ROM
//
// f000-ffff    some pages might contain another peripheral
//              if fcxx is ACIA, page fc is mapped to f4
//
// fcxx         ACIA, Model 502's cassette interface

// ----------------------------------------------------------------------------

// matrix[row][col]
static uint8_t keyboard_matrix[8][8] = {
{ 0, /*rshift*/ 0, /*lshift*/ 0, 0, 0, SDLK_ESCAPE, /*ctrl*/ 0, /*rpt*/ 0 },
{ 0, SDLK_p, SDLK_SEMICOLON, SDLK_SLASH, SDLK_SPACE, SDLK_z, SDLK_a, SDLK_q },
{ 0, SDLK_COMMA, SDLK_m, SDLK_n, SDLK_b, SDLK_v, SDLK_c, SDLK_x },
{ 0, SDLK_k, SDLK_j, SDLK_h, SDLK_g, SDLK_f, SDLK_d, SDLK_s },
{ 0, SDLK_i, SDLK_u, SDLK_y, SDLK_t, SDLK_r, SDLK_e, SDLK_w },
{ 0, 0, 0, SDLK_RETURN, /* LF */ 0, SDLK_o, SDLK_l, SDLK_PERIOD },
{ 0, 0, SDLK_BACKSPACE, SDLK_MINUS, SDLK_COLON, SDLK_0, SDLK_9, SDLK_8 },
{ 0, SDLK_7, SDLK_6, SDLK_5, SDLK_4, SDLK_3, SDLK_2, SDLK_1 }
};

static uint8_t keyboard_osi_matrix[8];
static uint8_t keyboard_osi_row;
static bool keyboard_inverted = true;

static void keyboard_init(void) {
    memset(keyboard_osi_matrix, keyboard_inverted ? 0xff : 0, 8);
}

static void keyboard_press_key(SDL_Keysym *key) {
    int i, row, col;

    if (key->sym > 127 || !key->sym) return;

    for (i = 0; i < 64; i++) {
        row = i / 8;
        col = i % 8;
        if (keyboard_matrix[row][col] == key->sym) break;
    }
    if (i == 64) return;    // not found

//    printf("\tfound row %d col %d\n", row, col);

    keyboard_init();

    keyboard_osi_matrix[row] ^= 1 << col;

    if (key->mod == KMOD_CAPS)
        keyboard_osi_matrix[0] ^= 1 << 0;
    if (key->mod == KMOD_LSHIFT)
        keyboard_osi_matrix[0] ^= 1 << 2;
    if (key->mod == KMOD_RSHIFT)
        keyboard_osi_matrix[0] ^= 1 << 1;
    if (key->mod == KMOD_LCTRL || key->mod == KMOD_RCTRL)
        keyboard_osi_matrix[0] ^= 1 << 6;
}

static void keyboard_release_key(SDL_Keysym *key) {
    keyboard_init();
}

static uint8_t keyboard_read(void) {
//    printf("keyb read, osi_row %d\n", keyboard_osi_row);
//    printf("bitmap: %02x\n", keyboard_osi_matrix[keyboard_osi_row]);
    return keyboard_osi_matrix[keyboard_osi_row];
}

static void keyboard_write(uint8_t value) {
//    printf("keyb write %02x\n", value);
    if (keyboard_inverted) value ^= 0xff;
    for (int i=0; i<8; i++) {
        if (value & (1<<i)) keyboard_osi_row = i;
    }
}

// ----------------------------------------------------------------------------

uint8_t read6502(uint16_t address) {
    if (address < ram_top) {
        return RAM[address];
    }
    if (basic_enabled) {
        if (address >= 0xa000 && address <= 0xbfff) {
            return BASIC[address - 0xa000];
        }
    }
    if (video_enabled) {
        if (address >= 0xd000 && address <= 0xd7ff) {
            return SCREEN[address - 0xd000];
        }
        if (color_enabled) {
            if (address >= 0xe000 && address <= 0xe7ff) {
                return COLOR[address - 0xe000];
            }
        }
    }
    if (address == 0xdf00) {
        return keyboard_read();
    }
    if (address >= kernel_bottom) {
        return KERNEL[address - 0xf000];
    }

    return 0xff;
}

void write6502(uint16_t address, uint8_t value) {
    if (address < ram_top) {
        RAM[address] = value;
    }
    if (video_enabled) {
        if (address >= 0xd000 && address <= 0xd7ff) {
            SCREEN[address - 0xd000] = value;
        }
        if (address >= 0xe000 && address <= 0xe7ff) {
            COLOR[address - 0xe000] = value;
        }
    }
    if (address == 0xdf00) {
        keyboard_write(value);
    }
}

// ----------------------------------------------------------------------------

// Load binary data into *buf
// If filesize > size, truncate.
// If filesize < size, prepend with zeroes, i.e. loaded data is at the end
// of the buffer.
// Return false if file I/O failed.
//
static bool load_file(uint8_t *buf, int size, char *filename, bool iskernel) {
    printf("loading %s\n", filename);
    FILE *f = fopen(filename, "rb");
    if (!f) {
        fprintf(stderr, "error: %s: unable to open\n", filename);
        return false;
    }

    fseek(f, 0, SEEK_END);
    int filesize = ftell(f);

    if (filesize > size) {
        fprintf(stderr, "warning: %s is larger than buffer size %d, "
                        "truncating...\n", filename, size);
        filesize = size;
    }

    int offset = size - filesize;

    memset(buf, 0, offset);

    fseek(f, 0, SEEK_SET);
    if (fread(buf + offset, 1, filesize, f) != filesize) {
        fprintf(stderr, "error: %s: read error\n", filename);
        return false;
    }

    fclose(f);

    if (iskernel) kernel_bottom = 0xf000 + offset;
    return true;
}

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

static void usage(void) {
    fprintf(stderr, "usage: ./osiemu [options]\n\n"
"options:\n"
"\n"
"    -b/--basic filename.rom    specify BASIC ROM\n"
"    -k/--kernel filename.rom   specify kernel ROM\n"
"    -f/--font filename.rom     specify font (8x2048 image)\n"
"\n"
"    -d/--disable-basic         disable BASIC (default: enabled)\n"
"    -v/--disable-video         disable video RAM (default: enabled)\n"
"\n"
"    -m/--video-mode mode       select mode: 64x32 (default), 64x16, or 32x32\n"
"    -i/--invert-keyboard       inverted keyboard matrix signals\n"
"\n"
"    -h/--help                  show usage information\n"
);
}

// ----------------------------------------------------------------------------

static struct option long_options[] = {
    { "help",           no_argument,        0, 'h' },
    { "basic",          required_argument,  0, 'b' },
    { "font",           required_argument,  0, 'f' },
    { "kernel",         required_argument,  0, 'k' },
    { "disable-basic",  no_argument,        0, 'd' },
    { "disable-video",  no_argument,        0, 'v' },
    { "zoom",           no_argument,        0, 'z' },
    { "video-mode",     required_argument,  0, 'm' },
};

int main(int argc, char **argv) {
    int option, index, zoom = 1, stretchx = 1, stretchy = 1;

    while ((option = getopt_long(argc, argv, "hb:k:f:",
                                 long_options, &index)) != -1) {
        switch (option) {
        case 0:
            printf("long option %s with argument %s\n",
                    long_options[index].name, optarg);
            break;
        case 'b':
            basic_filename = strdup(optarg);
            break;
        case 'f':
            font_filename = strdup(optarg);
            break;
        case 'k':
            kernel_filename = strdup(optarg);
            break;
        case 'd':
            basic_enabled = false;
            ram_top = 0xbfff;
            break;
        case 'v':
            video_enabled = false;
            break;
        case 'z':
            zoom = 2;
            break;
        case 'm':
            if (!strcmp(optarg, "64x32")) {
                osi_width = 64;
                osi_height = 32;
            } else if (!strcmp(optarg, "32x32")) {
                osi_width = 32;
                osi_height = 32;
                stretchx = 2;
            } else if (!strcmp(optarg, "64x16")) {
                osi_width = 64;
                osi_height = 16;
                stretchy = 2;
            } else {
                fprintf(stderr, "error: unrecognized mode: %s\n", optarg);
                return 1;
            }
            break;
        case 'h':
            usage();
            return 1;
        case ':':
        case '?':
            return 1;
        }
    }

    printf("OSIEMU v0.9 - Copyright © 2024 Ivo van Poorten\n");

    if (basic_enabled) {
        if (!load_file(BASIC, 8192, basic_filename, false))
            return 1;
    }
    if (!load_file(KERNEL, 4096, kernel_filename, true)) {
        return 1;
    }

    if (optind != argc) {
        fprintf(stderr, "error: wrong command line arguments\n");
        return 1;
    }

    ticks_per_frame = cpu_clock / fps;

    printf("screen width: %d\nscreen height: %d\n", osi_width, osi_height);
    printf("cpu clock: %d Hz\n", cpu_clock);
    printf("frame rate: %.2lf fps\n", fps);
    printf("ticks per frame: %.2lf\n", ticks_per_frame);

    if (SDL_Init(SDL_INIT_EVERYTHING) < 0) {
        fprintf(stderr, "error: SDL init failed\n");
        return 1;
    }

    screen_width = osi_width * 8;
    screen_height = osi_height * 8;

    window = SDL_CreateWindow("SDL Tutorial",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              stretchx * zoom * screen_width,
                              stretchy * zoom * screen_height,
                              SDL_WINDOW_SHOWN );
    if( window == NULL ) {
        fprintf(stderr,  "error: cannot create window: %s\n", SDL_GetError() );
        return 1;
    }

    if (!(font = load_optimized(window, font_filename))) {
        return 1;
    }

    reset6502();
    keyboard_init();

    winsurface = SDL_GetWindowSurface(window);
    screen = empty_surface(window, screen_width, screen_height);

    // doubles to avoid drift when cpu_clock/fps or 1000/fps is not an integer

    double sdl_ticks_per_frame = 1000.0 / fps;
    double target = SDL_GetTicks();
    double cpu_ticks = 0.0;
    double cpu_target = cpu_ticks + ticks_per_frame;

    while (1) {
        target += sdl_ticks_per_frame;

        blit_screenmem(screen, font);
        SDL_Rect fillrect = { 0, 0, stretchx * zoom * screen_width,
                                    stretchy * zoom * screen_height };
        SDL_BlitScaled(screen, 0, winsurface, &fillrect);
        SDL_UpdateWindowSurface(window);

        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            switch (e.type) {
            case SDL_QUIT:
                goto exit_out;
                break;
            case SDL_KEYDOWN:
                switch (e.key.keysym.sym) {
                default:
                    keyboard_press_key(&e.key.keysym);
                    break;
                }
                break;
            case SDL_KEYUP:
                switch (e.key.keysym.sym) {
                case SDLK_F5:
                    reset6502();
                    break;
                case SDLK_F9:
                    goto exit_out;
                    break;
                default:
                    keyboard_release_key(&e.key.keysym);
                    break;
                }
                break;
            }
        }

        while (cpu_ticks < cpu_target) {
            cpu_ticks += step6502();
        }

        cpu_target += ticks_per_frame;

        while (SDL_GetTicks() < target)
            ;
    }

exit_out:
}
