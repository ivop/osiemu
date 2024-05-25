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
#ifndef DONT_USE_NANOSLEEP
#include <time.h>
#endif

#include "fake6502/fake6502.h"

#include <SDL.h>

#include "monitor.h"
#include "mmu.h"
#include "keyboard.h"
#include "video.h"
#include "tape.h"
#include "floppy.h"

// ----------------------------------------------------------------------------

static char *basic_filename = "basic/basic-osi-fix.rom";
static char *kernel_filename = "kernel/syn600.rom";
static char *tape_input_filename = NULL;
static char *tape_output_filename = "tapeout.dat";
static char *drive0_filename = NULL;
static char *drive1_filename = NULL;
static char *drive2_filename = NULL;
static char *drive3_filename = NULL;

// How fast does our 6502 run?

#define CPU_CLOCK_C1P   (3932160/4)     // 1P / Superboard II Service Manual
#define CPU_CLOCK_UK101 (8000000/8)     // WinOSI, source???

static int cpu_clock = CPU_CLOCK_UK101;
static double fps = 60.0;
static double ticks_per_frame;

// ----------------------------------------------------------------------------

static void usage(void) {
    fprintf(stderr, "usage: ./osiemu [options]\n\n"
"options:\n"
"\n"
"    -b/--basic filename.rom    specify BASIC ROM\n"
"    -k/--kernel filename.rom   specify kernel ROM\n"
"    -c/--font filename.rom     specify character set font (8x2048 image)\n"
"\n"
"    -d/--disable-basic         disable BASIC (default: enabled)\n"
"\n"
"    -v/--disable-video         disable video RAM (default: enabled)\n"
"    -m/--video-mode mode       select mode: 64x32 (default), 64x16, or 32x32\n"
"    -M/--mono-color color      select monochrome color green, amber or white\n"
"    -a/--aspect mode           aspect mode: full (default), 16:9 or 4:3\n"
"    -z/--zoom                  increase display size by 2\n"
"    -V/--smooth-video          enable anti-aliased scaling, requires --zoom\n"
"\n"
"    -A/--ascii-keyboard        enable ASCII keyboard at 0xdf01\n"
"    -r/--raw-keyboard          enable raw keyboard mode\n"
"    -i/--invert-keyboard       invert keyboard matrix signals\n"
"\n"
"    -t/--tape-input file       specify tape input file (default: none)\n"
"    -T/--tape-output file      specify tape output file (default: tapeout.dat)\n"
"    -C/--tape-location         ACIA location: f000 (default), fc00\n"
"    -B/--tape-baseclock        set baseclock (default: 19200)\n"
"\n"
"    -f/--floppy0 file          specify floppy0 file (default: none)\n"
"    -F/--floppy1 file          specify floppy1 file (default: none)\n"
"    -g/--floppy2 file          specify floppy2 file (default: none)\n"
"    -G/--floppy3 file          specify floppy3 file (default: none)\n"
"\n"
"    -h/--help                  show usage information\n"
);
}

// ----------------------------------------------------------------------------

static struct option long_options[] = {
    { "aspect",         required_argument,  0, 'a' },
    { "ascii-keyboard", no_argument,        0, 'A' },
    { "basic",          required_argument,  0, 'b' },
    { "tape-baseclock", required_argument,  0, 'B' },
    { "font",           required_argument,  0, 'c' },
    { "tape-location",  required_argument,  0, 'C' },
    { "disable-basic",  no_argument,        0, 'd' },
    { "floppy0",        required_argument,  0, 'f' },
    { "floppy1",        required_argument,  0, 'F' },
    { "floppy2",        required_argument,  0, 'g' },
    { "floppy3",        required_argument,  0, 'G' },
    { "help",           no_argument,        0, 'h' },
    { "invert-keyboard",no_argument,        0, 'i' },
    { "kernel",         required_argument,  0, 'k' },
    { "video-mode",     required_argument,  0, 'm' },
    { "mono-color",     required_argument,  0, 'M' },
    { "raw-keyboard",   no_argument,        0, 'r' },
    { "tape-input",     required_argument,  0, 't' },
    { "tape-output",    required_argument,  0, 'T' },
    { "disable-video",  no_argument,        0, 'v' },
    { "smooth-video",   no_argument,        0, 'V' },
    { "zoom",           no_argument,        0, 'z' },
};

