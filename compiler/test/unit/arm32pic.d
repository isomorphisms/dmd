// See ../README.md for information about DMD unit tests.

module arm32pic;

import dmd.backend.arm32.pic : materializePicGotAddress;
import dmd.backend.melf : R_ARM_GOT_PREL;

@("Android A32 PIC GOT load matches Clang layout")
unittest
{
    // Clang 17 for:
    //     extern int ext;
    //     int *f(void) { return &ext; }
    // armv7a-linux-androideabi21 -marm -fPIC -O2 emits:
    //     e59f0004   ldr r0,[pc,#4]
    //     e79f0000   ldr r0,[pc,r0]
    //     e12fff1e   bx lr
    //     00000000   R_ARM_GOT_PREL ext
    auto seq = materializePicGotAddress(0, 12);

    assert(seq.literalLoad == 0xE59F_0004);
    assert(seq.gotLoad == 0xE79F_0000);
    assert(seq.literalAddend == 0);
    assert(seq.literalRelocation == R_ARM_GOT_PREL);
    assert(seq.dataMappingOffset == 12);
    assert(seq.armMappingResumeOffset == 16);
}

@("GOT literal addend compensates for a later literal-pool location")
unittest
{
    auto seq = materializePicGotAddress(3, 20);

    // First PC is I+8, so literal at I+20 uses immediate +12.
    assert(seq.literalLoad == 0xE59F_300C);

    // Second PC is I+12 while relocation place is I+20. An addend of +8
    // makes (I+12) + (GOT + 8 - (I+20)) == GOT.
    assert(seq.gotLoad == 0xE79F_3003);
    assert(seq.literalAddend == 8);
    assert(seq.literalRelocation == R_ARM_GOT_PREL);
    assert(seq.dataMappingOffset == 20);
    assert(seq.armMappingResumeOffset == 24);
}
