#pragma once
#include <SDL.h>
#include <stdint.h>

enum mono_colors {
    COLOR_GREEN = 0,
    COLOR_AMBER,
    COLOR_WHITE,
    COLOR_BLUISH
};

enum color_modes {
    COLORS_MONOCHROME,
    COLORS_440B,
    COLORS_540B,
    COLORS_630
};

enum hires_modes {
    HIRES_NONE,
    HIRES_440B,
    HIRES_541
};

extern enum mono_colors mono_color;
extern enum color_modes color_mode;
extern enum hires_modes hires_mode;

extern char *font_filename;
extern char *graph_font_filename;

extern bool video_enabled;
extern bool color_ram_enabled;
extern bool video_smooth;
extern bool fullscreen;

extern double aspectx;
extern double aspecty;

extern int zoom;
extern int stretchx;
extern int stretchy;

extern uint16_t screen_ram_bottom;
extern uint16_t screen_ram_top;
extern uint16_t color_ram_bottom;
extern uint16_t color_ram_top;
extern double saturation;

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

uint8_t screen_hires_ram_read(uint16_t address);
void screen_hires_ram_write(uint16_t address, uint8_t value);

uint8_t screen_control_540b_read(uint16_t address);
void screen_control_540b_write(uint16_t address, uint8_t value);

void screen_control_630_write(uint16_t address, uint8_t value);

void screen_swap_fonts(void);
