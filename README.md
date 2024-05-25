# osiemu
Ohio Scientific Instruments, Inc. Emulator

![screenshot]( screenshots/osiemu.png )  

## Features

* NMOS 6502 CPU
* 40kB RAM, or 48kB RAM without BASIC (Model 522)
* 8kB BASIC ROM
* Up to 4kB OS/Monitor ROM
* Polled keyboard, Model 542 or Model 600 mode, raw or cooked
* ASCII keyboard, Model 440B
* 64x32, 64x16, and 32x32 monochrome character based display
* Serial tape ACIA with selectable baudrate and location (0xF000 or 0xFC00)
* Bit-level floppy emulation, Model 470, up to four single sided 5¼" or 8" drives
* Hardware accelerated display
  * full resolution 512x256
  * optional 2x zoom
  * optional TV aspect ratio 16:9 or 4:3 with optional anti-aliasing
* On-Screen Display during peripheral access
* Built-in monitor, dump memory contents, set breakpoints, disassembler

## TODO

* Video: Model 440B color output (6-bit characters, upper two bits select color)
* Video: Model 540A video 32x32 with stride of 64
* Video: Model 540B video 64x32 and 32x32 with stride of 64, color RAM at 0xE000, mode register at 0xDE00
* Video: Model 541 High Resolution Graphics Expander
* Video: Model 630 Superboard color video expander
* Serial: Serial I/O without keyboard and display (named sockets)
* Harddisk: Model 590/592/594/596/598 Winchester, Shugart, and Okidata, CD-74 74MB, CD-36 36MB, CD-28 28MB, CD-23 23MB, or CD-7 7MB hard drives.
* Sound: SN76489AN and/or AY-3-8910
* Sound: ACIA RTS DAC
* Misc: Model 505 joysticks, and real-time clock
