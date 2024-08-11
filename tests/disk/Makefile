MADS ?= mads
XEX2LOD ?= ../../tools/xex2lod

all: format.lod

%.lod: %.xex
	$(XEX2LOD) < $< > $@

%.xex: %.s
	$(MADS) -o:$@ $<

clean:
	rm -f *~ *.xex *.lod
