SDL2CONFIG ?= sdl2-config
ifeq ($(MAKECMDGOALS),release)
	DEBUG = -O3
else
	DEBUG = -Og -g3
endif
WARN ?= -W -Wall -Wextra -pedantic
CFLAGS = -flto=auto $(WARN) $$($(SDL2CONFIG) --cflags) $(DEBUG) $(DEFINES)\
		-fsigned-char $(EXTRA_CFLAGS)
LFLAGS = -flto=auto $(EXTRA_LFLAGS)
LIBS = $$($(SDL2CONFIG) --libs) -lSDL2_image -lm

FILES = main.c mmu.c keyboard.c video.c fake6502/fake6502.c tape.c \
        cooked.c floppy.c monitor.c hslrgb.c sound.c control.c disasm.c \
		trace.c heatmap.c

SRC_FILES = $(FILES:%.c=src/%.c)
OBJ_FILES = $(SRC_FILES:%.c=%.o)

all: osiemu

release: strip

osiemu: $(OBJ_FILES)
	$(CC) $(LFLAGS) -o $@ $^ $(LIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

strip: osiemu
	strip $<

launcher/build/launcher:
	+make -C launcher

osiemu-launcher: launcher/build/launcher
	cp $< $@

launcher/build/release/launcher.exe:
	+make -C launcher

osiemu-launcher.exe: launcher/build/release/launcher.exe
	cp $< $@

clean:
	rm -f *~ osiemu osiemu.exe $(OBJ_FILES) .depend */*~ */*/*~ osiemu-launcher osiemu-launcher.exe *.tar.gz *.tar.bz2 *.tar.xz *.zip
	+make -C launcher clean

.depend: $(SRC_FILES)
	rm -f $@
	$(CC) $(CFLAGS) -MM $^ > .depend

ifneq ($(MAKECMDGOALS),clean)
include .depend
endif
