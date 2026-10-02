// See ../README.md for information about DMD unit tests.

module arm32address;

import dmd.backend.arm32.address : materializeAbsoluteAddress;
import dmd.backend.melf : R_ARM_MOVT_ABS, R_ARM_MOVW_ABS_NC;

@("A32 absolute symbol address uses MOVW then MOVT relocations")
unittest
{
    auto seq = materializeAbsoluteAddress(0);

    assert(seq.instructions[0].word == 0xE300_0000); // movw r0,#0
    assert(seq.instructions[0].relocation == R_ARM_MOVW_ABS_NC);

    assert(seq.instructions[1].word == 0xE340_0000); // movt r0,#0
    assert(seq.instructions[1].relocation == R_ARM_MOVT_ABS);
}

@("MOVW and MOVT carry the same signed REL addend")
unittest
{
    auto seq = materializeAbsoluteAddress(2, -4);

    assert(seq.instructions[0].word == 0xE30F_2FFC); // movw r2,#0xfffc
    assert(seq.instructions[1].word == 0xE34F_2FFC); // movt r2,#0xfffc

    assert(seq.instructions[0].relocation == R_ARM_MOVW_ABS_NC);
    assert(seq.instructions[1].relocation == R_ARM_MOVT_ABS);
}
