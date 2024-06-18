#include <math.h>

#define min(a,b) ((a)<(b) ? (a) : (b))

// Convert HSL to RGB
//
// Input:
// hue H ∈ [0°, 360°), saturation S ∈ [0, 1], and lightness L ∈ [0, 1]
// Output:
// R ∈ [0,255], G ∈ [0,255], B ∈ [0,255]

void hsl_to_rgb(double H, double S,  double L, int *R, int *G, int *B) {

    double C = (1.0 - fabs(2.0 * L - 1.0)) * S;
    double Htick = H / 60.0;
    double X = C * (1.0 - fabs(fmod(Htick, 2.0) - 1.0));

    double R1, G1, B1;

    if (Htick < 1.0) {
        R1 = C; G1 = X; B1 = 0;
    } else if (Htick < 2.0) {
        R1 = X; G1 = C; B1 = 0;
    } else if (Htick < 3.0) {
        R1 = 0; G1 = C; B1 = X;
    } else if (Htick < 4.0) {
        R1 = 0; G1 = X; B1 = C;
    } else if (Htick < 5.0) {
        R1 = X; G1 = 0; B1 = C;
    } else {
        R1 = C; G1 = 0; B1 = X;
    }

    double m = L - (C / 2.0);

    *R = min(floor((R1 + m) * 256.0), 255);
    *G = min(floor((G1 + m) * 256.0), 255);
    *B = min(floor((B1 + m) * 256.0), 255);
}
