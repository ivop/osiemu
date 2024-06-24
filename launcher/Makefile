QMAKE=qmake

all:
	mkdir -p build
	cd build; $(QMAKE) ../src/launcher.pro CONFIG+=Release
	+make -C build

clean:
	rm -rf build *~ */*~
