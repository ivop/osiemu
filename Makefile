CC ?= gcc
FAKE6502 = fake6502/fake6502.c

all: osiemu

osiemu: main.c
	$(CC) -flto -march=native -O3 -o $@ $^ $(FAKE6502)

clean:
	rm -f *~ osiemu
