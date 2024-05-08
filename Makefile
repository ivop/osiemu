CC ?= cc
FAKE6502 = fake6502/fake6502.c
SDL = $$(pkg-config --cflags --libs sdl2 SDL2_image)

all: osiemu

osiemu: main.c mmu.c keyboard.c video.c
	$(CC) -flto -march=native -O3 -o $@ $^ $(FAKE6502) $(SDL)

clean:
	rm -f *~ osiemu
