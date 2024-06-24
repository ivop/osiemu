QMAKE=qmake

all:
	mkdir -p build
	cd build; $(QMAKE) ../src/launcher.pro
	+make -C build

clean:
	rm -rf build *~ */*~
