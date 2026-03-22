/*
 * osiemu - Ohio Scientific Instruments, Inc. Emulator
 *
 * Copyright © 2024, 2025 by Ivo van Poorten
 *
 * This file is licensed under the terms of the 2-clause BSD license. Please
 * see the LICENSE file in the root project directory for the full text.
 */

/* References:
 *
 * - International Journal of VLSI System Design and Communication Systems
 *   Volume.02, IssueNo.07, October-2014, Pages: 0512-0517
 * - Lecture, RAM Testing, Jin-Fu Li, Advanced Reliable Systems (ARES) Lab.
 *   Dept. of Electrical Engineering, National Central University,
 *   Jhongli, Taiwan
 * - Understanding Memory Fault Models,
 *   https://www.embedded.com/understanding-memory-fault-models/
 */

/*
 * Include this from mmu.c only (!)
 * Separate file to reduce clutter in mmu.c
 *
 * Block $00 ($0000 - $03ff) is always good and the memory tester should
 * live there or run from ROM.
 *
 * TEST_BADRAM1, $0400 - $73ff  block $01 - $1c
 *
 *      faults: RDF, DRDF, SOF, ADF, TF, WDF, CFin, CFid, CFst
 *
 * TEST_BADRAM2, $0400 - $73ff  block $01 - $1c
 *
 *      faults: CFds, CFir (partial)
 *
 * TEST_BADRAM3, $0400 - $73ff  block $01 - $1c
 *
 *      faults: CFtr, CFwd, CFrd, CFir (partial)
 */

#ifdef TEST_BADRAM1
static uint8_t badram_read6502(uint16_t address) {
    /* IRF - Incorrect Read Fault */
    if (address == 0x0654) {
        return RAM[address] ^ 0x20;
    }
    /* RDF - Read Destructive Fault */
    if (address == 0x0b65) {
        RAM[address] ^= 0x20;
    }
    /* DRDF - Deceptive Read Destructive Fault */
    if (address == 0x0fed) {
        uint8_t val = RAM[address];
        RAM[address] ^= 0x80;
        return val;
    }
    /* SOF - Stuck Open Fault */
    static uint8_t prev;
    if (address == 0x1321) {
        return prev;
    }
    prev = RAM[address];
    /* ADF - Address Decoder Fault */
    /* Multiple Words, Single address */
    if (address == 0x2edc) {
        return RAM[address] | RAM[address-0x0100];
    }
    /* Single Word, Multiple Addresses */
    if (address == 0x3321 || address == 0x3123) {
        return RAM[0x3321];
    };
    return RAM[address];
}

