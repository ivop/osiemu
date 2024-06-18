#pragma once
#include <stdint.h>
#include <stdbool.h>

extern double tape_baseclock;
extern bool tape_running;

bool tape_init(char *input_file, char *output_file, double cpu_clock);
uint8_t tape_read(uint16_t address);
void tape_write(uint16_t address, uint8_t value);
void tape_tick(double ticks);
void tape_rewind(void);
