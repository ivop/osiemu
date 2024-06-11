# osiemu
Ohio Scientific Instruments, Inc. Emulator

![screenshot]( screenshots/osiemu.png )  

## Features

* NMOS 6502 CPU
* Selectable CPU speed
* 40kB RAM, or 48kB RAM without BASIC (Model 522)
* 8kB BASIC ROM
* Up to 4kB OS/Monitor ROM
* Polled keyboard, Model 542 or Model 600 mode, raw or cooked
* ASCII keyboard, Model 440B
* Two joysticks (d-pad or analog)
* 64x32, 64x16, and 32x32 character based display
* Switchable ASCII font and graphics font
* Color modes:
  * Monochrome white, green, amber, or bluish
  * Model 440B, 6-bit ASCII, 4 colors
  * Model 540B, 8 colors, inverse video
  * Model 630 Color Video Expander, 16 colors RGB, 8 dimmed, 8 bright
* High resolution overlays:
  * Model 440B, 128x128
  * Model 541, 256x256, High Resolution Graphics Expander
* Serial tape ACIA with selectable baudrate and memory location
* Bit-level floppy emulation, Model 470/505, up to four single sided 5¼" or 8" drives
* Hardware accelerated display
  * full resolution 512x256
  * optional 2x zoom
  * optional TV aspect ratio 16:9 or 4:3
  * optional anti-aliasing
* On-Screen Display during peripheral access
* Built-in monitor, dump/change memory contents, registers, set breakpoints, disassembler

## TODO

* Emulation: "Warp speed", run emulation as fast as possible
* Sound: Model 542B/C keyboard 0xdf01 tone generator / 8-bit DAC
* Sound: Model 600/Super board II keyboard 0xdf00 8-bit DAC
* Sound: 1-bit ACIA RTS DAC (Model?)
* Sound: SN76489AN and/or AY-3-8910
* Serial: Serial I/O without keyboard and display (named sockets)
* Harddisk: Model 590/592/594/596/598 Winchester, Shugart, and Okidata, CD-74 74MB, CD-36 36MB, CD-28 28MB, CD-23 23MB, or CD-7 7MB hard drives.
