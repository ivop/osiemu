MOSCLANG=/bigdata/llvm-mos/bin/mos-common-clang
XEX2LOD=../../tools/xex2lod

all: test.lod

%.lod: %.xex
	$(XEX2LOD) < $< > $@

%.xex: %.S
	$(MOSCLANG) -o $@ $<

clean:
	rm -f *~ *.xex *.lod *.elf
