#pragma once
#include <stdint.h>

struct picfileformatheader {
    uint8_t  id[8];
    uint8_t  version;
    uint8_t  ntracks;
    uint8_t  nsides;
    uint8_t  encoding;
    uint16_t bitrate;
    uint16_t rpm;
    uint8_t  interface;
    uint8_t  dnu;
    uint16_t offset;
    uint8_t  r_w;
    // v1.1 additions
    uint8_t single_step;
    uint8_t track0s0_altencoding;
    uint8_t track0s0_encoding;
    uint8_t track0s1_altencoding;
    uint8_t track0s1_encoding;
};

struct pictracklut {
    uint16_t offset;
    uint16_t length;
};
