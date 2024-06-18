#pragma once

#ifdef __GNUC__

    #define UNUSED          __attribute__((unused))
    #define unreachable()   __builtin_unreachable()

#else

    #include <assert.h>

    #define UNUSED
    #define unreachable()   assert(false)

#endif
