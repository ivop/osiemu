#include <stdio.h>
#include <string.h>

static char *lineptr;
static size_t n;

int main(int argc, char **argv) {
    for (int i=0; i<10; i++)
        putchar(0);
    putchar(0x0a);

    while ((getline(&lineptr, &n, stdin) >= 0)) {
        int l = strlen(lineptr);
        while (l && (lineptr[l-1] == '\r' || lineptr[l-1] == '\n')) {
            lineptr[l-1] = 0;
            l--;
        }
        printf("%s", lineptr);
        putchar(0x0d);
        for (int i=0; i<10; i++) putchar(0);
        putchar(0x0a);
    }
}
