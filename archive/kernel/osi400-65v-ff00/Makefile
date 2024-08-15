MADS=mads

all: osi400-65v.rom

%.rom: %.s
	$(MADS) -o:$@ $<

clean:
	rm -f *.rom *~
