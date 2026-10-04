/**
 * AAELF32 mapping-symbol kinds.
 *
 * Mapping symbols describe the interpretation of bytes inside Arm executable
 * sections. They are local STT_NOTYPE symbols with zero size.
 */

module dmd.backend.arm32.mapping;

nothrow:
@safe:

enum ArmMappingKind : ubyte
{
    arm,
    thumb,
    data,
}

const(char)[] armMappingSymbolName(ArmMappingKind kind)
{
    final switch (kind)
    {
        case ArmMappingKind.arm:   return "$a";
        case ArmMappingKind.thumb: return "$t";
        case ArmMappingKind.data:  return "$d";
    }
}
