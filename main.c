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

#include "mmu.h"
#include "keyboard.h"
#include "video.h"
#include "tape.h"

// ----------------------------------------------------------------------------

static char *basic_filename = "basic/basic-osi.rom";
static char *kernel_filename = "kernel/synmon-alt.rom";
static char *tape_input_filename = NULL;
static char *tape_output_filename = "tape_output.dat";

// How fast does our 6502 run?

#define CPU_CLOCK_C1P   (3932160/4)     // 1P / Superboard II Service Manual
#define CPU_CLOCK_UK101 (8000000/8)     // WinOSI, source???

static int cpu_clock = CPU_CLOCK_C1P;
static double fps = 60.0;
static double ticks_per_frame;

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
"    -a/--aspect mode           aspect mode: full (default), 16:9 or 4:3\n"
"    -i/--invert-keyboard       invert keyboard matrix signals\n"
"\n"
"    -h/--help                  show usage information\n"
);
}

// ----------------------------------------------------------------------------

static struct option long_options[] = {
    { "aspect",         required_argument,  0, 'a' },
    { "basic",          required_argument,  0, 'b' },
    { "disable-basic",  no_argument,        0, 'd' },
    { "font",           required_argument,  0, 'f' },
    { "help",           no_argument,        0, 'h' },
    { "invert-keyboard",no_argument,        0, 'i' },
    { "kernel",         required_argument,  0, 'k' },
    { "video-mode",     required_argument,  0, 'm' },
    { "disable-video",  no_argument,        0, 'v' },
    { "zoom",           no_argument,        0, 'z' },
};

int main(int argc, char **argv) {
    int option, index;

    while ((option = getopt_long(argc, argv, "b:df:hik:m:vz",
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
        case 'f':
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
        case 'i':
            keyboard_inverted ^= 1;
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

    if (SDL_Init(SDL_INIT_EVERYTHING) < 0) {
        fprintf(stderr, "error: SDL init failed\n");
        return 1;
    }

    if (!screen_init()) return 1;

    reset6502();
    keyboard_init();
    tape_init(tape_input_filename, tape_output_filename, cpu_clock);

    // doubles to avoid drift when cpu_clock/fps or 1000/fps is not an integer

    double sdl_ticks_per_frame = 1000.0 / fps;
    double target = SDL_GetTicks();
    double cpu_ticks = 0.0;
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
    ;
}
