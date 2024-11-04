CC ?= cc
CFLAGS = -O3 -static
MADS ?= mads

all: xex2lod test.lod hfe2osi osi2hfe mirrorbytes txt2bas hello.bas img2osi

%.lod: %.xex xex2lod
	./xex2lod < $< > $@

%.xex: %.s
	$(MADS) -o:$@ $<

%: %.c
	$(CC) $(CFLAGS) -s -o $@ $<

%.bas: %.txt txt2bas
	./txt2bas < $< > $@

clean:
	rm -f *~ xex2lod test.xex test.lod hfe2osi mirrorbytes txt2bas hello.bas \
		osi2hfe img2osi
