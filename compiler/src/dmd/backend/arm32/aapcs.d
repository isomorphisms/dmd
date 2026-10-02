/**
 * AAPCS32 base-procedure-call argument and result placement
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/arm32/aapcs.d, backend/arm32/aapcs.d)
 * References:  $(LINK2 https://github.com/ARM-software/abi-aa/blob/main/aapcs32/aapcs32.rst, AAPCS32)
 */

module dmd.backend.arm32.aapcs;

nothrow:
@safe:

/**
 * Machine-level scalar types needed by the first ARM32 ABI lowering slice.
 *
 * AAPCS32's base procedure-call standard passes these values through the core
 * register bank. Android armeabi-v7a uses this base/softfp convention for
 * floating-point calls: float uses one core register and double uses an aligned
 * pair, even when VFP instructions perform the arithmetic.
 */
enum MachineType : ubyte
{
    word,
    pointer,
    float32,
    doubleWord,
    float64,
}

/**
 * Source-level fundamental categories needed by AAPCS32 Stage B.
 */
enum FundamentalArgument : ubyte
{
    signedByte,
    unsignedByte,
    signedHalf,
    unsignedHalf,
    halfFloat,
    word,
    pointer,
    float32,
    doubleWord,
    float64,
}

/**
 * Preparation needed before placing an argument into its final core/stack slots.
 */
enum ArgumentExtension : ubyte
{
    none,
    signExtend,
    zeroExtend,
    unspecifiedUpperBits,
}

/**
 * Result of AAPCS32 Stage B pre-padding/extension.
 *
 * size is always a whole number of 32-bit words and alignment is the alignment
 * of the machine copy used by Stage C.
 */
struct MarshalledArgument
{
    uint size;
    uint alignment;
    ArgumentExtension extension;
    bool indirect;
}

/**
 * Apply Stage B.2/B.5 to a fundamental argument.
 */
MarshalledArgument marshalFundamental(FundamentalArgument type)
{
    final switch (type)
    {
        case FundamentalArgument.signedByte:
        case FundamentalArgument.signedHalf:
            return MarshalledArgument(4, 4, ArgumentExtension.signExtend, false);

        case FundamentalArgument.unsignedByte:
        case FundamentalArgument.unsignedHalf:
            return MarshalledArgument(4, 4, ArgumentExtension.zeroExtend, false);

        case FundamentalArgument.halfFloat:
            return MarshalledArgument(
                4, 4, ArgumentExtension.unspecifiedUpperBits, false);

        case FundamentalArgument.word:
        case FundamentalArgument.pointer:
        case FundamentalArgument.float32:
            return MarshalledArgument(4, 4, ArgumentExtension.none, false);

        case FundamentalArgument.doubleWord:
        case FundamentalArgument.float64:
            return MarshalledArgument(8, 8, ArgumentExtension.none, false);
    }
}

/**
 * Apply Stage B.1/B.4/B.5 to a composite argument.
 *
 * A dynamically-sized composite is replaced by a pointer to a caller copy.
 * A known-size composite is word-rounded and its machine copy is aligned to
 * 4 bytes for natural alignment <= 4, otherwise 8 bytes.
 */
MarshalledArgument marshalComposite(
    uint size,
    uint naturalAlignment,
    bool staticallyKnown = true)
{
    assert(naturalAlignment != 0 &&
        (naturalAlignment & (naturalAlignment - 1)) == 0);

    if (!staticallyKnown)
        return MarshalledArgument(4, 4, ArgumentExtension.none, true);

    assert(size != 0);
    return MarshalledArgument(
        alignUp(size, 4),
        naturalAlignment <= 4 ? 4 : 8,
        ArgumentExtension.none,
        false);
}

/**
 * Placement of one already-marshalled AAPCS32 machine argument.
 *
 * A value may occupy registers, the stack, or both. The latter is needed by
 * AAPCS32 rule C.5 for arguments that straddle r3 and the initial stacked
 * argument area.
 */
struct Placement
{
    enum ubyte noRegister = ubyte.max;
    enum uint noStack = uint.max;

    ubyte firstRegister = noRegister;
    ubyte registerCount;
    uint stackOffset = noStack;
    uint stackBytes;

    @property bool usesRegisters() const
    {
        return registerCount != 0;
    }

    @property bool usesStack() const
    {
        return stackBytes != 0;
    }
}

/**
 * Stateful implementation of AAPCS32 base-PCS argument allocation.
 *
 * Stack offsets are relative to SP at the public call boundary. The caller can
 * use alignedOutgoingStackBytes to reserve an 8-byte-aligned outgoing area.
 */
