/**
 * ARM Thumb-2 instruction encodings
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/arm32/thumb.d, backend/arm32/thumb.d)
 */

module dmd.backend.arm32.thumb;

import dmd.backend.arm32.instr : COND;

nothrow:
@safe:

/**
 * Thumb-2 instruction encoders used by the ARM32 backend.
 *
 * Thumb-2 is a mixed-width instruction set.  T16 encoders return a `ushort`.
 * T32 encoders return a `uint` whose low 16 bits are the first instruction
 * halfword and whose high 16 bits are the second halfword.  Writing that value
 * little-endian therefore produces the architectural halfwords in instruction
 * order.
 *
 * This module only encodes instructions.  ABI policy, relocations, instruction
 * selection, and ARM/Thumb state selection belong to higher backend layers.
 */
struct THUMB
{
    pure nothrow @safe:

    alias reg_t = ubyte;

    enum SP = 13;
    enum LR = 14;
    enum PC = 15;

    /// Architectural NOP hint in Thumb state.
    enum ushort nop = 0xBF00;

    private static void check_low_reg(reg_t reg)
    {
        assert(reg < 8);
    }

    private static void check_reg(reg_t reg)
    {
        assert(reg < 16);
    }

    private static uint pack32(ushort first, ushort second)
    {
        return cast(uint)first | (cast(uint)second << 16);
    }

    /************************ Thumb-16 data processing ************************/

    static ushort movs_imm(reg_t Rd, ubyte imm8)
    {
        check_low_reg(Rd);
        return cast(ushort)(0x2000 | (cast(uint)Rd << 8) | imm8);
    }

    static ushort adds_reg(reg_t Rd, reg_t Rn, reg_t Rm)
    {
        check_low_reg(Rd);
        check_low_reg(Rn);
        check_low_reg(Rm);
        return cast(ushort)(0x1800 |
                           (cast(uint)Rm << 6) |
                           (cast(uint)Rn << 3) |
                            cast(uint)Rd);
    }

    static ushort subs_reg(reg_t Rd, reg_t Rn, reg_t Rm)
    {
        check_low_reg(Rd);
        check_low_reg(Rn);
        check_low_reg(Rm);
        return cast(ushort)(0x1A00 |
                           (cast(uint)Rm << 6) |
                           (cast(uint)Rn << 3) |
                            cast(uint)Rd);
    }

    static ushort adds_imm3(reg_t Rd, reg_t Rn, uint imm3)
    {
        check_low_reg(Rd);
        check_low_reg(Rn);
        assert(imm3 < 8);
        return cast(ushort)(0x1C00 |
                           (imm3         << 6) |
                           (cast(uint)Rn << 3) |
                            cast(uint)Rd);
    }

    static ushort subs_imm3(reg_t Rd, reg_t Rn, uint imm3)
    {
        check_low_reg(Rd);
        check_low_reg(Rn);
        assert(imm3 < 8);
        return cast(ushort)(0x1E00 |
                           (imm3         << 6) |
                           (cast(uint)Rn << 3) |
                            cast(uint)Rd);
    }

    static ushort cmp_imm(reg_t Rn, ubyte imm8)
    {
        check_low_reg(Rn);
        return cast(ushort)(0x2800 | (cast(uint)Rn << 8) | imm8);
    }

    /************************ Thumb-16 loads and stores ***********************/

    private static ushort load_store_word(
        bool load, reg_t Rt, reg_t Rn, uint offset)
    {
        check_low_reg(Rt);
        check_low_reg(Rn);
        assert((offset & 3) == 0 && offset <= 124);
        return cast(ushort)((load ? 0x6800 : 0x6000) |
                           ((offset >> 2) << 6) |
                           (cast(uint)Rn << 3) |
                            cast(uint)Rt);
    }

    static ushort ldr_imm(reg_t Rt, reg_t Rn, uint offset)
    {
        return load_store_word(true, Rt, Rn, offset);
    }

    static ushort str_imm(reg_t Rt, reg_t Rn, uint offset)
    {
        return load_store_word(false, Rt, Rn, offset);
    }

