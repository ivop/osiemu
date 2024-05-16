CC ?= cc
MADS ?= mads

all: xex2lod test.lod hfe2osi

test.lod: test.xex xex2lod
	./xex2lod < $< > $@

test.xex: test.s
	$(MADS) -o:$@ $<

%: %.c
	$(CC) -O3 -s -o $@ $<

clean:
	rm -f *~ xex2lod test.xex test.lod hfe2osi
