#pragma once
#include <SDL.h>

extern char *font_filename;

extern uint8_t SCREEN[0x0800];
extern uint8_t COLOR[0x0800];

extern bool video_enabled;
extern bool color_enabled;
extern bool video_smooth;

extern double aspectx;
extern double aspecty;

extern int zoom;
extern int stretchx;
extern int stretchy;

extern int screen_width;
extern int screen_height;

extern int osi_width;
extern int osi_height;

bool screen_init(void);
void screen_update(void);
uint8_t screen_read(uint16_t address);
void screen_write(uint16_t address, uint8_t value);

