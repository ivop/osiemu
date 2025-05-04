; ----------------------------------------------------------------------------
; zif macros for mads
; idea: David Given's CP/M-65 native assembler and macros for llvm-mos as
; origin?: Zilog Developer Studio II
; label generation trick: Wrathchild at AtariAge
; implementation: Ivo van Poorten, September 2024, fixes April 2025
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; STACKS (max. depth is 256 per stack)

    .macro _zpush_internal " "
        .def :2_:4 = :6
    .endm

    .macro _zpush stack sp value
        _zpush_internal :stack <:sp :value
        .def :sp = :sp + 1
    .endm

    .macro _zpull_internal " "
        .def :6 = :2_:4
    .endm

    .macro _zpull stack sp var
        .def :sp = :sp - 1
        _zpull_internal :stack <:sp :var
    .endm

    .macro _zpeek stack sp var
        .def :sp = :sp - 1
        _zpull_internal :stack <:sp :var
        .def :sp = :sp + 1
    .endm

; ----------------------------------------------------------------------------
; HELPER MACROS FOR GENERATING LABELS

    .macro _zinsn_label " "    ; insn, base, number, number
        :2 :4_:6_:8
    .endm

    .macro _zlabel " "        ; base, number, number
        .def :2_:4_:6
    .endm

; ----------------------------------------------------------------------------
; ZIF/ZELSE/ZENDIF

?_zifsp = 0

    .macro zendif
        _zpull ?_zifstack ?_zifsp ?_ztmp
        _zlabel _zendif  >?_ztmp <?_ztmp
    .endm

    .macro zelse
        _zpull ?_zifstack ?_zifsp ?_ztmp
        _zpush ?_zifstack ?_zifsp *
        _zinsn_label jmp _zendif >* <*
        _zlabel _zendif >?_ztmp <?_ztmp
    .endm

    .macro _zif_common insn
        _zpush ?_zifstack ?_zifsp *
        _zinsn_label :insn _zendif >* <*
    .endm

    .macro zif_eq \ _zif_common jne \ .endm
    .macro zif_ne \ _zif_common jeq \ .endm
    .macro zif_pl \ _zif_common jmi \ .endm
    .macro zif_mi \ _zif_common jpl \ .endm
    .macro zif_cc \ _zif_common jcs \ .endm
    .macro zif_cs \ _zif_common jcc \ .endm

; ----------------------------------------------------------------------------
; ZLOOP/ZENDLOOP/ZREPEAT/ZUNTIL/ZBREAKIF/ZCONTINUE/ZCONTINUEIF

?_zloopsp = 0

    .macro zloop
        _zpush ?_zloopstack ?_zloopsp *
        _zlabel _zloopbegin >* <*
    .endm

    .macro zendloop
        _zpull ?_zloopstack ?_zloopsp ?_ztmp
        _zinsn_label jmp _zloopbegin >?_ztmp <?_ztmp
        _zlabel _zloopend >?_ztmp <?_ztmp
    .endm

    .macro _zbreakif insn
        _zpeek ?_zloopstack ?_zloopsp ?_ztmp
        _zinsn_label :insn _zloopend >?_ztmp <?_ztmp
    .endm

    .macro zbreak      \ _zbreakif jmp \ .endm

    .macro zbreakif_eq \ _zbreakif jeq \ .endm
    .macro zbreakif_ne \ _zbreakif jne \ .endm
    .macro zbreakif_pl \ _zbreakif jpl \ .endm
    .macro zbreakif_mi \ _zbreakif jmi \ .endm
    .macro zbreakif_cc \ _zbreakif jcc \ .endm
    .macro zbreakif_cs \ _zbreakif jcs \ .endm

    .macro zcontinue_if insn
        _zpeek ?_zloopstack ?_zloopsp ?_ztmp
        _zinsn_label :insn _zloopbegin >?_ztmp <?_ztmp
    .endm

    .macro zcontinue      \ zcontinue_if jmp \ .endm

    .macro zcontinueif_eq \ zcontinue_if jeq \ .endm
    .macro zcontinueif_ne \ zcontinue_if jne \ .endm
    .macro zcontinueif_pl \ zcontinue_if jpl \ .endm
    .macro zcontinueif_mi \ zcontinue_if jmi \ .endm
    .macro zcontinueif_cc \ zcontinue_if jcc \ .endm
    .macro zcontinueif_cs \ zcontinue_if jcs \ .endm

    .macro zrepeat \ zloop \ .endm

    .macro zuntil insn
        _zpull ?_zloopstack ?_zloopsp ?_ztmp
        _zinsn_label :insn _zloopbegin >?_ztmp <?_ztmp
        _zlabel _zloopend >?_ztmp <?_ztmp
    .endm

    .macro zuntil_eq \ zuntil jne \ .endm
    .macro zuntil_ne \ zuntil jeq \ .endm
    .macro zuntil_pl \ zuntil jmi \ .endm
    .macro zuntil_mi \ zuntil jpl \ .endm
    .macro zuntil_cc \ zuntil jcs \ .endm
    .macro zuntil_cs \ zuntil jcc \ .endm

