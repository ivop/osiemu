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

#include "sound.h"

static double dac_542b_volumes[256];    // maps 8-bit DAC to volume [0.0-1.0]
static double tone_542b_volumes[256];   // volume for freq div V [0.0-1.0]

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

// See doc/542B-DAC.txt for details

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
        tone_542b_volumes[V] = pow(10, a / 20.0);
    }
}

bool sound_init(double cpu_clock) {
    calculate_542b_dac_volumes();
    calculate_542b_tonegen_volumes(cpu_clock);
    return true;
}
