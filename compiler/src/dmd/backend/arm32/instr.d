/**
 * ARM A32 instruction encodings
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/arm32/instr.d, backend/arm32/instr.d)
 */

module dmd.backend.arm32.instr;

nothrow:
@safe:

/**
 * ARM condition codes.
 *
 * The encodings are defined by the A32 instruction set.  Condition code 0xF is
 * reserved for unconditional/special encodings and is not accepted by the
 * ordinary encoders below.
 */
enum COND : ubyte
{
    eq, ne, cs, cc, mi, pl, vs, vc,
    hi, ls, ge, lt, gt, le, al, nv,
}

/**
 * A32 instruction encoders used by the ARM32 backend.
 *
 * Register roles follow AAPCS32:
 * r0-r3 arguments/results/scratch, r4-r8 and r10-r11 callee-saved,
 * r9 platform-specific, r12 intra-procedure scratch, r13 SP, r14 LR, r15 PC.
 *
 * This module only encodes instructions.  Register allocation, ABI policy,
 * object relocations, and ARM/Thumb selection belong to higher backend layers.
 *
 * See_Also:
 * $(LINK2 https://github.com/ARM-software/abi-aa/blob/main/aapcs32/aapcs32.rst, AAPCS32)
 */
struct INSTR
{
    pure nothrow @safe:

    alias reg_t = ubyte;

    enum FP = 11;
    enum IP = 12;
    enum SP = 13;
    enum LR = 14;
    enum PC = 15;

    /// Architectural NOP hint in A32 state.
    enum uint nop = 0xE320_F000;

    private static void check_cond(COND cond)
    {
        assert(cond <= COND.al);
    }

    private static void check_reg(reg_t reg)
    {
        assert(reg < 16);
    }

    private static uint rotate_left(uint value, uint shift)
    {
        assert(shift < 32);
        return shift ? (value << shift) | (value >> (32 - shift)) : value;
    }

    /**
     * Encode an A32 modified immediate (imm8 rotated right by an even count).
     *
     * Returns:
     *   true and sets `operand2` if `value` is directly encodable by an
     *   A32 data-processing-immediate instruction; false otherwise.
     */
    static bool encode_modified_immediate(uint value, out uint operand2)
    {
        for (uint rotate = 0; rotate != 16; ++rotate)
        {
            const uint candidate = rotate_left(value, rotate * 2);
            if ((candidate & ~0xFFu) == 0)
            {
                operand2 = (rotate << 8) | candidate;
                return true;
            }
        }
        operand2 = 0;
        return false;
    }

    private static uint data_processing_reg(
        COND cond, uint opcode, bool setFlags, reg_t Rn, reg_t Rd, reg_t Rm)
    {
        check_cond(cond);
        check_reg(Rn);
        check_reg(Rd);
        check_reg(Rm);
        assert(opcode < 16);

        return (cast(uint)cond << 28) |
               (opcode          << 21) |
               ((setFlags ? 1u : 0u) << 20) |
               (cast(uint)Rn    << 16) |
               (cast(uint)Rd    << 12) |
                cast(uint)Rm;
    }

    private static uint data_processing_imm(
        COND cond, uint opcode, bool setFlags, reg_t Rn, reg_t Rd, uint value)
    {
        uint operand2;
        assert(encode_modified_immediate(value, operand2));
        check_cond(cond);
        check_reg(Rn);
        check_reg(Rd);
        assert(opcode < 16);

        return (cast(uint)cond << 28) |
               (1u              << 25) |
               (opcode          << 21) |
               ((setFlags ? 1u : 0u) << 20) |
               (cast(uint)Rn    << 16) |
               (cast(uint)Rd    << 12) |
                operand2;
    }

    static uint mov_reg(COND cond, reg_t Rd, reg_t Rm)
    {
        return data_processing_reg(cond, 13, false, 0, Rd, Rm);
    }

    static uint add_reg(COND cond, reg_t Rd, reg_t Rn, reg_t Rm)
    {
        return data_processing_reg(cond, 4, false, Rn, Rd, Rm);
    }

    static uint sub_reg(COND cond, reg_t Rd, reg_t Rn, reg_t Rm)
    {
        return data_processing_reg(cond, 2, false, Rn, Rd, Rm);
    }

    static uint cmp_reg(COND cond, reg_t Rn, reg_t Rm)
    {
        return data_processing_reg(cond, 10, true, Rn, 0, Rm);
    }

    static uint mov_imm(COND cond, reg_t Rd, uint value)
    {
        return data_processing_imm(cond, 13, false, 0, Rd, value);
    }

    static uint add_imm(COND cond, reg_t Rd, reg_t Rn, uint value)
    {
        return data_processing_imm(cond, 4, false, Rn, Rd, value);
    }

    static uint sub_imm(COND cond, reg_t Rd, reg_t Rn, uint value)
    {
        return data_processing_imm(cond, 2, false, Rn, Rd, value);
    }

    static uint cmp_imm(COND cond, reg_t Rn, uint value)
    {
        return data_processing_imm(cond, 10, true, Rn, 0, value);
    }

