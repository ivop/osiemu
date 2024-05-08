#pragma once
#include <SDL.h>

extern bool keyboard_inverted;

void keyboard_init(void);
void keyboard_press_key(SDL_Keysym *key);
void keyboard_release_key(SDL_Keysym *key);
uint8_t keyboard_read(void);
void keyboard_write(uint8_t value);
