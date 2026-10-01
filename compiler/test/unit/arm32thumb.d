// See ../README.md for information about DMD unit tests.

module arm32thumb;

import dmd.backend.arm32.instr : COND;
import dmd.backend.arm32.thumb : THUMB;

@("Thumb16 data-processing encodings")
unittest
{
    assert(THUMB.movs_imm(0, 7) == 0x2007);
    assert(THUMB.adds_imm3(0, 0, 1) == 0x1C40);
    assert(THUMB.subs_imm3(1, 1, 2) == 0x1E89);
    assert(THUMB.adds_reg(3, 1, 2) == 0x188B);
    assert(THUMB.subs_reg(3, 1, 2) == 0x1A8B);
    assert(THUMB.cmp_imm(0, 9) == 0x2809);
}

@("Thumb16 load store encodings")
unittest
{
    assert(THUMB.ldr_imm(0, 1, 12) == 0x68C8);
    assert(THUMB.str_imm(2, 3, 4) == 0x605A);
    assert(THUMB.ldrb_imm(4, 5, 7) == 0x79EC);
    assert(THUMB.strb_imm(4, 5, 7) == 0x71EC);
    assert(THUMB.ldrh_imm(6, 7, 6) == 0x88FE);
    assert(THUMB.strh_imm(6, 7, 6) == 0x80FE);
}

@("Thumb16 frame and branch encodings")
unittest
{
    enum r4 = 1u << 4;
    enum r5 = 1u << 5;
    enum lr = 1u << THUMB.LR;
    enum pc = 1u << THUMB.PC;

    assert(THUMB.push(r4 | r5 | lr) == 0xB530);
    assert(THUMB.pop(r4 | r5 | pc) == 0xBD30);
    assert(THUMB.bx(THUMB.LR) == 0x4770);

    // At address P, T16 branches use P + 4 as their PC value.
    assert(THUMB.b(2) == 0xE7FF);
    assert(THUMB.b_cond(COND.eq, 4) == 0xD000);
    assert(THUMB.b_cond(COND.ne, 2) == 0xD1FF);
}

@("Thumb32 MOVW MOVT encodings")
unittest
{
    // Low halfword is the first architectural halfword.  Written little-endian:
    // 0x2234_F241 -> bytes 41 f2 34 22 -> movw r2,#0x1234.
    assert(THUMB.movw(2, 0x1234) == 0x2234_F241);
    assert(THUMB.movt(2, 0x5678) == 0x6278_F2C5);
}
