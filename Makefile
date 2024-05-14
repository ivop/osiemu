CC ?= gcc
SDL2CONFIG ?= sdl2-config
CFLAGS = -flto -O3 $$($(SDL2CONFIG) --cflags) -g3 $(DEFINES)
LFLAGS = -flto
LIBS = $$($(SDL2CONFIG) --libs) -lSDL2_image -lSDL2_gfx

SRC_FILES = main.c mmu.c keyboard.c video.c fake6502/fake6502.c tape.c \
			cooked.c

OBJ_FILES = $(SRC_FILES:%.c=%.o)

all: osiemu

osiemu: $(OBJ_FILES)
	$(CC) $(LFLAGS) -o $@ $^ $(LIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

strip: osiemu
	strip $<

clean:
	rm -f *~ osiemu osiemu.exe *.o fake6502/*.o .depend */*~

.depend: $(SRC_FILES)
	rm -f $@
	$(CC) $(CFLAGS) -MM $^ >> .depend

include .depend
