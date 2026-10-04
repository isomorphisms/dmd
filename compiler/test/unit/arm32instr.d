// See ../README.md for information about DMD unit tests.

module arm32instr;

import dmd.backend.arm32.instr : COND, INSTR;

@("A32 register data-processing encodings")
unittest
{
    assert(INSTR.mov_reg(COND.al, 0, 1) == 0xE1A0_0001); // mov r0,r1
    assert(INSTR.add_reg(COND.al, 2, 3, 4) == 0xE083_2004); // add r2,r3,r4
    assert(INSTR.cmp_reg(COND.al, 0, 1) == 0xE150_0001); // cmp r0,r1
    assert(INSTR.mul(COND.al, 0, 1, 2) == 0xE000_0291); // mul r0,r1,r2
}

@("A32 modified immediate encodings")
unittest
{
    uint operand2;
    assert(INSTR.encode_modified_immediate(0x0000_00FF, operand2) && operand2 == 0x0FF);
    assert(INSTR.encode_modified_immediate(0xFF00_0000, operand2) && operand2 == 0x4FF);
    assert(INSTR.encode_modified_immediate(0x0000_0100, operand2) && operand2 == 0xC01);
    assert(INSTR.encode_modified_immediate(0x8000_0000, operand2) && operand2 == 0x102);
    assert(!INSTR.encode_modified_immediate(0x1234_5678, operand2));

    assert(INSTR.mov_imm(COND.al, 0, 0xFF) == 0xE3A0_00FF);
    assert(INSTR.mov_imm(COND.al, 1, 0xFF00_0000) == 0xE3A0_14FF);
    assert(INSTR.add_imm(COND.al, 2, 3, 0x100) == 0xE283_2C01);
    assert(INSTR.sub_imm(COND.al, 4, 5, 0x8000_0000) == 0xE245_4102);
    assert(INSTR.cmp_imm(COND.al, 6, 0x4000_0000) == 0xE356_0101);
}

@("A32 load store and frame encodings")
unittest
{
    assert(INSTR.ldr_imm(COND.al, 0, 1, 12) == 0xE591_000C); // ldr r0,[r1,#12]
    assert(INSTR.str_imm(COND.al, 2, 3, -4) == 0xE503_2004); // str r2,[r3,#-4]

    enum r4 = 1u << 4;
    enum r5 = 1u << 5;
    enum lr = 1u << INSTR.LR;
    enum pc = 1u << INSTR.PC;
    assert(INSTR.push(COND.al, r4 | r5 | lr) == 0xE92D_4030);
    assert(INSTR.pop(COND.al, r4 | r5 | pc) == 0xE8BD_8030);
}

@("A32 branch and constant materialization encodings")
unittest
{
    // A branch to its own instruction address has an encoded displacement of -8.
    assert(INSTR.b(COND.al, 0) == 0xEAFF_FFFE);
    assert(INSTR.bl(COND.al, 0) == 0xEBFF_FFFE);
    assert(INSTR.bx(COND.al, INSTR.LR) == 0xE12F_FF1E);

    assert(INSTR.movw(COND.al, 0, 0x1234) == 0xE301_0234);
    assert(INSTR.movt(COND.al, 0, 0x5678) == 0xE345_0678);
}
