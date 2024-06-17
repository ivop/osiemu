#pragma once
#include <stdbool.h>

extern bool sound_enabled;

void sound_start(void);
void sound_stop(void);

bool sound_init(double cpu_clock);
void sound_tick(double ticks);
