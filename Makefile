CC ?= gcc
SDL2CONFIG ?= sdl2-config
ifeq ($(MAKECMDGOALS),release)
	DEBUG = -O3
else
	DEBUG = -O0 -g3
endif
WARN ?= -W -Wall -Wextra
CFLAGS = -flto=auto $(WARN) $$($(SDL2CONFIG) --cflags) $(DEBUG) $(DEFINES)\
		-fsigned-char
LFLAGS = -flto=auto
LIBS = $$($(SDL2CONFIG) --libs) -lSDL2_image -lm

FILES = main.c mmu.c keyboard.c video.c fake6502/fake6502.c tape.c \
        cooked.c floppy.c monitor.c hslrgb.c sound.c control.c

SRC_FILES = $(FILES:%.c=src/%.c)
OBJ_FILES = $(SRC_FILES:%.c=%.o)

V ?= 0
ACTUAL_CC := $(CC)
CC_0 = @echo "Compiling $<"; $(ACTUAL_CC)
CC_1 = $(ACTUAL_CC)
CC = $(CC_$(V))
CC_LINK_0 = @echo "Linking $@"; $(ACTUAL_CC)
CC_LINK_1 = $(ACTUAL_CC)
CC_LINK = $(CC_LINK_$(V))
CC_DEPS_0 = @echo "Generating dependencies"; $(ACTUAL_CC)
CC_DEPS_1 = $(ACTUAL_CC)
CC_DEPS = $(CC_DEPS_$(V))

all: osiemu

release: strip

osiemu: $(OBJ_FILES)
	$(CC_LINK) $(LFLAGS) -o $@ $^ $(LIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

strip: osiemu
	strip $<

clean:
	rm -f *~ osiemu osiemu.exe $(OBJ_FILES) .depend */*~

.depend: $(SRC_FILES)
	@rm -f $@
	$(CC_DEPS) $(CFLAGS) -MM $^ >> .depend

ifneq ($(MAKECMDGOALS),clean)
include .depend
endif
