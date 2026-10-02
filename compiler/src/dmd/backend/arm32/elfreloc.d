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

import dmd.backend.melf : R_ARM_CALL;

nothrow:
@safe:

/**
 * Number of bytes occupied by the relocated field.
 *
 * This initial slice deliberately recognizes only A32 BL/BLX call relocation.
 */
size_t arm32RelocationSize(uint type)
{
    switch (type)
    {
        case R_ARM_CALL:
            return 4;
        default:
            assert(0, "ARM32 ELF relocation size not implemented");
    }
}

/**
 * ELF32 uses REL, so the relocation addend lives in the target field.
 * R_ARM_CALL's addend is the signed branch displacement encoded in the A32
 * instruction; the object writer must preserve the emitted instruction word.
 */
bool arm32RelocationPreservesTarget(uint type)
{
    return type == R_ARM_CALL;
}
