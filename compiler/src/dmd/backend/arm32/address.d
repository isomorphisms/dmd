/**
 * A32 symbol-address materialization sequences.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */

module dmd.backend.arm32.address;

import dmd.backend.arm32.elfreloc : arm32AbsoluteMovRelocation;
import dmd.backend.arm32.instr : COND, INSTR;

nothrow:
@safe:

/**
 * One instruction word plus the ELF relocation that applies to it.
 */
struct RelocatedInstruction
{
    uint word;
    uint relocation;
}

/**
 * A32 MOVW/MOVT pair for materializing an absolute 32-bit symbol address.
 *
 * ELF32 Arm uses REL relocations. For MOVW/MOVT, the initial addend is the
 * signed 16-bit literal encoded in the instruction. The same signed addend is
 * therefore encoded into both instructions; the linker selects the low or high
 * half of S+A according to each relocation type.
 *
 * Addends outside signed 16-bit range require a different strategy (for example
 * RELA or explicit post-addition) and are deliberately rejected by this slice.
 */
struct AbsoluteAddressSequence
{
    RelocatedInstruction[2] instructions;
}

/**
 * Build:
 *
 *     movw Rd, #:lower16:symbol+addend
 *     movt Rd, #:upper16:symbol+addend
 */
AbsoluteAddressSequence materializeAbsoluteAddress(
    INSTR.reg_t Rd,
    int addend = 0)
{
    assert(addend >= short.min && addend <= short.max);

    // AAELF32 defines the MOVW/MOVT REL addend as a signed imm16 interpreted
    // identically for both instructions.
    const ushort encodedAddend = cast(ushort)cast(short)addend;

    AbsoluteAddressSequence result;
    result.instructions[0] = RelocatedInstruction(
        INSTR.movw(COND.al, Rd, encodedAddend),
        arm32AbsoluteMovRelocation(false));
    result.instructions[1] = RelocatedInstruction(
        INSTR.movt(COND.al, Rd, encodedAddend),
        arm32AbsoluteMovRelocation(true));
    return result;
}
