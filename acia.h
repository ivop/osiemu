#pragma once
struct acia {
    // Callback functions
    //
    // int input()
    //      return values:
    //      -1      EOF
    //      0-255   input value
    //      set bit 8 if a value was missed
    //
    int (*input)(void);
    //
    // int output(uint8_t byte)
    //      return values:
    //      -1      last byte was not sent yet
    //      0       OK
    //
    int (*output)(uint8_t byte);
 
    // internal
    //
    uint8_t status;
    uint8_t command;
    uint8_t control;
};

void acia_init(struct acia *a, double cpu_clock);
void acia_hardware_reset(struct acia *a);
void acia_tick(struct acia *a);
