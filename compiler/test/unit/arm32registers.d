// See ../README.md for information about DMD unit tests.

module arm32registers;

import dmd.backend.arm32.registers;

@("AAPCS32 and Android core register policy")
unittest
{
    assert(argumentCoreMask == 0x000F);
    assert(callerSavedCoreMask == 0x100F);

    assert(aapcsCalleeSavedCoreMask == 0x0DF0);
    assert(androidCalleeSavedCoreMask == 0x0FF0);

    assert((aapcsCalleeSavedCoreMask & coreMask(CoreRegister.r9)) == 0);
    assert((androidCalleeSavedCoreMask & coreMask(CoreRegister.r9)) != 0);

    assert(linkRegisterMask == 0x4000);
    assert(programCounterMask == 0x8000);
}

@("AAPCS32 VFP preservation policy")
unittest
{
    assert(vfpCalleeSavedDMask == 0x0000_FF00u);
    assert((vfpCalleeSavedDMask & (1u << 8)) != 0);
    assert((vfpCalleeSavedDMask & (1u << 15)) != 0);
    assert((vfpCalleeSavedDMask & (1u << 7)) == 0);
    assert((vfpCallerSavedDMask & vfpCalleeSavedDMask) == 0);
}
