#pragma once
#include <stdint.h>
#include <stdbool.h>

void heatmap_init(void);
void heatmap_enable(void);
void heatmap_disable(void);
void heatmap_status(void);
void heatmap_read(uint16_t address);
void heatmap_write(uint16_t address);
void heatmap_save(char *filename);
void heatmap_image(char *filename);
