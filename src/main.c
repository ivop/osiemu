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
#include "sound.h"
#include "control.h"
#include "trace.h"
#include "../version.h"

// ----------------------------------------------------------------------------

static char *basic_filename = "basic/basic-osi-fix.rom";
static char *kernel_filename = "kernel/syn-600-c1-dcwm.rom";
static char *drive0_filename = NULL;
static char *drive1_filename = NULL;
static char *drive2_filename = NULL;
static char *drive3_filename = NULL;

#define CPU_CLOCK_QUARTER   ( 3932160/ 4.0) // 1/4 Video (SB II Service Manual)
#define CPU_CLOCK_HALF      ( 3932160/ 2.0) // 1/2 Video (SB II Service Manual)
#define CPU_CLOCK_510C_SLOW ( 8000000/ 8.0) // 1 MHz       (510C Schematics)
#define CPU_CLOCK_510C_FAST ( 8000000/ 4.0) // 2 MHz       (510C Schematics)
#define CPU_CLOCK_540B_BW   (11790000/12.0) // Black/White (540B Schematics)
#define CPU_CLOCK_540B_COL  (12080000/12.0) // Color       (540B Schematics)

static int cpu_clock = CPU_CLOCK_QUARTER;

#define FPS_60HZ    60.0                    // 440, 600
#define FPS_540_BW  (11790000/196608.0)     // 540B Black and White
#define FPS_540_COL (12080000/196608.0)     // 540B Color

static double fps = FPS_60HZ;
static double ticks_per_frame;
static bool warp_speed;
static char *tape_input_arg;
static char *tape_output_arg;

// ----------------------------------------------------------------------------

