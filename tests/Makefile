MADS ?= mads
XEX2LOD ?= ../tools/xex2lod

all: test_440b.lod joytest.lod colortest-540b.lod hirestest.lod \
	colortest-630.lod sound542b.lod sound600.lod sound542b-2.lod \
	show-chars.lod

%.lod: %.xex
	$(XEX2LOD) < $< > $@

%.xex: %.s
	$(MADS) -o:$@ $<

clean:
	rm -f *~ *.xex *.lod
