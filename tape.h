#pragma once
#include <stdint.h>
#include <stdbool.h>

bool tape_init(char *input_file, char *output_filei, double cpu_clock);
uint8_t tape_read(uint16_t address);
void tape_write(uint16_t address, uint8_t value);
