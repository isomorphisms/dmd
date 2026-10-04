/**
 * AEABI build attributes for the Android armeabi-v7a target.
 *
 * The payload is intentionally conservative: ARMv7-A, Thumb-2 capability,
 * VFPv3-D16, base/softfp PCS, r9 as v6, PC-relative data, GOT-indirect,
 * 8-byte ABI alignment, and no NEON requirement.
 *
 * It omits Tag_conformance because this backend is still under construction.
 */

module dmd.backend.arm32.attributes;

nothrow:
@safe:

static immutable ubyte[52] androidArmeabiV7aAttributes =
[
    0x41,                         // format version 'A'
    0x33, 0x00, 0x00, 0x00,     // vendor subsection length: 51
    0x61, 0x65, 0x61, 0x62, 0x69, 0x00, // "aeabi\0"
    0x01,                         // Tag_File
    0x29, 0x00, 0x00, 0x00,     // file subsection length: 41

    0x06, 0x0A,                   // Tag_CPU_arch = v7
    0x07, 0x41,                   // Tag_CPU_arch_profile = Application
    0x08, 0x01,                   // Tag_ARM_ISA_use = Yes
    0x09, 0x02,                   // Tag_THUMB_ISA_use = Thumb-2
    0x0A, 0x04,                   // Tag_FP_arch = VFPv3-D16
    0x0E, 0x00,                   // Tag_ABI_PCS_R9_use = v6
    0x0F, 0x01,                   // Tag_ABI_PCS_RW_data = PC-relative
    0x10, 0x01,                   // Tag_ABI_PCS_RO_data = PC-relative
    0x11, 0x02,                   // Tag_ABI_PCS_GOT_use = GOT-indirect
    0x12, 0x04,                   // Tag_ABI_PCS_wchar_t = 4
    0x14, 0x01,                   // Tag_ABI_FP_denormal = Needed
    0x15, 0x00,                   // Tag_ABI_FP_exceptions = Unused
    0x17, 0x03,                   // Tag_ABI_FP_number_model = IEEE 754
    0x18, 0x01,                   // Tag_ABI_align_needed = 8-byte
    0x19, 0x01,                   // Tag_ABI_align_preserved = 8-byte except leaf SP
    0x1A, 0x02,                   // Tag_ABI_enum_size = int
    0x22, 0x01,                   // Tag_CPU_unaligned_access = v6
    0x26, 0x01,                   // Tag_ABI_FP_16bit_format = IEEE 754
];
