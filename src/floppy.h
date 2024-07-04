#pragma once
#include <stdint.h>
#include <stdbool.h>

struct drive {
    FILE *f;
    char *fname;
    off_t offset;
    char *map;
    size_t mapsize;

    unsigned int pos;
    uint8_t bit;

    unsigned int curtrk;
    bool ready;
    bool r_w;
};

enum osi_disk_type {
    TYPE_525_SS,
    TYPE_8_SS
};

extern int disk_type;
extern struct drive drives[4];

extern bool floppy_enable;
extern bool head_on_disk;

bool floppy_init(char *drive0_filename, char *drive1_filename,
                 char *drive2_filename, char *drive3_filename,
                                                        double cpu_clock);

uint8_t floppy_pia_read(uint16_t address);
void floppy_pia_write(uint16_t address, uint8_t value);

uint8_t floppy_acia_read(uint8_t address);
void floppy_acia_write(uint16_t address, uint8_t value);

void floppy_tick(double ticks);
void floppy_get_current_track_and_drive(int *track, int *drive);
void floppy_quit(void);
