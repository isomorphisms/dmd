/**
 * Android/AAPCS32 core-register frame planning and A32 prologue/epilogue emission.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/arm32/frame.d, backend/arm32/frame.d)
 */

module dmd.backend.arm32.frame;

import dmd.backend.arm32.instr : COND, INSTR;
import dmd.backend.arm32.registers :
    CoreRegister, androidCalleeSavedCoreMask, linkRegisterMask, programCounterMask;

nothrow:
@safe:

/**
 * Core-register frame description for an Android armeabi-v7a function.
 *
 * This slice intentionally handles only the core-register save area and a
 * fixed-size local/outgoing area. VFP d8-d15 saves and dynamic alloca lowering
 * are separate layers.
 */
struct FramePlan
{
    uint savedCoreMask;
    uint localBytes;
    uint outgoingBytes;
    uint paddingBytes;
    uint bodyBytes;
    bool makesCalls;

    @property uint savedCoreBytes() const
    {
        return countBits(savedCoreMask) * 4;
    }

    @property uint totalStackBytes() const
    {
        return savedCoreBytes + bodyBytes;
    }

    @property bool savesLinkRegister() const
    {
        return (savedCoreMask & linkRegisterMask) != 0;
    }
}

/**
 * Plan a fixed-size Android ARM32 frame.
 *
 * modifiedCoreMask describes core variable registers modified by the body.
 * Volatile registers are ignored; Android callee-saved registers are preserved.
 * A non-leaf function also preserves its incoming LR because BL overwrites LR.
 *
 * localBytes and outgoingBytes are machine stack areas and must already be
 * rounded to whole words. Padding is added so SP remains 8-byte aligned at
 * public call boundaries.
 */
FramePlan planAndroidFrame(
    uint modifiedCoreMask,
    bool makesCalls,
    uint localBytes,
    uint outgoingBytes)
{
    assert((localBytes & 3) == 0);
    assert((outgoingBytes & 3) == 0);
    assert((modifiedCoreMask & (1u << CoreRegister.sp)) == 0);
    assert((modifiedCoreMask & (1u << CoreRegister.pc)) == 0);

    FramePlan plan;
    plan.localBytes = localBytes;
    plan.outgoingBytes = outgoingBytes;
    plan.makesCalls = makesCalls;

    plan.savedCoreMask = modifiedCoreMask & androidCalleeSavedCoreMask;
    if (makesCalls)
        plan.savedCoreMask |= linkRegisterMask;

    const uint rawBodyBytes = localBytes + outgoingBytes;
    const uint saveBytes = countBits(plan.savedCoreMask) * 4;
    plan.paddingBytes = (8 - ((saveBytes + rawBodyBytes) & 7)) & 7;
    plan.bodyBytes = rawBodyBytes + plan.paddingBytes;

    assert((plan.totalStackBytes & 7) == 0);
    return plan;
}

/**
 * Small fixed sequence used by this initial frame emitter.
 *
 * A core-only fixed frame needs at most PUSH + SUB in the prologue and
 * ADD + POP/BX in the epilogue.
 */
struct FrameSequence
{
    uint[3] words;
    ubyte length;

    void append(uint word)
    {
        assert(length < words.length);
        words[length++] = word;
    }
}

/**
 * Whether the current A32 encoder can emit this plan with a single immediate
 * ADD/SUB adjustment.
 *
 * Large frames will later be lowered by materializing/chunking the adjustment.
 */
bool canEmitSingleAdjustment(const ref FramePlan plan)
{
    if (plan.bodyBytes == 0)
        return true;

    uint operand2;
    return INSTR.encode_modified_immediate(plan.bodyBytes, operand2);
}

/// Emit PUSH and the fixed-size SP subtraction for a core-only A32 frame.
FrameSequence emitPrologue(const ref FramePlan plan)
{
    assert(canEmitSingleAdjustment(plan));

    FrameSequence result;

    if (plan.savedCoreMask)
        result.append(INSTR.push(COND.al, plan.savedCoreMask));

    if (plan.bodyBytes)
        result.append(INSTR.sub_imm(
            COND.al,
            cast(ubyte)CoreRegister.sp,
            cast(ubyte)CoreRegister.sp,
            plan.bodyBytes));

    return result;
}

/**
 * Emit the matching A32 epilogue.
 *
 * When LR was saved, restore it directly into PC so the POP returns. Otherwise
 * restore any variable registers and return with BX LR.
 */
FrameSequence emitEpilogue(const ref FramePlan plan)
{
    assert(canEmitSingleAdjustment(plan));

    FrameSequence result;

    if (plan.bodyBytes)
        result.append(INSTR.add_imm(
            COND.al,
            cast(ubyte)CoreRegister.sp,
            cast(ubyte)CoreRegister.sp,
            plan.bodyBytes));

    if (plan.savedCoreMask)
    {
        uint restoreMask = plan.savedCoreMask;
        if (plan.savesLinkRegister)
        {
            restoreMask &= ~linkRegisterMask;
            restoreMask |= programCounterMask;
            result.append(INSTR.pop(COND.al, restoreMask));
            return result;
        }

        result.append(INSTR.pop(COND.al, restoreMask));
    }

    result.append(INSTR.bx(COND.al, cast(ubyte)CoreRegister.lr));
    return result;
}

private pure uint countBits(uint value)
{
    uint count;
    while (value)
    {
        value &= value - 1;
        ++count;
    }
    return count;
}
