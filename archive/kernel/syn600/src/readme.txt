This is a commented assembler file that can create the same binary as the original SYN600 ROM 
for Ohio Scientific systems.
Use the A65 assembler @ https://osi.marks-lab.com/software/tools.html to build with a command like:
A65 -b syn600.asm
(Since this assembler file uses the same addresses in multiple places, A65 will generate relocation errors
which can be safely ignored.)

The SYN600 ROM can be used in a number of systems.
It supports the OSI C1PMF system, the OSI C2/C4/C8 BASIC in ROM system or 5.25" MF or 8" DF floppy disk systems.
The generated ROM contains the following pages:

 SYN600 - OSI 2K multiboard System ROM
 page 0 'H/D/M'   maps to $FF00 for a C2/C4 540Video & disk system
 page 1 keypoller maps to $FD00 for a C2/C4 540Video system
 page 2 monitor   maps to $FE00 for a C2/C4 540Video system
 page 3 'C/W/M'   maps to $FF00 for a C2/C4 540Video & tape system
 page 4 disk boot maps to $FC00 for a C1 system
 page 5 keypoller maps to $FD00 for a C1 system
 page 6 monitor   maps to $FE00 for a C1 system
 page 7 'D/C/W/M' maps to $FF00 for a C1 system
 
 The OSI C1P uses 4 ROM pages, the other systems use 3 ROM pages.