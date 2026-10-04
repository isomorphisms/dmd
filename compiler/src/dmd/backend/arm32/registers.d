/**
 * ARM32 procedure-call register policy.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/arm32/registers.d, backend/arm32/registers.d)
 * References:  $(LINK2 https://github.com/ARM-software/abi-aa/blob/main/aapcs32/aapcs32.rst, AAPCS32)
 */

module dmd.backend.arm32.registers;

nothrow:
@safe:

enum CoreRegister : ubyte
{
    r0, r1, r2, r3,
    r4, r5, r6, r7,
    r8, r9, r10, r11,
    r12, sp, lr, pc,
}

pure uint coreMask(CoreRegister reg)
{
    return 1u << cast(uint)reg;
}

/// r0-r3: AAPCS32 argument/result/scratch registers.
enum uint argumentCoreMask =
    (1u << CoreRegister.r0) |
    (1u << CoreRegister.r1) |
    (1u << CoreRegister.r2) |
    (1u << CoreRegister.r3);

/// r12/IP: intra-procedure-call scratch.
enum uint ipCoreMask = 1u << CoreRegister.r12;

/// Registers whose variable contents a normal call may clobber.
enum uint callerSavedCoreMask = argumentCoreMask | ipCoreMask;

/// AAPCS32 always-preserved variable registers; r9 is platform-defined.
enum uint aapcsCalleeSavedCoreMask =
    (1u << CoreRegister.r4) |
    (1u << CoreRegister.r5) |
    (1u << CoreRegister.r6) |
    (1u << CoreRegister.r7) |
    (1u << CoreRegister.r8) |
    (1u << CoreRegister.r10) |
    (1u << CoreRegister.r11);

/// Android's ARM32 PCS uses r9 as v6, so preserve it with the other variable registers.
enum uint androidCalleeSavedCoreMask =
    aapcsCalleeSavedCoreMask |
    (1u << CoreRegister.r9);

enum uint stackPointerMask = 1u << CoreRegister.sp;
enum uint linkRegisterMask = 1u << CoreRegister.lr;
enum uint programCounterMask = 1u << CoreRegister.pc;

/// d8-d15 must survive a call in the AAPCS32 VFP register convention.
enum uint vfpCalleeSavedDMask = 0x0000_FF00u;

/// d0-d7 and, when implemented, d16-d31 are call-clobbered.
enum uint vfpCallerSavedDMask = 0xFFFF_00FFu;
