# osiemu
Ohio Scientific Instruments, Inc. Emulator

![screenshot]( screenshots/osiemu.png )  

1. [Features](#features)
2. [Keybindings](#keybindings)
3. [Monitor](#monitor)
4. [Command line options](#command-line-options)
5. [Configuration files](#configuration-files)
6. [Build instructions](#build-instructions)
7. [Disk images](#disk-images)
8. [GUI launcher](#gui-launcher)

## Features

* NMOS 6502 CPU
* Selectable CPU speed, including "warp speed"
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
  * configurable frame rate
  * optional 2x, 3x, or 4x zoom
  * optional TV aspect ratio 16:9 or 4:3
  * optional anti-aliasing
  * optional scan lines or dots
* Sound modes:
  * Model 542B/C keyboard tone generator and 8-bit DAC
  * Superboard II/Model 600/C1P keyboard 8-bit DAC
* On-Screen Display during peripheral access
* Built-in monitor, dump/change memory contents, registers, set breakpoints, disassembler

## Keybindings

| Key | Function |
| --- | --- |
| F3 | Hardware switch, hi-res overlay |
| F4 | Hardware switch, normal font / graphics font |
| F5 | Hardware reset |
| F8 | Enter monitor |
| F9 | Exit emulator |
| F11 | Toggle fullscreen |

## Monitor

| Command | Arguments | Function |
| --- | --- | --- |
| q,quit |              | exit emulator |
| cont |                | continue emulation |
| help |                | print this help |
| show |                | show emulation window |
| hide |                | hide emulation window |
| d | [mem]             | dump memory contents |
| c | mem val ...       | change memory to value(s) |
| f | beg end val       | fill memory with value |
| regs |                | display CPU registers |
| setcpu | type         | set CPU type to nmos\|undef\|cmos |
| u | [mem]             | unassemble memory |
| setbp | mem           | set breakpoint |
| clrbp |               | clear breakpoint |
| l | mem file          | load raw data from file to mem |
| s | beg end file      | save raw data to file |
| setpc | val           | set PC to value |
| seta | val            | set A to value |
| setx | val            | set X to value |
| sety | val            | set Y to value |
| setsp | val           | set SP to value |
| setp | val            | set P to value |
| tapes |               | list current tape files |
| eject | input\|output | eject input or output tape |
| insert | input\|output file | insert input or output tape |
| rewind | input\|output | rewind input or output tape |
| drives |              | list mounted floppies |
| swap | numx numy      | swap drives numx and numy |
| unmount | num         | unmount drive |
| mount | num file      | mount file to drive num |


## Command line options

```
usage: osiemu <config-file>
       osiemu [options]

options:

    -b/--basic filename.rom    specify BASIC ROM
    -k/--kernel filename.rom   specify kernel ROM

    -c/--font filename         specify character set font (8x2048 image)
    -q/--graph-font filename   specify graphics font (8x2048 image)

    -K/--cpu-speed speed       select speed: quarter    0.983040 MHz (default)
                                             half       1.966080 MHz
                                             510c-slow  1.000000 MHz
                                             510c-fast  2.000000 MHz

    -v/--disable-video         disable video RAM (default: enabled)
    -m/--video-mode mode       forced modes:   64x32 (default)
                                               64x16
                                               32x32
                                               32x32s64
                               variable modes: 540b (32x32s64 / 64x32)
                                               600 (32x32 / 64x16)
    -M/--mono-color color      monochrome color green, amber, bluish or white
    -a/--aspect mode           aspect mode: full (default), 16:9 or 4:3
    -z/--zoom factor           increase display size by factor (2, 3, or 4)
    -V/--smooth-video          enable anti-aliased scaling
    -C/--color-mode mode       mode: monochrome (default), 440b, 540b, 630
    -s/--saturation            color saturation [0.0-1.0], default: 0.75
    -H/--hires-mode mode       mode: none, 440b (128x128), 541 (256x256)
    -S/--scanlines             emulate visual scanlines (zoom >= 2 only)
    -x/--pixels                emulate visual pixels (implies scanlines)

    -A/--ascii-keyboard        enable ASCII keyboard at 0xdf01
    -r/--raw-keyboard          enable raw keyboard mode
    -i/--invert-keyboard       invert keyboard matrix signals (model 542)

    -j/--joystick1 index       specify joystick 1
    -J/--joystick2 index       specify joystick 2

    -t/--tape-input file       specify tape input file (default: none)
    -T/--tape-output file      specify tape output file (default: none)
    -L/--tape-location         ACIA location: f000 (default), fc00
    -B/--tape-baseclock        set baseclock (default: 4800)

    -f/--floppy0 file          specify floppy0 file (default: none)
    -F/--floppy1 file          specify floppy1 file (default: none)
    -g/--floppy2 file          specify floppy2 file (default: none)
    -G/--floppy3 file          specify floppy3 file (default: none)

    -R/--force-ramtop hex      force RAM top to location hex

    -y/--sound-mode mode       mode: none, 542b (DAC+tone), 600 (DAC)
    -Y/--sound-bufsize size    set sound buffer size (32-2048, default: 256)

    -w/--warp-speed            run emulator as fast as possible

    -Z/--switches switches     comma separated list of hardware switches
                               "flipped" before startup
                                 hires       enable high resolution overlay
                                 graph       enable graphics font
                                 nobasic     disable BASIC ROM (8kB extra RAM)
                                 fullscreen  start fullscreen

    -h/--help                  show usage information
```

## Configuration files

Configuration files contain command line options, one per line.
The leading -- is optional.
If an option requires an argument, the option and the argument can be
separated by either a space or a '='.
Everything after the first space or '=' until the end of the line is
considered the argument. There's no need (and it's not supported) to put
arguments between single or double quotes. Escaping of characters isn't
needed either.

Example:

```
zoom 2
scanlines
video-mode=32x32
--cpu-speed half
kernel=long path with spaces/synmon.rom
```

More examples are in the _config_ directory.  

## Build instructions

### Linux

```
git clone --recurse-submodules https://github.com/ivop/osiemu
cd osiemu
make release
```

```make``` without any arguments will build a debug version (no optimizations, and level 3 debug info).  
You can override the sdl2-config utility used by setting the SDL2CONFIG variable on the command line, i.e.  
```
make -j8 release SDL2CONFIG=/path/to/sdl2-config CC=/path/to/my/compiler
```  

### Windows

Use Cygwin64. MinGW64 doesn't work because it is missing mmap and getline.

## Disk images

```osiemu``` uses its own disk image format.
For each track it contains the complete bitstream that enters the floppy ACIA,
including all the framing and prolonged stop bits for timing.
See [_doc/disk-format.txt_](doc/disk-format.txt) for details.
The _tools_ directory contains ```hfe2osi``` and ```osi2hfe``` to convert
from and to HFE flux dumps from/for real hardware.

## GUI launcher

<img src="screenshots/osiemu-launcher.png" alt="screenshot-launcher" height="256"/>  

If you are tired of fiddling with command line options, there's also a GUI launcher.
To build, use:

```
make osiemu-launcher
```

You'll need either Qt5 or Qt6 to build it.
If you want to override the default ```qmake``` that's used during the build process,
you can specify it on the command line.
For example:

```
make -j8 osiemu-launcher QMAKE=/path/to/Qt/6.7.2/gcc_64/bin/qmake6 CXX=/path/to/clang
```

forces a build against Qt 6.7.2 and use the clang compiler.
It has been tested with Qt 5.15.x and Qt 6.5.x and up.
On Windows, contrary to the main ```osiemu``` binary that has to be built with Cygwin, the launcher binary has to be built with MinGW.
Preferably the version that is distributed with Qt itself.

## Future additions?

* Serial: Serial I/O without keyboard and display, rewrite tape code, make it
work with socat, (virtual) serial ports, and minicom
* Sound: 1-bit ACIA RTS DAC (which model? where is the software?)
* Sound: SN76489AN and/or AY-3-8910 daughterboard
* Harddisk: Model 590/592/594/596/598 Winchester, Shugart, and Okidata, CD-74 74MB, CD-36 36MB, CD-28 28MB, CD-23 23MB, or CD-7 7MB hard drives.
* Serial: Implement S1883 UART? Where is the software?