    private static ushort load_store_byte(
        bool load, reg_t Rt, reg_t Rn, uint offset)
    {
        check_low_reg(Rt);
        check_low_reg(Rn);
        assert(offset <= 31);
        return cast(ushort)((load ? 0x7800 : 0x7000) |
                           (offset         << 6) |
                           (cast(uint)Rn   << 3) |
                            cast(uint)Rt);
    }

    static ushort ldrb_imm(reg_t Rt, reg_t Rn, uint offset)
    {
        return load_store_byte(true, Rt, Rn, offset);
    }

    static ushort strb_imm(reg_t Rt, reg_t Rn, uint offset)
    {
        return load_store_byte(false, Rt, Rn, offset);
    }

    private static ushort load_store_half(
        bool load, reg_t Rt, reg_t Rn, uint offset)
    {
        check_low_reg(Rt);
        check_low_reg(Rn);
        assert((offset & 1) == 0 && offset <= 62);
        return cast(ushort)((load ? 0x8800 : 0x8000) |
                           ((offset >> 1) << 6) |
                           (cast(uint)Rn   << 3) |
                            cast(uint)Rt);
    }

    static ushort ldrh_imm(reg_t Rt, reg_t Rn, uint offset)
    {
        return load_store_half(true, Rt, Rn, offset);
    }

    static ushort strh_imm(reg_t Rt, reg_t Rn, uint offset)
    {
        return load_store_half(false, Rt, Rn, offset);
    }

    /************************ Thumb-16 control/frame *************************/

    static ushort push(uint registers)
    {
        assert((registers & ~((1u << 8) - 1 | (1u << LR))) == 0);
        assert(registers != 0);
        return cast(ushort)(0xB400 |
                           (registers & 0xFF) |
                           ((registers & (1u << LR)) ? 0x100 : 0));
    }

    static ushort pop(uint registers)
    {
        assert((registers & ~((1u << 8) - 1 | (1u << PC))) == 0);
        assert(registers != 0);
        return cast(ushort)(0xBC00 |
                           (registers & 0xFF) |
                           ((registers & (1u << PC)) ? 0x100 : 0));
    }

    static ushort bx(reg_t Rm)
    {
        check_reg(Rm);
        return cast(ushort)(0x4700 | (cast(uint)Rm << 3));
    }

    /**
     * Encode a narrow unconditional branch.
     *
     * Params:
     *   targetFromInstruction = target byte displacement measured from the
     *                           address of this branch instruction.
     */
    static ushort b(int targetFromInstruction)
    {
        assert((targetFromInstruction & 1) == 0);
        const int scaled = (targetFromInstruction - 4) / 2;
        assert(scaled >= -1024 && scaled <= 1023);
        return cast(ushort)(0xE000 | (cast(uint)scaled & 0x7FF));
    }

    /**
     * Encode a narrow conditional branch.
     *
     * Condition codes AL and NV have no T16 conditional-branch encoding.
     */
    static ushort b_cond(COND cond, int targetFromInstruction)
    {
        assert(cond <= COND.le);
        assert((targetFromInstruction & 1) == 0);
        const int scaled = (targetFromInstruction - 4) / 2;
        assert(scaled >= -128 && scaled <= 127);
        return cast(ushort)(0xD000 |
                           (cast(uint)cond << 8) |
                           (cast(uint)scaled & 0xFF));
    }

    /************************ Thumb-32 constant materialization **************/

    private static uint mov_half(bool top, reg_t Rd, ushort value)
    {
        check_reg(Rd);
        assert(Rd != PC);

        const uint imm4 = value >> 12;
        const uint i = (value >> 11) & 1;
        const uint imm3 = (value >> 8) & 7;
        const uint imm8 = value & 0xFF;

        const ushort first = cast(ushort)((top ? 0xF2C0 : 0xF240) |
                                          (i << 10) |
                                          imm4);
        const ushort second = cast(ushort)((imm3 << 12) |
                                           (cast(uint)Rd << 8) |
                                            imm8);
        return pack32(first, second);
    }

    static uint movw(reg_t Rd, ushort value)
    {
        return mov_half(false, Rd, value);
    }

    static uint movt(reg_t Rd, ushort value)
    {
        return mov_half(true, Rd, value);
    }
}
