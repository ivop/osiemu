#pragma once
#include <stdint.h>

extern bool control_5xx_enable;
extern bool control_6xx_enable;

#define CONTROL_540B_32X32      0x01    // leave up to command line for now
#define CONTROL_542B_TONE_ON    0x02    // 542 keyboard tone
#define CONTROL_540B_COLOR_ON   0x04    // 1=color on
#define CONTROL_5XX_ACHOME      0x08    // 38-40kHz AC Home Control output

extern uint8_t control_5xx;

#define CONTROL_630_64x16       0x01    // leave up to command line for now
#define CONTROL_630_COLOR_ON    0x02    // 1=color on
#define CONTROL_600_BK0         0x04
#define CONTROL_600_BK1         0x08
#define CONTROL_600_DAC_ENABLE  0x10    // enable 600 DAC

extern uint8_t control_6xx;

void control_5xx_write(uint16_t address, uint8_t value);
void control_6xx_write(uint16_t address, uint8_t value);
