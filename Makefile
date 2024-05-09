CC ?= gcc
CFLAGS = -flto -O3 $$(pkg-config --cflags sdl2 SDL2_image SDL2_gfx) -g3
LFLAGS = -flto
LIBS = $$(pkg-config --libs sdl2 SDL2_image SDL2_gfx)

SRC_FILES = main.c mmu.c keyboard.c video.c fake6502/fake6502.c tape.c
OBJ_FILES = $(SRC_FILES:%.c=%.o)

all: osiemu

osiemu: $(OBJ_FILES)
	$(CC) $(LFLAGS) -o $@ $^ $(LIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

strip: osiemu
	strip $<

clean:
	rm -f *~ osiemu *.o fake6502/*.o .depend

.depend: $(SRC_FILES)
	rm -f $@
	$(CC) $(CFLAGS) -MM $^ >> .depend

include .depend