static void badram_write6502(uint16_t address, uint8_t value) {
    /* SAF - Stuck At Fault */
    if (address == 0x1723) {
        RAM[address] = value | 8;   // stuck at 1
        return;
    }
    if (address == 0x1b77) {
        RAM[address] = value & ~8;  // stuck at 0
        return;
    }
    /* TF - Transition Fault */
    if (address == 0x1f8e) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new > old) {
            RAM[address] = value & ~0x40;   // 0 -> 1 failure
            return;
        }
    }
    if (address == 0x23e6) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new < old) {
            RAM[address] = value | 0x40;   // 1 -> 0 failure
            return;
        }
    }
    /* WDF - Write Destructive Fault */
    if (address == 0x2617) {
        uint8_t old = RAM[address] & 2;
        uint8_t new = value & 2;
        if (!new && new == old) {           // 0w0 -> 1
            RAM[address] = value ^ 2;
            return;
        }
        return;
    }
    if (address == 0x2b5a) {
        uint8_t old = RAM[address] & 2;
        uint8_t new = value & 2;
        if (new && new == old) {            // 1w1 -> 0
            RAM[address] = value ^ 2;
            return;
        }
        return;
    }
    /* ADF - Address Decoder Fault */
    /* Single Word, Multiple Addresses */
    if (address == 0x3321 || address == 0x3123) {
        RAM[0x3321] = RAM[0x3123] = value;
        return;
    };
    /* CF - Coupling Faults */
    /* CFin - Inversion Coupling Fault, victim higher */
    if (address == 0x3456) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new > old) {                // Rising
            RAM[address+0x5a] ^= 0x08;
        }
    }
    if (address == 0x3856) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new < old) {                // Falling
            RAM[address+0x5a] ^= 0x08;
        }
    }
    /* CFin - Inversion Coupling Fault, victim lower */
    if (address == 0x3d56) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new > old) {                // Rising, flip victim
            RAM[address-0x5a] ^= 0x08;
        }
    }
    if (address == 0x4156) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new < old) {                // Falling, flip victim
            RAM[address-0x5a] ^= 0x08;
        }
    }
    /* MATS++ does NOT detect some of the Idempotent CFs */
    /* CFid - Idempotent Coupling Fault, victim higher */
    if (address == 0x4556) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new > old) {                // Rising, clear victim
            RAM[address+0x5a] &= ~0x08;
        }
    }
    if (address == 0x4956) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new < old) {                // Falling, clear victim
            RAM[address+0x5a] &= 0x08;
        }
    }
    /* CFid - Idempotent Coupling Fault, victim lower */
    if (address == 0x4d56) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new > old) {                // Rising, clear victim
            RAM[address-0x5a] &= ~0x08;
        }
    }
    if (address == 0x5156) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new < old) {                // Falling, clear victim
            RAM[address-0x5a] &= 0x08;
        }
    }
    /* Idempotent Coupling Fault, victim higher */
    if (address == 0x5556) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new > old) {                // Rising, set victim
            RAM[address+0x5a] |= 0x08;
        }
    }
    if (address == 0x5956) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new < old) {                // Falling, set victim
            RAM[address+0x5a] |= 0x08;
        }
    }
    /* Idempotent Coupling Fault, victim lower */
    if (address == 0x5d56) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new > old) {                // Rising, set victim
            RAM[address-0x5a] |= 0x08;
        }
    }
    if (address == 0x6156) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new < old) {                // Falling, set victim
            RAM[address-0x5a] |= 0x08;
        }
    }
    /* Static Coupling, victim higher */
    if (address == 0x6523) {
        if ((RAM[address] & 0x01) == 0) {
            RAM[address+0x5a] &= ~2;    // aggressor 0, victim 0
        }
    }
    if (address == 0x6923) {
        if ((RAM[address] & 0x01) == 0) {
            RAM[address+0x5a] |= 2;    // aggressor 0, victim 1
        }
    }
    /* Static Coupling, victim lower */
    if (address == 0x6d23) {
        if ((RAM[address] & 0x01) == 0) {
            RAM[address-0x5a] &= ~2;    // aggressor 0, victim 0
        }
    }
    if (address == 0x7123) {
        if ((RAM[address] & 0x01) == 0) {
            RAM[address-0x5a] |= 2;    // aggressor 0, victim 1
        }
    }

    RAM[address] = value;
}
#endif

