// See ../README.md for information about DMD unit tests.

module arm32elfreloc;

import dmd.backend.arm32.elfreloc :
    arm32AbsoluteMovRelocation,
    arm32RelocationPreservesTarget,
    arm32RelocationSize;
import dmd.backend.melf :
    R_ARM_CALL, R_ARM_MOVT_ABS, R_ARM_MOVW_ABS_NC;

@("implemented A32 instruction relocations preserve their REL addends")
unittest
{
    foreach (type; [R_ARM_CALL, R_ARM_MOVW_ABS_NC, R_ARM_MOVT_ABS])
    {
        assert(arm32RelocationSize(type) == 4);
        assert(arm32RelocationPreservesTarget(type));
    }
}

@("absolute A32 address halves select MOVW then MOVT relocations")
unittest
{
    assert(arm32AbsoluteMovRelocation(false) == R_ARM_MOVW_ABS_NC);
    assert(arm32AbsoluteMovRelocation(true) == R_ARM_MOVT_ABS);
}
