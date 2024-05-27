#pragma once
#include <SDL.h>
#include <stdint.h>
#include <stdbool.h>

extern bool keyboard_inverted;
extern bool keyboard_cooked;
extern bool keyboard_ascii_enable;
extern int keyboard_joysticks[2];

bool keyboard_init(double cpu_clock);
void keyboard_press_key(SDL_Keysym *key);
void keyboard_release_key(SDL_Keysym *key);
void keyboard_text_input(char *text);
void keyboard_tick(double ticks);

void keyboard_joystick_event(SDL_Event *e);

uint8_t keyboard_read(void);
void keyboard_write(uint8_t value);

uint8_t keyboard_ascii_read(void);
