#! /bin/sh

PAGE_FD=2
PAGE_FE=3
PAGE_FF=4

rm -f output.rom
dd if=synmon-1.rom of=output.rom bs=256 skip=$PAGE_FD count=1 conv=notrunc
dd if=synmon-1.rom of=output.rom bs=256 skip=$PAGE_FE count=1 seek=1 conv=notrunc
dd if=synmon-1.rom of=output.rom bs=256 skip=$PAGE_FF count=1 seek=2 conv=notrunc
