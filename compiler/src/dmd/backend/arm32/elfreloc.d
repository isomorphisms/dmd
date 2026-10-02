/**
 * ARM32 ELF relocation properties used by the generic ELF object writer.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */

module dmd.backend.arm32.elfreloc;

import dmd.backend.melf :
    R_ARM_CALL, R_ARM_MOVT_ABS, R_ARM_MOVW_ABS_NC;

nothrow:
@safe:

/**
 * Number of bytes occupied by an implemented ARM32 relocated field.
 */
size_t arm32RelocationSize(uint type)
{
    switch (type)
    {
        case R_ARM_CALL:
        case R_ARM_MOVW_ABS_NC:
        case R_ARM_MOVT_ABS:
            return 4;

        default:
            assert(0, "ARM32 ELF relocation size not implemented");
    }
}

/**
 * ELF32 uses REL, so the relocation addend lives in the target field.
 *
 * A32 BL carries its branch addend in imm24. MOVW/MOVT relocations form their
 * initial addend by interpreting the instruction's imm16 field as a signed
 * 16-bit value. In all three cases the object writer must preserve the emitted
 * instruction word rather than replacing it with a raw integer.
 */
bool arm32RelocationPreservesTarget(uint type)
{
    switch (type)
    {
        case R_ARM_CALL:
        case R_ARM_MOVW_ABS_NC:
        case R_ARM_MOVT_ABS:
            return true;

        default:
            return false;
    }
}

/// Relocation type for one half of an absolute MOVW/MOVT address materialization.
uint arm32AbsoluteMovRelocation(bool topHalf)
{
    return topHalf ? R_ARM_MOVT_ABS : R_ARM_MOVW_ABS_NC;
}
