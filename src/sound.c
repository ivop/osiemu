/*
 * osiemu - Ohio Scientific Instruments, Inc. Emulator
 *
 * Copyright © 2024 by Ivo van Poorten
 *
 * This file is licensed under the terms of the 2-clause BSD license. Please
 * see the LICENSE file in the root project directory for the full text.
 */

#include <stdio.h>
#include <math.h>
#include <stdbool.h>
#include <SDL.h>
#include <SDL_audio.h>

#include "portability.h"
#include "sound.h"
#include "control.h"

bool sound_enabled;
unsigned int sound_bufsize = 256;

enum sound_mode_e sound_mode = SOUND_MODE_542B;

static SDL_AudioDeviceID audio_device;

static double dac_542b_volumes[256];    // maps 8-bit DAC to volume [0.0-1.0]
static double tone_542b_volumes[256];   // volume for freq div V [0.0-1.0]

static double *dac_600_volumes = dac_542b_volumes;      // identical

#define RINGBUF_SIZE 4096

static uint16_t ring_buffer[RINGBUF_SIZE];
static uint16_t *readp = ring_buffer;
static uint16_t *writep = ring_buffer;

static uint8_t dac_or_tone = 0;

static double tone_counter;
static double tone_interval = 5*2*(0+1);
static bool   tone_level;

static double sample_counter;
static double sample_interval;

// ----------------------------------------------------------------------------

// See doc/542B-DAC.txt for details

static double poly6[4][7] = {
/*  1-100 Hz */ { -1.511750E+01, -1.958976E-14, -1.165709E-06, -1.754988E-16,
                   1.564514E-13, -6.738307E-20, -2.760927E-20 },
/* .1-  1kHz */ { -1.511747E+01, -5.057542E-07, -1.161440E-06, -1.797632E-11,
                   1.975130E-13, -5.047754E-17,  2.504592E-22 },
/*  1- 10kHz */ { -1.473646E+01, -6.210253E-04, -1.052175E-06,  3.130030E-10,
                  -4.307847E-14,  2.948358E-18, -8.047391E-23 },
/* 10-100kHz */ { -1.865841E+01, -1.495209E-03,  4.912716E-08, -1.049522E-12,
                   1.308050E-17, -8.637777E-23,  2.328160E-28 }
};

static void calculate_542b_dac_volumes(void) {
    static double Rtop = 510;
    static double Rbits[8] = {
        68000, 33000, 16000, 8200, 3900, 2000, 1000, 510
    };
 
    static double normZero = 1.659589;

    for (int x=0; x<256; x++) {
        double Rbottom = 0.0;
        for (int bit=0; bit<8; bit++) {
            if (!(x & (1<<bit))) {
                Rbottom += 1.0 / Rbits[bit];
            }
        }
        if (Rbottom == 0.0) Rbottom = 1.0/1000000000.0;     // --> inf
        Rbottom = 1.0 / Rbottom;

        double Rtotal = Rtop + Rbottom;
        double Vout = 5.0 * Rbottom / Rtotal;               // voltage divider
        Vout = (Vout - normZero) / (5.0 - normZero);        // [0.0-1.0]
 
        dac_542b_volumes[x] = Vout;
    }
}

// ----------------------------------------------------------------------------

// See doc/542B-tone-generator.txt for details

static double attenuation(double x) {
    int p = 3;
    if (x < 100.0)          p = 0;
    else if (x < 1000.0)    p = 1;
    else if (x < 10000.0)   p = 2;

    double result = 0.0;
    for (int i=0; i<7; i++) result += poly6[p][i] * pow(x,i);

    return result;
}

static void calculate_542b_tonegen_volumes(double cpu_clock) {
    for (int V=0; V<256; V++) {
        double f = cpu_clock / 5.0 / 2.0 / (V+1) / 2.0;
        double a = attenuation(f) + 15.16;           // normalize to 0dB
        if (f > 16000) a = -96.0;
        tone_542b_volumes[V] = pow(10, a / 20.0);
    }
}

// ----------------------------------------------------------------------------

static uint16_t mixer(void) {
    uint16_t sample = 0;
    if (sound_mode == SOUND_MODE_542B) {
        // we mix the DAC and tone generator (or silence) 50:50
        if (control_5xx & CONTROL_542B_TONE_ON) {
            sample += tone_level * tone_542b_volumes[dac_or_tone] * 32767;
        }
        sample += dac_542b_volumes[dac_or_tone] * 32767;
    } else if (sound_mode == SOUND_MODE_600) {
        if (control_6xx & CONTROL_600_DAC_ENABLE) {
            sample = dac_600_volumes[dac_or_tone] * 65535;
        }
    }
    return sample;
}

void sound_tick(double ticks) {
    if (!sound_enabled) return;

    if (sound_mode == SOUND_MODE_542B) {
        tone_counter += ticks;
        if (tone_counter >= tone_interval) {
            tone_counter -= tone_interval;
            tone_level ^= 1;
        }
    }

    sample_counter += ticks;
    if (sample_counter >= sample_interval) {
        sample_counter -= sample_interval;
        // increase first, then write; in case readp catches up, last sample
        // is repeated
        writep++;
        if (writep == &ring_buffer[RINGBUF_SIZE]) writep = ring_buffer;
        *writep = mixer();
    }
}

// ----------------------------------------------------------------------------

static void callback(void *udata UNUSED, uint8_t *stream, int len) {
    uint16_t *s = (uint16_t *) stream;

    for (int i=0; i<len; i+=sizeof(int16_t)) {
        *s++ = *readp;
        if (readp != writep) {
            readp++;
            if (readp == &ring_buffer[RINGBUF_SIZE]) readp = ring_buffer;
        }
    }
}

// ----------------------------------------------------------------------------

void sound_start(void) {
    if (sound_enabled) SDL_PauseAudioDevice(audio_device, false);
}

void sound_stop(void) {
    if (sound_enabled) SDL_PauseAudioDevice(audio_device, true);
}

// ----------------------------------------------------------------------------

bool sound_init(double cpu_clock) {
    if (!sound_enabled) return true;

    SDL_AudioSpec audio_spec;
    SDL_zero(audio_spec);
    audio_spec.freq = 44100;
    audio_spec.format = AUDIO_U16SYS;
    audio_spec.channels = 1;
    audio_spec.samples = sound_bufsize;
    audio_spec.callback = callback;

    audio_device = SDL_OpenAudioDevice(NULL, false, &audio_spec, NULL, false);

    if (!audio_device) {
        fprintf(stderr, "sound: unable to open default audio device\n");
        return false;
    }

    puts("sound: opened default audio device");

    calculate_542b_dac_volumes();
    calculate_542b_tonegen_volumes(cpu_clock);

    sample_interval = cpu_clock / 44100.0;

    return true;
}

// ----------------------------------------------------------------------------

void sound_5xx_write_dac_or_tone(uint8_t value) {
    dac_or_tone = value;
    tone_interval = 5*2*(value+1);
}

void sound_6xx_write_dac(uint8_t value) {
    dac_or_tone = value;
}
