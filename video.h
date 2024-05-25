#pragma once
#include <SDL.h>
#include <stdint.h>

enum mono_colors {
    COLOR_GREEN = 0,
    COLOR_AMBER,
    COLOR_WHITE
};

extern char *font_filename;

extern bool video_enabled;
extern bool color_ram_enabled;
extern bool video_smooth;
extern enum mono_colors mono_color;
extern bool fullscreen;

extern double aspectx;
extern double aspecty;

extern int zoom;
extern int stretchx;
extern int stretchy;

extern int screen_width;
extern int screen_height;

extern int osi_width;
extern int osi_height;
extern int osi_stride;

bool screen_init(void);
void screen_update(void);
void screen_hide(void);
void screen_unhide(void);
void screen_toggle_fullscreen(void);
uint8_t screen_read(uint16_t address);
void screen_write(uint16_t address, uint8_t value);
uint8_t screen_color_ram_read(uint16_t address);
void screen_color_ram_write(uint16_t address, uint8_t value);
