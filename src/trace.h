#pragma once
#include <stdbool.h>

void trace_tick(double ticks);
void trace_init(void);
void trace_on(void);
void trace_off(void);
bool trace_status(void);
void trace_save(char *filename);

extern unsigned int stack_debug;
void trace_stack_on(void);
void trace_stack_off(void);
bool trace_stack_status(void);
void trace_stack_tick(void);
void trace_stack_show(void);
