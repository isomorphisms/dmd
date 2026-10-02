// See ../README.md for information about DMD unit tests.

module arm32frame;

import dmd.backend.arm32.frame :
    FramePlan, canEmitSingleAdjustment, emitEpilogue, emitPrologue, planAndroidFrame;
import dmd.backend.arm32.registers : CoreRegister, coreMask;

@("leaf frame needs no link-register save")
unittest
{
    auto plan = planAndroidFrame(0, false, 0, 0);
    assert(plan.savedCoreMask == 0);
    assert(plan.bodyBytes == 0);
    assert(plan.totalStackBytes == 0);

    auto prologue = emitPrologue(plan);
    assert(prologue.length == 0);

    auto epilogue = emitEpilogue(plan);
    assert(epilogue.length == 1);
    assert(epilogue.words[0] == 0xE12F_FF1E); // bx lr
}

@("non-leaf frame saves modified Android callee registers and LR")
unittest
{
    const modified = coreMask(CoreRegister.r4) | coreMask(CoreRegister.r7);
    auto plan = planAndroidFrame(modified, true, 4, 0);

    assert(plan.savedCoreMask == (
        coreMask(CoreRegister.r4) |
        coreMask(CoreRegister.r7) |
        coreMask(CoreRegister.lr)));
    assert(plan.savedCoreBytes == 12);
    assert(plan.bodyBytes == 4);
    assert(plan.paddingBytes == 0);
    assert(plan.totalStackBytes == 16);

    auto prologue = emitPrologue(plan);
    assert(prologue.length == 2);
    assert(prologue.words[0] == 0xE92D_4090); // push {r4,r7,lr}
    assert(prologue.words[1] == 0xE24D_D004); // sub sp,sp,#4

    auto epilogue = emitEpilogue(plan);
    assert(epilogue.length == 2);
    assert(epilogue.words[0] == 0xE28D_D004); // add sp,sp,#4
    assert(epilogue.words[1] == 0xE8BD_8090); // pop {r4,r7,pc}
}

@("frame planner adds only the padding required for 8-byte public SP alignment")
unittest
{
    auto plan = planAndroidFrame(coreMask(CoreRegister.r4), true, 4, 0);

    // r4 + lr = 8 saved bytes; a 4-byte local needs 4 bytes of padding.
    assert(plan.savedCoreBytes == 8);
    assert(plan.localBytes == 4);
    assert(plan.paddingBytes == 4);
    assert(plan.bodyBytes == 8);
    assert(plan.totalStackBytes == 16);
}

@("volatile modifications do not create callee-save traffic")
unittest
{
    const modified =
        coreMask(CoreRegister.r0) |
        coreMask(CoreRegister.r3) |
        coreMask(CoreRegister.r12);

    auto plan = planAndroidFrame(modified, false, 0, 0);
    assert(plan.savedCoreMask == 0);
}

@("Android preserves r9 as v6")
unittest
{
    auto plan = planAndroidFrame(coreMask(CoreRegister.r9), false, 0, 0);
    assert(plan.savedCoreMask == coreMask(CoreRegister.r9));

    // One 4-byte save needs one extra 4-byte body pad to keep entry/exit SP aligned.
    assert(plan.savedCoreBytes == 4);
    assert(plan.paddingBytes == 4);
    assert(plan.totalStackBytes == 8);

    auto prologue = emitPrologue(plan);
    assert(prologue.length == 2);
    assert(prologue.words[0] == 0xE92D_0200); // push {r9}
    assert(prologue.words[1] == 0xE24D_D004); // sub sp,sp,#4
}

@("outgoing call area participates in the same frame alignment")
unittest
{
    auto plan = planAndroidFrame(0, true, 0, 8);
    assert(plan.savedCoreBytes == 4); // lr
    assert(plan.outgoingBytes == 8);
    assert(plan.paddingBytes == 4);
    assert(plan.bodyBytes == 12);
    assert(plan.totalStackBytes == 16);
}

@("large stack adjustment decomposes into encodable byte-lane chunks")
unittest
{
    auto plan = planAndroidFrame(0, false, 0x1234, 0);
    assert(plan.paddingBytes == 4);
    assert(plan.bodyBytes == 0x1238);
    assert((plan.totalStackBytes & 7) == 0);
    assert(!canEmitSingleAdjustment(plan));

    auto prologue = emitPrologue(plan);
    assert(prologue.length == 2);
    assert(prologue.words[0] == 0xE24D_D038); // sub sp,sp,#0x38
    assert(prologue.words[1] == 0xE24D_DC12); // sub sp,sp,#0x1200

    auto epilogue = emitEpilogue(plan);
    assert(epilogue.length == 3);
    assert(epilogue.words[0] == 0xE28D_D038); // add sp,sp,#0x38
    assert(epilogue.words[1] == 0xE28D_DC12); // add sp,sp,#0x1200
    assert(epilogue.words[2] == 0xE12F_FF1E); // bx lr
}


@("VFP callee saves use one contiguous d-register range")
unittest
{
    const modifiedVfp = (1u << 8) | (1u << 10) | (1u << 15);
    auto plan = planAndroidFrame(0, modifiedVfp, false, 0, 0);

    // d9 and d11-d14 are harmlessly included so one VPUSH/VPOP pair suffices.
    assert(plan.savedVfpFirst == 8);
    assert(plan.savedVfpCount == 8);
    assert(plan.savedVfpBytes == 64);
    assert(plan.totalStackBytes == 64);

    auto prologue = emitPrologue(plan);
    assert(prologue.length == 1);
    assert(prologue.words[0] == 0xED2D_8B10); // vpush {d8-d15}

    auto epilogue = emitEpilogue(plan);
    assert(epilogue.length == 2);
    assert(epilogue.words[0] == 0xECBD_8B10); // vpop {d8-d15}
    assert(epilogue.words[1] == 0xE12F_FF1E); // bx lr
}

@("caller-saved VFP registers do not create frame traffic")
unittest
{
    const modifiedVfp = (1u << 0) | (1u << 7) | (1u << 16) | (1u << 31);
    auto plan = planAndroidFrame(0, modifiedVfp, false, 0, 0);
    assert(!plan.savesVfpRegisters);
    assert(plan.savedVfpBytes == 0);
}

@("core and VFP saves unwind in reverse stack order")
unittest
{
    auto plan = planAndroidFrame(
        coreMask(CoreRegister.r4),
        (1u << 8) | (1u << 9),
        true,
        4,
        0);

    // push {r4,lr} = 8, vpush {d8-d9} = 16, body = 8 including padding.
    assert(plan.savedCoreBytes == 8);
    assert(plan.savedVfpBytes == 16);
    assert(plan.paddingBytes == 4);
    assert(plan.totalStackBytes == 32);

    auto prologue = emitPrologue(plan);
    assert(prologue.length == 3);
    assert(prologue.words[0] == 0xE92D_4010); // push {r4,lr}
    assert(prologue.words[1] == 0xED2D_8B04); // vpush {d8-d9}
    assert(prologue.words[2] == 0xE24D_D008); // sub sp,sp,#8

    auto epilogue = emitEpilogue(plan);
    assert(epilogue.length == 3);
    assert(epilogue.words[0] == 0xE28D_D008); // add sp,sp,#8
    assert(epilogue.words[1] == 0xECBD_8B04); // vpop {d8-d9}
    assert(epilogue.words[2] == 0xE8BD_8010); // pop {r4,pc}
}
