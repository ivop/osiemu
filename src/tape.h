#pragma once
#include <stdint.h>
#include <stdbool.h>

extern double tape_baseclock;
extern char *tape_input_filename;
extern char *tape_output_filename;
extern int tape_activity;

bool tape_init(char *input_file, char *output_file, double cpu_clock);
uint8_t tape_read(uint16_t address);
void tape_write(uint16_t address, uint8_t value);
void tape_tick(double ticks);
void tape_rewind_input(void);
void tape_rewind_output(void);
void tape_eject_input(void);
void tape_eject_output(void);
bool tape_insert_input(char *filename);
bool tape_insert_output(char *filename);
