#pragma once
#include <SDL.h>

extern bool keyboard_inverted;
extern bool keyboard_cooked;

void keyboard_init(double cpu_clock);
void keyboard_press_key(SDL_Keysym *key);
void keyboard_release_key(SDL_Keysym *key);
void keyboard_text_input(char *text);
void keyboard_tick(double ticks);

uint8_t keyboard_read(void);
void keyboard_write(uint8_t value);
