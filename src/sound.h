#pragma once
#include <stdbool.h>

extern bool sound_enabled;

enum sound_mode_e {
    SOUND_MODE_NONE,
    SOUND_MODE_542B,        // $df01 8-bit DAC and Tone Generator
    SOUND_MODE_600          // $df00 8-bit DAC
};

extern enum sound_mode_e sound_mode;

void sound_start(void);
void sound_stop(void);

bool sound_init(double cpu_clock);
void sound_tick(double ticks);

void sound_5xx_write_dac_or_tone(uint8_t value);
void sound_6xx_write_dac(uint8_t value);
