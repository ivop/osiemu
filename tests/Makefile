MADS ?= mads
XEX2LOD ?= ../tools/xex2lod

all: test_440b.lod joytest.lod

%.lod: %.xex
	$(XEX2LOD) < $< > $@

%.xex: %.s
	$(MADS) -o:$@ $<

clean:
	rm -f *~ *.xex *.lod
