CC ?= cc
MADS ?= mads

all: xex2lod test.lod hfe2osi mirrorbytes txt2bas

%.lod: %.xex xex2lod
	./xex2lod < $< > $@

%.xex: %.s
	$(MADS) -o:$@ $<

%: %.c
	$(CC) -O3 -s -o $@ $<

clean:
	rm -f *~ xex2lod test.xex test.lod hfe2osi mirrorbytes txt2bas
