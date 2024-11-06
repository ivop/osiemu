// Quick hack to calculate 630 output voltage levels
// See doc/reveng/osi630.txt for details
// cc -o calc630 calc630.c
// image written to pal.ppm, scale with pnmscale 16 pal.ppm > out.ppm

#include <stdio.h>
#include <stdint.h>

// test 0.01 (bridge), 20, 47, 75

#define R_top       75.0
#define R_bottom    150.0
#define R_pullup    470.0
#define R_load      75.0

#define Vcc         5.0
#define V_out_max   0.700

int main(void) {
    double R_pulldown;
    double R_total;
    double V_00;        // both pull down
    double V_x0;        // top floats, bottom pulls down
    double V_xx;        // both float

    R_pulldown = 1.0 / (1.0/R_top + 1.0/R_bottom + 1.0/R_load);
    R_total = R_pullup + R_pulldown;
    V_00 = (R_pulldown / R_total) * Vcc;

    R_pulldown = 1.0 / (1.0/R_bottom + 1.0/R_load);
    R_total = R_pullup + R_pulldown;
    V_x0 = (R_pulldown / R_total) * Vcc;

    R_pulldown = R_load;
    R_total = R_pullup + R_pulldown;
    V_xx = (R_pulldown / R_total) * Vcc;


    uint8_t H_00 = V_00 / V_out_max * 0xff;
    uint8_t H_x0 = V_x0 / V_out_max * 0xff;
    uint8_t H_xx = V_xx / V_out_max * 0xff;

    printf("black level resistor = %.0f Ohm\n", R_top);

    printf("V_00 = %.1f mV --> %02x\n", V_00 * 1000.0, H_00);
    printf("V_x0 = %.1f mV --> %02x\n", V_x0 * 1000.0, H_x0);
    printf("V_xx = %.1f mV --> %02x\n", V_xx * 1000.0, H_xx);


    uint8_t bg[8][3], fg[8][3];       // 8 x R G B

    for (unsigned int i=0; i<8; i++) {
        if (!i) {       // 000 special case
            bg[i][0] = bg[i][1] = bg[i][2] = H_00;
            fg[i][0] = fg[i][1] = fg[i][2] = H_xx;
            continue;
        }
        if (i & 1) {    // red
            bg[i][0] = H_x0;
            fg[i][0] = H_xx;
        } else {
            bg[i][0] = fg[i][0] = H_00;
        }
        if (i & 2) {    // green
            bg[i][1] = H_x0;
            fg[i][1] = H_xx;
        } else {
            bg[i][1] = fg[i][1] = H_00;
        }
        if (i & 4) {    // blue
            bg[i][2] = H_x0;
            fg[i][2] = H_xx;
        } else {
            bg[i][2] = fg[i][2] = H_00;
        }
    }

    printf("\npalette (BGR):\n\n");
    printf("   fore    back\n");

    for (unsigned int i=0; i<8; i++) {
        printf("%i  ", i);
        printf("%02x%02x%02x  ", fg[i][2], fg[i][1], fg[i][0]);
        printf("%02x%02x%02x\n", bg[i][2], bg[i][1], bg[i][0]);
    }

    FILE *f = fopen("pal.ppm", "wb");
    fprintf(f, "P6\n32 2\n255\n");
    for (unsigned int i=0; i<8; i++) {
        fprintf(f, "%c%c%c", bg[i][0], bg[i][1], bg[i][2]);
        fprintf(f, "%c%c%c", bg[i][0], bg[i][1], bg[i][2]);
        fprintf(f, "%c%c%c", fg[i][0], fg[i][1], fg[i][2]);
        fprintf(f, "%c%c%c", fg[i][0], fg[i][1], fg[i][2]);
    }
    for (unsigned int i=0; i<8; i++) {
        fprintf(f, "%c%c%c", fg[i][0], fg[i][1], fg[i][2]);
        fprintf(f, "%c%c%c", fg[i][0], fg[i][1], fg[i][2]);
        fprintf(f, "%c%c%c", bg[i][0], bg[i][1], bg[i][2]);
        fprintf(f, "%c%c%c", bg[i][0], bg[i][1], bg[i][2]);
    }
    fclose(f);
}