int main(int argc, char **argv) {
    int option, index;
    double cpu_ticks = 0.0;

    printf("OSIEMU v0.9 - Copyright © 2024 Ivo van Poorten\n");

    while ((option = getopt_long(argc, argv, "a:Ab:c:C:df:F:g:G:hik:m:M:rt:T:vVz",
                                 long_options, &index)) != -1) {
        switch (option) {
        case 0:
            printf("long option %s with argument %s\n",
                    long_options[index].name, optarg);
            break;
        case 'a':
            if (!strcmp(optarg, "full")) {
                aspectx = 1.0;
                aspecty = 1.0;
            } else if (!strcmp(optarg, "16:9")) {
                aspectx = 8.0/9.0;
                aspecty = 1.0;
            } else if (!strcmp(optarg, "4:3")) {
                aspectx = 6.0/9.0;
                aspecty = 1.0;
            } else {
                printf("warning: unknown aspect %s\n", optarg);
            }
            break;
        case 'b':
            basic_filename = strdup(optarg);
            break;
        case 'c':
            font_filename = strdup(optarg);
            break;
        case 'k':
            kernel_filename = strdup(optarg);
            break;
        case 'd':
            mmu_basic_enabled = false;
            mmu_ram_top = 0xbfff;
            break;
        case 'v':
            video_enabled = false;
            break;
        case 'V':
            video_smooth = true;
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
        case 'M':
            if (!strcmp(optarg, "green")) {
                mono_color = COLOR_GREEN;
            } else if (!strcmp(optarg, "amber")) {
                mono_color = COLOR_AMBER;
            } else {
                mono_color = COLOR_WHITE;
            }
            break;
        case 'i':
            keyboard_inverted ^= 1;
            break;
        case 't':
            tape_input_filename = strdup(optarg);
            break;
        case 'T':
            tape_output_filename = strdup(optarg);
            break;
        case 'C':
            if (!strcmp(optarg, "f000")) {
                tape_location = 0xf000;
            } else if (!strcmp(optarg, "fc00")) {
                tape_location = 0xfc00;
            } else {
                fprintf(stderr, "error: unknown tape location\n");
            }
            break;
        case 'B':
            tape_baseclock = strtod(optarg, NULL);
            break;
        case 'r':
            keyboard_cooked = false;
            keyboard_ascii_enable = false;
            break;
        case 'A':
            keyboard_ascii_enable = true;
            break;
        case 'f':
            drive0_filename = strdup(optarg);
            break;
        case 'F':
            drive1_filename = strdup(optarg);
            break;
        case 'g':
            drive2_filename = strdup(optarg);
            break;
        case 'G':
            drive3_filename = strdup(optarg);
            break;
        case 'h':
            usage();
            return 1;
        case ':':
        case '?':
            return 1;
        }
    }

    if (mmu_basic_enabled) {
        if (!mmu_load_file(BASIC, 8192, basic_filename, false))
            return 1;
    }
    if (!mmu_load_file(KERNEL, 4096, kernel_filename, true)) {
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

    printf("matrix keyboard mode: %s\n", keyboard_cooked ? "cooked" : "raw");
    printf("matrix signals: %s\n", keyboard_inverted ? "model 600" : "model 540");
    printf("ascii keyboard: %s\n", keyboard_ascii_enable ? "enabled" : "disabled");

    if (SDL_Init(SDL_INIT_EVERYTHING) < 0) {
        fprintf(stderr, "error: SDL init failed\n");
        return 1;
    }

    if (!screen_init()) return 1;

    reset6502();
    keyboard_init(cpu_clock);
    if (!tape_init(tape_input_filename, tape_output_filename, cpu_clock)) {
        return 1;
    }
    if (!floppy_init(drive0_filename, drive1_filename,
                     drive2_filename, drive3_filename, cpu_clock)) {
        return 1;
    }

    // doubles to avoid drift when cpu_clock/fps or 1000/fps is not an integer

    double sdl_ticks_per_frame = 1000.0 / fps;
    double target = SDL_GetTicks();
    double cpu_target = cpu_ticks + ticks_per_frame;

    while (1) {
        target += sdl_ticks_per_frame;

        screen_update();

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
                    tape_rewind();
                    break;
                case SDLK_F8:
                    screen_hide();
                    if (!monitor()) goto exit_out;
                    screen_unhide();
                    break;
                case SDLK_F9:
                    goto exit_out;
                    break;
                case SDLK_F11:
                    screen_toggle_fullscreen();
                    break;
                default:
                    keyboard_release_key(&e.key.keysym);
                    break;
                }
                break;
            case SDL_TEXTINPUT:
                keyboard_text_input(e.text.text);
                break;
            }
        }

        while (cpu_ticks < cpu_target) {
            double ticks = step6502();
            cpu_ticks += ticks;
            tape_tick(ticks);
            keyboard_tick(ticks);
            floppy_tick(ticks);
            if (!monitor_checkbp()) goto exit_out;
        }

        cpu_target += ticks_per_frame;

        while (SDL_GetTicks() < target) {
#ifndef DONT_USE_NANOSLEEP
            struct timespec wait = { 0, 100000 };   // 0.1ms
            nanosleep(&wait,NULL);
#else
            SDL_Delay(1);                           // 1ms, less accurate
#endif
        }
    }

exit_out:
    ;
}
