#pragma once
struct acia {
    // callbacks
    //
    int (*input)(void);                 // return -1 on EOF, or value [0..]
    int (*output)(uint8_t byte);        // return -1 on overun, 0 OK
 
    // internal
    //
    uint8_t status;
    uint8_t command;
    uint8_t control;
};

void acia_init(struct acia *a, double cpu_clock);
void acia_hardware_reset(struct acia *a);
void acia_tick(struct acia *a);
