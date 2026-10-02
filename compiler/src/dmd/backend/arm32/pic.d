/**
 * Position-independent A32 GOT address materialization.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */

module dmd.backend.arm32.pic;

import dmd.backend.arm32.instr : COND, INSTR;
import dmd.backend.melf : R_ARM_GOT_PREL;

nothrow:
@safe:

/**
 * A32 sequence for loading a symbol address through its GOT entry.
 *
 * Given first instruction address I and literal address L:
 *
 *   ldr Rd,[pc,#L-(I+8)]
 *   ldr Rd,[pc,Rd]
 *   ...
 * L: .word GOT(symbol) + A - L      R_ARM_GOT_PREL
 *
 * The second instruction's architectural PC is I+12. To make that base plus
 * the relocated literal equal GOT(symbol), the REL addend must be L-(I+12).
 */
struct PicGotAddressSequence
{
    uint literalLoad;
    uint gotLoad;
    uint literalAddend;
    uint literalRelocation;

    // AAELF32 mapping-symbol transitions relative to the first instruction.
    uint dataMappingOffset;
    uint armMappingResumeOffset;
}

/**
 * Build the two-instruction GOT address load and the associated literal entry.
 *
 * Params:
 *   Rd = destination/core scratch register
 *   literalFromFirstInstruction = byte displacement L-I
 */
PicGotAddressSequence materializePicGotAddress(
    INSTR.reg_t Rd,
    int literalFromFirstInstruction)
{
    assert((literalFromFirstInstruction & 3) == 0);

    // First instruction reads the relocation word from its literal pool.
    const int literalFromPc = literalFromFirstInstruction - 8;
    assert(literalFromPc >= -4095 && literalFromPc <= 4095);

    PicGotAddressSequence result;
    result.literalLoad = INSTR.ldr_imm(
        COND.al, Rd, INSTR.PC, literalFromPc);

    // R_ARM_GOT_PREL writes GOT(S)+A-P into the literal. The second LDR uses
    // architectural PC I+12 as its base, so choose A=P-(I+12).
    result.gotLoad = INSTR.ldr_reg(
        COND.al, Rd, INSTR.PC, Rd);
    result.literalAddend =
        cast(uint)(literalFromFirstInstruction - 12);
    result.literalRelocation = R_ARM_GOT_PREL;

    // Emit $d where the literal begins. If code resumes immediately after this
    // one-word literal, emit $a at armMappingResumeOffset; omit it when the
    // literal reaches the end of the executable section.
    result.dataMappingOffset = cast(uint)literalFromFirstInstruction;
    result.armMappingResumeOffset =
        cast(uint)(literalFromFirstInstruction + uint.sizeof);
    return result;
}