#ifdef TEST_BADRAM2
static uint8_t badram_read6502(uint16_t address) {
    /* Disturb Cell Coupling Faults CFd */
    /* Disturb Victim when Aggressor reads 0 */
    if (address == 0x0543) {
        if ((RAM[address] & 0x20) == 0) {
            RAM[address-0x6e] |= 1;         // set victim below aggressor
        }
    }
    if (address == 0x0943) {
        if ((RAM[address] & 0x20) == 0) {
            RAM[address+0x6e] |= 1;         // set victim above aggressor
        }
    }
    if (address == 0x0d43) {
        if ((RAM[address] & 0x20) == 0) {
            RAM[address-0x6e] &= ~1;         // clear victim below aggressor
        }
    }
    if (address == 0x1143) {
        if ((RAM[address] & 0x20) == 0) {
            RAM[address+0x6e] &= ~1;         // clear victim above aggressor
        }
    }
    /* Disturb Victim when Aggressor reads 1 */
    if (address == 0x1543) {
        if (RAM[address] & 0x20) {
            RAM[address-0x6e] |= 1;         // set victim below aggressor
        }
    }
    if (address == 0x1943) {
        if (RAM[address] & 0x20) {
            RAM[address+0x6e] |= 1;         // set victim above aggressor
        }
    }
    if (address == 0x1d43) {
        if (RAM[address] & 0x20) {
            RAM[address-0x6e] &= ~1;         // clear victim below aggressor
        }
    }
    if (address == 0x2143) {
        if (RAM[address] & 0x20) {
            RAM[address+0x6e] &= ~1;         // clear victim above aggressor
        }
    }
    /* CFir - Incorrect Read Coupling Faults (partial) */
    if (address == 0x6532) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address-0x41] & 0x04;
        if (readval && !addr) {
            return RAM[address] ^ 0x10;     // flip if a=0 and v=1, a below
        }
    }
    if (address == 0x6932) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address+0x41] & 0x04;
        if (readval && !addr) {
            return RAM[address] ^ 0x10;     // flip if a=0 and v=1, a above
        }
    }
    if (address == 0x6d32) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address-0x41] & 0x04;
        if (readval && addr) {
            return RAM[address] ^ 0x10;     // flip if a=1 and v=1, a below
        }
    }
    if (address == 0x7132) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address+0x41] & 0x04;
        if (readval && addr) {
            return RAM[address] ^ 0x10;     // flip if a=1 and v=1, a above
        }
    }
    return RAM[address];
}

static void badram_write6502(uint16_t address, uint8_t value) {
    /* Disturb Cell Coupling Faults CFd */
    /* Disturb Victim when Aggressor writes 0->1 transition */
    if (address == 0x2582) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new > old) {
            RAM[address-0xbc] |= 8;         // set victim below aggressor
        }
    }
    if (address == 0x2982) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new > old) {
            RAM[address+0xbc] |= 8;         // set victim above aggressor
        }
    }
    if (address == 0x2d82) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new > old) {
            RAM[address-0xbc] &= ~8;        // clear victim below aggressor
        }
    }
    if (address == 0x3182) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new > old) {
            RAM[address+0xbc] &= ~8;        // clear victim above aggressor
        }
    }
    /* Disturb Victim when Aggressor writes 0->0 */
    if (address == 0x3582) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (!new && new == old) {
            RAM[address-0xbc] |= 8;         // set victim below aggressor
        }
    }
    if (address == 0x3982) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (!new && new == old) {
            RAM[address+0xbc] |= 8;         // set victim above aggressor
        }
    }
    if (address == 0x3d82) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (!new && new == old) {
            RAM[address-0xbc] &= ~8;        // clear victim below aggressor
        }
    }
    if (address == 0x4182) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (!new && new == old) {
            RAM[address+0xbc] &= ~8;        // clear victim above aggressor
        }
    }
    /* Disturb Victim when Aggressor writes 1->0 transition */
    if (address == 0x4582) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new < old) {
            RAM[address-0xbc] |= 8;         // set victim below aggressor
        }
    }
    if (address == 0x4982) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new < old) {
            RAM[address+0xbc] |= 8;         // set victim above aggressor
        }
    }
    if (address == 0x4d82) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new < old) {
            RAM[address-0xbc] &= ~8;        // clear victim below aggressor
        }
    }
    if (address == 0x5182) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new < old) {
            RAM[address+0xbc] &= ~8;        // clear victim above aggressor
        }
    }
    /* Disturb Victim when Aggressor writes 1->1 */
    if (address == 0x5582) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new && new == old) {
            RAM[address-0xbc] |= 8;         // set victim below aggressor
        }
    }
    if (address == 0x5982) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new && new == old) {
            RAM[address+0xbc] |= 8;         // set victim above aggressor
        }
    }
    if (address == 0x5d82) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new && new == old) {
            RAM[address-0xbc] &= ~8;        // clear victim below aggressor
        }
    }
    if (address == 0x6182) {
        uint8_t old = RAM[address] & 0x40;
        uint8_t new = value & 0x40;
        if (new && new == old) {
            RAM[address+0xbc] &= ~8;        // clear victim above aggressor
        }
    }
    RAM[address] = value;
}
#endif

