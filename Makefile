CC ?= gcc
SDL2CONFIG ?= sdl2-config
DEBUG ?= -g3
WARN ?= -W -Wall -Wextra
CFLAGS = -flto=auto -O3 $(WARN) $$($(SDL2CONFIG) --cflags) $(DEBUG) $(DEFINES)
LFLAGS = -flto=auto
LIBS = $$($(SDL2CONFIG) --libs) -lSDL2_image

SRC_FILES = main.c mmu.c keyboard.c video.c fake6502/fake6502.c tape.c \
			cooked.c floppy.c monitor.c

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
