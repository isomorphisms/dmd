// See ../README.md for information about DMD unit tests.

module arm32aapcs;

import dmd.backend.arm32.aapcs :
    AAPCS32Allocator, ArgumentExtension, FundamentalArgument,
    MachineType, Placement, marshalComposite, marshalFundamental,
    resultPlacement;

@("AAPCS32 softfp scalars use core registers")
unittest
{
    AAPCS32Allocator abi;

    auto a = abi.place(MachineType.word);
    assert(a.firstRegister == 0 && a.registerCount == 1 && !a.usesStack);

    auto f = abi.place(MachineType.float32);
    assert(f.firstRegister == 1 && f.registerCount == 1 && !f.usesStack);

    auto d = abi.place(MachineType.float64);
    assert(d.firstRegister == 2 && d.registerCount == 2 && !d.usesStack);

    assert(abi.stackedArgumentBytes == 0);
    assert(abi.alignedOutgoingStackBytes == 0);
}

@("AAPCS32 double words begin at an even core register")
unittest
{
    AAPCS32Allocator abi;

    auto first = abi.place(MachineType.word);
    assert(first.firstRegister == 0);

    auto second = abi.place(MachineType.doubleWord);
    assert(second.firstRegister == 2);
    assert(second.registerCount == 2);
}

@("AAPCS32 stacked scalar area preserves public SP alignment")
unittest
{
    AAPCS32Allocator abi;

    foreach (_; 0 .. 4)
        abi.place(MachineType.word);

    auto fifth = abi.place(MachineType.word);
    assert(fifth.stackOffset == 0 && fifth.stackBytes == 4);
    assert(abi.stackedArgumentBytes == 4);

    // The argument itself needs only four bytes, but SP must still be 8-byte
    // aligned at the call boundary.
    assert(abi.alignedOutgoingStackBytes == 8);
}

@("AAPCS32 stack double words receive 8-byte alignment")
unittest
{
    AAPCS32Allocator abi;

    foreach (_; 0 .. 4)
        abi.place(MachineType.word);

    auto stackedWord = abi.place(MachineType.word);
    assert(stackedWord.stackOffset == 0 && stackedWord.stackBytes == 4);

    auto stackedDouble = abi.place(MachineType.float64);
    assert(stackedDouble.stackOffset == 8 && stackedDouble.stackBytes == 8);
    assert(abi.stackedArgumentBytes == 16);
    assert(abi.alignedOutgoingStackBytes == 16);
}

@("AAPCS32 rule C.5 splits a larger machine argument")
unittest
{
    AAPCS32Allocator abi;

    abi.place(MachineType.word);
    abi.place(MachineType.word);

    // A 12-byte Stage-B argument starts in r2/r3 and finishes at [sp].
    auto composite = abi.placeMachineArgument(12, 4);
    assert(composite.firstRegister == 2);
    assert(composite.registerCount == 2);
    assert(composite.stackOffset == 0);
    assert(composite.stackBytes == 4);

    // Once stack allocation has started, later arguments stay on the stack.
    auto next = abi.place(MachineType.word);
    assert(!next.usesRegisters);
    assert(next.stackOffset == 4 && next.stackBytes == 4);
    assert(abi.alignedOutgoingStackBytes == 8);
}

@("AAPCS32 indirect results reserve r0")
unittest
{
    AAPCS32Allocator abi;
    abi.reserveIndirectResult();

    auto word = abi.place(MachineType.word);
    assert(word.firstRegister == 1 && word.registerCount == 1);

    auto wide = abi.place(MachineType.doubleWord);
    assert(wide.firstRegister == 2 && wide.registerCount == 2);
}

@("AAPCS32 softfp results use r0 and r0-r1")
unittest
{
    auto f = resultPlacement(MachineType.float32);
    assert(f.firstRegister == 0 && f.registerCount == 1 && !f.usesStack);

    auto d = resultPlacement(MachineType.float64);
    assert(d.firstRegister == 0 && d.registerCount == 2 && !d.usesStack);
}


@("AAPCS32 Stage B extends sub-word integral arguments")
unittest
{
    auto sb = marshalFundamental(FundamentalArgument.signedByte);
    assert(sb.size == 4 && sb.alignment == 4);
    assert(sb.extension == ArgumentExtension.signExtend);
    assert(!sb.indirect);

    auto uh = marshalFundamental(FundamentalArgument.unsignedHalf);
    assert(uh.size == 4 && uh.alignment == 4);
    assert(uh.extension == ArgumentExtension.zeroExtend);

    auto hf = marshalFundamental(FundamentalArgument.halfFloat);
    assert(hf.size == 4 && hf.alignment == 4);
    assert(hf.extension == ArgumentExtension.unspecifiedUpperBits);
}

@("AAPCS32 Stage B keeps softfp float machine sizes")
unittest
{
    auto f = marshalFundamental(FundamentalArgument.float32);
    assert(f.size == 4 && f.alignment == 4);
    assert(f.extension == ArgumentExtension.none);

    auto d = marshalFundamental(FundamentalArgument.float64);
    assert(d.size == 8 && d.alignment == 8);
    assert(d.extension == ArgumentExtension.none);
}

@("AAPCS32 Stage B rounds known composites to words")
unittest
{
    auto a = marshalComposite(5, 1);
    assert(a.size == 8 && a.alignment == 4 && !a.indirect);

    auto b = marshalComposite(12, 8);
    assert(b.size == 12 && b.alignment == 8 && !b.indirect);

    auto overAligned = marshalComposite(12, 16);
    assert(overAligned.size == 12 && overAligned.alignment == 8);
}

@("AAPCS32 Stage B replaces dynamic composites by a pointer")
unittest
{
    auto a = marshalComposite(0, 8, false);
    assert(a.size == 4 && a.alignment == 4);
    assert(a.indirect);
    assert(a.extension == ArgumentExtension.none);
}

@("Stage B output feeds Stage C placement directly")
unittest
{
    AAPCS32Allocator abi;

    auto byteArg = marshalFundamental(FundamentalArgument.signedByte);
    auto composite = marshalComposite(8, 8);

    auto a = abi.place(byteArg);
    assert(a.firstRegister == 0 && a.registerCount == 1);

    // Double-word aligned composite skips r1 and occupies r2-r3.
    auto b = abi.place(composite);
    assert(b.firstRegister == 2 && b.registerCount == 2);
}