#ifdef TEST_BADRAM3
static uint8_t badram_read6502(uint16_t address) {
    /* Read Destructive Coupling Faults */
    /* Read of victim causes transition if aggressor is in certain state */
    if (address == 0x4532) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address-0x41] & 0x04;
        if (!readval && !addr) {
            RAM[address] ^= 0x10;           // flip if a=0 and v=0, a below
        }
    }
    if (address == 0x4932) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address+0x41] & 0x04;
        if (!readval && !addr) {
            RAM[address] ^= 0x10;           // flip if a=0 and v=0, a above
        }
    }
    if (address == 0x4d32) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address-0x41] & 0x04;
        if (!readval && addr) {
            RAM[address] ^= 0x10;           // flip if a=1 and v=0, a below
        }
    }
    if (address == 0x5132) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address+0x41] & 0x04;
        if (!readval && addr) {
            RAM[address] ^= 0x10;           // flip if a=1 and v=0, a above
        }
    }
    if (address == 0x5532) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address-0x41] & 0x04;
        if (readval && !addr) {
            RAM[address] ^= 0x10;           // flip if a=0 and v=1, a below
        }
    }
    if (address == 0x5932) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address+0x41] & 0x04;
        if (readval && !addr) {
            RAM[address] ^= 0x10;           // flip if a=0 and v=1, a above
        }
    }
    if (address == 0x5d32) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address-0x41] & 0x04;
        if (readval && addr) {
            RAM[address] ^= 0x10;           // flip if a=1 and v=1, a below
        }
    }
    if (address == 0x6132) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address+0x41] & 0x04;
        if (readval && addr) {
            RAM[address] ^= 0x10;           // flip if a=1 and v=1, a above
        }
    }
    /* Incorrect Read Coupling Faults (partial) */
    if (address == 0x6532) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address-0x41] & 0x04;
        if (!readval && !addr) {
            return RAM[address] ^ 0x10;     // flip if a=0 and v=0, a below
        }
    }
    if (address == 0x6932) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address+0x41] & 0x04;
        if (!readval && !addr) {
            return RAM[address] ^ 0x10;     // flip if a=0 and v=0, a above
        }
    }
    if (address == 0x6d32) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address-0x41] & 0x04;
        if (!readval && addr) {
            return RAM[address] ^ 0x10;     // flip if a=1 and v=0, a below
        }
    }
    if (address == 0x7132) {
        bool readval = RAM[address] & 0x10;
        bool addr = RAM[address+0x41] & 0x04;
        if (!readval && addr) {
            return RAM[address] ^ 0x10;     // flip if a=1 and v=0, a above
        }
    }
    return RAM[address];
}

