#pragma once
#include <stdint.h>

extern uint8_t BASIC[0x2000];
extern uint8_t KERNEL[0x1000];

extern uint16_t mmu_ram_top;
extern bool mmu_basic_enabled;
extern uint16_t tape_location;

bool mmu_load_file(char *heading, uint8_t *buf, unsigned int size, char *filename, bool iskernel);
