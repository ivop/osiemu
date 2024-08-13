/*
 * osiemu - Ohio Scientific Instruments, Inc. Emulator
 *
 * Copyright © 2024 by Ivo van Poorten
 *
 * This file is licensed under the terms of the 2-clause BSD license. Please
 * see the LICENSE file in the root project directory for the full text.
 */

#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>

#include "control.h"
#include "portability.h"
#include "video.h"

bool control_5xx_enable;
bool control_6xx_enable;

uint8_t control_5xx;
uint8_t control_6xx;

void control_5xx_write(uint16_t address UNUSED, uint8_t value) {
    uint8_t old = control_5xx;
    control_5xx = value;
    if ((old&1) != (value&1)) screen_reinit_540();
}

void control_6xx_write(uint16_t address UNUSED, uint8_t value) {
    uint8_t old = control_6xx;
    control_6xx = value;
    if ((old&1) != (value&1)) screen_reinit_600();
}
