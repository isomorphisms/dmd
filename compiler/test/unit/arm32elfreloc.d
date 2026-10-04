// See ../README.md for information about DMD unit tests.

module arm32elfreloc;

import dmd.backend.arm32.elfreloc :
    arm32RelocationPreservesTarget, arm32RelocationSize;
import dmd.backend.melf : R_ARM_CALL;

@("R_ARM_CALL relocates one A32 instruction and keeps its in-place addend")
unittest
{
    assert(arm32RelocationSize(R_ARM_CALL) == 4);
    assert(arm32RelocationPreservesTarget(R_ARM_CALL));
}