static void badram_write6502(uint16_t address, uint8_t value) {
    /* CFtr - Transition Coupling Faults */
    /* Write transition to victim fails if aggressor is in certain state */
    /* 0->1 transitions */
    if (address == 0x0567) {
        uint8_t old = RAM[address] & 0x04;
        uint8_t new = value & 0x04;
        bool aggr = RAM[address - 0x98] & 0x20;
        if (new > old && !aggr)             // fail 0->1 if aggr below is 0
            value &= ~0x04;
    }
    if (address == 0x0967) {
        uint8_t old = RAM[address] & 0x04;
        uint8_t new = value & 0x04;
        bool aggr = RAM[address + 0x98] & 0x20;
        if (new > old && !aggr)             // fail 0->1 if aggr above is 0
            value &= ~0x04;
    }
    if (address == 0x0d67) {
        uint8_t old = RAM[address] & 0x04;
        uint8_t new = value & 0x04;
        bool aggr = RAM[address - 0x98] & 0x20;
        if (new > old && aggr)              // fail 0->1 if aggr below is 1
            value &= ~0x04;
    }
    if (address == 0x1167) {
        uint8_t old = RAM[address] & 0x04;
        uint8_t new = value & 0x04;
        bool aggr = RAM[address + 0x98] & 0x20;
        if (new > old && aggr)              // fail 0->1 if aggr above is 1
            value &= ~0x04;
    }
    /* 1->0 transitions */
    if (address == 0x1567) {
        uint8_t old = RAM[address] & 0x04;
        uint8_t new = value & 0x04;
        bool aggr = RAM[address - 0x98] & 0x20;
        if (new < old && !aggr)             // fail 1->0 if aggr below is 0
            value |= 0x04;
    }
    if (address == 0x1967) {
        uint8_t old = RAM[address] & 0x04;
        uint8_t new = value & 0x04;
        bool aggr = RAM[address + 0x98] & 0x20;
        if (new < old && !aggr)             // fail 1->0 if aggr above is 0
            value |= 0x04;
    }
    if (address == 0x1d67) {
        uint8_t old = RAM[address] & 0x04;
        uint8_t new = value & 0x04;
        bool aggr = RAM[address - 0x98] & 0x20;
        if (new < old && aggr)              // fail 1->0 if aggr below is 1
            value |= 0x04;
    }
    if (address == 0x2167) {
        uint8_t old = RAM[address] & 0x04;
        uint8_t new = value & 0x04;
        bool aggr = RAM[address + 0x98] & 0x20;
        if (new < old && aggr)              // fail 1->0 if aggr above is 1
            value |= 0x04;
    }
    /* CFwd - Write Destructive Coupling Faults */
    /* non-transition write to victim flips if aggressor in state x */
    /* 0->0 non-transitions */
    if (address == 0x2589) {
        uint8_t old = RAM[address] & 0x80;
        uint8_t new = value & 0x80;
        bool aggr = RAM[address - 0xab] & 0x08;
        if (!new && new == old && !aggr) {
            value ^= 0x80;                  // flip 0->0 if aggr below is 0
        }
    }
    if (address == 0x2989) {
        uint8_t old = RAM[address] & 0x80;
        uint8_t new = value & 0x80;
        bool aggr = RAM[address + 0xab] & 0x08;
        if (!new && new == old && !aggr) {
            value ^= 0x80;                  // flip 0->0 if aggr above is 0
        }
    }
    if (address == 0x2d89) {
        uint8_t old = RAM[address] & 0x80;
        uint8_t new = value & 0x80;
        bool aggr = RAM[address - 0xab] & 0x08;
        if (!new && new == old && aggr) {
            value ^= 0x80;                  // flip 0->0 if aggr below is 1
        }
    }
    if (address == 0x3189) {
        uint8_t old = RAM[address] & 0x80;
        uint8_t new = value & 0x80;
        bool aggr = RAM[address + 0xab] & 0x08;
        if (!new && new == old && aggr) {
            value ^= 0x80;                  // flip 0->0 if aggr above is 1
        }
    }
    /* 1->1 non-transitions */
    if (address == 0x3589) {
        uint8_t old = RAM[address] & 0x80;
        uint8_t new = value & 0x80;
        bool aggr = RAM[address - 0xab] & 0x08;
        if (new && new == old && !aggr) {
            value ^= 0x80;                  // flip 1->1 if aggr below is 0
        }
    }
    if (address == 0x3989) {
        uint8_t old = RAM[address] & 0x80;
        uint8_t new = value & 0x80;
        bool aggr = RAM[address + 0xab] & 0x08;
        if (new && new == old && !aggr) {
            value ^= 0x80;                  // flip 1->1 if aggr above is 0
        }
    }
    if (address == 0x3d89) {
        uint8_t old = RAM[address] & 0x80;
        uint8_t new = value & 0x80;
        bool aggr = RAM[address - 0xab] & 0x08;
        if (new && new == old && aggr) {
            value ^= 0x80;                  // flip 1->1 if aggr below is 1
        }
    }
    if (address == 0x4189) {
        uint8_t old = RAM[address] & 0x80;
        uint8_t new = value & 0x80;
        bool aggr = RAM[address + 0xab] & 0x08;
        if (new && new == old && aggr) {
            value ^= 0x80;                  // flip 1->1 if aggr above is 1
        }
    }
    RAM[address] = value;
}
#endif
