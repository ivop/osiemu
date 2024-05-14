#pragma once
#include <stdint.h>
#include <stdbool.h>

extern bool floppy_enable;

bool floppy_init(char *drive0_filename, char *drive1_filename,
                                                        double cpu_clock);

uint8_t floppy_pia_read(uint16_t address);
void floppy_pia_write(uint16_t address, uint8_t value);

uint8_t floppy_acia_read(uint8_t address);
void floppy_acia_write(uint16_t address, uint8_t value);

void floppy_tick(double ticks);