struct AAPCS32Allocator
{
    private ubyte nextCoreRegister; // NCRN: 0..4, where 4 means no core regs remain
    private uint nextStackOffset;   // NSAA relative to incoming/public-interface SP

    /// AAPCS32 Stage A.4: r0 contains the address of an indirect result.
    void reserveIndirectResult()
    {
        assert(nextCoreRegister == 0);
        assert(nextStackOffset == 0);
        nextCoreRegister = 1;
    }

    /**
     * Place one scalar according to the base PCS.
     *
     * In Android armeabi-v7a softfp, float32 and float64 deliberately take this
     * same path rather than VFP argument registers.
     */
    Placement place(MachineType type)
    {
        final switch (type)
        {
            case MachineType.word:
            case MachineType.pointer:
            case MachineType.float32:
                return placeMachineArgument(4, 4);

            case MachineType.doubleWord:
            case MachineType.float64:
                return placeMachineArgument(8, 8);
        }
    }

    /// Place an argument after Stage B marshalling.
    Placement place(MarshalledArgument argument)
    {
        return placeMachineArgument(argument.size, argument.alignment);
    }

    /**
     * Place an argument after AAPCS32 Stage B has converted it to a machine
     * representation whose size is a whole number of words.
     *
     * Params:
     *   size = marshalled argument size in bytes, rounded to a multiple of 4
     *   alignment = 4 or 8 byte ABI alignment
     */
    Placement placeMachineArgument(uint size, uint alignment)
    {
        assert(size != 0 && (size & 3) == 0);
        assert(alignment == 4 || alignment == 8);
        assert(nextCoreRegister <= 4);

        Placement result;

        // C.3: double-word-aligned arguments start at an even core register.
        if (alignment == 8)
            nextCoreRegister = cast(ubyte)((cast(uint)nextCoreRegister + 1u) & ~1u);

        const uint words = size / 4;
        const uint availableRegisters = 4u - nextCoreRegister;

        // C.4: the complete argument fits in the remaining core registers.
        if (words <= availableRegisters)
        {
            result.firstRegister = nextCoreRegister;
            result.registerCount = cast(ubyte)words;
            nextCoreRegister += cast(ubyte)words;
            return result;
        }

        // C.5: before any stacked argument has been allocated, an argument may
        // be split between the remaining core registers and the stack.
        if (nextCoreRegister < 4 && nextStackOffset == 0)
        {
            const uint registerWords = 4u - nextCoreRegister;
            const uint registerBytes = registerWords * 4;

            result.firstRegister = nextCoreRegister;
            result.registerCount = cast(ubyte)registerWords;
            result.stackOffset = 0;
            result.stackBytes = size - registerBytes;

            nextCoreRegister = 4;
            nextStackOffset = result.stackBytes;
            return result;
        }

        // C.6: once stacking begins, no later argument returns to core regs.
        nextCoreRegister = 4;

        // C.7: preserve double-word stack alignment.
        if (alignment == 8)
            nextStackOffset = alignUp(nextStackOffset, 8);

        // C.8: allocate the complete argument on the stack.
        result.stackOffset = nextStackOffset;
        result.stackBytes = size;
        nextStackOffset += size;
        return result;
    }

    /// Raw bytes occupied by stacked arguments, including ABI padding.
    @property uint stackedArgumentBytes() const
    {
        return nextStackOffset;
    }

    /**
     * Size the caller should reserve for outgoing stacked arguments while
     * retaining AAPCS32's 8-byte SP alignment at a public interface.
     */
    @property uint alignedOutgoingStackBytes() const
    {
        return alignUp(nextStackOffset, 8);
    }
}

/**
 * Base-PCS scalar result placement.
 *
 * A word-sized result (including float in softfp) is returned in r0; a
 * double-word result (including double in softfp) is returned in r0-r1.
 */
Placement resultPlacement(MachineType type)
{
    Placement result;
    result.firstRegister = 0;

    final switch (type)
    {
        case MachineType.word:
        case MachineType.pointer:
        case MachineType.float32:
            result.registerCount = 1;
            return result;

        case MachineType.doubleWord:
        case MachineType.float64:
            result.registerCount = 2;
            return result;
    }
}

private uint alignUp(uint value, uint alignment)
{
    assert(alignment != 0 && (alignment & (alignment - 1)) == 0);
    return (value + alignment - 1) & ~(alignment - 1);
}
