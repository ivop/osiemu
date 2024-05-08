#pragma once

extern uint8_t RAM[0xc000];
extern uint8_t BASIC[0x2000];
extern uint8_t SCREEN[0x0800];
extern uint8_t COLOR[0x0800];
extern uint8_t KERNEL[0x1000];

extern uint16_t ram_top;
extern uint16_t kernel_bottom;

extern bool basic_enabled;

bool load_file(uint8_t *buf, int size, char *filename, bool iskernel);
