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
#include <string.h>
#include "portability.h"
#include "fake6502/fake6502.h"

#include <SDL.h>

#include "keyboard.h"
#include "cooked.h"

bool keyboard_inverted = true;
bool keyboard_cooked = true;
bool keyboard_ascii_enable = false;

int keyboard_joysticks[2] = { -1, -1 };
static uint8_t joystick_values[2];
static uint8_t joystick_triggers[2];
static int joystick_axes[2][2];

static double keyboard_ticks;
static double interval;

static uint8_t ascii_value = 0x80;

enum ascii_state_e {
    STATE_IDLE,
    STATE_PULSE_DOWN,
    STATE_PULSE_UP
};

static enum ascii_state_e ascii_state = STATE_IDLE;

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
static char fake_input[2] = " ";

// ----------------------------------------------------------------------------

static void clear_matrix(void) {
    memset(keyboard_osi_matrix, keyboard_inverted ? 0xff : 0, 8);
}

// ----------------------------------------------------------------------------

bool keyboard_init(double cpu_clock) {
    interval = cpu_clock / 50.0;
    clear_matrix();
    SDL_StartTextInput();

    int numsticks = SDL_NumJoysticks();

    printf("joystick: detected %d joysticks\n", numsticks);

    if (keyboard_joysticks[0] < 0 && keyboard_joysticks[1] < 0) {
        for (int i=0; i<numsticks; i++) {
            printf("joystick: %d - %s (%04x:%04x)\n", i,
                                            SDL_JoystickNameForIndex(i),
                                            SDL_JoystickGetDeviceVendor(i),
                                            SDL_JoystickGetDeviceProduct(i));
        }
        return true;
    }

    for (int i=0; i<2; i++) {
        if (keyboard_joysticks[i] >= numsticks) {
            puts("joystick: invalid joystick number");
            return false;
        }

        SDL_Joystick *p = SDL_JoystickOpen(keyboard_joysticks[i]);

        if (!p) {
            printf("joystick: cannot open joystick device %d\n",
                                                        keyboard_joysticks[i]);
            return false;
        }
    }

    return true;
}

// ----------------------------------------------------------------------------

static void raw_keyboard_modifiers(SDL_Keysym *key) {
    if (key->mod & KMOD_CAPS)
        keyboard_osi_matrix[0] ^= 1 << 0;
    if (key->mod & KMOD_LSHIFT)
        keyboard_osi_matrix[0] ^= 1 << 2;
    if (key->mod & KMOD_RSHIFT)
        keyboard_osi_matrix[0] ^= 1 << 1;
    if (key->mod & KMOD_LCTRL || key->mod & KMOD_RCTRL)
        keyboard_osi_matrix[0] ^= 1 << 6;
}

void keyboard_press_key(SDL_Keysym *key) {
    int i, row, col;

    if (keyboard_cooked) {
        if ( (key->sym != SDLK_LCTRL && (key->mod & KMOD_LCTRL)) ||
             (key->sym != SDLK_RCTRL && (key->mod & KMOD_RCTRL)) ) {
            // Control combinations don't generate TEXTINPUT events
            if (key->sym >= SDLK_a && key->sym <= SDLK_z) {
                fake_input[0] = key->sym - SDLK_a + 1;
                keyboard_text_input(fake_input);
            }
        } else if (key->sym == SDLK_RETURN) {
            fake_input[0] = 28;
            keyboard_text_input(fake_input);
        } else if (key->sym == SDLK_ESCAPE) {
            fake_input[0] = 27;
            keyboard_text_input(fake_input);
        } else if (key->sym == SDLK_BACKSPACE) {
            fake_input[0] = 127;
            keyboard_text_input(fake_input);
        }
        return;
    }

    // RAW keyboard

    clear_matrix();

    if (key->sym > 127 || !key->sym) {
        raw_keyboard_modifiers(key);
        return;
    }

    for (i = 0; i < 64; i++) {
        row = i / 8;
        col = i % 8;
        if (keyboard_matrix[row][col] == key->sym) break;
    }
    if (i == 64) return;    // not found

    keyboard_osi_matrix[row] ^= 1 << col;

    raw_keyboard_modifiers(key);
}

// ----------------------------------------------------------------------------

void keyboard_release_key(SDL_Keysym *key UNUSED) {
    clear_matrix();
    raw_keyboard_modifiers(key);
}

// ----------------------------------------------------------------------------

void keyboard_text_input(char *text) {
    if (!keyboard_cooked) {
        return;
    }

    unsigned char key = text[0] & 0x7f;

    if (keyboard_ascii_enable) {
        ascii_value = key | 0x80;
        if (ascii_value == (28 | 0x80)) {
            ascii_value = 13 | 0x80;        // CR --> ^M
        }
        ascii_state = STATE_PULSE_DOWN;
    }

    if (cooked_lut[key].row > 0) {
        clear_matrix();
        keyboard_osi_matrix[cooked_lut[key].row] ^= 1 << cooked_lut[key].col;;

        char shift = cooked_lut[key].shift;

        if (shift == 1) {
            keyboard_osi_matrix[0] ^= 1 << 2;   // lshift
        } else if (shift == 2) {
            keyboard_osi_matrix[0] ^= 1 << 1;   // rshift
        } else if (shift == 3) {
            keyboard_osi_matrix[0] ^= 1 << 0;   // caps
        }
        if (cooked_lut[key].control) {
            keyboard_osi_matrix[0] ^= 1 << 6;   // ctrl
        }
    }
}

// ----------------------------------------------------------------------------