; ----------------------------------------------------------------------------
; ALIASES

    .macro zif_z  \ zif_eq \ .endm
    .macro zif_nz \ zif_ne \ .endm
    .macro zif_lt \ zif_cc \ .endm
    .macro zif_ge \ zif_cs \ .endm

    .macro zbreakif_z  \ zbreakif_eq \ .endm
    .macro zbreakif_nz \ zbreakif_ne \ .endm
    .macro zbreakif_lt \ zbreakif_cc \ .endm
    .macro zbreakif_ge \ zbreakif_cs \ .endm

    .macro zcontinueif_z  \ zcontinueif_eq \ .endm
    .macro zcontinueif_nz \ zcontinueif_ne \ .endm
    .macro zcontinueif_lt \ zcontinueif_cc \ .endm
    .macro zcontinueif_ge \ zcontinueif_cs \ .endm

    .macro zuntil_z  \ zuntil_eq \ .endm
    .macro zuntil_nz \ zuntil_ne \ .endm
    .macro zuntil_lt \ zuntil_cc \ .endm
    .macro zuntil_ge \ zuntil_cs \ .endm

; ----------------------------------------------------------------------------
; LONGHAND

    .macro zif_equal            \ zif_eq \ .endm
    .macro zif_not_equal        \ zif_ne \ .endm
    .macro zif_plus             \ zif_pl \ .endm
    .macro zif_minus            \ zif_mi \ .endm
    .macro zif_carry_clear      \ zif_cc \ .endm
    .macro zif_carry_set        \ zif_cs \ .endm
    .macro zif_zero             \ zif_z  \ .endm
    .macro zif_not_zero         \ zif_nz \ .endm
    .macro zif_positive         \ zif_pl \ .endm
    .macro zif_negative         \ zif_mi \ .endm
    .macro zif_less_than        \ zif_lt \ .endm
    .macro zif_greater_or_equal \ zif_ge \ .endm

    .macro zbreakif_equal            \ zbreakif_eq \ .endm
    .macro zbreakif_not_equal        \ zbreakif_ne \ .endm
    .macro zbreakif_plus             \ zbreakif_pl \ .endm
    .macro zbreakif_minus            \ zbreakif_mi \ .endm
    .macro zbreakif_carry_clear      \ zbreakif_cc \ .endm
    .macro zbreakif_carry_set        \ zbreakif_cs \ .endm
    .macro zbreakif_zero             \ zbreakif_z  \ .endm
    .macro zbreakif_not_zero         \ zbreakif_nz \ .endm
    .macro zbreakif_positive         \ zbreakif_pl \ .endm
    .macro zbreakif_negative         \ zbreakif_mi \ .endm
    .macro zbreakif_less_than        \ zbreakif_lt \ .endm
    .macro zbreakif_greater_or_equal \ zbreakif_ge \ .endm

    .macro zcontinueif_equal            \ zcontinueif_eq \ .endm
    .macro zcontinueif_not_equal        \ zcontinueif_ne \ .endm
    .macro zcontinueif_plus             \ zcontinueif_pl \ .endm
    .macro zcontinueif_minus            \ zcontinueif_mi \ .endm
    .macro zcontinueif_carry_clear      \ zcontinueif_cc \ .endm
    .macro zcontinueif_carry_set        \ zcontinueif_cs \ .endm
    .macro zcontinueif_zero             \ zcontinueif_z  \ .endm
    .macro zcontinueif_not_zero         \ zcontinueif_nz \ .endm
    .macro zcontinueif_positive         \ zcontinueif_pl \ .endm
    .macro zcontinueif_negative         \ zcontinueif_mi \ .endm
    .macro zcontinueif_less_than        \ zcontinueif_lt \ .endm
    .macro zcontinueif_greater_or_equal \ zcontinueif_ge \ .endm

    .macro zuntil_equal            \ zuntil_eq \ .endm
    .macro zuntil_not_equal        \ zuntil_ne \ .endm
    .macro zuntil_plus             \ zuntil_pl \ .endm
    .macro zuntil_minus            \ zuntil_mi \ .endm
    .macro zuntil_carry_clear      \ zuntil_cc \ .endm
    .macro zuntil_carry_set        \ zuntil_cs \ .endm
    .macro zuntil_zero             \ zuntil_z  \ .endm
    .macro zuntil_not_zero         \ zuntil_nz \ .endm
    .macro zuntil_positive         \ zuntil_pl \ .endm
    .macro zuntil_negative         \ zuntil_mi \ .endm
    .macro zuntil_less_than        \ zuntil_lt \ .endm
    .macro zuntil_greater_or_equal \ zuntil_ge \ .endm

; ----------------------------------------------------------------------------
