// See ../README.md for information about DMD unit tests.

module arm32mapping;

import dmd.backend.arm32.mapping :
    ArmMappingKind, armMappingSymbolName;

@("AAELF32 mapping symbol names")
unittest
{
    assert(armMappingSymbolName(ArmMappingKind.arm) == "$a");
    assert(armMappingSymbolName(ArmMappingKind.thumb) == "$t");
    assert(armMappingSymbolName(ArmMappingKind.data) == "$d");
}
