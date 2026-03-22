MADS ?= mads
XEX2LOD ?= ../tools/xex2lod

all: test_440b.lod joytest.lod colortest-540b.lod hirestest.lod \
	colortest-630.lod sound542b.lod sound600.lod sound542b-2.lod \
	show-chars.lod test-600-series-d800.lod test-540-de00.lod \
	memtest.lod memtestrom256.bin memtestrom512.bin

%.lod: %.xex
	$(XEX2LOD) < $< > $@

%.xex: %.s
	$(MADS) -o:$@ $<

%.bin: %.s
	$(MADS) -o:$@ $<

clean:
	rm -f *~ *.xex *.lod
