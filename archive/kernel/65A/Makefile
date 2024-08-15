MADS=mads

all: 65a.rom

%.rom: %.s
	$(MADS) -o:$@ $<

clean:
	rm -f *.rom *~
