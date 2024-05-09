CC ?= cc
MADS ?= mads

all: bin2lod test.lod

test.lod: test.bin bin2lod
	./bin2lod < $< > $@

test.bin: test.s
	$(MADS) -o:$@ $<

bin2lod: bin2lod.c
	$(CC) -O3 -s -o $@ $<

clean:
	rm -f *~ bin2lod test.bin test.lod
