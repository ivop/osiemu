CC ?= gcc
FAKE6502 = fake6502/fake6502.c
CFLAGS = -flto -O3 $$(pkg-config --cflags sdl2 SDL2_image)
LFLAGS = -flto
LIBS = $$(pkg-config --libs sdl2 SDL2_image)

all: osiemu

osiemu: main.o mmu.o keyboard.o video.o fake6502/fake6502.o
	$(CC) $(LFLAGS) -o $@ $^ $(LIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

strip: osiemu
	strip osiemu

clean:
	rm -f *~ osiemu *.o fake6502/*.o
