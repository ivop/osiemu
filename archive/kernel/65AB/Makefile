MADS=mads

all: 65ab.rom

%.rom: %.s
	$(MADS) -o:$@ $<

clean:
	rm -f *.rom *~
