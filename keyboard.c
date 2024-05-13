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
#include "fake6502/fake6502.h"

#include <SDL.h>

#include "keyboard.h"
#include "cooked.h"

bool keyboard_inverted = true;
bool keyboard_cooked = true;

static double keyboard_ticks;
static double interval;
static bool cooked_pressed;

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

static void clear_matrix(void) {
    memset(keyboard_osi_matrix, keyboard_inverted ? 0xff : 0, 8);
}

void keyboard_init(double cpu_clock) {
    interval = cpu_clock / 50.0;
    clear_matrix();
    SDL_StartTextInput();
}

static char fake_input[2] = " ";

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

    if (key->sym > 127 || !key->sym) return;

    for (i = 0; i < 64; i++) {
        row = i / 8;
        col = i % 8;
        if (keyboard_matrix[row][col] == key->sym) break;
    }
    if (i == 64) return;    // not found

//    printf("\tfound row %d col %d\n", row, col);

    clear_matrix();

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

void keyboard_release_key(SDL_Keysym *key) {
    clear_matrix();
}

void keyboard_text_input(char *text) {
    if (!keyboard_cooked) {
        return;
    }
    if (isprint(text[0])) {
        printf("%c\n", text[0]);
    } else {
        printf("$%02x\n", text[0]);
    }
    char key = text[0] & 0x7f;
    if (cooked_lut[key].row > 0) {
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

void keyboard_tick(double ticks) {
    if (!keyboard_cooked) {
        return;
    }

    keyboard_ticks += ticks;
    if (keyboard_ticks < interval) {
        return;
    }

    keyboard_ticks -= interval;
}

uint8_t keyboard_read(void) {
    return keyboard_osi_matrix[keyboard_osi_row];
}

void keyboard_write(uint8_t value) {
    if (keyboard_inverted) value ^= 0xff;
    for (int i=0; i<8; i++) {
        if (value & (1<<i)) keyboard_osi_row = i;
    }
}

// ----------------------------------------------------------------------------
