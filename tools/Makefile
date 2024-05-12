CC ?= cc
MADS ?= mads

all: bin2lod test.lod hfe2osi

test.lod: test.bin bin2lod
	./bin2lod < $< > $@

test.bin: test.s
	$(MADS) -o:$@ $<

%: %.c
	$(CC) -O3 -s -o $@ $<

clean:
	rm -f *~ bin2lod test.bin test.lod hfe2osi
