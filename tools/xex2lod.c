#include <stdio.h>

static int get16(void) {
    int a = getchar();
    return a | (getchar() << 8);
}

int main(int argc, char **argv) {
    int start = get16(), end;

    if (start != 0xffff) {
        fprintf(stderr, "format not recognized\n");
        return 1;
    }

    while (1) {
        if (start == 0xffff) start = get16();
        end = get16();

        fprintf(stderr, "block: $%04x - $%04x\n", start, end);

        if (start == 0x02e0 && end == 0x02e1) {
            start = get16();
            fprintf(stderr, "RUN: $%04x\n", start);
            printf(".%04XG%c", start, 13);
            break;
        }

        //printf(".%04X%c/", start, 13);
        printf(".%04X/", start);
        for (; start <= end; start++)
            printf("%02X%c", getchar(), 13);

        start = get16();
        if (start < 0) break;
    }
}
