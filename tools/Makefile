CC ?= cc
MADS ?= mads

all: xex2lod test.lod hfe2osi mirrorbytes txt2bas hello.bas

%.lod: %.xex xex2lod
	./xex2lod < $< > $@

%.xex: %.s
	$(MADS) -o:$@ $<

%: %.c
	$(CC) -O3 -s -o $@ $<

%.bas: %.txt
	./txt2bas < $< > $@

clean:
	rm -f *~ xex2lod test.xex test.lod hfe2osi mirrorbytes txt2bas hello.bas
