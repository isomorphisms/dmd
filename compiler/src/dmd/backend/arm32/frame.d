/**
 * Android/AAPCS32 frame planning and A32 prologue/epilogue emission.
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
    CoreRegister, androidCalleeSavedCoreMask, linkRegisterMask, programCounterMask,
    vfpCalleeSavedDMask;

nothrow:
@safe:

/**
 * Fixed-size Android armeabi-v7a frame description.
 *
 * Core callee saves and VFP d8-d15 saves are represented independently.
 * If several non-adjacent D registers need preservation, the planner saves the
 * smallest contiguous range covering them so one VPUSH/VPOP pair is sufficient.
 */
struct FramePlan
{
    nothrow:
    enum ubyte noVfpRegister = ubyte.max;

    uint savedCoreMask;
    ubyte savedVfpFirst = noVfpRegister;
    ubyte savedVfpCount;
    uint localBytes;
    uint outgoingBytes;
    uint paddingBytes;
    uint bodyBytes;
    bool makesCalls;

    @property uint savedCoreBytes() const
    {
        return countBits(savedCoreMask) * 4;
    }

    @property uint savedVfpBytes() const
    {
        return cast(uint)savedVfpCount * 8;
    }

    @property uint totalStackBytes() const
    {
        return savedCoreBytes + savedVfpBytes + bodyBytes;
    }

    @property bool savesLinkRegister() const
    {
        return (savedCoreMask & linkRegisterMask) != 0;
    }

    @property bool savesVfpRegisters() const
    {
        return savedVfpCount != 0;
    }
}

/// Plan a frame when the function does not modify any VFP callee-saved registers.
FramePlan planAndroidFrame(
    uint modifiedCoreMask,
    bool makesCalls,
    uint localBytes,
    uint outgoingBytes)
{
    return planAndroidFrame(
        modifiedCoreMask, 0, makesCalls, localBytes, outgoingBytes);
}

/**
 * Plan a fixed-size Android ARM32 frame.
 *
 * modifiedCoreMask describes core registers modified by the body.
 * modifiedVfpDMask uses bit n for Dn. Only d8-d15 require preservation.
 *
 * localBytes and outgoingBytes are machine stack areas and must already be
 * rounded to whole words. Padding is added so SP remains 8-byte aligned at
 * public call boundaries.
 */
FramePlan planAndroidFrame(
    uint modifiedCoreMask,
    uint modifiedVfpDMask,
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

    const uint savedVfpMask = modifiedVfpDMask & vfpCalleeSavedDMask;
    if (savedVfpMask)
    {
        const ubyte first = firstSetBit(savedVfpMask);
        const ubyte last = lastSetBit(savedVfpMask);
        plan.savedVfpFirst = first;
        plan.savedVfpCount = cast(ubyte)(last - first + 1);
    }

    const uint rawBodyBytes = localBytes + outgoingBytes;
    const uint saveBytes = plan.savedCoreBytes + plan.savedVfpBytes;
    plan.paddingBytes = (8 - ((saveBytes + rawBodyBytes) & 7)) & 7;
    plan.bodyBytes = rawBodyBytes + plan.paddingBytes;

    assert((plan.totalStackBytes & 7) == 0);
    return plan;
}

/**
 * Small fixed sequence used by the initial frame emitter.
 *
 * The maximum core+VFP fixed epilogue is ADD + VPOP + POP + BX.
 */
struct FrameSequence
{
    nothrow:
    uint[4] words;
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
 * Large frames will later be lowered by materializing or chunking the adjustment.
 */
bool canEmitSingleAdjustment(const ref FramePlan plan)
{
    if (plan.bodyBytes == 0)
        return true;

    uint operand2;
    return INSTR.encode_modified_immediate(plan.bodyBytes, operand2);
}

/// Emit core saves, VFP saves and the fixed-size SP subtraction.
FrameSequence emitPrologue(const ref FramePlan plan)
{
    assert(canEmitSingleAdjustment(plan));

    FrameSequence result;

    if (plan.savedCoreMask)
        result.append(INSTR.push(COND.al, plan.savedCoreMask));

    if (plan.savesVfpRegisters)
        result.append(INSTR.vpush(
            COND.al, plan.savedVfpFirst, plan.savedVfpCount));

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
 * VFP state is restored before the core PUSH area. When LR was saved, restore
 * it directly into PC so the final core POP returns.
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

    if (plan.savesVfpRegisters)
        result.append(INSTR.vpop(
            COND.al, plan.savedVfpFirst, plan.savedVfpCount));

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

private pure ubyte firstSetBit(uint value)
{
    assert(value != 0);
    for (ubyte bit = 0; bit < 32; ++bit)
    {
        if (value & (1u << bit))
            return bit;
    }
    assert(0);
}

private pure ubyte lastSetBit(uint value)
{
    assert(value != 0);
    for (int bit = 31; bit >= 0; --bit)
    {
        if (value & (1u << bit))
            return cast(ubyte)bit;
    }
    assert(0);
}
