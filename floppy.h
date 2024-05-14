#pragma once
#include <stdint.h>
#include <stdbool.h>

extern bool floppy_enable;

bool floppy_init(void);

uint8_t floppy_pia_read(uint16_t address);
void floppy_pia_write(uint16_t address, uint8_t value);

uint8_t floppy_acia_read(uint8_t address);
void floppy_acia_write(uint16_t address, uint8_t value);
