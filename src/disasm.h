#pragma once

enum cpu_type {
    CPU_TYPE_NMOS6502,
    CPU_TYPE_NMOS6502_UNDEF,
    CPU_TYPE_CMOS6502
};

void disasm_set_cpu(enum cpu_type type);
char *disasm_get_string(uint16_t *address);
