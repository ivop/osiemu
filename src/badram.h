/*
 * osiemu - Ohio Scientific Instruments, Inc. Emulator
 *
 * Copyright © 2024 by Ivo van Poorten
 *
 * This file is licensed under the terms of the 2-clause BSD license. Please
 * see the LICENSE file in the root project directory for the full text.
 */

// Include this from mmu.c only (!)
// Separate file to reduce clutter in mmu.c
//
// TEST_BADRAM, $0400-$6fff have various forms of faulty behaviour
//                          that's block 0x01 - 0x1b

#define TEST_BADRAM

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
    /* CFs - Coupling Faults */
    /* Inversion Coupling Fault, victim higher */
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
    /* Inversion Coupling Fault, victim lower */
    if (address == 0x3956) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new > old) {                // Rising, flip victim
            RAM[address-0x5a] ^= 0x08;
        }
    }
    if (address == 0x3d56) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new < old) {                // Falling, flip victim
            RAM[address-0x5a] ^= 0x08;
        }
    }
    /* MATS++ does NOT detect some of the Idempotent CFs */
    /* Idempotent Coupling Fault, victim higher */
    if (address == 0x4156) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new > old) {                // Rising, clear victim
            RAM[address+0x5a] &= ~0x08;
        }
    }
    if (address == 0x4556) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new < old) {                // Falling, clear victim
            RAM[address+0x5a] &= 0x08;
        }
    }
    /* Idempotent Coupling Fault, victim lower */
    if (address == 0x4956) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new > old) {                // Rising, clear victim
            RAM[address-0x5a] &= ~0x08;
        }
    }
    if (address == 0x4d56) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new < old) {                // Falling, clear victim
            RAM[address-0x5a] &= 0x08;
        }
    }
    /* Idempotent Coupling Fault, victim higher */
    if (address == 0x5156) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new > old) {                // Rising, set victim
            RAM[address+0x5a] |= 0x08;
        }
    }
    if (address == 0x5556) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new < old) {                // Falling, set victim
            RAM[address+0x5a] |= 0x08;
        }
    }
    /* Idempotent Coupling Fault, victim lower */
    if (address == 0x5956) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new > old) {                // Rising, set victim
            RAM[address-0x5a] |= 0x08;
        }
    }
    if (address == 0x5d56) {
        uint8_t old = RAM[address] & 0x08;
        uint8_t new = value & 0x08;
        if (new < old) {                // Falling, set victim
            RAM[address-0x5a] |= 0x08;
        }
    }
    /* Static Coupling, victim higher */
    if (address == 0x6123) {
        if ((RAM[address] & 0x01) == 0) {
            RAM[address+0x5a] &= ~2;    // aggressor 0, victim 0
        }
    }
    if (address == 0x6523) {
        if ((RAM[address] & 0x01) == 0) {
            RAM[address+0x5a] |= 2;    // aggressor 0, victim 1
        }
    }
    /* Static Coupling, victim lower */
    if (address == 0x6923) {
        if ((RAM[address] & 0x01) == 0) {
            RAM[address-0x5a] &= ~2;    // aggressor 0, victim 0
        }
    }
    if (address == 0x6d23) {
        if ((RAM[address] & 0x01) == 0) {
            RAM[address-0x5a] |= 2;    // aggressor 0, victim 1
        }
    }

    RAM[address] = value;
}