    /**
     * MUL Rd,Rm,Rs.
     */
    static uint mul(COND cond, reg_t Rd, reg_t Rm, reg_t Rs)
    {
        check_cond(cond);
        check_reg(Rd);
        check_reg(Rm);
        check_reg(Rs);

        return (cast(uint)cond << 28) |
               (cast(uint)Rd   << 16) |
               (cast(uint)Rs   <<  8) |
               (9u             <<  4) |
                cast(uint)Rm;
    }

    private static uint load_store_imm(
        COND cond, bool load, bool byteAccess, bool writeback,
        reg_t Rn, reg_t Rt, int offset)
    {
        check_cond(cond);
        check_reg(Rn);
        check_reg(Rt);
        assert(offset >= -4095 && offset <= 4095);

        const bool up = offset >= 0;
        const uint imm12 = cast(uint)(up ? offset : -offset);

        return (cast(uint)cond << 28) |
               (1u              << 26) |
               (1u              << 24) |
               ((up ? 1u : 0u) << 23) |
               ((byteAccess ? 1u : 0u) << 22) |
               ((writeback ? 1u : 0u) << 21) |
               ((load ? 1u : 0u) << 20) |
               (cast(uint)Rn    << 16) |
               (cast(uint)Rt    << 12) |
                imm12;
    }

    static uint ldr_imm(COND cond, reg_t Rt, reg_t Rn, int offset)
    {
        return load_store_imm(cond, true, false, false, Rn, Rt, offset);
    }

    static uint str_imm(COND cond, reg_t Rt, reg_t Rn, int offset)
    {
        return load_store_imm(cond, false, false, false, Rn, Rt, offset);
    }

    static uint ldrb_imm(COND cond, reg_t Rt, reg_t Rn, int offset)
    {
        return load_store_imm(cond, true, true, false, Rn, Rt, offset);
    }

    static uint strb_imm(COND cond, reg_t Rt, reg_t Rn, int offset)
    {
        return load_store_imm(cond, false, true, false, Rn, Rt, offset);
    }

    private static uint block_transfer(
        COND cond, bool pre, bool up, bool writeback, bool load,
        reg_t Rn, uint registers)
    {
        check_cond(cond);
        check_reg(Rn);
        assert(registers != 0 && registers < 0x1_0000);

        return (cast(uint)cond << 28) |
               (4u              << 25) |
               ((pre ? 1u : 0u) << 24) |
               ((up ? 1u : 0u) << 23) |
               ((writeback ? 1u : 0u) << 21) |
               ((load ? 1u : 0u) << 20) |
               (cast(uint)Rn    << 16) |
                registers;
    }

    /// PUSH is the A32 alias for STMDB sp!, register-list.
    static uint push(COND cond, uint registers)
    {
        return block_transfer(cond, true, false, true, false, SP, registers);
    }

    /// POP is the A32 alias for LDMIA sp!, register-list.
    static uint pop(COND cond, uint registers)
    {
        return block_transfer(cond, false, true, true, true, SP, registers);
    }

    /**
     * Encode B/BL using a target displacement measured from the address of the
     * branch instruction itself.  A32 branch immediates are relative to PC,
     * which reads as instruction-address + 8.
     */
    private static uint branch(COND cond, bool link, int targetFromInstruction)
    {
        check_cond(cond);
        assert((targetFromInstruction & 3) == 0);

        const long scaled = (cast(long)targetFromInstruction - 8) / 4;
        assert(scaled >= -0x80_0000 && scaled <= 0x7F_FFFF);

        return (cast(uint)cond << 28) |
               (5u              << 25) |
               ((link ? 1u : 0u) << 24) |
               (cast(uint)scaled & 0x00FF_FFFF);
    }

    static uint b(COND cond, int targetFromInstruction)
    {
        return branch(cond, false, targetFromInstruction);
    }

    static uint bl(COND cond, int targetFromInstruction)
    {
        return branch(cond, true, targetFromInstruction);
    }

    static uint bx(COND cond, reg_t Rm)
    {
        check_cond(cond);
        check_reg(Rm);
        return (cast(uint)cond << 28) | 0x012F_FF10 | cast(uint)Rm;
    }

    static uint blx_reg(COND cond, reg_t Rm)
    {
        check_cond(cond);
        check_reg(Rm);
        return (cast(uint)cond << 28) | 0x012F_FF30 | cast(uint)Rm;
    }

    /**
     * MOVW/MOVT are available on ARMv7-A and let the backend materialize a
     * 32-bit constant without a literal pool.
     */
    private static uint mov_half(COND cond, bool top, reg_t Rd, ushort value)
    {
        check_cond(cond);
        check_reg(Rd);

        return (cast(uint)cond << 28) |
               (0x30u           << 20) |
               ((top ? 1u : 0u) << 22) |
               ((cast(uint)value & 0xF000) << 4) |
               (cast(uint)Rd    << 12) |
               (cast(uint)value & 0x0FFF);
    }

    static uint movw(COND cond, reg_t Rd, ushort value)
    {
        return mov_half(cond, false, Rd, value);
    }

    static uint movt(COND cond, reg_t Rd, ushort value)
    {
        return mov_half(cond, true, Rd, value);
    }
}