static void usage(void) {
    fprintf(stderr,

"usage: osiemu <config-file>\n"
"       osiemu [options]\n\n"
"options:\n"
"\n"
"    -b/--basic filename.rom    specify BASIC ROM\n"
"    -k/--kernel filename.rom   specify kernel ROM\n"
"\n"
"    -c/--font filename         specify character set font (8x2048 image)\n"
"    -q/--graph-font filename   specify graphics font (8x2048 image)\n"
"\n"
"    -K/--cpu-speed speed       select speed: quarter    %.6lf MHz (default)\n"
"                                             half       %.6lf MHz\n"
"                                             510c-slow  %.6lf MHz\n"
"                                             510c-fast  %.6lf MHz\n"
"                                             540bw      %.6lf MHz\n"
"                                             540col     %.6lf MHz\n",
    CPU_CLOCK_QUARTER / 1000000.0, CPU_CLOCK_HALF / 1000000.0,
    CPU_CLOCK_510C_SLOW / 1000000.0, CPU_CLOCK_510C_FAST / 1000000.0,
    CPU_CLOCK_540B_BW / 1000000.0, CPU_CLOCK_540B_COL / 1000000.0);

    fprintf(stderr, 
"\n"
"    -v/--disable-video         disable video RAM (default: enabled)\n"
"    -m/--video-mode mode       forced modes:   64x32 (default)\n"
"                                               64x16\n"
"                                               32x32\n"
"                                               32x32s64\n"
"                               variable modes: 540b (32x32s64 / 64x32)\n"
"                                               600 (32x32 / 64x16)\n"
"    -M/--mono-color color      monochrome color green, amber, bluish or white\n"
"    -a/--aspect mode           aspect mode: full (default), 16:9 or 4:3\n"
"    -z/--zoom factor           increase display size by factor (2, 3, or 4)\n"
"    -V/--smooth-video          enable anti-aliased scaling\n"
"    -C/--color-mode mode       mode: monochrome (default), 440b, 540b, 630\n"
);
    fprintf(stderr,
"    -d/--frame-rate rate       display rate: 60     %.6lf Hz (default)\n"
"                                             540bw  %.6lf Hz\n"
"                                             540col %.6lf Hz\n",
    FPS_60HZ, FPS_540_BW, FPS_540_COL);

    fprintf(stderr,
"    -s/--saturation            color saturation [0.0-1.0], default: %.2lf\n",
    saturation);

    fprintf(stderr,
"    -H/--hires-mode mode       mode: none, 440b (128x128), 541 (256x256)\n"
"    -S/--scanlines             emulate visual scanlines (zoom >= 2 only)\n"
"    -x/--pixels                emulate visual pixels (implies scanlines)\n"
"\n"
"    -A/--ascii-keyboard        enable ASCII keyboard at 0xdf01\n"
"    -r/--raw-keyboard          enable raw keyboard mode\n"
"    -i/--invert-keyboard       invert keyboard matrix signals (model 542)\n"
"\n"
"    -j/--joystick1 index       specify joystick 1\n"
"    -J/--joystick2 index       specify joystick 2\n"
"\n"
"    -t/--tape-input file       specify tape input file (default: none)\n"
"    -T/--tape-output file      specify tape output file (default: none)\n"
"    -L/--tape-location         ACIA location: f000 (default), fc00\n"
"    -B/--tape-baseclock        set baseclock (default: 4800)\n"
"\n"
"    -f/--floppy0 file          specify floppy0 file (default: none)\n"
"    -F/--floppy1 file          specify floppy1 file (default: none)\n"
"    -g/--floppy2 file          specify floppy2 file (default: none)\n"
"    -G/--floppy3 file          specify floppy3 file (default: none)\n"
"\n"
"    -R/--force-ramtop hex      force RAM top to location hex\n"
"\n"
"    -y/--sound-mode mode       mode: none, 542b (DAC+tone), 600 (DAC)\n"
"    -Y/--sound-bufsize size    set sound buffer size (32-2048, default: 256)\n"
"\n"
"    -w/--warp-speed            run emulator as fast as possible\n"
"\n"
"    -Z/--switches switches     comma separated list of hardware switches\n"
"                               \"flipped\" before startup\n"
"                                 hires       enable high resolution overlay\n"
"                                 graph       enable graphics font\n"
"                                 nobasic     disable BASIC ROM (8kB extra RAM)\n"
"                                 fullscreen  start fullscreen\n"
"\n"
"    -D/--debug flag,...        enable debug messages: floppy\n"
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
    { "color-mode",     required_argument,  0, 'C' },
    { "frame-rate",     required_argument,  0, 'd' },
    { "debug",          required_argument,  0, 'D' },
    { "floppy0",        required_argument,  0, 'f' },
    { "floppy1",        required_argument,  0, 'F' },
    { "floppy2",        required_argument,  0, 'g' },
    { "floppy3",        required_argument,  0, 'G' },
    { "help",           no_argument,        0, 'h' },
    { "hires-mode",     required_argument,  0, 'H' },
    { "invert-keyboard",no_argument,        0, 'i' },
    { "joystick1",      required_argument,  0, 'j' },
    { "joystick2",      required_argument,  0, 'J' },
    { "kernel",         required_argument,  0, 'k' },
    { "cpu-speed",      required_argument,  0, 'K' },
    { "tape-location",  required_argument,  0, 'L' },
    { "video-mode",     required_argument,  0, 'm' },
    { "mono-color",     required_argument,  0, 'M' },
    { "graph-font",     required_argument,  0, 'q' },
    { "raw-keyboard",   no_argument,        0, 'r' },
    { "force-ramtop",   required_argument,  0, 'R' },
    { "saturation",     required_argument,  0, 's' },
    { "scanlines",      no_argument,        0, 'S' },
    { "tape-input",     required_argument,  0, 't' },
    { "tape-output",    required_argument,  0, 'T' },
    { "disable-video",  no_argument,        0, 'v' },
    { "smooth-video",   no_argument,        0, 'V' },
    { "warp-speed",     no_argument,        0, 'w' },
    { "pixels",         no_argument,        0, 'x' },
    { "sound-mode",     required_argument,  0, 'y' },
    { "sound-bufsize",  required_argument,  0, 'Y' },
    { "zoom",           required_argument,  0, 'z' },
    { "switches",       required_argument,  0, 'Z' },
};

int main_program(int argc, char **argv) {
    int option, index;
    double cpu_ticks = 0.0;
    bool switch_hires = false;
    bool switch_graph_font = false;
    bool switch_fullscreen = false;

    printf("OSIEMU - %s - Copyright © 2024 Ivo van Poorten\n", VERSION_STRING);

    while ((option = getopt_long(argc, argv, "a:Ab:B:c:C:d:D:f:F:g:G:hH:ij:J:k:K:L:m:M:qrR:s:St:T:vVwxy:Y:zZ:",
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
        case 'q':
            graph_font_filename = strdup(optarg);
            break;
        case 'k':
            kernel_filename = strdup(optarg);
            break;
        case 'K':
            if (!strcmp(optarg, "quarter")) {
                cpu_clock = CPU_CLOCK_QUARTER;
            } else if (!strcmp(optarg, "half")) {
                cpu_clock = CPU_CLOCK_HALF;
            } else if (!strcmp(optarg, "510c-slow")) {
                cpu_clock = CPU_CLOCK_510C_SLOW;
            } else if (!strcmp(optarg, "510c-fast")) {
                cpu_clock = CPU_CLOCK_510C_FAST;
            } else if (!strcmp(optarg, "540bw")) {
                cpu_clock = CPU_CLOCK_540B_BW;
            } else if (!strcmp(optarg, "540col")) {
                cpu_clock = CPU_CLOCK_540B_COL;
            } else {
                cpu_clock = strtol(optarg, NULL, 10);
            }
            break;
        case 'v':
            video_enabled = false;
            break;
        case 'V':
            video_smooth = true;
            break;
        case 'z':
            zoom = strtol(optarg, NULL, 10);
            if (zoom != 1 && zoom != 2 && zoom != 3 && zoom != 4) {
                fprintf(stderr, "error: invalid zoom factor\n");
                return 1;
            }
            break;
        case 'm':
            if (!strcmp(optarg, "64x32")) {
                osi_width = 64;
                osi_height = 32;
                osi_stride = 64;
                screen_ram_top = 0xd7ff;
            } else if (!strcmp(optarg, "32x32")) {
                osi_width = 32;
                osi_height = 32;
                osi_stride = 32;
                stretchx = 2;
                screen_ram_top = 0xd3ff;
            } else if (!strcmp(optarg, "32x32s64")) {
                osi_width = 32;
                osi_height = 32;
                osi_stride = 64;
                stretchx = 2;
                screen_ram_top = 0xd7ff;
            } else if (!strcmp(optarg, "64x16")) {
                osi_width = 64;
                osi_height = 16;
                osi_stride = 64;
                stretchy = 2;
                screen_ram_top = 0xd3ff;
            } else if (!strcmp(optarg, "540b")) {
                osi_width = 32;
                osi_height = 32;
                osi_stride = 64;
                stretchx = 2;
                screen_ram_top = 0xd7ff;
                control_5xx_enable = true;
            } else if (!strcmp(optarg, "600")) {
                osi_width = 32;
                osi_height = 32;
                osi_stride = 32;
                stretchx = 2;
                screen_ram_top = 0xd3ff;
                control_6xx_enable = true;
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
            } else if (!strcmp(optarg, "bluish")) {
                mono_color = COLOR_BLUISH;
            } else {
                mono_color = COLOR_WHITE;
            }
            break;
        case 'C':
            if (!strcmp(optarg, "monochrome")) {
                color_mode = COLORS_MONOCHROME;
            } else if (!strcmp(optarg, "440b")) {
                color_mode = COLORS_440B;
            } else if (!strcmp(optarg, "540b")) {
                color_mode = COLORS_540B;
                color_ram_enabled = true;
                color_ram_bottom = 0xe000;
                color_ram_top    = 0xe7ff;
                control_5xx_enable = true;
            } else if (!strcmp(optarg, "630")) {
                color_mode = COLORS_630;
                color_ram_enabled = true;
                color_ram_bottom  = 0xd400;
                color_ram_top     = 0xd7ff;
                control_6xx_enable = true;
            } else {
                fprintf(stderr, "error: unknown color mode: %s\n", optarg);
                return 1;
            }
            break;
        case 'd':
            if (!strcmp(optarg, "60")) {
                fps = FPS_60HZ;
            } else if (!strcmp(optarg, "540bw")) {
                fps = FPS_540_BW;
            } else if (!strcmp(optarg, "540col")) {
                fps = FPS_540_COL;
            } else {
                fprintf(stderr, "error: unknown frame rate\n");
                return 1;
            }
            break;
        case 's':
            saturation = strtod(optarg, NULL);
            if (saturation < 0.0 || saturation > 1.0) {
                fprintf(stderr, "error: saturation out of range [0.0-1.0]\n");
                return 1;
            }
            break;
        case 'S':
            scanlines_enable = true;
            break;
        case 'x':
            pixels_enable = true;
            scanlines_enable = true;
            break;
        case 'H':
            if (!strcmp(optarg, "none")) {
                hires_mode = HIRES_NONE;
            } else if (!strcmp(optarg, "440b")) {
                hires_mode = HIRES_440B;
            } else if (!strcmp(optarg, "541")) {
                hires_mode = HIRES_541;
                mmu_ram_top = 0x7ffe;
            } else {
                fprintf(stderr, "error: unknown hires mode: %s\n", optarg);
                return 1;
            }
            break;
        case 'i':
            keyboard_inverted ^= 1;
            break;
        case 't':
            tape_input_arg = strdup(optarg);
            break;
        case 'T':
            tape_output_arg = strdup(optarg);
            break;
        case 'L':
            tape_location = strtol(optarg, NULL, 16);
            if (tape_location != 0xf000 && tape_location != 0xfc00) {
                fprintf(stderr, "error: unknown tape location\n");
                return 1;
            }
            break;
        case 'B':
            tape_baseclock = strtod(optarg, NULL);
            break;
        case 'r':
            keyboard_cooked = false;
            keyboard_ascii_enable = false;
            break;
        case 'R':
            mmu_ram_top = strtol(optarg, NULL, 16);
            if (mmu_ram_top > 0xbfff) {
                puts("warning: ramtop > 0xbfff, are you sure?");
            }
            break;
        case 'A':
            keyboard_ascii_enable = true;
            break;
        case 'j':
            keyboard_joysticks[0] = atoi(optarg);
            break;
        case 'J':
            keyboard_joysticks[1] = atoi(optarg);
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
        case 'w':
            warp_speed = true;
            break;
        case 'y':
            if (!strcmp(optarg, "none")) {
                sound_enabled = false;
            } else if (!strcmp(optarg, "542b")) {
                sound_enabled = true;
                sound_mode = SOUND_MODE_542B;
                control_5xx_enable = true;
            } else if (!strcmp(optarg, "600")) {
                sound_enabled = true;
                sound_mode = SOUND_MODE_600;
                control_6xx_enable = true;
            } else {
                fprintf(stderr, "error: unknown mode %s\n", optarg);
                return 1;
            }
            break;
        case 'Y':
            sound_bufsize = strtol(optarg, NULL, 10);
            if (sound_bufsize < 32 || sound_bufsize > 2048) {
                fprintf(stderr, "error: invalid bufsize %s\n", optarg);
                return 1;
            }
            break;
        case 'Z': {
            char *sw = strtok(optarg, ",\r\n");
            while (sw) {
                if (!strcmp(sw, "hires")) {
                    puts("switch: hires on");
                    switch_hires = true;
                } else if (!strcmp(sw, "graph")) {
                    puts("switch: graph font on");
                    switch_graph_font = true;
                } else if (!strcmp(sw, "nobasic")) {
                    mmu_basic_enabled = false;
                    mmu_ram_top = 0xbfff;
                } else if (!strcmp(sw, "fullscreen")) {
                    puts("switch: start fullscreen");
                    switch_fullscreen = true;
                } else {
                    fprintf(stderr, "unrecognized switch '%s'\n", sw);
                    return 1;
                }
                sw = strtok(NULL, ",\r\n");
            }
            }
            break;
        case 'D': {
            char *w = strtok(optarg, ",\r\n");
            while (w) {
                if (!strcmp(w, "floppy")) {
                    floppy_debug++;
                    printf("debug: floppy, level %d\n", floppy_debug);
                } else if (!strcmp(w, "stack")) {
                    stack_debug++;
                    printf("debug: floppy, level %d\n", stack_debug);
                } else {
                    fprintf(stderr, "unrecognized debug type '%s'\n", w);
                    return 1;
                }
                w = strtok(NULL, ",\r\n");
            }
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

    if (optind != argc) {
        fprintf(stderr, "error: wrong command line arguments\n");
        return 1;
    }

    if (mmu_basic_enabled) {
        if (!mmu_load_file("basic", BASIC, 8192, basic_filename, false))
            return 1;
    }
    if (!mmu_load_file("kernel", KERNEL, 4096, kernel_filename, true)) {
        return 1;
    }

    if (color_mode == COLORS_630 && screen_ram_top >= 0xd400) {
        fprintf(stderr, "error: screen memory overlaps color RAM\n");
        return 1;
    }

    ticks_per_frame = cpu_clock / fps;

    printf("color mode: %s\n", color_modes_name[color_mode]);
    if (color_mode == COLORS_MONOCHROME) {
        printf("monochrome color: %s\n", mono_colors_name[mono_color]);
    }
    printf("hires mode: %s\n", hires_modes_name[hires_mode]);
    printf("screen width: %d\nscreen height: %d\n", osi_width, osi_height);
    printf("cpu clock: %d Hz\n", cpu_clock);
    printf("warp speed: %s\n", warp_speed ? "on" : "off");
    printf("frame rate: %.2lf fps\n", fps);
    printf("ticks per frame: %.2lf\n", ticks_per_frame);

    printf("matrix keyboard mode: %s\n", keyboard_cooked ? "cooked" : "raw");
    printf("matrix signals: %s\n", keyboard_inverted ? "model 600" : "model 542");
    printf("ascii keyboard: %s\n", keyboard_ascii_enable ? "enabled" : "disabled");

    if (SDL_Init(SDL_INIT_EVERYTHING) < 0) {
        fprintf(stderr, "error: SDL init failed\n");
        return 1;
    }

    if (!screen_init(cpu_clock, fps)) return 1;

    reset6502();
    if (!keyboard_init(cpu_clock)) {
        return 1;
    }
    if (!tape_init(tape_input_arg, tape_output_arg, cpu_clock)) {
        return 1;
    }
    if (!floppy_init(drive0_filename, drive1_filename,
                     drive2_filename, drive3_filename, cpu_clock)) {
        return 1;
    }
    if (!sound_init(cpu_clock)) {
        return 1;
    }

    // doubles to avoid drift when cpu_clock/fps or 1000/fps is not an integer

    double sdl_ticks_per_frame = 1000.0 / fps;
    double target = SDL_GetTicks();
    double cpu_target = cpu_ticks + ticks_per_frame;

    sound_start();

    if (switch_hires) screen_toggle_hires();
    if (switch_graph_font) screen_swap_fonts();
    if (switch_fullscreen) screen_toggle_fullscreen();

    trace_init();
    trace_status();

    while (1) {
        fflush(stdout);
        fflush(stderr);

        target += sdl_ticks_per_frame;

        screen_update();

        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            switch (e.type) {
            case SDL_QUIT:
                goto exit_out;
                break;
            case SDL_KEYDOWN:
                if (e.key.repeat) break;
                switch (e.key.keysym.sym) {
                default:
                    keyboard_press_key(&e.key.keysym);
                    break;
                }
                break;
            case SDL_KEYUP:
                if (e.key.repeat) break;
                switch (e.key.keysym.sym) {
                case SDLK_F3:
                    screen_toggle_hires();
                    break;
                case SDLK_F4:
                    screen_swap_fonts();
                    break;
                case SDLK_F5:
                    reset6502();
                    break;
                case SDLK_F8:
                    {
                    screen_hide();
                    double remember = SDL_GetTicks();
                    if (!monitor()) goto exit_out;
                    double elapsed = SDL_GetTicks() - remember;
                    target += elapsed;
                    screen_unhide();
                    }
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
            case SDL_JOYAXISMOTION:
            case SDL_JOYBUTTONDOWN:
            case SDL_JOYBUTTONUP:
            case SDL_JOYHATMOTION:
                keyboard_joystick_event(&e);
                break;
//            default:
//                printf("main: sdl event %d\n", e.type);
//                break;
            }
        }

        while (cpu_ticks < cpu_target) {
            if (monitor_checkbp()) {
                screen_hide();
                double remember = SDL_GetTicks();
                if (!monitor()) goto exit_out;
                double elapsed = SDL_GetTicks() - remember;
                target += elapsed;
                screen_unhide();
            }
            static double ticks;
            trace_tick(ticks);
            trace_stack_tick();
            ticks = step6502();
            cpu_ticks += ticks;
            tape_tick(ticks);
            keyboard_tick(ticks);
            floppy_tick(ticks);
            screen_tick(ticks);
            sound_tick(ticks);
        }

        cpu_target += ticks_per_frame;

        if (!warp_speed) {
            while (SDL_GetTicks() < target) {
#ifndef DONT_USE_NANOSLEEP
                struct timespec wait = { 0, 100000 };   // 0.1ms
                nanosleep(&wait,NULL);
#else
                SDL_Delay(1);                           // 1ms, less accurate
#endif
            }
        }
    }

exit_out:
    floppy_quit();
    SDL_Quit();
    return 0;
}

#define add_arg(x) \
    myargc++; \
    myargv = realloc(myargv, myargc * sizeof(char *)); \
    myargv[myargc-1] = (x)

int main(int argc, char **argv) {
    if (argc == 1 || argc > 2 || (argv[1] && argv[1][0] == '-')) {
        return main_program(argc, argv);
    }
    printf("loading configuration from %s\n", argv[1]);

    FILE *f = fopen(argv[1], "rb");
    if (!f) {
        fprintf(stderr, "unable to open %s\n", argv[1]);
        return 1;
    }

    char *lineptr = NULL;
    size_t n = 0;

    int myargc = 0;
    char **myargv = NULL;

    add_arg("osiemu");

    while (getline(&lineptr, &n, f) >= 0) {
        char *p = strtok(lineptr, " =\r\n");
        if (p[0] == '-') {
            add_arg(strdup(p));
        } else {
            char *q = malloc(strlen(p)+2+1);
            q[0] = q[1] = '-';
            memcpy(q+2, p, strlen(p)+1);
            add_arg(q);
        }
        p = strtok(NULL, "\r\n");
        if (p) {
            add_arg(strdup(p));
        }
    }
    return main_program(myargc, myargv);
}
