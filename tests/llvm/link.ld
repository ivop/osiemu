MEMORY {
    zp : ORIGIN = 0x80, LENGTH = 0x80
    ram (rw) : ORIGIN = 0x0300, LENGTH = 0x9d00
}

SECTIONS {
    .zp : {
        *(.zp .zp.*)
    } >zp

    .text : {
        *(.text .text.*)
    } >ram

    .data : {
        *(.data .data.* .rodata .rodata.*)
        __data_end = .;
    } >ram

    .noinit (NOLOAD) : {
        *(.noinit .noinit.*)
    } >ram
}

OUTPUT_FORMAT {
    SHORT(0xffff)
    SHORT(0x0300)
    SHORT(--__data_end - 1)

    TRIM(ram)

    SHORT(0x02e0)
    SHORT(0x02e1)
    SHORT(main)
}