void keyboard_tick(double ticks) {
    if (!keyboard_ascii_enable) {
        return;
    }

    keyboard_ticks += ticks;
    if (keyboard_ticks < interval) {
        return;
    }

    keyboard_ticks -= interval;

    switch (ascii_state) {
    case STATE_IDLE:
        break;
    case STATE_PULSE_DOWN:
        ascii_value &= 0x7f;
        ascii_state = STATE_PULSE_UP;
        break;
    case STATE_PULSE_UP:
        ascii_value |= 0x80;
        ascii_state = STATE_IDLE;
        break;
    }
}

// ----------------------------------------------------------------------------

uint8_t keyboard_read(void) {
    uint8_t mask = keyboard_osi_row;
    uint8_t value = 0;
    if (keyboard_inverted) {        // Model 600
        mask ^= 0xff;
        value ^= 0xff;
        for (int i=0; i<8; i++) {
            if (mask & (1<<i)) value &= keyboard_osi_matrix[i];
        }
    } else {
        for (int i=0; i<8; i++) {   // Model 540
            if (mask & (1<<i)) value |= keyboard_osi_matrix[i];
        }
    }
    return value;
}

// ----------------------------------------------------------------------------

void keyboard_write(uint8_t value) {
    keyboard_osi_row = value;
}

// ----------------------------------------------------------------------------

uint8_t keyboard_ascii_read(void) {
    return ascii_value;
}

// ----------------------------------------------------------------------------

#define HAT_UP      0x01
#define HAT_RIGHT   0x02
#define HAT_DOWN    0x04
#define HAT_LEFT    0x08

#define JOY1_UP     0x10
#define JOY1_DOWN   0x08
#define JOY1_RIGHT  0x04
#define JOY1_LEFT   0x02
#define JOY1_FIRE   0x01

#define JOY2_FIRE   0x80
#define JOY2_DOWN   0x40
#define JOY2_UP     0x20
#define JOY2_RIGHT  0x10
#define JOY2_LEFT   0x08

static int hat_to_joy[2][16] = {
    {
    [HAT_UP]               = JOY1_UP,
    [HAT_RIGHT]            = JOY1_RIGHT,
    [HAT_DOWN]             = JOY1_DOWN,
    [HAT_LEFT]             = JOY1_LEFT,
    [HAT_UP   | HAT_RIGHT] = JOY1_UP   | JOY1_RIGHT,
    [HAT_DOWN | HAT_RIGHT] = JOY1_DOWN | JOY1_RIGHT,
    [HAT_UP   | HAT_LEFT]  = JOY1_UP   | JOY1_LEFT,
    [HAT_DOWN | HAT_LEFT]  = JOY1_DOWN | JOY1_LEFT
    },
    {
    [HAT_UP]               = JOY2_UP,
    [HAT_RIGHT]            = JOY2_RIGHT,
    [HAT_DOWN]             = JOY2_DOWN,
    [HAT_LEFT]             = JOY2_LEFT,
    [HAT_UP   | HAT_RIGHT] = JOY2_UP   | JOY2_RIGHT,
    [HAT_DOWN | HAT_RIGHT] = JOY2_DOWN | JOY2_RIGHT,
    [HAT_UP   | HAT_LEFT]  = JOY2_UP   | JOY2_LEFT,
    [HAT_DOWN | HAT_LEFT]  = JOY2_DOWN | JOY2_LEFT
    }
};

#define DEADZONE 8000

void keyboard_joystick_event(SDL_Event *e) {
    uint8_t mask = keyboard_inverted ? 0xff : 0x00;
    int fakehat = 0;
    int which = -1;

    if (keyboard_joysticks[0] == e->jhat.which) {
        which = 0;
    } else if (keyboard_joysticks[1] == e->jhat.which) {
        which = 1;
    }
    if (which < 0) return;

    switch (e->type) {
    case SDL_JOYAXISMOTION:
        if (e->jaxis.axis > 1) return;

        joystick_axes[which][e->jaxis.axis] = e->jaxis.value; // buffer values

        if (joystick_axes[which][1] < -DEADZONE) fakehat |= HAT_UP;
        if (joystick_axes[which][1] >  DEADZONE) fakehat |= HAT_DOWN;
        if (joystick_axes[which][0] < -DEADZONE) fakehat |= HAT_LEFT;
        if (joystick_axes[which][0] >  DEADZONE) fakehat |= HAT_RIGHT;

        joystick_values[which] = hat_to_joy[which][fakehat];
        break;

    case SDL_JOYHATMOTION:
        if (e->jhat.hat > 0) return;
        joystick_values[which] = hat_to_joy[which][e->jhat.value];
        break;

    case SDL_JOYBUTTONDOWN:
        if (keyboard_joysticks[0] == e->jhat.which) {
            which = 0;
        } else if (keyboard_joysticks[1] == e->jhat.which) {
            which = 1;
        }
        if (which < 0) return;

        joystick_triggers[which] = which ? JOY2_FIRE : JOY1_FIRE;
        break;

    case SDL_JOYBUTTONUP:
        if (keyboard_joysticks[0] == e->jhat.which) {
            which = 0;
        } else if (keyboard_joysticks[1] == e->jhat.which) {
            which = 1;
        }
        if (which < 0) return;

        joystick_triggers[which] = 0;
        break;
    }
    keyboard_osi_matrix[7] = (joystick_values[0] | joystick_triggers[0]) ^ mask;
    keyboard_osi_matrix[4] = (joystick_values[1] | joystick_triggers[1]) ^ mask;
}

// ----------------------------------------------------------------------------
