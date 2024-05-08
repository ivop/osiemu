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

#include "keyboard.h"

bool keyboard_inverted = true;

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

void keyboard_init(void) {
    memset(keyboard_osi_matrix, keyboard_inverted ? 0xff : 0, 8);
}

void keyboard_press_key(SDL_Keysym *key) {
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

void keyboard_release_key(SDL_Keysym *key) {
    keyboard_init();
}

uint8_t keyboard_read(void) {
//    printf("keyb read, osi_row %d\n", keyboard_osi_row);
//    printf("bitmap: %02x\n", keyboard_osi_matrix[keyboard_osi_row]);
    return keyboard_osi_matrix[keyboard_osi_row];
}

void keyboard_write(uint8_t value) {
//    printf("keyb write %02x\n", value);
    if (keyboard_inverted) value ^= 0xff;
    for (int i=0; i<8; i++) {
        if (value & (1<<i)) keyboard_osi_row = i;
    }
}

// ----------------------------------------------------------------------------
